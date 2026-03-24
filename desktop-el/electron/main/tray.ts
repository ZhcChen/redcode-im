import { Menu, Tray, nativeImage } from "electron";

export interface AppTrayControllerOptions {
  onShow: () => void;
  onQuit: () => void;
}

const TRAY_ICON =
  "iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAHElEQVR4nGNgGAVDBv///wMxw6gBJiYmBiYqAQA41QQU1Ji/7QAAAABJRU5ErkJggg==";

export class AppTrayController {
  private tray?: Tray;

  constructor(private readonly options: AppTrayControllerOptions) {}

  create(): void {
    if (this.tray) {
      return;
    }

    const icon = nativeImage.createFromDataURL(`data:image/png;base64,${TRAY_ICON}`);
    const tray = new Tray(icon);
    tray.setToolTip("RedCode IM");
    tray.setContextMenu(
      Menu.buildFromTemplate([
        {
          label: "显示主窗口",
          click: this.options.onShow
        },
        {
          type: "separator"
        },
        {
          label: "退出",
          click: this.options.onQuit
        }
      ])
    );
    tray.on("click", this.options.onShow);

    this.tray = tray;
  }

  destroy(): void {
    this.tray?.destroy();
    this.tray = undefined;
  }
}
