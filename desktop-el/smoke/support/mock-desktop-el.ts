interface DesktopElMockUser {
  id: string;
  username: string;
  nickname: string;
  email: string;
}

interface DesktopElMockOptions {
  appName?: string;
  hostVersion?: string;
  user?: DesktopElMockUser;
}

export const installDesktopElMock = (options: DesktopElMockOptions = {}) => {
  const appName = options.appName ?? "RedCode";
  const hostVersion = options.hostVersion ?? "0.1.0-smoke";
  const user = options.user ?? {
    id: "user-smoke",
    username: "13800138000",
    nickname: "Smoke User",
    email: "smoke@example.com",
  };
  const state = {
    currentUser: null as DesktopElMockUser | null,
    wsStatus: "disconnected",
    windowTitle: "",
  };

  const buildBootstrapSnapshot = () => ({
    accounts: state.currentUser
      ? [
          {
            id: state.currentUser.id,
            display_name: state.currentUser.nickname,
          },
        ]
      : [],
    config: {
      app_name: appName,
      environment: "smoke",
      api_base_url: "http://127.0.0.1:8010",
      ws_url: "ws://127.0.0.1:8010/ws",
      version: "0.1.0",
      build_number: 1,
      channel: "stable",
    },
    recent_conversations: [],
    connection: {
      status: state.wsStatus,
    },
    feature_flags: {},
    auth: {
      logged_in: Boolean(state.currentUser),
      current_user: state.currentUser
        ? {
            id: state.currentUser.id,
            username: state.currentUser.username,
            email: state.currentUser.email,
            nickname: state.currentUser.nickname,
            avatar_url: null,
            status: "active",
          }
        : null,
    },
  });

  const buildLoginResponse = () => ({
    success: true,
    message: "ok",
    data: {
      token: "token-smoke",
      refresh_token: "refresh-smoke",
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        nickname: user.nickname,
        avatar_url: null,
        avatar_object_key: null,
        status: "active",
      },
    },
  });

  const invoke = async (method: string) => {
    switch (method) {
      case "core.bootstrap.get":
        return buildBootstrapSnapshot();
      case "core.config.get":
        return {
          app_name: appName,
        };
      case "settings.captcha.get":
        return {
          success: true,
          message: "",
          data: {
            require_captcha_for_login: false,
          },
        };
      case "auth.login":
      case "auth.login.sms":
        state.currentUser = user;
        return buildLoginResponse();
      case "ws.connect":
        state.wsStatus = "authenticated";
        return undefined;
      case "ws.disconnect":
        state.wsStatus = "disconnected";
        return undefined;
      case "ws.status.get":
        return {
          status: state.wsStatus,
        };
      case "chat.list":
        return {
          success: true,
          message: "",
          data: [],
        };
      default:
        throw new Error(`unhandled desktop-el mock method: ${method}`);
    }
  };

  Object.defineProperty(window, "desktopEl", {
    configurable: true,
    value: {
      rpc: {
        invoke,
        onEvent: () => () => undefined,
      },
      app: {
        getVersion: async () => hostVersion,
        quit: async () => undefined,
      },
      window: {
        show: async () => undefined,
        hide: async () => undefined,
        focus: async () => undefined,
        setTitle: async (title: string) => {
          state.windowTitle = title;
        },
        requestAttention: async () => undefined,
      },
      dialog: {
        open: async () => ({ canceled: true, filePaths: [] }),
        save: async () => ({ canceled: true }),
      },
      notification: {
        isSupported: async () => true,
        show: async () => undefined,
      },
      file: {
        saveFromURL: async () => ({ filePath: "/tmp/mock-file" }),
        getCachedPath: async () => null,
        cacheFromURL: async () => ({
          filePath: "/tmp/mock-cache-file",
          fileUrl: "file:///tmp/mock-cache-file",
        }),
        openPath: async () => undefined,
      },
    },
  });
};
