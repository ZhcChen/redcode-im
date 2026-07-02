export interface MessageRuntimeSettings {
  serverStorageMode: string;
  contentAuditMode: string;
}

export interface GeneralSettings {
  appName: string;
  messageRuntime: MessageRuntimeSettings;
}

export interface DocumentContent {
  title: string;
  content: string;
  updatedAt?: string | null;
}
