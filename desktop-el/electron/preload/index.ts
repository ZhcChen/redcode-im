import { contextBridge } from "electron";

contextBridge.exposeInMainWorld("desktopEl", {
  version: "0.1.0"
});
