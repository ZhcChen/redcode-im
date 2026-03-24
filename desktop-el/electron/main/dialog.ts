import { dialog } from "electron";
import type { DesktopDialogOpenOptions, DesktopDialogSaveOptions } from "../preload/types.js";
import type { MainWindowController } from "./window.js";

export interface DesktopDialogService {
  open(options?: DesktopDialogOpenOptions): Promise<Electron.OpenDialogReturnValue>;
  save(options?: DesktopDialogSaveOptions): Promise<Electron.SaveDialogReturnValue>;
}

export const createDialogService = (windowController: MainWindowController): DesktopDialogService => ({
  open(options = {}) {
    return dialog.showOpenDialog(windowController.getWindow(), {
      title: options.title,
      defaultPath: options.defaultPath,
      buttonLabel: options.buttonLabel,
      filters: options.filters,
      properties: options.properties ?? ["openFile"]
    });
  },
  save(options = {}) {
    return dialog.showSaveDialog(windowController.getWindow(), {
      title: options.title,
      defaultPath: options.defaultPath,
      buttonLabel: options.buttonLabel,
      filters: options.filters
    });
  }
});
