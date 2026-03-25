import { describe, expect, test } from "bun:test";
import { buildDesktopWindowTitle } from "./desktop-window-title";

describe("desktop window title helpers", () => {
  test("uses app name when there is no signed-in user", () => {
    expect(buildDesktopWindowTitle("CHATLY", null)).toBe("CHATLY");
  });

  test("prefers mobile and falls back to nickname or username for signed-in users", () => {
    expect(
      buildDesktopWindowTitle("CHATLY", {
        id: "user-1",
        mobile: "13800138000",
        nickname: "陈晨",
        username: "chen",
      }),
    ).toBe("CHATLY - 13800138000");

    expect(
      buildDesktopWindowTitle("CHATLY", {
        id: "user-2",
        mobile: "",
        nickname: "林一",
        username: "linyi",
      }),
    ).toBe("CHATLY - 林一");

    expect(
      buildDesktopWindowTitle("CHATLY", {
        id: "user-3",
        mobile: "",
        nickname: "",
        username: "linyi",
      }),
    ).toBe("CHATLY - linyi");
  });
});
