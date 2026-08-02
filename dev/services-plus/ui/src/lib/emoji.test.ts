import { describe, expect, it } from "vitest";
import { MESSAGE_EMOJIS } from "../components/EmojiPicker";

describe("message emoji allowlist", () => {
  it("contains five general and five GTA-themed unique choices", () => {
    expect(MESSAGE_EMOJIS).toHaveLength(10);
    expect(new Set(MESSAGE_EMOJIS).size).toBe(10);
    expect(MESSAGE_EMOJIS.slice(0, 5)).toEqual(["👍", "❤️", "😂", "😮", "😢"]);
    expect(MESSAGE_EMOJIS.slice(5)).toEqual(["🚗", "💵", "🚨", "🔧", "🍔"]);
  });
});
