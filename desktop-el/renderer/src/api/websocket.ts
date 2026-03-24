export interface WebSocketParams {
  userId: string;
  token: string;
}

export type ConnectionStatus = "disconnected" | "connecting" | "authenticated";

const requireDesktopRuntime = () => {
  if (!window.desktopEl) {
    throw new Error("desktop-el runtime is not available");
  }
  return window.desktopEl;
};

export const WebSocketApi = {
  async connect(params: WebSocketParams, wsUrl?: string): Promise<void> {
    await requireDesktopRuntime().rpc.invoke("ws.connect", {
      url: wsUrl,
      token: params.token,
      user_id: params.userId
    });
  },

  async disconnect(): Promise<void> {
    await requireDesktopRuntime().rpc.invoke("ws.disconnect");
  },

  async getStatus(): Promise<ConnectionStatus> {
    const result = await requireDesktopRuntime().rpc.invoke<{ status: ConnectionStatus }>("ws.status.get");
    return result.status;
  }
};
