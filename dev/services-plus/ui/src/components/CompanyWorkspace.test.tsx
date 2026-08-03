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

  it("uses red badges only for actionable and unseen items", () => {
    const signaledWorkspace: WorkspaceData = {
      ...workspace,
      requests: [{ id: 1, companyId: "downtown-cab", companyName: "Downtown Cab Co.", status: "pending" }],
      conversations: [{ id: 1, numberId: "main", numberLabel: "Main", lastMessage: "Hello", lastMessageAt: "2026-08-03T10:00:00Z", unreadCount: 2 }],
      calls: [{ id: 10, numberId: "main", status: "completed", created_at: "2026-08-03T10:00:00Z" }]
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
