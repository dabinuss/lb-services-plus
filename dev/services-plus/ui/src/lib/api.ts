import type { AdminCompany, AdminState, ApiResponse, CitizenRequest, Company, CompanyOperationsPatch, CompanyPatch, CompanyWorkspace, ConversationData, InboxConversation, InboxMessage, InitialState, MessageReactionUpdate, MyActivity, RequestSettings } from "../types";
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
    const employee: Employee = { source: browserState.currentUser.source, name: browserState.currentUser.name, role: "Operations Manager", companyId: employment.companyId, status: "available", dispatchEnabled: true, dispatchForced: false, isLeader: employment.isLeader, activeCall: false, activeRequest: false, activeNumberIds: ["taxi-main"], version: 2 };
    const colleagues: Employee[] = [
      { source: 24, name: "Avery Brooks", role: "Senior Driver", companyId: employment.companyId, status: "available", dispatchEnabled: true, dispatchForced: false, isLeader: false, activeCall: false, activeRequest: false, version: 2 },
      { source: 31, name: "Mika Hart", role: "Dispatcher", companyId: employment.companyId, status: "on_break", dispatchEnabled: true, dispatchForced: false, isLeader: false, activeCall: false, activeRequest: false, version: 2 }
    ];
    employment.onDuty = true; employment.employee = employee; employment.activeEmployees = [employee, ...colleagues];
    browserState.companies = browserState.companies.map((company) => company.id === employment.companyId ? { ...company, available: true, employeeCount: 3 } : company);
    return { success: true, data: { currentUser: structuredClone(browserState.currentUser), companies: structuredClone(browserState.companies) } as T };
  }
  if (event === "leaveDuty" && employment) {
    employment.onDuty = false; employment.employee = null; employment.activeEmployees = [];
    return { success: true, data: { currentUser: structuredClone(browserState.currentUser), companies: structuredClone(browserState.companies) } as T };
  }
  if ((event === "updateStatus" || event === "toggleDispatch") && employment?.employee) {
    const payload = data as { status?: Employee["status"]; enabled?: boolean };
    if (event === "updateStatus" && payload.status) employment.employee.status = payload.status;
    if (event === "toggleDispatch" && typeof payload.enabled === "boolean") {
      employment.employee.dispatchEnabled = payload.enabled;
      browserWorkspace.numberSubscriptions?.forEach((number) => {
        number.canSubscribe = number.authorized && (payload.enabled || number.staffingMode === "self_select" || number.staffingMode === "restricted");
        if (payload.enabled && number.enabled && number.authorized) number.subscribed = true;
      });
      if (payload.enabled) employment.employee.activeNumberIds = browserWorkspace.numberSubscriptions?.filter((number) => number.enabled && number.authorized).map((number) => number.numberId) || [];
    }
    employment.activeEmployees = employment.activeEmployees.map((employee) => employee.source === employment.employee?.source ? employment.employee : employee).filter(Boolean) as Employee[];
    return { success: true, data: structuredClone(employment.employee) as T };
  }
  if (event === "toggleNumberSubscription" && employment?.employee) {
    const payload = data as { numberId: string; enabled: boolean };
    employment.employee.activeNumberIds = payload.enabled ? [...new Set([...(employment.employee.activeNumberIds || []), payload.numberId])] : (employment.employee.activeNumberIds || []).filter((id) => id !== payload.numberId);
    const subscription = browserWorkspace.numberSubscriptions?.find((item) => item.numberId === payload.numberId); if (subscription) subscription.subscribed = payload.enabled;
    return { success: true, data: structuredClone(employment.employee) as T };
  }
  if (event === "updateNumberOperations") {
    const numbers = (data as { numbers: Array<{ id: string } & Partial<Company["numbers"][number]>> }).numbers;
    const company = browserState.companies.find((item) => item.id === employment?.companyId);
    if (company) company.numbers = company.numbers.map((number) => ({ ...number, ...(numbers.find((item) => item.id === number.id) || {}) }));
    browserWorkspace.numberSubscriptions?.forEach((subscription) => {
      const update = numbers.find((number) => number.id === subscription.numberId);
      if (update) Object.assign(subscription, update);
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
  if (event === "getCompanyWorkspace") return { success: true, data: structuredClone(browserWorkspace) as T };
  if (event === "acceptRequest" || event === "transitionRequest" || event === "returnRequest") {
    const payload = data as { id: number; phaseId?: string }; const request = browserWorkspace.requests.find((item) => item.id === payload.id);
    if (request) { if (event === "acceptRequest") { request.status = "active"; request.phaseId = "accepted"; if (employment?.employee) { employment.employee.status = "busy"; employment.employee.activeRequest = true; employment.employee.activeRequestId = request.id; } } if (event === "transitionRequest" && payload.phaseId) { request.phaseId = payload.phaseId; if (payload.phaseId === "completed") request.status = "completed"; } if (event === "returnRequest") { request.status = "returned"; request.phaseId = undefined; if (employment?.employee) { employment.employee.status = "available"; employment.employee.activeRequest = false; employment.employee.activeRequestId = undefined; } } return { success: true, data: structuredClone(request) as T }; }
  }
  if (event === "cancelRequest") { const request = browserActivity.requests.find((item) => item.id === (data as { id: number }).id) || browserWorkspace.requests.find((item) => item.id === (data as { id: number }).id); if (request) { request.status = "cancelled"; return { success: true, data: structuredClone(request) as T }; } }
  if (event === "updateNumberEligibility") {
    const payload = data as { numberId: string; targetSource: number; enabled: boolean };
    const eligibility = browserWorkspace.numberEligibility?.find((number) => number.numberId === payload.numberId)?.people.find((person) => person.source === payload.targetSource);
    if (eligibility) eligibility.eligible = payload.enabled;
    return { success: true, data: structuredClone(data) as T };
  }
  if (event === "updateRequestSettings") { browserWorkspace.requestSettings = { ...browserWorkspace.requestSettings, ...(data as { settings: RequestSettings }).settings }; return { success: true, data: structuredClone(browserWorkspace.requestSettings) as T }; }
  if (event === "getCitizenInbox") return { success: true, data: structuredClone(browserCitizenConversations) as T };
  if (event === "sendCitizenMessage" || event === "sendEmployeeMessage") {
    const payload = data as { companyId?: string; numberId?: string; conversationId?: number; body: string; attachments: string[] }; const company = browserState.companies.find((item) => item.id === payload.companyId) || browserState.companies[1];
    let conversation = [...browserCitizenConversations, ...browserWorkspace.conversations].find((item) => item.id === payload.conversationId || (item.companyId === company.id && item.numberId === payload.numberId));
    if (!conversation) { conversation = { id: Date.now(), companyId: company.id, companyName: company.displayName, logo: company.logo, numberId: payload.numberId || company.numbers[0].id, numberLabel: company.numbers[0].label, externalNumber: "5550199", lastMessage: payload.body, lastMessageAt: new Date().toISOString(), unreadCount: 0 }; browserCitizenConversations.unshift(conversation); }
    conversation.lastMessage = payload.body || "Attachment"; const message: InboxMessage = { id: Date.now(), senderNumber: event === "sendCitizenMessage" ? "5550199" : company.numbers[0].number, senderType: event === "sendCitizenMessage" ? "citizen" : "employee", body: payload.body, attachments: payload.attachments || [], createdAt: new Date().toISOString() }; browserMessages.push(message); return { success: true, data: message as T };
  }
  if (event === "sendCurrentLocation") return { success: true, data: { id: Date.now(), body: "", attachments: [], coords: { x: 215.4, y: -810.2 } } as T };
  if (event === "getConversationMessages") { const payload = data as { conversationId: number }; const item = [...browserCitizenConversations, ...browserWorkspace.conversations].find((entry) => entry.id === payload.conversationId)!; const result: ConversationData = { conversation: { id: item.id, companyId: item.companyId || "downtown-cab", numberId: item.numberId, externalNumber: item.externalNumber || "5550199" }, messages: structuredClone(browserMessages) }; return { success: true, data: result as T }; }
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
    const company: Company = { ...input, categoryName: category?.name ?? input.categoryId, available: false, employeeCount: 0, primaryNumber: input.numbers[0]?.number, numbers: input.numbers.map((number, index) => ({ ...number, id: number.id || `${input.id}-${index + 1}` })), version: Date.now() };
    const index = browserState.companies.findIndex((item) => item.id === company.id);
    if (index >= 0) browserState.companies[index] = company; else browserState.companies.push(company);
    if (company.id === browserWorkspace.companyId) {
      browserWorkspace.numberSubscriptions?.forEach((subscription) => {
        const number = company.numbers.find((item) => item.id === subscription.numberId);
        if (number) Object.assign(subscription, number);
      });
    }
    return { success: true, data: structuredClone(company) as T };
  }
  if (event === "adminDeleteCompany") {
    const companyId = (data as { companyId: string }).companyId;
    browserState.companies = browserState.companies.filter((company) => company.id !== companyId);
    return { success: true, data: { id: companyId } as T };
  }
  if (event === "adminUpdateCategory") {
    const payload = data as { categoryId: string; requestCompetition: boolean };
    const category = browserState.categories.find((item) => item.id === payload.categoryId);
    if (!category) return { success: false, error: { code: "category_not_found", message: "Category not found.", retryable: false } };
    category.requestCompetition = payload.requestCompetition;
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
    return { success: true, data: structuredClone(browserState.settings) as T };
  }
  return { success: false, error: { code: "browser_mock", message: "This action requires FiveM.", retryable: false } };
}

const browserState = structuredClone(browserFixture);
const browserActivity: MyActivity = { calls: [
  { id: 103, companyId: "downtown-cab", displayName: "Downtown Cab Co.", number: "5550100", result: "completed", created_at: "2026-08-01T19:42:00Z" },
  { id: 102, companyId: "pillbox", displayName: "Pillbox Medical Center", number: "912", result: "answered", created_at: "2026-07-30T08:15:00Z" },
  { id: 101, companyId: "bennys", displayName: "Benny's Motorworks", number: "5550200", result: "missed", created_at: "2026-07-27T16:03:00Z" }
], requests: [] };
const requestSettings: RequestSettings = { label: "Ride Request", createLabel: "Request a ride", templateIds: ["general", "appointment", "complaint", "information", "callback", "immediate_pickup"], phaseIds: ["accepted", "on_the_way", "picked_up", "ride_active", "completed"], navigationOnAccept: "automatic", defaultPhone: "5550199", requestNumbers: [{ id: "taxi-main", label: "Dispatch" }], templates: [
  { id: "general", kind: "general", name: "General request", fields: [{ id: "subject", type: "text", label: "Subject", required: true, maxLength: 120 }, { id: "description", type: "description", label: "Description", required: true, maxLength: 1000 }, { id: "phone", type: "phone", label: "Phone number", required: false, maxLength: 32 }] },
  { id: "appointment", kind: "general", name: "Appointment request", fields: [{ id: "description", type: "description", label: "Description", required: true, maxLength: 1000 }, { id: "phone", type: "phone", label: "Phone number", required: false, maxLength: 32 }] },
  { id: "complaint", kind: "general", name: "Complaint", fields: [{ id: "description", type: "description", label: "Description", required: true, maxLength: 1000 }, { id: "phone", type: "phone", label: "Phone number", required: false, maxLength: 32 }] },
  { id: "information", kind: "general", name: "Information request", fields: [{ id: "description", type: "description", label: "Description", required: true, maxLength: 1000 }, { id: "phone", type: "phone", label: "Phone number", required: false, maxLength: 32 }] },
  { id: "callback", kind: "general", name: "Request a callback", fields: [{ id: "description", type: "description", label: "Description", required: true, maxLength: 1000 }, { id: "phone", type: "phone", label: "Phone number", required: false, maxLength: 32 }] },
  { id: "immediate_pickup", kind: "specialized", name: "Pickup", fields: [{ id: "location", type: "location", label: "Pickup location", required: true, maxLength: 150 }, { id: "people", type: "people", label: "Passengers", required: true, minimum: 1, maximum: 20 }, { id: "phone", type: "phone", label: "Phone number", required: false, maxLength: 32 }] }
], phases: [{ id: "accepted", name: "Accepted" }, { id: "on_the_way", name: "On the way" }, { id: "picked_up", name: "Passenger picked up" }, { id: "ride_active", name: "Ride active" }, { id: "completed", name: "Completed" }], numberId: "taxi-main" };
const browserCitizenConversations: InboxConversation[] = [{ id: 501, companyId: "downtown-cab", companyName: "Downtown Cab Co.", logo: "./icon.svg", numberId: "taxi-main", numberLabel: "Dispatch", lastMessage: "Your driver is on the way.", lastMessageAt: "2026-08-02T18:35:00Z", unreadCount: 0 }];
const browserMessages: InboxMessage[] = [{ id: 1, senderNumber: "5550199", senderType: "citizen", body: "Can I get a pickup at Legion Square?", attachments: [], reactions: [{ emoji: "👍", count: 2, mine: false }], createdAt: "2026-08-02T18:30:00Z" }, { id: 2, senderNumber: "5550100", senderType: "employee", body: "Your driver is on the way.", attachments: [], createdAt: "2026-08-02T18:35:00Z" }];
const browserWorkspace: CompanyWorkspace = { companyId: "downtown-cab", requestSettings, numberEligibility: [{ numberId: "taxi-main", label: "Dispatch", people: [{ source: 12, name: "Jordan Reed", eligible: true }, { source: 24, name: "Avery Brooks", eligible: true }, { source: 31, name: "Mika Hart", eligible: true }] }], numberSubscriptions: [{ numberId: "taxi-main", label: "Dispatch", enabled: true, callsEnabled: true, inboxEnabled: true, requestsEnabled: true, staffingMode: "self_select", authorized: true, canSubscribe: true, subscribed: true }], requests: [{ id: 701, companyId: "downtown-cab", companyName: "Downtown Cab Co.", templateId: "immediate_pickup", requestLabel: "Ride Request", status: "pending", payload: { location: "Legion Square", people: 2 }, createdAt: "2026-08-02T19:10:00Z" }], conversations: [{ id: 501, numberId: "taxi-main", numberLabel: "Dispatch", externalNumber: "5550199", lastMessage: "Can I get a pickup at Legion Square?", lastMessageAt: "2026-08-02T18:30:00Z", unreadCount: 2 }], calls: [{ id: 301, callerNumber: "5550188", numberId: "taxi-main", status: "completed", created_at: "2026-08-02T17:20:00Z" }] };
const jobs: Record<string, string> = { pillbox: "ambulance", "downtown-cab": "taxi", bennys: "mechanic" };
function makeAdminState(): AdminState {
  return { framework: "browser", categories: structuredClone(browserState.categories), settings: structuredClone(browserState.settings), companies: browserState.companies.map((company) => ({ ...structuredClone(company), job: jobs[company.id] ?? company.id } as AdminCompany)), numberEligibility: Object.fromEntries(browserState.companies.map((company) => [company.id, company.id === browserWorkspace.companyId ? structuredClone(browserWorkspace.numberEligibility || []) : []])) };
}

export function getInitialState() {
  return fetchNui<InitialState>("getInitialState");
}

export function startCall(number: string) {
  window.createCall?.({ number, videoCall: false, hideNumber: false });
}
