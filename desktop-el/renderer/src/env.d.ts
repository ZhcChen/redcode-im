import type { DesktopElAPI } from "../../electron/preload/types.js";

declare global {
  interface Window {
    desktopEl?: DesktopElAPI;
  }
}

export {};
