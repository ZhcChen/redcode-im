package app

import (
	"context"
	"encoding/json"
	"net/http"

	"desktop-el-core/internal/auth"
	"desktop-el-core/internal/bootstrap"
	"desktop-el-core/internal/chat"
	"desktop-el-core/internal/config"
	"desktop-el-core/internal/eventbus"
	"desktop-el-core/internal/friend"
	"desktop-el-core/internal/httpclient"
	"desktop-el-core/internal/rpc"
	"desktop-el-core/internal/session"
	"desktop-el-core/internal/settings"
	"desktop-el-core/internal/state"
	"desktop-el-core/internal/user"
	"desktop-el-core/internal/ws"
)

type App struct {
	config       config.Config
	bus          *eventbus.Bus
	bootstrap    *bootstrap.Service
	encoder      *rpc.Encoder
	httpClient   *httpclient.Client
	session      *session.Service
	authService  *auth.Service
	settings     *settings.Service
	chat         *chat.Service
	friend       *friend.Service
	userService  *user.Service
	wsClient     *ws.Client
	wsDispatcher *ws.Dispatcher
}

type httpRequestParams struct {
	Method      string            `json:"method"`
	Path        string            `json:"path"`
	Headers     map[string]string `json:"headers,omitempty"`
	QueryParams map[string]string `json:"query_params,omitempty"`
	Body        map[string]any    `json:"body,omitempty"`
	InjectToken *bool             `json:"inject_token,omitempty"`
}

type latestVersionParams struct {
	Platform       string `json:"platform,omitempty"`
	Channel        string `json:"channel,omitempty"`
	CurrentVersion string `json:"current_version,omitempty"`
}

type wsConnectParams struct {
	URL   string `json:"url,omitempty"`
	Token string `json:"token"`
}

func New(cfg config.Config, bus *eventbus.Bus, bootstrapService *bootstrap.Service, encoder *rpc.Encoder) *App {
	sessionService := session.New()
	httpTransport := httpclient.New(httpclient.Config{
		BaseURL: cfg.APIBaseURL,
	})

	return &App{
		config:       cfg,
		bus:          bus,
		bootstrap:    bootstrapService,
		encoder:      encoder,
		httpClient:   httpTransport,
		session:      sessionService,
		authService:  auth.New(httpTransport, sessionService),
		settings:     settings.New(httpTransport),
		chat:         chat.New(httpTransport),
		friend:       friend.New(httpTransport),
		userService:  user.New(httpTransport, sessionService),
		wsClient:     ws.NewClient(),
		wsDispatcher: ws.NewDispatcher(bus),
	}
}

func (a *App) RegisterRPC() *rpc.Server {
	server := rpc.NewServer()

	server.Register("core.ping", func(_ context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		return map[string]any{
			"ok":          true,
			"app_name":    a.config.AppName,
			"environment": a.config.Environment,
		}, nil
	})

	server.Register("core.bootstrap.get", func(_ context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		return a.buildBootstrapSnapshot(), nil
	})

	server.Register("core.config.get", func(_ context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		return map[string]any{
			"api_base_url": a.config.APIBaseURL,
			"ws_url":       a.config.WSURL,
			"version":      a.config.AppVersion,
			"build_number": a.config.BuildNumber,
			"channel":      a.config.Channel,
			"app_name":     a.config.AppName,
			"environment":  a.config.Environment,
		}, nil
	})

	server.Register("http.request", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var request httpRequestParams
		if err := unmarshalParams(params, &request); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		injectToken := true
		if request.InjectToken != nil {
			injectToken = *request.InjectToken
		}

		response, err := a.httpClient.Do(ctx, httpclient.Request{
			Method:      request.Method,
			Path:        request.Path,
			Headers:     request.Headers,
			Query:       request.QueryParams,
			Body:        request.Body,
			InjectToken: boolPtr(injectToken),
		})
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return response, nil
	})

	server.Register("auth.login", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload auth.LoginParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.authService.LoginEnvelope(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("auth.login.sms", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload auth.SMSLoginParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.authService.LoginWithSMSEnvelope(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("auth.register", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload auth.RegisterParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.authService.Register(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("auth.sms.send", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload auth.SendSMSParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.authService.SendLoginSMS(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("auth.me.get", func(ctx context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		result, err := a.authService.GetCurrentUser(ctx)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("auth.logout", func(ctx context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		a.session.Clear()
		a.httpClient.SetToken("")
		if err := a.wsClient.Disconnect(); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		_ = a.emitEvent(ctx, "ws.status.updated", map[string]any{"status": string(a.wsClient.Status())})
		return map[string]any{"success": true}, nil
	})

	server.Register("user.me.update", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload user.UpdateMeParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.userService.UpdateMe(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("user.search", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload user.SearchUsersParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.userService.SearchUsers(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("settings.captcha.get", func(ctx context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		result, err := a.settings.GetCaptchaSetting(ctx)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("settings.privacy.get", func(ctx context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		result, err := a.settings.GetPrivacyPolicy(ctx)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("settings.user-agreement.get", func(ctx context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		result, err := a.settings.GetUserAgreement(ctx)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("settings.app-name.get", func(ctx context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		result, err := a.settings.GetAppName(ctx)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("settings.general.get", func(ctx context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		result, err := a.settings.GetGeneralSettings(ctx)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.list", func(ctx context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		result, err := a.chat.ListChats(ctx)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.private.ensure", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.EnsurePrivateChatParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.EnsurePrivateChat(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.create", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.CreateGroupParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.CreateGroup(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.room.get", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.RoomParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.GetRoom(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.room.members.list", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.RoomParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.ListRoomMembers(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.room.members.add", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.AddRoomMembersParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.AddRoomMembers(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.room.member.remove", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.RemoveRoomMemberParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.RemoveRoomMember(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.owner.transfer", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.TransferRoomOwnerParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.TransferRoomOwner(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.admins.list", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.RoomParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.ListGroupAdmins(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.admin.appoint", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.AppointGroupAdminParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.AppointGroupAdmin(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.admin.remove", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.RemoveGroupAdminParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.RemoveGroupAdmin(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.join_requests.list", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.RoomParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.ListGroupJoinRequests(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.join_request.review", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.ReviewGroupJoinRequestParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.ReviewGroupJoinRequest(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.mutes.list", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.RoomParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.ListGroupMutes(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.mute.create", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.MuteGroupMemberParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.CreateGroupMute(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.mute.remove", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.RemoveGroupMuteParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.RemoveGroupMute(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.rules.list", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.RoomParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.ListGroupRules(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.rule.create", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.CreateGroupRuleParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.CreateGroupRule(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.rule.update", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.UpdateGroupRuleParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.UpdateGroupRule(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.rule.delete", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.DeleteGroupRuleParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.DeleteGroupRule(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.operation_logs.list", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.ListGroupOperationLogsParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.ListGroupOperationLogs(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.settings.get", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.RoomParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.GetGroupSettings(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.settings.global_mute.update", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.UpdateGlobalMuteParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.UpdateGroupGlobalMute(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.group.settings.update", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.UpdateGroupSettingsParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.UpdateGroupSettings(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.messages.list", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.ListMessagesParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.ListMessages(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.send", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.SendMessageParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.SendMessage(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.forward", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.ForwardMessageParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.ForwardMessage(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.read_until", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.MarkReadUntilParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.MarkReadUntil(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.delete", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.DeleteMessageParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.DeleteMessage(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.attachment.signature", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.AttachmentSignatureParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.RequestAttachmentSignature(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.attachment.multipart.initiate", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.AttachmentMultipartInitiateParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.InitiateAttachmentMultipartUpload(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.attachment.multipart.part_signature", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.MultipartPartSignatureParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.GenerateMultipartPartSignature(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.attachment.multipart.part_commit", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.MultipartPartCommitParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.CommitMultipartPart(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.attachment.multipart.complete", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.MultipartCompleteParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.CompleteMultipartUpload(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.attachment.multipart.abort", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.MultipartAbortParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.AbortMultipartUpload(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.attachment.download_url", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.AttachmentDownloadURLParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.GetAttachmentDownloadURL(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("chat.attachment.upload.commit", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload chat.AttachmentUploadCommitParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.chat.CommitAttachmentUpload(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("friend.list", func(ctx context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		result, err := a.friend.ListFriends(ctx)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("friend.requests.list", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload friend.ListFriendRequestsParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.friend.ListFriendRequests(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("friend.request.respond", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload friend.RespondFriendRequestParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.friend.RespondFriendRequest(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("friend.request.create", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload friend.CreateFriendRequestParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.friend.CreateFriendRequest(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("friend.remark.update", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload friend.UpdateFriendRemarkParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.friend.UpdateFriendRemark(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("friend.delete", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload friend.DeleteFriendParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		result, err := a.friend.DeleteFriend(ctx, payload)
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return result, nil
	})

	server.Register("version.latest.get", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload latestVersionParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		channel := payload.Channel
		if channel == "" {
			channel = a.config.Channel
		}
		platform := payload.Platform
		if platform == "" {
			platform = "macos"
		}

		response, err := a.httpClient.Do(ctx, httpclient.Request{
			Method: http.MethodGet,
			Path:   "/versions/latest",
			Query: map[string]string{
				"platform":        platform,
				"channel":         channel,
				"current_version": payload.CurrentVersion,
			},
			InjectToken: boolPtr(false),
		})
		if err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		return response, nil
	})

	server.Register("ws.connect", func(ctx context.Context, params json.RawMessage) (any, *rpc.RPCError) {
		var payload wsConnectParams
		if err := unmarshalParams(params, &payload); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInvalidParams, err.Error())
		}
		wsURL := payload.URL
		if wsURL == "" {
			wsURL = a.config.WSURL
		}
		if err := a.wsClient.Connect(ctx, ws.ConnectParams{
			URL:   wsURL,
			Token: payload.Token,
		}); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		a.startWSPump()
		_ = a.emitEvent(ctx, "ws.status.updated", map[string]any{"status": string(a.wsClient.Status())})
		return map[string]any{"status": string(a.wsClient.Status())}, nil
	})

	server.Register("ws.disconnect", func(ctx context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		if err := a.wsClient.Disconnect(); err != nil {
			return nil, rpc.NewRPCError(rpc.ErrCodeInternal, err.Error())
		}
		_ = a.emitEvent(ctx, "ws.status.updated", map[string]any{"status": string(a.wsClient.Status())})
		return map[string]any{"status": string(a.wsClient.Status())}, nil
	})

	server.Register("ws.status.get", func(_ context.Context, _ json.RawMessage) (any, *rpc.RPCError) {
		return map[string]any{"status": string(a.wsClient.Status())}, nil
	})

	return server
}

func (a *App) EmitBootstrapSnapshot(ctx context.Context) error {
	snapshot := a.buildBootstrapSnapshot()
	a.bus.Publish(ctx, eventbus.Event{
		Name: "core.bootstrap.snapshot",
		Data: snapshot,
	})

	return a.encoder.EncodeEvent(rpc.Event{
		Type:  rpc.TypeEvent,
		Event: "core.bootstrap.snapshot",
		Data:  mustJSONRaw(snapshot),
	})
}

func (a *App) emitEvent(ctx context.Context, name string, data any) error {
	a.wsDispatcher.PublishStatus(ctx, a.wsClient.Status())
	return a.encoder.EncodeEvent(rpc.Event{
		Type:  rpc.TypeEvent,
		Event: name,
		Data:  mustJSONRaw(data),
	})
}

func (a *App) emitWSPush(ctx context.Context, data map[string]any) error {
	a.wsDispatcher.PublishPush(ctx, data)
	return a.encoder.EncodeEvent(rpc.Event{
		Type:  rpc.TypeEvent,
		Event: "ws.push",
		Data:  mustJSONRaw(data),
	})
}

func (a *App) startWSPump() {
	go func() {
		for {
			payload, err := a.wsClient.ReadMessage(context.Background())
			if err != nil {
				return
			}

			var data map[string]any
			if err := json.Unmarshal(payload, &data); err != nil {
				continue
			}

			_ = a.emitWSPush(context.Background(), data)
		}
	}()
}

func (a *App) buildBootstrapSnapshot() state.BootstrapSnapshot {
	snapshot := a.bootstrap.BuildSnapshot()
	snapshot.Connection.Status = string(a.wsClient.Status())
	snapshot.Auth = state.AuthSnapshot{
		LoggedIn: a.session.AccessToken() != "",
	}
	if currentUser := a.session.CurrentUser(); currentUser != nil {
		snapshot.Auth.CurrentUser = currentUser
	}
	return snapshot
}

func mustJSONRaw(v any) json.RawMessage {
	data, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return data
}

func unmarshalParams(raw json.RawMessage, target any) error {
	if len(raw) == 0 || string(raw) == "null" {
		return nil
	}
	return json.Unmarshal(raw, target)
}

func boolPtr(value bool) *bool {
	return &value
}
