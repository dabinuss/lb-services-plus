// @vitest-environment jsdom

import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { CompanyWorkspace as WorkspaceData, Employee } from "../types";
import { CompanyWorkspace } from "./CompanyWorkspace";

let container: HTMLDivElement;
let root: Root;

beforeEach(() => {
  container = document.createElement("div");
  document.body.appendChild(container);
  root = createRoot(container);
});

afterEach(() => {
  act(() => root.unmount());
  container.remove();
  window.sessionStorage.clear();
});

const workspace: WorkspaceData = {
  companyId: "downtown-cab",
  conversations: [],
  requests: [],
  calls: [],
  pagination: { conversations: { hasMore: false }, requests: { hasMore: false }, calls: { hasMore: false } },
  numberStates: [],
  requestSettings: {
    label: "Requests",
    createLabel: "Create request",
    templateIds: [],
    templates: [],
    phases: [],
    navigationOnAccept: "disabled"
  }
};

const employees: Employee[] = Array.from({ length: 10 }, (_, index) => ({
  source: index + 1,
  name: `Employee ${String(index + 1).padStart(2, "0")}`,
  role: index === 0 ? "Dispatcher" : "Driver",
  grade: index,
  companyId: "downtown-cab",
  status: "available",
  dispatchEnabled: index === 0,
  dispatchForced: false,
  isLeader: false,
  activeCall: false,
  activeRequest: false,
  version: 1
}));

describe("CompanyWorkspace", () => {
  it("requests the next server page with the request cursor", async () => {
    const onLoadMore = vi.fn().mockResolvedValue(true);
    const pagedWorkspace: WorkspaceData = {
      ...workspace,
      requests: Array.from({ length: 8 }, (_, index) => ({ id: 100 - index, companyId: "downtown-cab", companyName: "Downtown Cab Co.", status: "completed" as const })),
      pagination: { ...workspace.pagination, requests: { nextCursor: 93, hasMore: true } }
    };
    await act(async () => root.render(<CompanyWorkspace data={pagedWorkspace} employees={employees} selfSource={1} locale="en" busy={false} isLeader={false} canDelete={false} onLoadMore={onLoadMore} onOpenConversation={vi.fn()} onAcceptRequest={vi.fn()} onTransition={vi.fn()} onReturn={vi.fn()} onSaveSettings={vi.fn()} onDeleteRequest={vi.fn()} onDeleteConversation={vi.fn()} onCallEmployee={vi.fn()} onContactEmployee={vi.fn()} />));

    await act(async () => container.querySelector<HTMLButtonElement>('button[aria-label="Next page"]')?.click());
    expect(onLoadMore).toHaveBeenCalledWith("requests", 93, undefined);
  });

  it("keeps the team in its own tab and paginates long rosters", () => {
    act(() => root.render(<CompanyWorkspace data={workspace} employees={employees} selfSource={1} locale="en" busy={false} isLeader={false} canDelete={false} onOpenConversation={vi.fn()} onAcceptRequest={vi.fn()} onTransition={vi.fn()} onReturn={vi.fn()} onSaveSettings={vi.fn()} onDeleteRequest={vi.fn()} onDeleteConversation={vi.fn()} onCallEmployee={vi.fn()} onContactEmployee={vi.fn()} />));

    act(() => container.querySelector<HTMLButtonElement>('button[aria-label="Active team"]')?.click());
    expect(container.querySelectorAll(".employee-row")).toHaveLength(8);
    expect(container.querySelector(".employee-row strong")?.textContent).toBe("Employee 10");
    expect(container.textContent).toContain("1 / 2");

    act(() => container.querySelector<HTMLButtonElement>('button[aria-label="Next page"]')?.click());
    expect(container.querySelectorAll(".employee-row")).toHaveLength(2);
    expect(container.textContent).toContain("2 / 2");
  });

  it("loads a selected inbox with its composite cursor", async () => {
    const onLoadMore = vi.fn().mockResolvedValue(true);
    const onInboxChange = vi.fn().mockResolvedValue(true);
    const cursor = { lastMessageAt: "2026-08-03 09:00:00", id: 41 };
    const inboxWorkspace: WorkspaceData = {
      ...workspace,
      conversations: Array.from({ length: 8 }, (_, index) => ({ id: 48 - index, numberId: "main", numberLabel: "Main", lastMessage: "Message", lastMessageAt: new Date(Date.UTC(2026, 7, 3, 8, -index)).toISOString(), unreadCount: 0 })),
      numberStates: [{ numberId: "main", label: "Main", enabled: true, callsEnabled: true, inboxEnabled: true, requestsEnabled: true, canSelectForDispatch: true, selectedForDispatch: true }],
      pagination: { ...workspace.pagination, conversations: { nextCursor: cursor, hasMore: true } },
      summary: { unansweredRequests: 0, unreadMessages: 0, unreadByNumber: { main: 0 }, unseenCalls: 0, latestCallId: 0 }
    };
    await act(async () => root.render(<CompanyWorkspace data={inboxWorkspace} employees={employees} selfSource={1} locale="en" busy={false} isLeader={false} canDelete={false} onLoadMore={onLoadMore} onInboxChange={onInboxChange} onOpenConversation={vi.fn()} onAcceptRequest={vi.fn()} onTransition={vi.fn()} onReturn={vi.fn()} onSaveSettings={vi.fn()} onDeleteRequest={vi.fn()} onDeleteConversation={vi.fn()} onCallEmployee={vi.fn()} onContactEmployee={vi.fn()} />));

    act(() => container.querySelector<HTMLButtonElement>('button[aria-label="Shared inbox"]')?.click());
    await act(async () => Array.from(container.querySelectorAll<HTMLButtonElement>(".inbox-number-tabs button")).find((button) => button.textContent?.includes("Main"))?.click());
    expect(onInboxChange).toHaveBeenCalledWith("main");
    await act(async () => container.querySelector<HTMLButtonElement>('button[aria-label="Next page"]')?.click());
    expect(onLoadMore).toHaveBeenCalledWith("conversations", cursor, "main");
  });

  it("uses red badges only for actionable and unseen items", () => {
    const signaledWorkspace: WorkspaceData = {
      ...workspace,
      requests: [{ id: 1, companyId: "downtown-cab", companyName: "Downtown Cab Co.", status: "pending" }],
      conversations: [{ id: 1, numberId: "main", numberLabel: "Main", lastMessage: "Hello", lastMessageAt: "2026-08-03T10:00:00Z", unreadCount: 2 }],
      calls: [{ id: 10, numberId: "main", status: "completed", created_at: "2026-08-03T10:00:00Z" }]
      , summary: { unansweredRequests: 7, unreadMessages: 4, unreadByNumber: { main: 4 }, unseenCalls: 3, latestCallId: 10 }
    };
    act(() => root.render(<CompanyWorkspace data={signaledWorkspace} employees={employees} selfSource={1} locale="en" busy={false} isLeader={false} canDelete={false} onOpenConversation={vi.fn()} onAcceptRequest={vi.fn()} onTransition={vi.fn()} onReturn={vi.fn()} onSaveSettings={vi.fn()} onDeleteRequest={vi.fn()} onDeleteConversation={vi.fn()} onCallEmployee={vi.fn()} onContactEmployee={vi.fn()} />));

    expect(container.querySelector('button[aria-label="Requests"] i')?.classList.contains("alert")).toBe(true);
    expect(container.querySelector('button[aria-label="Shared inbox"] i')?.classList.contains("alert")).toBe(true);
    expect(container.querySelector('button[aria-label="Company calls"] i')?.classList.contains("alert")).toBe(true);
    expect(container.querySelector('button[aria-label="Active team"] i')?.classList.contains("neutral")).toBe(true);

    act(() => container.querySelector<HTMLButtonElement>('button[aria-label="Company calls"]')?.click());
    expect(container.querySelector('button[aria-label="Company calls"] i')?.textContent).toBe("0");
    expect(container.querySelector('button[aria-label="Company calls"] i')?.classList.contains("neutral")).toBe(true);
  });

  it("shows the assigned employee and role on a handled request", () => {
    const assignedWorkspace: WorkspaceData = {
      ...workspace,
      requests: [{ id: 9, companyId: "downtown-cab", companyName: "Downtown Cab Co.", status: "active", assignee: { name: "Mika Hart", role: "Dispatcher" } }]
    };
    act(() => root.render(<CompanyWorkspace data={assignedWorkspace} employees={employees} selfSource={1} locale="en" busy={false} isLeader={false} canDelete={false} onOpenConversation={vi.fn()} onAcceptRequest={vi.fn()} onTransition={vi.fn()} onReturn={vi.fn()} onSaveSettings={vi.fn()} onDeleteRequest={vi.fn()} onDeleteConversation={vi.fn()} onCallEmployee={vi.fn()} onContactEmployee={vi.fn()} />));

    expect(container.textContent).toContain("Handled by: Mika Hart · Dispatcher");
  });
});
