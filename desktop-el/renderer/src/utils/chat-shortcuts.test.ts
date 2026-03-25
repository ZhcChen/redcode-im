import { describe, expect, test } from "bun:test";
import {
  isOpenSearchShortcut,
  isSubmitEditShortcut,
} from "./chat-shortcuts";

describe("chat shortcuts helpers", () => {
  test("detects command or control plus f as search shortcut", () => {
    expect(
      isOpenSearchShortcut({
        key: "f",
        ctrlKey: true,
        metaKey: false,
        shiftKey: false,
        altKey: false,
        defaultPrevented: false,
      }),
    ).toBe(true);

    expect(
      isOpenSearchShortcut({
        key: "F",
        ctrlKey: false,
        metaKey: true,
        shiftKey: false,
        altKey: false,
        defaultPrevented: false,
      }),
    ).toBe(true);
  });

  test("detects command or control plus enter as edit submit shortcut", () => {
    expect(
      isSubmitEditShortcut({
        key: "Enter",
        ctrlKey: true,
        metaKey: false,
        shiftKey: false,
        altKey: false,
        defaultPrevented: false,
      }),
    ).toBe(true);

    expect(
      isSubmitEditShortcut({
        key: "Enter",
        ctrlKey: false,
        metaKey: true,
        shiftKey: false,
        altKey: false,
        defaultPrevented: false,
      }),
    ).toBe(true);

    expect(
      isSubmitEditShortcut({
        key: "Enter",
        ctrlKey: false,
        metaKey: false,
        shiftKey: false,
        altKey: false,
        defaultPrevented: false,
      }),
    ).toBe(false);
  });
});
