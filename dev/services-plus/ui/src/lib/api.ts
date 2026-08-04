import type { AdminCompany, AdminState, ApiResponse, CitizenRequest, Company, CompanyOperationsPatch, CompanyPatch, CompanyWorkspace, ConversationData, DeletedCompany, InboxConversation, InboxMessage, InitialState, MessageReactionUpdate, MyActivity, RequestSettings, WorkspaceCursor, WorkspaceSection } from "../types";
import { browserFixture } from "../test/fixture";
import type { Employee } from "../types";

declare global {
  interface Window {
    fetchNui?: <T>(event: string, data?: unknown, scriptName?: string) => Promise<T>;
    createCall?: (options: { number?: string; company?: string; videoCall?: boolean; hideNumber?: boolean }) => void;
  }
}

export async function fetchNui<T>(event: string, data: unknown = {}): Promise<ApiResponse<T>> {
  if (window.fetchNui) return window.fetchNui<ApiResponse<T>>(event, data);

  await new Promise((resolve) => window.setTimeout(resolve, event === "enterDuty" ? 650 : 80));
  if (event === "getInitialState") return { success: true, data: structuredClone(browserState) as T };
  const employment = browserState.currentUser.employment;
  if (event === "enterDuty" && employment) {
    const activeNumberIds = browserWorkspace.numberStates?.filter((number) => number.enabled).map((number) => number.numberId) || [];
    const employee: Employee = { source: browserState.currentUser.source, name: browserState.currentUser.name, role: "Operations Manager", grade: 4, companyId: employment.companyId, status: "available", dispatchEnabled: true, dispatchForced: false, isLeader: employment.isLeader, activeCall: false, activeRequest: false, activeNumberIds, version: 2 };
    const colleagues: Employee[] = [
      { source: 24, name: "Avery Brooks", role: "Senior Driver", grade: 2, companyId: employment.companyId, status: "available", dispatchEnabled: true, dispatchForced: false, isLeader: false, activeCall: false, activeRequest: false, version: 2 },
      { source: 31, name: "Mika Hart", role: "Dispatcher", grade: 3, companyId: employment.companyId, status: "on_break", dispatchEnabled: true, dispatchForced: false, isLeader: false, activeCall: false, activeRequest: false, version: 2 }
    ];
    employment.onDuty = true; employment.employee = employee; employment.activeEmployees = [employee, ...colleagues];
    browserWorkspace.numberStates?.forEach((number) => { number.canSelectForDispatch = number.enabled; number.selectedForDispatch = number.enabled; });
    browserState.companies = browserState.companies.map((company) => company.id === employment.companyId ? { ...company, available: true, numbers: company.numbers.map((number) => ({ ...number, available: number.enabled })) } : company);
    persistBrowserConfiguration();
    return { success: true, data: { currentUser: structuredClone(browserState.currentUser), companies: structuredClone(browserState.companies) } as T };
  }
  if (event === "leaveDuty" && employment) {
    employment.onDuty = false; employment.employee = null; employment.activeEmployees = [];
    browserState.companies = browserState.companies.map((company) => company.id === employment.companyId ? { ...company, available: false, numbers: company.numbers.map((number) => ({ ...number, available: false })) } : company);
    persistBrowserConfiguration();
    return { success: true, data: { currentUser: structuredClone(browserState.currentUser), companies: structuredClone(browserState.companies) } as T };
  }
  if ((event === "updateStatus" || event === "toggleDispatch") && employment?.employee) {
    const payload = data as { status?: Employee["status"]; enabled?: boolean };
    if (event === "updateStatus" && payload.status) employment.employee.status = payload.status;
    if (event === "toggleDispatch" && typeof payload.enabled === "boolean") {
      const dispatchEnabled = payload.enabled;
      employment.employee.dispatchEnabled = dispatchEnabled;
      browserWorkspace.numberStates?.forEach((number) => {
        number.canSelectForDispatch = dispatchEnabled;
        if (dispatchEnabled && number.enabled) number.selectedForDispatch = true;
      });
      if (dispatchEnabled) employment.employee.activeNumberIds = browserWorkspace.numberStates?.filter((number) => number.enabled).map((number) => number.numberId) || [];
    }
    employment.activeEmployees = employment.activeEmployees.map((employee) => employee.source === employment.employee?.source ? employment.employee : employee).filter(Boolean) as Employee[];
    persistBrowserConfiguration();
    return { success: true, data: structuredClone(employment.employee) as T };
  }
  if (event === "toggleDispatchLine" && employment?.employee) {
    const payload = data as { numberId: string; enabled: boolean };
    employment.employee.activeNumberIds = payload.enabled ? [...new Set([...(employment.employee.activeNumberIds || []), payload.numberId])] : (employment.employee.activeNumberIds || []).filter((id) => id !== payload.numberId);
    const numberState = browserWorkspace.numberStates?.find((item) => item.numberId === payload.numberId); if (numberState) numberState.selectedForDispatch = payload.enabled;
    persistBrowserConfiguration();
    return { success: true, data: structuredClone(employment.employee) as T };
  }
  if (event === "updateNumberOperations") {
    const numbers = (data as { numbers: Array<{ id: string } & Partial<Company["numbers"][number]>> }).numbers;
    const company = browserState.companies.find((item) => item.id === employment?.companyId);
    if (company) company.numbers = company.numbers.map((number) => ({ ...number, ...(numbers.find((item) => item.id === number.id) || {}) }));
    browserWorkspace.numberStates?.forEach((numberState) => {
      const update = numbers.find((number) => number.id === numberState.numberId);
      if (update) Object.assign(numberState, update);
    });
    return { success: true, data: structuredClone(company) as T };
  }
  if (event === "updateCompanyOperations") {
    const payload = data as { companyId: string; patch: CompanyOperationsPatch };
    const current = browserState.companies.find((company) => company.id === payload.companyId);
    if (current) {
      Object.assign(current, payload.patch);
      return { success: true, data: structuredClone(current) as T };
    }
  }
  if (event === "startCompanyCall") {
    const payload = data as { companyId: string };
    const company = browserState.companies.find((item) => item.id === payload.companyId);
    if (company?.primaryNumber) {
      browserActivity.calls.unshift({ id: Date.now(), companyId: company.id, displayName: company.displayName, number: company.primaryNumber, result: "initiated", created_at: new Date().toISOString() });
      return { success: true, data: { number: company.primaryNumber } as T };
    }
  }
  if (event === "createRequest") {
    const payload = data as { companyId: string; templateId: string; values: Record<string, string | number> };
    const company = browserState.companies.find((item) => item.id === payload.companyId);
    if (company) {
      const request: CitizenRequest = { id: Date.now(), companyId: company.id, companyName: company.displayName, templateId: payload.templateId, requestLabel: "Ride Request", status: "pending", payload: payload.values, createdAt: new Date().toISOString() };
      browserActivity.requests.unshift(request);
      browserWorkspace.requests.unshift(request);
      return { success: true, data: request as T };
    }
  }
  if (event === "getRequestOptions") return { success: true, data: structuredClone(browserWorkspace.requestSettings) as T };
  if (event === "getCompanyWorkspace") return { success: true, data: makeBrowserWorkspacePage(data) as T };
  if (event === "acceptRequest" || event === "transitionRequest" || event === "returnRequest") {
    const payload = data as { id: number; phaseId?: string }; const request = browserWorkspace.requests.find((item) => item.id === payload.id);
    if (request) { if (event === "acceptRequest") { request.status = "active"; request.phaseId = "accepted"; if (employment?.employee) { employment.employee.status = "busy"; employment.employee.activeRequest = true; employment.employee.activeRequestId = request.id; } } if (event === "transitionRequest" && payload.phaseId) { request.phaseId = payload.phaseId; if (payload.phaseId === "completed") request.status = "completed"; } if (event === "returnRequest") { request.status = "returned"; request.phaseId = undefined; if (employment?.employee) { employment.employee.status = "available"; employment.employee.activeRequest = false; employment.employee.activeRequestId = undefined; } } return { success: true, data: structuredClone(request) as T }; }
  }
  if (event === "cancelRequest") { const request = browserActivity.requests.find((item) => item.id === (data as { id: number }).id) || browserWorkspace.requests.find((item) => item.id === (data as { id: number }).id); if (request) { request.status = "cancelled"; return { success: true, data: structuredClone(request) as T }; } }
  if (event === "updateRequestSettings") { const settings = (data as { settings: RequestSettings }).settings; browserWorkspace.requestSettings = { ...browserWorkspace.requestSettings, ...settings, templates: browserWorkspace.requestSettings.templates.map((template) => ({ ...template, fields: template.fields.map((field) => ({ ...field, ...settings.fieldSettings?.[template.id]?.[field.id] })) })) }; return { success: true, data: structuredClone(browserWorkspace.requestSettings) as T }; }
  if (event === "getCitizenInbox") return { success: true, data: structuredClone(browserCitizenConversations) as T };
  if (event === "sendCitizenMessage" || event === "sendEmployeeMessage") {
    const payload = data as { companyId?: string; numberId?: string; conversationId?: number; body: string; attachments: string[] }; const company = browserState.companies.find((item) => item.id === payload.companyId) || browserState.companies[1];
    let conversation = [...browserCitizenConversations, ...browserWorkspace.conversations].find((item) => item.id === payload.conversationId || (item.companyId === company.id && item.numberId === payload.numberId));
    if (!conversation) { conversation = { id: Date.now(), companyId: company.id, companyName: company.displayName, logo: company.logo, numberId: payload.numberId || company.numbers[0].id, numberLabel: company.numbers[0].label, externalNumber: "5550199", lastMessage: payload.body, lastMessageAt: new Date().toISOString(), unreadCount: 0 }; browserCitizenConversations.unshift(conversation); }
    conversation.lastMessage = payload.body || "Attachment"; const message: InboxMessage = { id: Date.now(), senderNumber: event === "sendCitizenMessage" ? "5550199" : company.numbers[0].number, senderType: event === "sendCitizenMessage" ? "citizen" : "employee", body: payload.body, attachments: payload.attachments || [], createdAt: new Date().toISOString() }; browserMessages.push(message); return { success: true, data: message as T };
  }
  if (event === "sendCurrentLocation") return { success: true, data: { id: Date.now(), body: "", attachments: [], coords: { x: 215.4, y: -810.2 } } as T };
  if (event === "getConversationMessages") { const payload = data as { conversationId: number; citizen?: boolean }; const item = [...browserCitizenConversations, ...browserWorkspace.conversations].find((entry) => entry.id === payload.conversationId)!; if (!payload.citizen) { const workspaceItem = browserWorkspace.conversations.find((entry) => entry.id === payload.conversationId); if (workspaceItem) workspaceItem.unreadCount = 0; } const result: ConversationData = { conversation: { id: item.id, companyId: item.companyId || "downtown-cab", numberId: item.numberId, externalNumber: item.externalNumber || "5550199" }, messages: structuredClone(browserMessages) }; return { success: true, data: result as T }; }
  if (event === "reactToMessage") {
    const payload = data as { messageId: number; emoji: string }; const message = browserMessages.find((item) => item.id === payload.messageId);
    if (message) {
      const reactions = message.reactions || []; const existing = reactions.find((item) => item.mine);
      if (existing) { existing.count -= 1; if (existing.count < 1) reactions.splice(reactions.indexOf(existing), 1); else existing.mine = false; }
      if (existing?.emoji !== payload.emoji) { const selected = reactions.find((item) => item.emoji === payload.emoji); if (selected) { selected.count += 1; selected.mine = true; } else reactions.push({ emoji: payload.emoji, count: 1, mine: true }); }
      message.reactions = reactions; const result: MessageReactionUpdate = { messageId: message.id, conversationId: 501, reactions: structuredClone(reactions) }; return { success: true, data: result as T };
    }
  }
  if (event === "getMyActivity") return { success: true, data: structuredClone(browserActivity) as T };
  if (event === "getEmployeeContact") return { success: true, data: { number: "5550199" } as T };
  if (event === "openEmployeeContact") return { success: true, data: { opened: true } as T };
  if (event === "getAdminState") return { success: true, data: makeAdminState() as T };
  if (event === "adminSaveCompany") {
    const input = (data as { company: CompanyPatch }).company;
    const category = browserState.categories.find((item) => item.id === input.categoryId);
    const index = browserState.companies.findIndex((item) => item.id === input.id);
    const current = index >= 0 ? browserState.companies[index] : undefined;
    const available = current?.available ?? false;
    const numbers = input.numbers.map((number, numberIndex) => {
      const id = number.id || `${input.id}-${numberIndex + 1}`;
      const existing = current?.numbers.find((item) => item.id === id);
      return { ...number, id, available: existing?.available ?? (available && number.enabled) };
    });
    const company: Company = { ...input, categoryName: category?.name ?? input.categoryId, available, primaryNumber: numbers.find((number) => number.enabled)?.number, numbers, version: Date.now() };
    if (index >= 0) browserState.companies[index] = company; else browserState.companies.push(company);
    jobs[company.id] = input.job;
    if (company.id === browserWorkspace.companyId) {
      const dispatchEnabled = employment?.employee?.dispatchEnabled === true;
      browserWorkspace.numberStates = company.numbers.map((number) => {
        const currentState = browserWorkspace.numberStates?.find((item) => item.numberId === number.id);
        return { numberId: number.id, label: number.label, enabled: number.enabled, callsEnabled: number.callsEnabled, inboxEnabled: number.inboxEnabled, requestsEnabled: number.requestsEnabled, canSelectForDispatch: dispatchEnabled && number.enabled, selectedForDispatch: currentState?.selectedForDispatch ?? (dispatchEnabled && number.enabled) };
      });
      browserWorkspace.requestSettings.requestNumbers = company.numbers.filter((number) => number.enabled && number.requestsEnabled).map((number) => ({ id: number.id, label: number.label }));
    }
    persistBrowserConfiguration();
    return { success: true, data: structuredClone(company) as T };
  }
  if (event === "adminDeleteCompany") {
    const companyId = (data as { companyId: string }).companyId;
    const removed = browserState.companies.find((company) => company.id === companyId);
    browserState.companies = browserState.companies.filter((company) => company.id !== companyId);
    if (removed) browserDeletedCompanies.unshift({ id: removed.id, job: jobs[removed.id] ?? removed.id, displayName: removed.displayName, logo: removed.logo, categoryId: removed.categoryId, deletedAt: new Date().toISOString() });
    persistBrowserConfiguration();
    return { success: true, data: { id: companyId } as T };
  }
  if (event === "adminRestoreCompany") {
    const companyId = (data as { companyId: string }).companyId;
    const index = browserDeletedCompanies.findIndex((company) => company.id === companyId);
    if (index < 0) return { success: false, error: { code: "company_not_found", message: "Company not found.", retryable: false } };
    const [restored] = browserDeletedCompanies.splice(index, 1);
    const category = browserState.categories.find((item) => item.id === restored.categoryId);
    const company: Company = { id: restored.id, displayName: restored.displayName, logo: restored.logo ?? "", backgroundImage: "", categoryId: restored.categoryId, categoryName: category?.name ?? restored.categoryId, description: "", location: "", openingHours: "", keywords: [], available: false, requestsEnabled: false, messagesEnabled: true, dispatchMode: "ring_all", numbers: [], version: Date.now() };
    browserState.companies.push(company);
    persistBrowserConfiguration();
    return { success: true, data: structuredClone(company) as T };
  }
  if (event === "adminUpdateCategory") {
    const payload = data as { categoryId: string; requestCompetition: boolean };
    const category = browserState.categories.find((item) => item.id === payload.categoryId);
    if (!category) return { success: false, error: { code: "category_not_found", message: "Category not found.", retryable: false } };
    category.requestCompetition = payload.requestCompetition;
    persistBrowserConfiguration();
    return { success: true, data: structuredClone(category) as T };
  }
  if (event === "deleteRequest") {
    const id = Number((data as { id: number }).id); browserWorkspace.requests = browserWorkspace.requests.filter((item) => item.id !== id); return { success: true, data: { id } as T };
  }
  if (event === "deleteConversation") {
    const id = Number((data as { id: number }).id); browserWorkspace.conversations = browserWorkspace.conversations.filter((item) => item.id !== id); return { success: true, data: { id } as T };
  }
  if (event === "deleteMessage") {
    const id = Number((data as { id: number }).id); return { success: true, data: { id, conversationId: 501 } as T };
  }
  if (event === "adminUpdateSettings") {
    browserState.settings = (data as { settings: InitialState["settings"] }).settings;
    persistBrowserConfiguration();
    return { success: true, data: structuredClone(browserState.settings) as T };
  }
  return { success: false, error: { code: "browser_mock", message: "This action requires FiveM.", retryable: false } };
}

interface BrowserConfiguration {
  settings: InitialState["settings"];
  companies: Company[];
  categories: InitialState["categories"];
  currentUser?: InitialState["currentUser"];
  jobs: Record<string, string>;
}

const browserStorageKey = "services-plus-browser-configuration-v1";
function loadBrowserConfiguration(): BrowserConfiguration | null {
  try {
    const value = window.localStorage.getItem(browserStorageKey);
    if (!value) return null;
    const parsed = JSON.parse(value) as BrowserConfiguration;
    return Array.isArray(parsed.companies) && Array.isArray(parsed.categories) && parsed.settings ? parsed : null;
  } catch {
    return null;
  }
}

const persistedBrowserConfiguration = loadBrowserConfiguration();
const browserState = structuredClone(browserFixture);
if (persistedBrowserConfiguration) {
  browserState.settings = persistedBrowserConfiguration.settings;
  browserState.categories = persistedBrowserConfiguration.categories;
  browserState.companies = persistedBrowserConfiguration.companies;
  if (persistedBrowserConfiguration.currentUser) browserState.currentUser = persistedBrowserConfiguration.currentUser;
}
const browserActivity: MyActivity = { calls: [
  { id: 103, companyId: "downtown-cab", displayName: "Downtown Cab Co.", number: "5550100", result: "completed", created_at: "2026-08-01T19:42:00Z", distribution: "dispatch_only", queueDurationSeconds: 14, callDurationSeconds: 187 },
  { id: 102, companyId: "pillbox", displayName: "Pillbox Medical Center", number: "912", result: "answered", created_at: "2026-07-30T08:15:00Z", distribution: "ring_all", queueDurationSeconds: 3, callDurationSeconds: 62 },
  { id: 101, companyId: "bennys", displayName: "Benny's Motorworks", number: "5550200", result: "missed", created_at: "2026-07-27T16:03:00Z", distribution: "ring_all", queueDurationSeconds: 45, callDurationSeconds: null }
], requests: [] };
const requestSettings: RequestSettings = { label: "Ride Request", createLabel: "Request a ride", templateIds: ["immediate_pickup"], navigationOnAccept: "automatic", defaultPhone: "5550199", requestNumbers: [{ id: "taxi-main", label: "Dispatch" }], templates: [
  { id: "immediate_pickup", kind: "specialized", name: "Pickup", fields: [{ id: "people", type: "people", label: "Passengers", required: true, minimum: 1, maximum: 20 }, { id: "phone", type: "phone", label: "Phone number", required: false, maxLength: 32 }] },
], phases: [{ id: "accepted", name: "Accepted" }, { id: "on_the_way", name: "On the way" }, { id: "picked_up", name: "Passenger picked up" }, { id: "ride_active", name: "Ride active" }, { id: "completed", name: "Completed" }], numberId: "taxi-main" };
const browserCitizenConversations: InboxConversation[] = [{ id: 501, companyId: "downtown-cab", companyName: "Downtown Cab Co.", logo: "./icon.svg", numberId: "taxi-main", numberLabel: "Dispatch", lastMessage: "Your driver is on the way.", lastMessageAt: "2026-08-02T18:35:00Z", unreadCount: 0 }];
const browserMessages: InboxMessage[] = [{ id: 1, senderNumber: "5550199", senderType: "citizen", body: "Can I get a pickup at Legion Square?", attachments: [], reactions: [{ emoji: "👍", count: 2, mine: false }], createdAt: "2026-08-02T18:30:00Z" }, { id: 2, senderNumber: "5550100", senderType: "employee", body: "Your driver is on the way.", attachments: [], createdAt: "2026-08-02T18:35:00Z" }];
const browserWorkspace: CompanyWorkspace = { companyId: "downtown-cab", requestSettings, pagination: { conversations: { hasMore: false }, requests: { hasMore: false }, calls: { hasMore: false } }, numberStates: [{ numberId: "taxi-main", label: "Dispatch", enabled: true, callsEnabled: true, inboxEnabled: true, requestsEnabled: true, canSelectForDispatch: true, selectedForDispatch: true }], requests: [{ id: 701, companyId: "downtown-cab", companyName: "Downtown Cab Co.", templateId: "immediate_pickup", requestLabel: "Ride Request", status: "pending", payload: { people: 2, phone: "5550199" }, createdAt: "2026-08-02T19:10:00Z" }, { id: 700, companyId: "downtown-cab", companyName: "Downtown Cab Co.", templateId: "immediate_pickup", requestLabel: "Ride Request", status: "active", phaseId: "driving_to_pickup", payload: { people: 1, phone: "5550124" }, assignee: { name: "Mika Hart", role: "Dispatcher", source: 31 }, createdAt: "2026-08-02T18:50:00Z" }], conversations: [{ id: 501, numberId: "taxi-main", numberLabel: "Dispatch", externalNumber: "5550199", lastMessage: "Can I get a pickup at Legion Square?", lastMessageAt: "2026-08-02T18:30:00Z", unreadCount: 2 }], calls: [{ id: 301, callerNumber: "5550188", numberId: "taxi-main", distribution: "dispatch_only", status: "completed", created_at: "2026-08-02T17:20:00Z", queueDurationSeconds: 9, callDurationSeconds: 214 }] };
browserWorkspace.requests.push(...Array.from({ length: 62 }, (_, index) => ({ id: 699 - index, companyId: "downtown-cab", companyName: "Downtown Cab Co.", templateId: "immediate_pickup", requestLabel: "Ride Request", status: index % 7 === 0 ? "returned" : "completed", payload: { people: index % 4 + 1, phone: `555${String(1200 + index)}` }, createdAt: new Date(Date.UTC(2026, 6, 31, 20, 0, -index)).toISOString() })));
browserWorkspace.calls.push(...Array.from({ length: 62 }, (_, index) => ({ id: 300 - index, callerNumber: `555${String(2000 + index)}`, numberId: "taxi-main", status: index % 5 === 0 ? "missed" : "completed", created_at: new Date(Date.UTC(2026, 6, 31, 18, 0, -index)).toISOString() })));
browserWorkspace.conversations.push(...Array.from({ length: 62 }, (_, index) => ({ id: 500 - index, numberId: index % 2 === 0 ? "taxi-main" : "taxi-booking", numberLabel: index % 2 === 0 ? "Dispatch" : "Bookings", externalNumber: `555${String(3000 + index)}`, lastMessage: `Browser preview conversation ${index + 1}`, lastMessageAt: new Date(Date.UTC(2026, 6, 31, 16, 0, -index)).toISOString(), unreadCount: index % 9 === 0 ? 1 : 0 })));

function makeBrowserWorkspacePage(input: unknown): CompanyWorkspace {
  const payload = (input || {}) as { sections?: WorkspaceSection[]; cursors?: Partial<Record<WorkspaceSection, WorkspaceCursor>>; conversationNumberId?: string; limit?: number; includeSummary?: boolean; seenCallId?: number };
  const requested = new Set(payload.sections || ["conversations", "requests", "calls"]);
  const limit = Math.max(1, Math.min(50, Number(payload.limit) || 24));
  const numericPage = <T extends { id: number }>(items: T[], section: WorkspaceSection) => {
    const cursor = Number(payload.cursors?.[section]) || Number.MAX_SAFE_INTEGER;
    const visible = items.filter((item) => item.id < cursor);
    return { items: visible.slice(0, limit), state: { nextCursor: visible[Math.min(limit, visible.length) - 1]?.id, hasMore: visible.length > limit } };
  };
  const conversationCursor = payload.cursors?.conversations;
  const cursor = typeof conversationCursor === "object" ? conversationCursor : undefined;
  const visibleConversations = browserWorkspace.conversations.filter((item) => (!payload.conversationNumberId || item.numberId === payload.conversationNumberId) && (!cursor || item.lastMessageAt < cursor.lastMessageAt || item.lastMessageAt === cursor.lastMessageAt && item.id < cursor.id));
  const conversationItems = requested.has("conversations") ? visibleConversations.slice(0, limit) : [];
  const requestPage = requested.has("requests") ? numericPage(browserWorkspace.requests, "requests") : { items: [], state: { hasMore: false } };
  const callPage = requested.has("calls") ? numericPage(browserWorkspace.calls, "calls") : { items: [], state: { hasMore: false } };
  const unreadByNumber = browserWorkspace.conversations.reduce<Record<string, number>>((counts, item) => { counts[item.numberId] = (counts[item.numberId] || 0) + Number(item.unreadCount || 0); return counts; }, {});
  const latestCallId = browserWorkspace.calls[0]?.id || 0;
  return structuredClone({ ...browserWorkspace, conversations: conversationItems, requests: requestPage.items, calls: callPage.items, pagination: { conversations: { nextCursor: conversationItems.length ? { lastMessageAt: conversationItems.at(-1)!.lastMessageAt, id: conversationItems.at(-1)!.id } : undefined, hasMore: requested.has("conversations") && visibleConversations.length > limit }, requests: requestPage.state, calls: callPage.state }, summary: payload.includeSummary === false ? undefined : { unansweredRequests: browserWorkspace.requests.filter((item) => item.status === "pending" || item.status === "returned").length, unreadMessages: Object.values(unreadByNumber).reduce((sum, count) => sum + count, 0), unreadByNumber, unseenCalls: browserWorkspace.calls.filter((item) => item.id > Number(payload.seenCallId || 0)).length, latestCallId } });
}
const browserWorkspaceCompany = browserState.companies.find((company) => company.id === browserWorkspace.companyId);
if (browserWorkspaceCompany) {
  const employee = browserState.currentUser.employment?.employee;
  browserWorkspace.numberStates = browserWorkspaceCompany.numbers.map((number) => ({ numberId: number.id, label: number.label, enabled: number.enabled, callsEnabled: number.callsEnabled, inboxEnabled: number.inboxEnabled, requestsEnabled: number.requestsEnabled, canSelectForDispatch: employee?.dispatchEnabled === true && number.enabled, selectedForDispatch: employee?.activeNumberIds?.includes(number.id) === true }));
  browserWorkspace.requestSettings.requestNumbers = browserWorkspaceCompany.numbers.filter((number) => number.enabled && number.requestsEnabled).map((number) => ({ id: number.id, label: number.label }));
}
const jobs: Record<string, string> = { pillbox: "ambulance", "downtown-cab": "taxi", bennys: "mechanic", ...persistedBrowserConfiguration?.jobs };
const browserDeletedCompanies: DeletedCompany[] = [];
function persistBrowserConfiguration() {
  try {
    window.localStorage.setItem(browserStorageKey, JSON.stringify({ settings: browserState.settings, companies: browserState.companies, categories: browserState.categories, currentUser: browserState.currentUser, jobs } satisfies BrowserConfiguration));
  } catch {
    // Browser preview persistence is optional when storage is unavailable.
  }
}
function makeAdminState(): AdminState {
  return { framework: "browser", categories: structuredClone(browserState.categories), settings: structuredClone(browserState.settings), companies: browserState.companies.map((company) => ({ ...structuredClone(company), job: jobs[company.id] ?? company.id } as AdminCompany)), deletedCompanies: structuredClone(browserDeletedCompanies) };
}

export function getInitialState() {
  return fetchNui<InitialState>("getInitialState");
}

export function startCall(number: string) {
  window.createCall?.({ number, videoCall: false, hideNumber: false });
}
