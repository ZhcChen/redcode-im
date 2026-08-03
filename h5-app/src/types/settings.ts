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

export type ReleasePlatform = 'windows' | 'macos' | 'ios' | 'android' | 'linux';

export interface VersionStatus {
  currentVersion: string;
  platform: ReleasePlatform;
  hasUpdate: boolean;
  latestVersion: string | null;
  releaseNotes: string | null;
  mandatory: boolean;
  storeUrl: string | null;
}
