import { describe, expect, it, vi } from "vitest";
import { subscribeToNui } from "./events";

describe("subscribeToNui", () => {
  it("forwards valid messages and removes its listener", () => {
    const handler = vi.fn();
    const unsubscribe = subscribeToNui(handler);
    window.dispatchEvent(new MessageEvent("message", { data: { type: "company.updated", payload: { id: "taxi" } } }));
    expect(handler).toHaveBeenCalledOnce();
    unsubscribe();
    window.dispatchEvent(new MessageEvent("message", { data: { type: "company.updated", payload: {} } }));
    expect(handler).toHaveBeenCalledOnce();
  });
});
