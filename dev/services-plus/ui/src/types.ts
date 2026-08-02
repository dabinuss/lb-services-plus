export type EmployeeStatus = "available" | "busy" | "on_break" | "off_duty";

export interface ApiError {
  code: string;
  message: string;
  retryable: boolean;
}

export type ApiResponse<T> =
  | { success: true; data: T }
  | { success: false; error: ApiError };

export interface CompanyNumber {
  id: string;
  label: string;
  number: string;
  distribution: "ring_all" | "random" | "dispatch_only";
  sharedInbox: boolean;
}

export interface Company {
  id: string;
  displayName: string;
  logo: string;
  backgroundImage: string;
  categoryId: string;
  categoryName: string;
  description: string;
  location: string;
  openingHours: string;
  keywords: string[];
  available: boolean;
  employeeCount: number;
  requestsEnabled: boolean;
  messagesEnabled: boolean;
  dispatchMode: "ring_all" | "random" | "dispatch_only";
  primaryNumber?: string;
  numbers: CompanyNumber[];
  version: number;
}

export interface Category {
  id: string;
  icon: string;
  name: string;
  names: { en: string; de: string };
  keywords: string[];
}

export interface Employee {
  source: number;
  name: string;
  role: string;
  companyId: string;
  status: EmployeeStatus;
  dispatchEnabled: boolean;
  dispatchForced: boolean;
  isLeader: boolean;
  activeCall: boolean;
  activeRequest: boolean;
  version: number;
}

export interface Employment {
  companyId: string;
  companyName: string;
  isLeader: boolean;
  onDuty: boolean;
  employee: Employee | null;
  activeEmployees: Employee[];
}

export interface CurrentUser {
  source: number;
  name: string;
  isServerAdmin: boolean;
  employment: Employment | null;
}

export interface AppSettings {
  directoryTitle: string;
  callsEnabled: boolean;
  requestsEnabled: boolean;
}

export interface InitialState {
  apiVersion: number;
  locale: string;
  framework: string;
  settings: AppSettings;
  companies: Company[];
  categories: Category[];
  currentUser: CurrentUser;
}

export interface AppMessage<T = unknown> {
  type: string;
  version?: number;
  timestamp?: number;
  payload: T;
}

export interface CompanyOperationsPatch {
  requestsEnabled: boolean;
  messagesEnabled: boolean;
  dispatchMode: "ring_all" | "random" | "dispatch_only";
}

export interface AdminCompany extends Company {
  job: string;
}

export interface CompanyPatch {
  id: string;
  job: string;
  displayName: string;
  logo: string;
  backgroundImage: string;
  categoryId: string;
  description: string;
  location: string;
  openingHours: string;
  requestsEnabled: boolean;
  messagesEnabled: boolean;
  dispatchMode: "ring_all" | "random" | "dispatch_only";
  keywords: string[];
  numbers: Array<Omit<CompanyNumber, "id">>;
}

export interface CitizenRequest {
  id: number;
  companyId: string;
  companyName: string;
  status: string;
  phaseId?: string;
  payload?: { details?: string; location?: string };
  details?: string;
  location?: string;
  createdAt?: string;
  created_at?: string;
}

export interface CitizenCall {
  id: number;
  companyId: string;
  displayName: string;
  number: string;
  result: string;
  created_at: string;
}

export interface MyActivity { calls: CitizenCall[]; requests: CitizenRequest[]; }

export interface AdminState {
  companies: AdminCompany[];
  categories: Category[];
  settings: AppSettings;
  framework: string;
}
