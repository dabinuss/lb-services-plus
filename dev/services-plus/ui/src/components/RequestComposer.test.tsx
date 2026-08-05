// @vitest-environment jsdom

import { act } from "react";
import { createRoot, type Root } from "react-dom/client";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { fetchNui } from "../lib/api";
import type { Company, RequestSettings } from "../types";
import { RequestComposer } from "./RequestComposer";

vi.mock("../lib/api", () => ({ fetchNui: vi.fn() }));

const company = {
  id: "downtown-cab",
  displayName: "Downtown Cab Co.",
  logo: "./icon.svg",
  backgroundImage: "",
  categoryId: "taxi_transport",
  categoryName: "Taxi & Transport",
  description: "Taxi service",
  location: "East Vinewood",
  openingHours: "24/7",
  keywords: [],
  available: true,
  requestsEnabled: true,
  messagesEnabled: true,
  dispatchMode: "dispatch_only",
  requestNotificationActionable: true,
  numbers: [],
  version: 1
} satisfies Company;

const settings: RequestSettings = {
  label: "Fahrtanfrage",
  createLabel: "Fahrt anfragen",
  templateIds: ["immediate_pickup"],
  templates: [{ id: "immediate_pickup", kind: "specialized", name: "Abholung", fields: [{ id: "people", type: "people", label: "Personen", required: false }] }],
  navigationOnAccept: "automatic"
};

describe("RequestComposer failures", () => {
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

  it("keeps the composer open and tells German users to call after submit failure", async () => {
    vi.mocked(fetchNui).mockResolvedValue({ success: true, data: settings });
    const onClose = vi.fn();
    await act(async () => root.render(<RequestComposer company={company} locale="de" busy={false} onClose={onClose} onSubmit={vi.fn().mockResolvedValue(false)} />));

    const send = Array.from(container.querySelectorAll("button")).find((button) => button.textContent?.includes("Anfrage senden"));
    expect(send).toBeTruthy();
    await act(async () => send?.click());

    expect(container.textContent).toContain("Die Anfrage konnte nicht gesendet werden. Bitte rufe das Unternehmen stattdessen an.");
    expect(onClose).not.toHaveBeenCalled();
  });

  it("shows the same guidance when request options cannot be loaded", async () => {
    vi.mocked(fetchNui).mockResolvedValue({ success: false, error: { code: "request_failed", message: "Internal error", retryable: true } });
    await act(async () => root.render(<RequestComposer company={company} locale="en" busy={false} onClose={vi.fn()} onSubmit={vi.fn()} />));

    expect(container.textContent).toContain("The request could not be sent. Please call the company instead.");
    expect(container.textContent).not.toContain("Internal error");
  });
});
