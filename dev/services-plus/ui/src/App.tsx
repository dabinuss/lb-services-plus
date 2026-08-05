import { BriefcaseBusiness, Building2, ClipboardList, LoaderCircle, ShieldCheck } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { Activity } from "./components/Activity";
import { AdminPanel } from "./components/AdminPanel";
import { ConfirmDialog } from "./components/ConfirmDialog";
import { ConversationView } from "./components/ConversationView";
import { Directory } from "./components/Directory";
import { IncomingOffer } from "./components/IncomingOffer";
import { MessageComposer } from "./components/MessageComposer";
import { NumberSelector } from "./components/NumberSelector";
import { Portal } from "./components/Portal";
import { RequestComposer } from "./components/RequestComposer";
import { fetchNui, getInitialState, startCall } from "./lib/api";
import { subscribeToNui } from "./lib/events";
import { t, type Locale } from "./lib/i18n";
import { appendUnique, WorkspaceRequestGate } from "./lib/workspace";
import type { AdminState, AppMessage, AppSettings, Category, CitizenRequest, Company, CompanyNumber, CompanyPatch, CompanyWorkspace, CurrentUser, Employee, EmployeeStatus, InboxConversation, InboxMessage, InitialState, MessageReaction, MessageReactionUpdate, MyActivity, NumberOperationsPatch, RequestSettings, WorkOffer, WorkspaceCursor, WorkspaceSection } from "./types";

// Groups identical resubmissions of the same content within a short window under one
// key, so a double click or a retry after a lost response cannot create a duplicate
// request or message. A genuinely new submission a few seconds later gets a new key.
function idempotencyKey(parts: unknown[]): string {
  return `${Math.floor(Date.now() / 15000)}:${JSON.stringify(parts)}`;
}

type View = "directory" | "activity" | "portal" | "admin";
export default function App() {
  const [state, setState] = useState<InitialState | null>(null); const [view, setView] = useState<View>("directory");
  const [locale, setLocaleState] = useState<Locale>(() => localStorage.getItem("services-plus-locale") === "de" ? "de" : "en");
  const [loading, setLoading] = useState(true); const [busy, setBusy] = useState(false); const [error, setError] = useState<string | null>(null); const [toast, setToast] = useState<string | null>(null);
  const [requestCompany, setRequestCompany] = useState<Company | null>(null); const [messageCompany, setMessageCompany] = useState<Company | null>(null);
  const [callCompanyChoice, setCallCompanyChoice] = useState<Company | null>(null);
  const [activity, setActivity] = useState<MyActivity | null>(null); const [activityLoading, setActivityLoading] = useState(false); const [workspace, setWorkspace] = useState<CompanyWorkspace | null>(null);
  const [conversation, setConversation] = useState<{ item: InboxConversation; citizen: boolean } | null>(null); const [offer, setOffer] = useState<WorkOffer | null>(null); const [adminState, setAdminState] = useState<AdminState | null>(null);
  const [confirmState, setConfirmState] = useState<{ message: string; onConfirm: () => void } | null>(null);
  const confirmAction = (message: string, action: () => void) => setConfirmState({ message, onConfirm: () => { setConfirmState(null); action(); } });
  const toastTimer = useRef<number | undefined>(undefined); const localeRef = useRef(locale); const sourceRef = useRef<number | undefined>(undefined); const stateRef = useRef<InitialState | null>(null); const workspaceGate = useRef(new WorkspaceRequestGate()); const workspaceInboxRef = useRef<string | undefined>(undefined);

  const setLocale = (next: Locale) => { localStorage.setItem("services-plus-locale", next); localeRef.current = next; setLocaleState(next); };
  useEffect(() => { sourceRef.current = state?.currentUser.source; stateRef.current = state; }, [state]);
  const notify = useCallback((message: string) => { if (toastTimer.current) window.clearTimeout(toastTimer.current); setToast(message); toastTimer.current = window.setTimeout(() => setToast(null), 2600); }, []);
  const load = useCallback(async () => {
    setLoading(true); setError(null);
    try {
      const response = await getInitialState();
      if (response.success) setState(response.data); else setError(response.error.message);
    } catch {
      setError(t(localeRef.current, "operationFailed"));
    } finally {
      setLoading(false);
    }
  }, []);
  const loadWorkspace = useCallback(async (section?: WorkspaceSection, cursor?: WorkspaceCursor, conversationNumberId?: string, replace = false) => {
    if (section === "conversations" && !cursor) workspaceInboxRef.current = conversationNumberId;
    const token = workspaceGate.current.begin(section);
    try {
      const companyId = stateRef.current?.currentUser.employment?.companyId;
      let seenCallId = 0;
      try { if (companyId) seenCallId = Number(sessionStorage.getItem(`services-plus-seen-calls:${companyId}`)) || 0; } catch { /* Session persistence is optional. */ }
      const inboxNumberId = section === "conversations" ? conversationNumberId : !section ? workspaceInboxRef.current : undefined;
      const response = await fetchNui<CompanyWorkspace>("getCompanyWorkspace", { limit: 24, locale: localeRef.current, includeSummary: !section, seenCallId, ...(inboxNumberId ? { conversationNumberId: inboxNumberId } : {}), ...(section ? { sections: [section], cursors: cursor ? { [section]: cursor } : {} } : {}) });
      if (!workspaceGate.current.isCurrent(token)) return false;
      if (!response.success) { notify(response.error.message); return false; }
      if (!section) setWorkspace(response.data);
      else setWorkspace((current) => {
        if (!current) return response.data;
        const pagination = { ...current.pagination, [section]: response.data.pagination[section] };
        if (section === "requests") return { ...current, requests: appendUnique(current.requests, response.data.requests), pagination };
        if (section === "calls") return { ...current, calls: appendUnique(current.calls, response.data.calls), pagination };
        return { ...current, conversations: replace ? response.data.conversations : appendUnique(current.conversations, response.data.conversations), pagination };
      });
      return true;
    } catch {
      notify(t(localeRef.current, "operationFailed"));
      return false;
    }
  }, [notify]);
  const markConversationRead = useCallback((conversationId: number) => setWorkspace((current) => {
    const item = current?.conversations.find((entry) => entry.id === conversationId);
    const unread = Number(item?.unreadCount || 0);
    if (!current || !item || unread < 1) return current;
    const byNumber = { ...(current.summary?.unreadByNumber || {}) };
    byNumber[item.numberId] = Math.max(0, Number(byNumber[item.numberId] || 0) - unread);
    return { ...current, conversations: current.conversations.map((entry) => entry.id === conversationId ? { ...entry, unreadCount: 0 } : entry), summary: current.summary ? { ...current.summary, unreadMessages: Math.max(0, current.summary.unreadMessages - unread), unreadByNumber: byNumber } : undefined };
  }), []);

  useEffect(() => {
    let active = true; void getInitialState().then((response) => { if (!active) return; if (response.success) setState(response.data); else setError(response.error.message); }).catch(() => { if (active) setError(t(localeRef.current, "operationFailed")); }).finally(() => { if (active) setLoading(false); });
    const unsubscribe = subscribeToNui((message: AppMessage) => {
      if (!active) return;
      if (message.type === "company.updated") { const company = message.payload as Company; setState((current) => current ? { ...current, companies: current.companies.some((item) => item.id === company.id) ? current.companies.map((item) => item.id === company.id ? company : item) : [...current.companies, company] } : current); }
      if (message.type === "company.deleted") { const { id } = message.payload as { id: string }; setState((current) => current ? { ...current, companies: current.companies.filter((company) => company.id !== id) } : current); }
      if (message.type === "settings.updated") { const settings = message.payload as AppSettings; setState((current) => current ? { ...current, settings } : current); }
      if (message.type === "category.updated") { const category = message.payload as Category; setState((current) => current ? { ...current, categories: current.categories.map((item) => item.id === category.id ? category : item) } : current); setAdminState((current) => current ? { ...current, categories: current.categories.map((item) => item.id === category.id ? category : item) } : current); }
      if (message.type === "employee.updated" || message.type === "employee.removed") {
        const employee = message.payload as Employee; setState((current) => { const employment = current?.currentUser.employment; if (!current || !employment || (employee.companyId && employee.companyId !== employment.companyId)) return current; const without = employment.activeEmployees.filter((item) => item.source !== employee.source); const activeEmployees = message.type === "employee.updated" ? [...without, employee].sort((a, b) => a.name.localeCompare(b.name)) : without; const ownEmployee = employee.source === current.currentUser.source && message.type === "employee.updated" ? employee : employment.employee; return { ...current, currentUser: { ...current.currentUser, employment: { ...employment, employee: ownEmployee, activeEmployees } } }; });
        if (employee.source === sourceRef.current && employee.status !== "available") setOffer(null);
      }
      if (message.type === "call.offer") { const item = message.payload as { id: number; callToken: string; companyName: string; numberLabel: string }; setOffer({ kind: "call", id: item.id, callToken: item.callToken, title: item.companyName, subtitle: item.numberLabel }); }
      if (message.type === "call.queue") { const item = message.payload as { position: number }; notify(`${t(localeRef.current, "queuePosition")}: ${item.position}`); }
      // A request offer only ever shows through LB Phone's own notification (see
      // server/requests.lua's SendNotification, gated by the company's
      // requestNotificationActionable setting) - nothing renders in the app itself.
      if (message.type === "call.offer.removed" || message.type === "call.accepted.local") { const item = message.payload as { id: number }; setOffer((current) => current?.kind === "call" && current.id === item.id ? null : current); }
      if (message.type === "request.citizen.updated") { const item = message.payload as CitizenRequest; setActivity((current) => current ? { ...current, requests: current.requests.some((request) => request.id === item.id) ? current.requests.map((request) => request.id === item.id ? item : request) : [item, ...current.requests] } : { calls: [], conversations: [], requests: [item] }); }
      if (message.type === "request.updated" || message.type === "inbox.message") void loadWorkspace();
      if (message.type === "inbox.deleted") { const item = message.payload as { id: number }; setConversation((current) => current?.item.id === item.id ? null : current); void loadWorkspace(); }
      if (message.type === "session.invalidated") { notify(localeRef.current === "de" ? "Deine Unternehmenssitzung wurde beendet." : "Your company session ended."); setWorkspace(null); void load(); }
    });
    return () => { active = false; unsubscribe(); if (toastTimer.current) window.clearTimeout(toastTimer.current); };
  }, [load, loadWorkspace, notify]);

  const run = async <T,>(action: string, payload: unknown, apply: (data: T) => void) => {
    setBusy(true);
    try {
      const response = await fetchNui<T>(action, payload);
      if (response.success) apply(response.data); else notify(response.error.message);
      return response.success;
    } catch {
      notify(t(localeRef.current, "operationFailed"));
      return false;
    } finally {
      setBusy(false);
    }
  };
  const applySession = (data: { currentUser: CurrentUser; companies: Company[] }) => setState((current) => current ? { ...current, currentUser: data.currentUser, companies: data.companies } : current);
  const updateEmployee = (employee: Employee) => setState((current) => { const employment = current?.currentUser.employment; return !current || !employment ? current : { ...current, currentUser: { ...current.currentUser, employment: { ...employment, employee, activeEmployees: employment.activeEmployees.map((item) => item.source === employee.source ? employee : item) } } }; });
  const updateDispatch = (employee: Employee) => { updateEmployee(employee); void loadWorkspace(); };
  const updateDispatchLine = (numberId: string, enabled: boolean, employee: Employee) => {
    updateEmployee(employee);
    setWorkspace((current) => current ? { ...current, numberStates: current.numberStates?.map((number) => number.numberId === numberId ? { ...number, selectedForDispatch: enabled } : number) } : current);
    void loadWorkspace();
  };
  const enterDuty = async () => { const success = await run<{ currentUser: CurrentUser; companies: Company[] }>("enterDuty", {}, applySession); if (success) { workspaceInboxRef.current = undefined; await loadWorkspace(); } return success; };
  const leaveDuty = async () => { const success = await run<{ currentUser: CurrentUser; companies: Company[] }>("leaveDuty", {}, applySession); if (success) { workspaceInboxRef.current = undefined; setWorkspace(null); setView("directory"); } };
  const openPortal = async () => { setView("portal"); if (state?.currentUser.employment?.onDuty) await loadWorkspace(); };
  const openActivity = async () => {
    setView("activity"); setActivityLoading(true);
    try {
      const [history, inbox] = await Promise.all([fetchNui<MyActivity>("getMyActivity", { limit: 30 }), fetchNui<InboxConversation[]>("getCitizenInbox", { limit: 30 })]);
      if (history.success) setActivity({ ...history.data, conversations: inbox.success ? inbox.data : [] }); else notify(history.error.message);
      if (!inbox.success) notify(inbox.error.message);
    } catch {
      notify(t(localeRef.current, "operationFailed"));
    } finally {
      setActivityLoading(false);
    }
  };
  const openAdmin = async () => {
    setView("admin"); if (adminState) return; setBusy(true);
    try {
      const response = await fetchNui<AdminState>("getAdminState");
      if (response.success) setAdminState(response.data); else { notify(response.error.message); setView("directory"); }
    } catch {
      notify(t(localeRef.current, "operationFailed")); setView("directory");
    } finally {
      setBusy(false);
    }
  };
  const refreshAdmin = async () => {
    try {
      const response = await fetchNui<AdminState>("getAdminState");
      if (response.success) setAdminState(response.data); else notify(response.error.message);
    } catch {
      notify(t(localeRef.current, "operationFailed"));
    }
  };
  const callCompanyNumber = async (company: Company, number?: CompanyNumber) => {
    setBusy(true);
    try {
      const response = await fetchNui<{ number: string }>("startCompanyCall", { companyId: company.id, numberId: number?.id });
      if (response.success) startCall(response.data.number); else notify(response.error.message);
    } catch {
      notify(t(localeRef.current, "operationFailed"));
    } finally {
      setBusy(false); setCallCompanyChoice(null);
    }
  };
  const callCompany = async (company: Company) => { const numbers = company.numbers.filter((number) => number.enabled && number.publicVisible && number.callsEnabled && number.available); if (numbers.length > 1) { setCallCompanyChoice({ ...company, numbers }); return; } if (numbers[0]) await callCompanyNumber(company, numbers[0]); };
  const callEmployee = async (employee: Employee) => {
    setBusy(true);
    try {
      const response = await fetchNui<{ number: string }>("getEmployeeContact", { targetSource: employee.source });
      if (response.success) startCall(response.data.number); else notify(response.error.message);
    } catch {
      notify(t(localeRef.current, "operationFailed"));
    } finally {
      setBusy(false);
    }
  };
  const createRequest = async (templateId: string, values: Record<string, string | number>) => {
    if (!requestCompany) return false;
    setBusy(true);
    try {
      const response = await fetchNui<CitizenRequest>("createRequest", { companyId: requestCompany.id, templateId, values, locale, clientRequestId: idempotencyKey([requestCompany.id, templateId, values]) });
      if (!response.success) return false;
      setActivity((current) => ({ calls: current?.calls ?? [], conversations: current?.conversations ?? [], requests: [response.data, ...(current?.requests ?? [])] }));
      notify(t(locale, "requestCreated"));
      setView("activity");
      return true;
    } catch {
      return false;
    } finally {
      setBusy(false);
    }
  };
  const sendCitizenMessage = async (numberId: string, body: string, attachments: string[]) => { if (!messageCompany) return false; const success = await run<InboxMessage>("sendCitizenMessage", { companyId: messageCompany.id, numberId, body, attachments, clientRequestId: idempotencyKey([messageCompany.id, numberId, body, attachments]) }, () => notify(t(locale, "messageSent"))); if (success) { setMessageCompany(null); await openActivity(); } return success; };
  const sendConversationMessage = async (conversationId: number, body: string, attachments: string[]) => { const citizen = conversation?.citizen !== false; let sent: InboxMessage | null = null; await run<InboxMessage>(citizen ? "sendCitizenMessage" : "sendEmployeeMessage", citizen ? { companyId: conversation?.item.companyId, numberId: conversation?.item.numberId, body, attachments, clientRequestId: idempotencyKey([conversation?.item.companyId, conversation?.item.numberId, body, attachments]) } : { conversationId, body, attachments, clientRequestId: idempotencyKey([conversationId, body, attachments]) }, (result) => { sent = { ...result, id: result.id || Date.now(), senderType: citizen ? "citizen" : "employee", attachments: result.attachments || attachments }; }); return sent; };
  const sendConversationLocation = async () => { if (!conversation) return null; let sent: InboxMessage | null = null; await run<InboxMessage>("sendCurrentLocation", { citizen: conversation.citizen, conversationId: conversation.item.id, companyId: conversation.item.companyId, numberId: conversation.item.numberId }, (result) => { sent = { ...result, id: result.id || Date.now(), senderType: conversation.citizen ? "citizen" : "employee", attachments: result.attachments || [] }; notify(t(locale, "locationSent")); }); return sent; };
  const reactToMessage = async (messageId: number, emoji: string) => { if (!conversation) return null; let reactions: MessageReaction[] | null = null; await run<MessageReactionUpdate>("reactToMessage", { messageId, emoji, citizen: conversation.citizen }, (result) => { reactions = result.reactions; }); return reactions; };
  const acceptOffer = async () => { if (!offer) return; const success = await run<unknown>("acceptCall", { id: offer.id }, () => undefined); if (success) { setOffer(null); await loadWorkspace(); } };
  const declineOffer = async () => { if (!offer) return; await run("declineCall", { id: offer.id }, () => setOffer(null)); };
  const patchRequest = (updated: CitizenRequest) => setWorkspace((current) => current ? { ...current, requests: current.requests.map((item) => item.id === updated.id ? updated : item) } : current);

  if (loading) return <div className="boot-state"><LoaderCircle className="spinner" size={28} /><span>Loading services...</span></div>;
  if (error || !state) return <div className="boot-state error"><Building2 size={30} /><h1>Services unavailable</h1><p>{error || "Initial state is missing."}</p><button type="button" onClick={load}>Try again</button></div>;

  return <div className="app-shell">
    <header className="app-header"><div className="brand-mark"><Building2 size={19} /></div><div className="header-title"><h1>{state.settings.directoryTitle}</h1><span>{view === "directory" ? "Services+" : t(locale, view)}</span></div><div className="language-switch" aria-label={t(locale, "language")}><button type="button" className={locale === "en" ? "active" : ""} onClick={() => setLocale("en")} aria-label="English" title="English"><i className="flag flag-us" /></button><button type="button" className={locale === "de" ? "active" : ""} onClick={() => setLocale("de")} aria-label="Deutsch" title="Deutsch"><i className="flag flag-de" /></button></div></header>
    <div className="app-content">{conversation ? <ConversationView conversation={conversation.item} citizen={conversation.citizen} locale={locale} busy={busy} canDelete={!conversation.citizen && state.currentUser.employment?.employee?.dispatchEnabled === true} onClose={() => setConversation(null)} onSend={sendConversationMessage} onLocation={sendConversationLocation} onReact={reactToMessage} onRead={markConversationRead} onDelete={async (id) => run<{ id: number }>("deleteMessage", { id }, () => undefined)} /> : <>
      {view === "directory" && <Directory companies={state.companies} categories={state.categories} settings={state.settings} locale={locale} onCall={(company) => void callCompany(company)} onRequest={setRequestCompany} onMessage={setMessageCompany} />}
      {view === "activity" && <Activity data={activity} locale={locale} loading={activityLoading} onConversation={(item) => setConversation({ item, citizen: true })} onCancelRequest={(id) => void run<CitizenRequest>("cancelRequest", { id }, (updated) => setActivity((current) => current ? { ...current, requests: current.requests.map((item) => item.id === id ? updated : item) } : current))} />}
      {view === "portal" && <Portal user={state.currentUser} companies={state.companies} locale={locale} busy={busy} workspace={workspace} onLoadMore={(section, cursor, numberId) => loadWorkspace(section, cursor, numberId)} onInboxChange={(numberId) => loadWorkspace("conversations", undefined, numberId, true)} onCallsSeen={() => setWorkspace((current) => current?.summary ? { ...current, summary: { ...current.summary, unseenCalls: 0 } } : current)} onEnter={enterDuty} onLeave={() => void leaveDuty()} onStatus={(status: EmployeeStatus) => void run("updateStatus", { status }, updateEmployee)} onDispatch={(enabled) => void run("toggleDispatch", { enabled }, updateDispatch)} onDispatchLine={(numberId, enabled) => void run<Employee>("toggleDispatchLine", { enabled, numberId }, (employee) => updateDispatchLine(numberId, enabled, employee))} onNumberOperations={(numbers: NumberOperationsPatch[]) => void run<Company>("updateNumberOperations", { numbers }, (company) => { setState((current) => current ? { ...current, companies: current.companies.map((item) => item.id === company.id ? company : item) } : current); void loadWorkspace(); })} onCallEmployee={(employee) => void callEmployee(employee)} onContactEmployee={(employee) => void run("openEmployeeContact", { targetSource: employee.source }, () => undefined)} onOpenConversation={(item) => setConversation({ item, citizen: false })} onAcceptRequest={(request) => void run<CitizenRequest>("acceptRequest", { id: request.id }, patchRequest)} onReturnRequest={(request) => void run<CitizenRequest>("returnRequest", { id: request.id }, patchRequest)} onNavigateToRequest={(request) => void run<{ id: number }>("navigateToRequest", { id: request.id }, () => undefined)} onDeleteRequest={(request) => confirmAction(`${t(locale, "deleteRequest")}?`, () => void run<{ id: number }>("deleteRequest", { id: request.id }, () => void loadWorkspace()))} onDeleteConversation={(item) => confirmAction(`${t(locale, "deleteConversation")}?`, () => void run<{ id: number }>("deleteConversation", { id: item.id }, () => void loadWorkspace()))} onSaveRequestSettings={(settings) => void run<RequestSettings>("updateRequestSettings", { settings }, (saved) => setWorkspace((current) => current ? { ...current, requestSettings: saved } : current))} />}
      {view === "admin" && state.currentUser.isServerAdmin && (adminState ? <AdminPanel data={adminState} locale={locale} busy={busy} onSaveCompany={async (company: CompanyPatch) => { const success = await run<Company>("adminSaveCompany", { company }, (saved) => setState((current) => current ? { ...current, companies: current.companies.some((item) => item.id === saved.id) ? current.companies.map((item) => item.id === saved.id ? saved : item) : [...current.companies, saved] } : current)); if (success) await refreshAdmin(); return success; }} onDeleteCompany={(companyId) => void run<{ id: string }>("adminDeleteCompany", { companyId }, ({ id }) => { setState((current) => current ? { ...current, companies: current.companies.filter((company) => company.id !== id) } : current); setAdminState((current) => current ? { ...current, companies: current.companies.filter((company) => company.id !== id) } : current); void refreshAdmin(); })} onRestoreCompany={(companyId) => void run<Company>("adminRestoreCompany", { companyId }, (restored) => { setState((current) => current ? { ...current, companies: [...current.companies, restored] } : current); void refreshAdmin(); })} onSaveSettings={(settings) => void run<AppSettings>("adminUpdateSettings", { settings }, (saved) => { setState((current) => current ? { ...current, settings: saved } : current); setAdminState((current) => current ? { ...current, settings: saved } : current); })} onSaveCategory={(categoryId, requestCompetition) => void run<Category>("adminUpdateCategory", { categoryId, requestCompetition }, (saved) => { setState((current) => current ? { ...current, categories: current.categories.map((item) => item.id === saved.id ? saved : item) } : current); setAdminState((current) => current ? { ...current, categories: current.categories.map((item) => item.id === saved.id ? saved : item) } : current); })} /> : <div className="boot-state"><LoaderCircle className="spinner" size={25} /></div>)}
    </>}</div>
    {!conversation && <nav className="bottom-nav" aria-label="Services+ navigation"><button type="button" className={view === "directory" ? "active" : ""} onClick={() => setView("directory")} title={t(locale, "directory")}><Building2 size={21} /></button><button type="button" className={view === "activity" ? "active" : ""} onClick={() => void openActivity()} title={t(locale, "activity")}><ClipboardList size={21} />{activity?.requests.some((request) => ["pending", "active", "returned"].includes(request.status)) && <i />}</button>{state.currentUser.employment && <button type="button" className={view === "portal" ? "active" : ""} onClick={() => void openPortal()} title={t(locale, "portal")}><BriefcaseBusiness size={21} /><i /></button>}{state.currentUser.isServerAdmin && <button type="button" className={view === "admin" ? "active" : ""} onClick={() => void openAdmin()} title={t(locale, "admin")}><ShieldCheck size={21} /></button>}</nav>}
    {requestCompany && <RequestComposer company={requestCompany} locale={locale} busy={busy} onClose={() => setRequestCompany(null)} onSubmit={createRequest} />}
    {messageCompany && <MessageComposer company={messageCompany} locale={locale} busy={busy} onClose={() => setMessageCompany(null)} onSubmit={sendCitizenMessage} />}
    {callCompanyChoice && <NumberSelector company={callCompanyChoice} locale={locale} onClose={() => setCallCompanyChoice(null)} onSelect={(number) => void callCompanyNumber(callCompanyChoice, number)} />}
    {offer && <IncomingOffer offer={offer} locale={locale} busy={busy} onAccept={() => void acceptOffer()} onDecline={() => void declineOffer()} />}
    {confirmState && <ConfirmDialog message={confirmState.message} locale={locale} busy={busy} onConfirm={confirmState.onConfirm} onCancel={() => setConfirmState(null)} />}
    {toast && <div className="toast" role="status">{toast}</div>}
  </div>;
}
