import { describe, expect, test } from "bun:test";
import { shouldBlockKeyboardNavigation } from "./navigation-shortcuts";

describe("navigation shortcuts helpers", () => {
  test("blocks desktop browser navigation shortcuts on non-mac platforms", () => {
    expect(
      shouldBlockKeyboardNavigation({
        key: "ArrowLeft",
        code: "ArrowLeft",
        altKey: true,
        ctrlKey: false,
        metaKey: false,
        defaultPrevented: false,
      }, false),
    ).toBe(true);

    expect(
      shouldBlockKeyboardNavigation({
        key: "Backspace",
        code: "Backspace",
        altKey: true,
        ctrlKey: false,
        metaKey: false,
        defaultPrevented: false,
      }, false),
    ).toBe(true);
  });

  test("blocks mac bracket navigation shortcuts and ignores unrelated keys", () => {
    expect(
      shouldBlockKeyboardNavigation({
        key: "[",
        code: "BracketLeft",
        altKey: false,
        ctrlKey: false,
        metaKey: true,
        defaultPrevented: false,
      }, true),
    ).toBe(true);

    expect(
      shouldBlockKeyboardNavigation({
        key: "k",
        code: "KeyK",
        altKey: false,
        ctrlKey: true,
        metaKey: false,
        defaultPrevented: false,
      }, false),
    ).toBe(false);
  });
});
