import type { AdminCompany, AdminState, ApiResponse, CitizenRequest, Company, CompanyOperationsPatch, CompanyPatch, InitialState, MyActivity } from "../types";
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
    const employee: Employee = { source: browserState.currentUser.source, name: browserState.currentUser.name, role: "Operations Manager", companyId: employment.companyId, status: "available", dispatchEnabled: true, dispatchForced: false, isLeader: employment.isLeader, activeCall: false, activeRequest: false, version: 2 };
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
    if (event === "toggleDispatch" && typeof payload.enabled === "boolean") employment.employee.dispatchEnabled = payload.enabled;
    employment.activeEmployees = employment.activeEmployees.map((employee) => employee.source === employment.employee?.source ? employment.employee : employee).filter(Boolean) as Employee[];
    return { success: true, data: structuredClone(employment.employee) as T };
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
    const payload = data as { companyId: string; details: string; location: string };
    const company = browserState.companies.find((item) => item.id === payload.companyId);
    if (company) {
      const request: CitizenRequest = { id: Date.now(), companyId: company.id, companyName: company.displayName, status: "pending", details: payload.details, location: payload.location, createdAt: new Date().toISOString() };
      browserActivity.requests.unshift(request);
      return { success: true, data: request as T };
    }
  }
  if (event === "getMyActivity") return { success: true, data: structuredClone(browserActivity) as T };
  if (event === "getEmployeeContact") return { success: true, data: { number: "5550199" } as T };
  if (event === "openEmployeeContact") return { success: true, data: { opened: true } as T };
  if (event === "getAdminState") return { success: true, data: makeAdminState() as T };
  if (event === "adminSaveCompany") {
    const input = (data as { company: CompanyPatch }).company;
    const category = browserState.categories.find((item) => item.id === input.categoryId);
    const company: Company = { ...input, categoryName: category?.name ?? input.categoryId, available: false, employeeCount: 0, primaryNumber: input.numbers[0]?.number, numbers: input.numbers.map((number, index) => ({ ...number, id: `${input.id}-${index + 1}` })), version: Date.now() };
    const index = browserState.companies.findIndex((item) => item.id === company.id);
    if (index >= 0) browserState.companies[index] = company; else browserState.companies.push(company);
    return { success: true, data: structuredClone(company) as T };
  }
  if (event === "adminDeleteCompany") {
    const companyId = (data as { companyId: string }).companyId;
    browserState.companies = browserState.companies.filter((company) => company.id !== companyId);
    return { success: true, data: { id: companyId } as T };
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
const jobs: Record<string, string> = { pillbox: "ambulance", "downtown-cab": "taxi", bennys: "mechanic" };
function makeAdminState(): AdminState {
  return { framework: "browser", categories: structuredClone(browserState.categories), settings: structuredClone(browserState.settings), companies: browserState.companies.map((company) => ({ ...structuredClone(company), job: jobs[company.id] ?? company.id } as AdminCompany)) };
}

export function getInitialState() {
  return fetchNui<InitialState>("getInitialState");
}

export function startCall(number: string) {
  window.createCall?.({ number, videoCall: false, hideNumber: false });
}
