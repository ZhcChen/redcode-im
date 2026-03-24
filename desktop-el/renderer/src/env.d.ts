import type { DesktopElAPI } from "../../electron/preload/types";

declare global {
  interface Window {
    desktopEl?: DesktopElAPI;
  }
}

export {};
