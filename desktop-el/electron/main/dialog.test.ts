import { beforeEach, describe, expect, test } from "bun:test";
import {
  electronMockState,
  resetElectronMockState,
} from "../test-support/electron-mock.js";

const { createDialogService } = await import("./dialog.js");

describe("createDialogService", () => {
  beforeEach(() => {
    resetElectronMockState();
  });

  test("forwards open and save options to electron dialog", async () => {
    const ownerWindow = { id: "main-window" };
    const service = createDialogService({
      getWindow() {
        return ownerWindow as never;
      },
    } as never);

    const openResult = await service.open({
      title: "选择文件",
      defaultPath: "/tmp/demo.txt",
      buttonLabel: "选择",
      filters: [{ name: "Text", extensions: ["txt"] }],
    });
    const saveResult = await service.save({
      title: "保存文件",
      defaultPath: "/tmp/output.txt",
      buttonLabel: "保存",
      filters: [{ name: "Text", extensions: ["txt"] }],
    });

    expect(openResult).toEqual({
      canceled: false,
      filePaths: ["/tmp/mock-open.txt"],
    });
    expect(saveResult).toEqual({
      canceled: false,
      filePath: "/tmp/mock-save.txt",
    });
    expect(electronMockState.openDialogCalls).toEqual([
      [
        ownerWindow,
        {
          title: "选择文件",
          defaultPath: "/tmp/demo.txt",
          buttonLabel: "选择",
          filters: [{ name: "Text", extensions: ["txt"] }],
          properties: ["openFile"],
        },
      ],
    ]);
    expect(electronMockState.saveDialogCalls).toEqual([
      [
        ownerWindow,
        {
          title: "保存文件",
          defaultPath: "/tmp/output.txt",
          buttonLabel: "保存",
          filters: [{ name: "Text", extensions: ["txt"] }],
        },
      ],
    ]);
  });
});
