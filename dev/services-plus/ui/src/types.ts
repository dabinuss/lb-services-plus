export type EmployeeStatus = "available" | "busy" | "occupied" | "on_break" | "off_duty";

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
  enabled: boolean;
  callsEnabled: boolean;
  inboxEnabled: boolean;
  requestsEnabled: boolean;
  publicVisible: boolean;
  available?: boolean;
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
  requestsEnabled: boolean;
  hasRequestTemplates?: boolean;
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
  hasRequestTemplates?: boolean;
  requestCompetition: boolean;
}

export interface Employee {
  source: number;
  name: string;
  role: string;
  grade: number;
  companyId: string;
  status: EmployeeStatus;
  dispatchEnabled: boolean;
  dispatchForced: boolean;
  isLeader: boolean;
  activeCall: boolean;
  activeRequest: boolean;
  activeCallId?: number;
  activeRequestId?: number;
  activeNumberIds?: string[];
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

export type NumberOperationsPatch = Pick<CompanyNumber, "id" | "enabled" | "callsEnabled" | "inboxEnabled" | "requestsEnabled" | "publicVisible" | "distribution">;

export interface AdminCompany extends Company {
  job: string;
}

export interface DeletedCompany {
  id: string;
  job: string;
  displayName: string;
  logo?: string;
  categoryId: string;
  deletedAt: string;
  deletedBy?: string;
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
  numbers: Array<Omit<CompanyNumber, "id" | "available"> & { id?: string }>;
}

export interface CitizenRequest {
  id: number;
  companyId: string;
  company_id?: string;
  companyName: string;
  status: string;
  phaseId?: string;
  phase_id?: string;
  payload?: Record<string, string | number>;
  details?: string;
  location?: string;
  createdAt?: string;
  created_at?: string;
  templateId?: string;
  template_id?: string;
  requestLabel?: string;
  request_label?: string;
  assignee?: { name: string; role: string; source?: number; identifier?: string };
  phases?: RequestPhase[];
}

export interface CitizenCall {
  id: number;
  companyId: string;
  displayName: string;
  number: string;
  result: string;
  created_at: string;
  distribution?: "ring_all" | "random" | "dispatch_only";
  queueDurationSeconds?: number;
  callDurationSeconds?: number | null;
}

export interface RequestField {
  id: string;
  type: "text" | "description" | "location" | "phone" | "requested_time" | "people" | "vehicle_plate" | "image" | "notes" | "select";
  label: string;
  required: boolean;
  enabled?: boolean;
  maxLength?: number;
  minimum?: number;
  maximum?: number;
  options?: Array<{ value: string; label: string }>;
}

export interface RequestTemplate { id: string; kind: "general" | "specialized"; name: string; fields: RequestField[]; }
export interface RequestPhase { id: string; name: string; }
export interface RequestSettings {
  label: string;
  createLabel: string;
  templateIds: string[];
  templates: RequestTemplate[];
  phases: RequestPhase[];
  fieldSettings?: Record<string, Record<string, { enabled: boolean; required: boolean }>>;
  numberId?: string;
  requestNumbers?: Array<{ id: string; label: string }>;
  navigationOnAccept: "disabled" | "ask" | "automatic";
  defaultPhone?: string;
}

export interface InboxConversation {
  id: number;
  companyId?: string;
  companyName?: string;
  logo?: string;
  numberId: string;
  numberLabel: string;
  externalNumber?: string;
  lastMessage: string;
  lastMessageAt: string;
  unreadCount: number;
}

export interface InboxMessage {
  id: number;
  senderNumber: string;
  senderType: "citizen" | "employee";
  body: string;
  attachments: string[];
  coords?: { x: number; y: number };
  created_at?: string;
  createdAt?: string;
  reactions?: MessageReaction[];
}

export interface MessageReaction { emoji: string; count: number; mine: boolean; }
export interface MessageReactionUpdate { messageId: number; conversationId: number; reactions: MessageReaction[]; personal?: boolean; }

export interface ConversationData { conversation: { id: number; companyId: string; numberId: string; externalNumber: string }; messages: InboxMessage[]; }
export interface CompanyCall { id: number; callerNumber?: string; numberId: string; distribution?: "ring_all" | "random" | "dispatch_only"; status: string; assignedIdentifier?: string; created_at: string; queueDurationSeconds?: number; callDurationSeconds?: number | null; }
export interface NumberState { numberId: string; label: string; enabled: boolean; callsEnabled: boolean; inboxEnabled: boolean; requestsEnabled: boolean; canSelectForDispatch: boolean; selectedForDispatch: boolean; }
export type WorkspaceSection = "conversations" | "requests" | "calls";
export interface ConversationCursor { lastMessageAt: string; id: number; }
export type WorkspaceCursor = number | ConversationCursor;
export interface WorkspacePageState { nextCursor?: WorkspaceCursor; hasMore: boolean; }
export interface WorkspaceSummary { unansweredRequests: number; unreadMessages: number; unreadByNumber: Record<string, number>; unseenCalls: number; latestCallId: number; }
export interface CompanyWorkspace { companyId?: string; conversations: InboxConversation[]; requests: CitizenRequest[]; calls: CompanyCall[]; requestSettings: RequestSettings; numberStates?: NumberState[]; pagination: Record<WorkspaceSection, WorkspacePageState>; summary?: WorkspaceSummary; }
export interface WorkOffer {
  kind: "call" | "request";
  id: number;
  title: string;
  subtitle: string;
  callToken?: string;
  payload?: Record<string, unknown>;
  companyName?: string;
  companyLogo?: string;
  companyBackground?: string;
  categoryName?: string;
  categoryIcon?: string;
}

export interface MyActivity { calls: CitizenCall[]; requests: CitizenRequest[]; conversations?: InboxConversation[]; }

export interface AdminState {
  companies: AdminCompany[];
  deletedCompanies: DeletedCompany[];
  categories: Category[];
  settings: AppSettings;
  framework: string;
}
