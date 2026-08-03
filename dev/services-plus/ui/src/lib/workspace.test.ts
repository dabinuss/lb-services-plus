import { describe, expect, it } from "vitest";
import { appendUnique, WorkspaceRequestGate } from "./workspace";

describe("workspace pagination", () => {
  it("deduplicates more than fifty records across server pages", () => {
    const first = Array.from({ length: 50 }, (_, index) => ({ id: 100 - index }));
    const second = Array.from({ length: 25 }, (_, index) => ({ id: 51 - index }));
    const result = appendUnique(first, second);
    expect(result).toHaveLength(74);
    expect(new Set(result.map((item) => item.id)).size).toBe(74);
  });

  it("rejects stale refreshes and stale responses for the same section", () => {
    const gate = new WorkspaceRequestGate();
    const oldRefresh = gate.begin();
    const currentRefresh = gate.begin();
    expect(gate.isCurrent(oldRefresh)).toBe(false);
    expect(gate.isCurrent(currentRefresh)).toBe(true);

    const firstInbox = gate.begin("conversations");
    const latestInbox = gate.begin("conversations");
    expect(gate.isCurrent(firstInbox)).toBe(false);
    expect(gate.isCurrent(latestInbox)).toBe(true);
  });

  it("allows independent list requests to complete in parallel", () => {
    const gate = new WorkspaceRequestGate();
    gate.begin();
    const requests = gate.begin("requests");
    const calls = gate.begin("calls");
    expect(gate.isCurrent(requests)).toBe(true);
    expect(gate.isCurrent(calls)).toBe(true);
  });
});
