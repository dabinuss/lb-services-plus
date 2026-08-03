// @vitest-environment jsdom

import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { fetchNui } from "../lib/api";
import type { ConversationData, InboxConversation } from "../types";
import { ConversationView } from "./ConversationView";

vi.mock("../lib/api", () => ({ fetchNui: vi.fn() }));

const conversation: InboxConversation = {
  id: 12,
  companyId: "downtown-cab",
  companyName: "Downtown Cab Co.",
  numberId: "cab-main",
  numberLabel: "Dispatch",
  externalNumber: "5550101",
  lastMessage: "Pickup requested",
  lastMessageAt: "2026-08-03T12:00:00Z",
  unreadCount: 1
};

const loaded: ConversationData = {
  conversation: { id: 12, companyId: "downtown-cab", numberId: "cab-main", externalNumber: "5550101" },
  messages: [{ id: 3, senderNumber: "5550101", senderType: "citizen", body: "Pickup requested", attachments: [] }]
};

describe("ConversationView loading", () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    vi.mocked(fetchNui).mockReset();
    container = document.createElement("div");
    document.body.appendChild(container);
    root = createRoot(container);
  });

  afterEach(() => {
    act(() => root.unmount());
    container.remove();
  });

  it("shows a localized retry state and loads messages after retry", async () => {
    vi.mocked(fetchNui).mockRejectedValueOnce(new Error("timeout")).mockResolvedValueOnce({ success: true, data: loaded });
    const onRead = vi.fn();
    await act(async () => root.render(<ConversationView conversation={conversation} locale="de" citizen={false} busy={false} onClose={vi.fn()} onSend={vi.fn()} onLocation={vi.fn()} onReact={vi.fn()} onRead={onRead} canDelete={false} onDelete={vi.fn()} />));

    expect(container.textContent).toContain("Nachrichten konnten nicht geladen werden.");
    const retry = Array.from(container.querySelectorAll("button")).find((button) => button.textContent === "Erneut versuchen");
    await act(async () => retry?.click());

    expect(container.textContent).toContain("Pickup requested");
    expect(onRead).toHaveBeenCalledWith(12);
  });
});
