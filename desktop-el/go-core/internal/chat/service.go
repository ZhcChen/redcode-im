package chat

import (
	"context"
	"net/http"
	"strconv"

	"desktop-el-core/internal/httpclient"
)

type EnsurePrivateChatParams struct {
	FriendUserID string `json:"friend_user_id"`
}

type CreateGroupParams struct {
	Name          string   `json:"name"`
	MemberUserIDs []string `json:"member_user_ids"`
}

type RoomParams struct {
	RoomID string `json:"room_id"`
}

type UpdateGlobalMuteParams struct {
	RoomID          string `json:"room_id"`
	Enabled         bool   `json:"enabled"`
	Reason          string `json:"reason,omitempty"`
	DurationMinutes int64  `json:"duration_minutes,omitempty"`
}

type UpdateGroupSettingsParams struct {
	RoomID                    string `json:"room_id"`
	JoinApprovalRequired      *bool  `json:"join_approval_required,omitempty"`
	MemberCanInvite           *bool  `json:"member_can_invite,omitempty"`
	MemberCanAddFriends       *bool  `json:"member_can_add_friends,omitempty"`
	RequireAdminToAddFriends  *bool  `json:"require_admin_to_add_friends,omitempty"`
	MaxMembers                *int   `json:"max_members,omitempty"`
}

type ListMessagesParams struct {
	RoomID   string `json:"room_id"`
	Limit    int    `json:"limit,omitempty"`
	BeforeID string `json:"before_id,omitempty"`
	SinceID  string `json:"since_id,omitempty"`
}

type SendMessageParams struct {
	RoomID          string               `json:"room_id"`
	Content         string               `json:"content,omitempty"`
	Parts           []MessagePartPayload `json:"parts,omitempty"`
	QuotedMessageID string               `json:"quoted_message_id,omitempty"`
}

type MarkReadUntilParams struct {
	RoomID    string `json:"room_id"`
	MessageID string `json:"message_id"`
}

type DeleteMessageParams struct {
	RoomID    string `json:"room_id"`
	MessageID string `json:"message_id"`
}

type AttachmentDownloadURLParams struct {
	RoomID           string `json:"room_id"`
	Key              string `json:"key"`
	ExpiresInSeconds int    `json:"expires_in_seconds,omitempty"`
}

type MessagePartPayload struct {
	Type         string `json:"type"`
	Text         string `json:"text,omitempty"`
	Key          string `json:"key,omitempty"`
	Name         string `json:"name,omitempty"`
	Mime         string `json:"mime,omitempty"`
	Size         int64  `json:"size,omitempty"`
	Width        int    `json:"width,omitempty"`
	Height       int    `json:"height,omitempty"`
	DurationMS   int    `json:"duration_ms,omitempty"`
	ThumbnailKey string `json:"thumbnail_key,omitempty"`
}

type AttachmentSignatureParams struct {
	RoomID      string `json:"room_id"`
	PartType    string `json:"part_type"`
	Filename    string `json:"filename,omitempty"`
	ContentType string `json:"content_type,omitempty"`
	FileSize    int64  `json:"file_size,omitempty"`
	HashValue   string `json:"hash_value,omitempty"`
	HashAlg     int    `json:"hash_alg,omitempty"`
}

type AttachmentMultipartInitiateParams struct {
	RoomID      string `json:"room_id"`
	PartType    string `json:"part_type"`
	Filename    string `json:"filename,omitempty"`
	ContentType string `json:"content_type,omitempty"`
	FileSize    int64  `json:"file_size"`
	HashValue   string `json:"hash_value,omitempty"`
	HashAlg     int    `json:"hash_alg,omitempty"`
}

type MultipartPartSignatureParams struct {
	SessionID  string `json:"session_id"`
	PartNumber int    `json:"part_number"`
}

type MultipartPartCommitParams struct {
	SessionID  string `json:"session_id"`
	PartNumber int    `json:"part_number"`
	ETag       string `json:"etag"`
}

type MultipartCompletedPart struct {
	PartNumber int    `json:"part_number"`
	ETag       string `json:"etag"`
}

type MultipartCompleteParams struct {
	SessionID string                   `json:"session_id"`
	Parts     []MultipartCompletedPart `json:"parts"`
}

type AttachmentUploadCommitParams struct {
	RoomID    string `json:"room_id"`
	Key       string `json:"key"`
	HashValue string `json:"hash_value,omitempty"`
	HashAlg   int    `json:"hash_alg,omitempty"`
	FileSize  int64  `json:"file_size,omitempty"`
}

type MultipartAbortParams struct {
	SessionID string `json:"session_id"`
}

type Service struct {
	client *httpclient.Client
}

func New(client *httpclient.Client) *Service {
	return &Service{client: client}
}

func (s *Service) ListChats(ctx context.Context) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/chats",
	})
}

func (s *Service) EnsurePrivateChat(ctx context.Context, params EnsurePrivateChatParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/friends/" + params.FriendUserID + "/chat",
		Body:   map[string]any{},
	})
}

func (s *Service) CreateGroup(ctx context.Context, params CreateGroupParams) (httpclient.Response, error) {
	body := map[string]any{
		"name":       params.Name,
		"member_ids": params.MemberUserIDs,
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/rooms",
		Body:   body,
	})
}

func (s *Service) GetRoom(ctx context.Context, params RoomParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/rooms/" + params.RoomID,
	})
}

func (s *Service) ListRoomMembers(ctx context.Context, params RoomParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/rooms/" + params.RoomID + "/members",
	})
}

func (s *Service) GetGroupSettings(ctx context.Context, params RoomParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/rooms/" + params.RoomID + "/settings",
	})
}

func (s *Service) UpdateGroupGlobalMute(ctx context.Context, params UpdateGlobalMuteParams) (httpclient.Response, error) {
	body := map[string]any{
		"enabled": params.Enabled,
	}
	if params.Reason != "" {
		body["reason"] = params.Reason
	}
	if params.DurationMinutes > 0 {
		body["duration_minutes"] = params.DurationMinutes
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/rooms/" + params.RoomID + "/mutes/global",
		Body:   body,
	})
}

func (s *Service) UpdateGroupSettings(ctx context.Context, params UpdateGroupSettingsParams) (httpclient.Response, error) {
	body := map[string]any{}
	if params.JoinApprovalRequired != nil {
		body["join_approval_required"] = *params.JoinApprovalRequired
	}
	if params.MemberCanInvite != nil {
		body["member_can_invite"] = *params.MemberCanInvite
	}
	if params.MemberCanAddFriends != nil {
		body["member_can_add_friends"] = *params.MemberCanAddFriends
	}
	if params.RequireAdminToAddFriends != nil {
		body["require_admin_to_add_friends"] = *params.RequireAdminToAddFriends
	}
	if params.MaxMembers != nil {
		body["max_members"] = *params.MaxMembers
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPatch,
		Path:   "/rooms/" + params.RoomID + "/settings",
		Body:   body,
	})
}

func (s *Service) ListMessages(ctx context.Context, params ListMessagesParams) (httpclient.Response, error) {
	query := map[string]string{}
	if params.Limit > 0 {
		query["limit"] = strconv.Itoa(params.Limit)
	}
	if params.BeforeID != "" {
		query["before_id"] = params.BeforeID
	}
	if params.SinceID != "" {
		query["since_id"] = params.SinceID
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/rooms/" + params.RoomID + "/messages",
		Query:  query,
	})
}

func (s *Service) SendMessage(ctx context.Context, params SendMessageParams) (httpclient.Response, error) {
	body := map[string]any{}
	if params.Content != "" {
		body["content"] = params.Content
	}
	if len(params.Parts) > 0 {
		body["parts"] = params.Parts
	}
	if params.QuotedMessageID != "" {
		body["quoted_message_id"] = params.QuotedMessageID
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/rooms/" + params.RoomID + "/messages",
		Body:   body,
	})
}

func (s *Service) MarkReadUntil(ctx context.Context, params MarkReadUntilParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/rooms/" + params.RoomID + "/messages/read_until",
		Body: map[string]any{
			"message_id": params.MessageID,
		},
	})
}

func (s *Service) DeleteMessage(ctx context.Context, params DeleteMessageParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodDelete,
		Path:   "/rooms/" + params.RoomID + "/messages/" + params.MessageID,
	})
}

func (s *Service) GetAttachmentDownloadURL(ctx context.Context, params AttachmentDownloadURLParams) (httpclient.Response, error) {
	query := map[string]string{
		"key": params.Key,
	}
	if params.ExpiresInSeconds > 0 {
		query["expires_in_seconds"] = strconv.Itoa(params.ExpiresInSeconds)
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodGet,
		Path:   "/rooms/" + params.RoomID + "/messages/attachments/download",
		Query:  query,
	})
}

func (s *Service) RequestAttachmentSignature(ctx context.Context, params AttachmentSignatureParams) (httpclient.Response, error) {
	body := map[string]any{
		"part_type": params.PartType,
	}
	if params.Filename != "" {
		body["filename"] = params.Filename
	}
	if params.ContentType != "" {
		body["content_type"] = params.ContentType
	}
	if params.FileSize > 0 {
		body["file_size"] = params.FileSize
	}
	if params.HashValue != "" {
		body["hash_value"] = params.HashValue
	}
	if params.HashAlg > 0 {
		body["hash_alg"] = params.HashAlg
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/rooms/" + params.RoomID + "/messages/attachments/signature",
		Body:   body,
	})
}

func (s *Service) InitiateAttachmentMultipartUpload(ctx context.Context, params AttachmentMultipartInitiateParams) (httpclient.Response, error) {
	body := map[string]any{
		"part_type": params.PartType,
		"file_size": params.FileSize,
	}
	if params.Filename != "" {
		body["filename"] = params.Filename
	}
	if params.ContentType != "" {
		body["content_type"] = params.ContentType
	}
	if params.HashValue != "" {
		body["hash_value"] = params.HashValue
	}
	if params.HashAlg > 0 {
		body["hash_alg"] = params.HashAlg
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/rooms/" + params.RoomID + "/messages/attachments/multipart/initiate",
		Body:   body,
	})
}

func (s *Service) GenerateMultipartPartSignature(ctx context.Context, params MultipartPartSignatureParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/uploads/multipart/sessions/" + params.SessionID + "/parts/signature",
		Body: map[string]any{
			"part_number": params.PartNumber,
		},
	})
}

func (s *Service) CommitMultipartPart(ctx context.Context, params MultipartPartCommitParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/uploads/multipart/sessions/" + params.SessionID + "/parts/commit",
		Body: map[string]any{
			"part_number": params.PartNumber,
			"etag":        params.ETag,
		},
	})
}

func (s *Service) CompleteMultipartUpload(ctx context.Context, params MultipartCompleteParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/uploads/multipart/sessions/" + params.SessionID + "/complete",
		Body: map[string]any{
			"parts": params.Parts,
		},
	})
}

func (s *Service) AbortMultipartUpload(ctx context.Context, params MultipartAbortParams) (httpclient.Response, error) {
	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/uploads/multipart/sessions/" + params.SessionID + "/abort",
		Body:   map[string]any{},
	})
}

func (s *Service) CommitAttachmentUpload(ctx context.Context, params AttachmentUploadCommitParams) (httpclient.Response, error) {
	body := map[string]any{
		"key": params.Key,
	}
	if params.HashValue != "" {
		body["hash_value"] = params.HashValue
	}
	if params.HashAlg > 0 {
		body["hash_alg"] = params.HashAlg
	}
	if params.FileSize > 0 {
		body["file_size"] = params.FileSize
	}

	return s.client.Do(ctx, httpclient.Request{
		Method: http.MethodPost,
		Path:   "/rooms/" + params.RoomID + "/messages/attachments/commit",
		Body:   body,
	})
}
