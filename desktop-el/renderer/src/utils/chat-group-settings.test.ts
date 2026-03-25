import { describe, expect, test } from "bun:test";
import { resolveGroupMaxMembersUpdate } from "./chat-group-settings";

describe("chat group settings helpers", () => {
  test("accepts trimmed positive integer max member input", () => {
    expect(resolveGroupMaxMembersUpdate(" 256 ", 500)).toEqual({
      nextValue: 256,
      errorMessage: null,
    });
  });

  test("rejects invalid max member input", () => {
    expect(resolveGroupMaxMembersUpdate("0", 500)).toEqual({
      nextValue: null,
      errorMessage: "群最大人数必须是正整数。",
    });
    expect(resolveGroupMaxMembersUpdate("12.5", 500)).toEqual({
      nextValue: null,
      errorMessage: "群最大人数必须是正整数。",
    });
  });

  test("rejects unchanged max member input", () => {
    expect(resolveGroupMaxMembersUpdate("500", 500)).toEqual({
      nextValue: null,
      errorMessage: "群最大人数未发生变化。",
    });
  });
});
