declare module '@tauri-apps/api/fs' {
  export enum BaseDirectory {
    Audio,
    Cache,
    Config,
    Data,
    LocalData,
    Log,
    Temp,
    App,
    Resource,
    AppCache,
    AppConfig,
    AppData,
    AppLocalData,
    AppLog,
    Desktop,
    Document,
    Download,
    Picture,
    Public,
    Video,
    Template
  }

  export function create(path: string, options?: { dir?: BaseDirectory; recursive?: boolean; path?: string }): Promise<void>
  export function writeFile(options: { path: string; contents: Uint8Array; dir?: BaseDirectory }): Promise<void>
  export function removeFile(options: { path: string; dir?: BaseDirectory }): Promise<void>
}

declare module '@tauri-apps/api/path' {
  export function appDataDir(): Promise<string>
  export function join(...paths: string[]): Promise<string>
}
