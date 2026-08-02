import { BriefcaseBusiness, Building2, ClipboardList, LoaderCircle, ShieldCheck } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { Activity } from "./components/Activity";
import { AdminPanel } from "./components/AdminPanel";
import { Directory } from "./components/Directory";
import { Portal } from "./components/Portal";
import { RequestComposer } from "./components/RequestComposer";
import { fetchNui, getInitialState, startCall } from "./lib/api";
import { subscribeToNui } from "./lib/events";
import { t, type Locale } from "./lib/i18n";
import type { AdminState, AppMessage, AppSettings, CitizenRequest, Company, CompanyOperationsPatch, CompanyPatch, CurrentUser, Employee, EmployeeStatus, InitialState, MyActivity } from "./types";

type View = "directory" | "activity" | "portal" | "admin";

export default function App() {
  const [state, setState] = useState<InitialState | null>(null);
  const [view, setView] = useState<View>("directory");
  const [locale, setLocaleState] = useState<Locale>(() => localStorage.getItem("services-plus-locale") === "de" ? "de" : "en");
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [requestCompany, setRequestCompany] = useState<Company | null>(null);
  const [activity, setActivity] = useState<MyActivity | null>(null);
  const [activityLoading, setActivityLoading] = useState(false);
  const [adminState, setAdminState] = useState<AdminState | null>(null);
  const toastTimer = useRef<number | undefined>(undefined);
  const localeRef = useRef(locale);

  const setLocale = (next: Locale) => { localStorage.setItem("services-plus-locale", next); localeRef.current = next; setLocaleState(next); };
  const notify = useCallback((message: string) => { if (toastTimer.current) window.clearTimeout(toastTimer.current); setToast(message); toastTimer.current = window.setTimeout(() => setToast(null), 2600); }, []);
  const load = useCallback(async () => { setLoading(true); setError(null); const response = await getInitialState(); if (response.success) setState(response.data); else setError(response.error.message); setLoading(false); }, []);

  useEffect(() => {
    let active = true;
    void getInitialState().then((response) => { if (!active) return; if (response.success) setState(response.data); else setError(response.error.message); setLoading(false); });
    const unsubscribe = subscribeToNui((message: AppMessage) => {
      if (!active) return;
      if (message.type === "company.updated") { const company = message.payload as Company; setState((current) => current ? { ...current, companies: current.companies.some((item) => item.id === company.id) ? current.companies.map((item) => item.id === company.id ? company : item) : [...current.companies, company] } : current); }
      if (message.type === "company.deleted") { const { id } = message.payload as { id: string }; setState((current) => current ? { ...current, companies: current.companies.filter((company) => company.id !== id) } : current); }
      if (message.type === "settings.updated") { const settings = message.payload as AppSettings; setState((current) => current ? { ...current, settings } : current); }
      if (message.type === "employee.updated" || message.type === "employee.removed") {
        const employee = message.payload as Employee;
        setState((current) => {
          const employment = current?.currentUser.employment;
          if (!current || !employment || (employee.companyId && employee.companyId !== employment.companyId)) return current;
          const without = employment.activeEmployees.filter((item) => item.source !== employee.source);
          const activeEmployees = message.type === "employee.updated" ? [...without, employee].sort((a, b) => a.name.localeCompare(b.name)) : without;
          const ownEmployee = employee.source === current.currentUser.source && message.type === "employee.updated" ? employee : employment.employee;
          return { ...current, currentUser: { ...current.currentUser, employment: { ...employment, employee: ownEmployee, activeEmployees } } };
        });
      }
      if (message.type === "session.invalidated") { notify(localeRef.current === "de" ? "Deine Unternehmenssitzung wurde beendet." : "Your company session ended."); void load(); }
      if (message.type === "app.closed") void fetchNui("appClosed");
    });
    return () => { active = false; unsubscribe(); if (toastTimer.current) window.clearTimeout(toastTimer.current); void fetchNui("appClosed"); };
  }, [load, notify]);

  const run = async <T,>(action: string, payload: unknown, apply: (data: T) => void) => { setBusy(true); const response = await fetchNui<T>(action, payload); if (response.success) apply(response.data); else notify(response.error.message); setBusy(false); return response.success; };
  const openActivity = async () => { setView("activity"); setActivityLoading(true); const response = await fetchNui<MyActivity>("getMyActivity", { limit: 30 }); if (response.success) setActivity(response.data); else notify(response.error.message); setActivityLoading(false); };
  const openAdmin = async () => { setView("admin"); if (adminState) return; setBusy(true); const response = await fetchNui<AdminState>("getAdminState"); if (response.success) setAdminState(response.data); else { notify(response.error.message); setView("directory"); } setBusy(false); };
  const refreshAdmin = async () => { const response = await fetchNui<AdminState>("getAdminState"); if (response.success) setAdminState(response.data); };
  const applySession = (data: { currentUser: CurrentUser; companies: Company[] }) => setState((current) => current ? { ...current, currentUser: data.currentUser, companies: data.companies } : current);
  const updateEmployee = (employee: Employee) => setState((current) => { const employment = current?.currentUser.employment; return !current || !employment ? current : { ...current, currentUser: { ...current.currentUser, employment: { ...employment, employee, activeEmployees: employment.activeEmployees.map((item) => item.source === employee.source ? employee : item) } } }; });
  const callCompany = async (company: Company) => { setBusy(true); const response = await fetchNui<{ number: string }>("startCompanyCall", { companyId: company.id }); if (response.success) startCall(response.data.number); else notify(response.error.message); setBusy(false); };
  const callEmployee = async (employee: Employee) => { setBusy(true); const response = await fetchNui<{ number: string }>("getEmployeeContact", { targetSource: employee.source }); if (response.success) startCall(response.data.number); else notify(response.error.message); setBusy(false); };
  const openEmployeeContact = async (employee: Employee) => { setBusy(true); const response = await fetchNui<{ opened: boolean }>("openEmployeeContact", { targetSource: employee.source }); if (!response.success) notify(response.error.message); setBusy(false); };
  const createRequest = async (details: string, location: string) => { if (!requestCompany) return false; setBusy(true); const response = await fetchNui<CitizenRequest>("createRequest", { companyId: requestCompany.id, details, location }); if (response.success) { setActivity((current) => ({ calls: current?.calls ?? [], requests: [response.data, ...(current?.requests ?? [])] })); notify(locale === "de" ? "Anfrage wurde erstellt." : "Request created."); setView("activity"); } else notify(response.error.message); setBusy(false); return response.success; };

  if (loading) return <div className="boot-state"><LoaderCircle className="spinner" size={28} /><span>Loading services...</span></div>;
  if (error || !state) return <div className="boot-state error"><Building2 size={30} /><h1>Services unavailable</h1><p>{error || "Initial state is missing."}</p><button type="button" onClick={load}>Try again</button></div>;

  return <div className="app-shell">
    <header className="app-header"><div className="brand-mark"><Building2 size={19} /></div><div className="header-title"><h1>{state.settings.directoryTitle}</h1><span>{view === "directory" ? "Services+" : t(locale, view)}</span></div><div className="language-switch" aria-label={t(locale, "language")}><button type="button" className={locale === "en" ? "active" : ""} onClick={() => setLocale("en")} aria-label="English" title="English"><i className="flag flag-us" /></button><button type="button" className={locale === "de" ? "active" : ""} onClick={() => setLocale("de")} aria-label="Deutsch" title="Deutsch"><i className="flag flag-de" /></button></div></header>
    <div className="app-content">
      {view === "directory" && <Directory companies={state.companies} categories={state.categories} settings={state.settings} locale={locale} onCall={(company) => void callCompany(company)} onRequest={setRequestCompany} />}
      {view === "activity" && <Activity data={activity} locale={locale} loading={activityLoading} />}
      {view === "portal" && <Portal user={state.currentUser} companies={state.companies} locale={locale} busy={busy} onEnter={() => run("enterDuty", {}, applySession)} onLeave={() => void run("leaveDuty", {}, applySession)} onStatus={(status: EmployeeStatus) => void run("updateStatus", { status }, updateEmployee)} onDispatch={(enabled) => void run("toggleDispatch", { enabled }, updateEmployee)} onCallEmployee={(employee) => void callEmployee(employee)} onContactEmployee={(employee) => void openEmployeeContact(employee)} onCompanySave={(companyId: string, patch: CompanyOperationsPatch) => void run<Company>("updateCompanyOperations", { companyId, patch }, (company) => { setState((current) => current ? { ...current, companies: current.companies.map((item) => item.id === company.id ? company : item) } : current); notify(locale === "de" ? "Betriebseinstellungen gespeichert." : "Operational settings updated."); })} />}
      {view === "admin" && state.currentUser.isServerAdmin && (adminState ? <AdminPanel data={adminState} locale={locale} busy={busy} onSaveCompany={async (company: CompanyPatch) => { const success = await run<Company>("adminSaveCompany", { company }, (saved) => setState((current) => current ? { ...current, companies: current.companies.some((item) => item.id === saved.id) ? current.companies.map((item) => item.id === saved.id ? saved : item) : [...current.companies, saved] } : current)); if (success) await refreshAdmin(); return success; }} onDeleteCompany={(companyId) => void run<{ id: string }>("adminDeleteCompany", { companyId }, ({ id }) => { setState((current) => current ? { ...current, companies: current.companies.filter((company) => company.id !== id) } : current); setAdminState((current) => current ? { ...current, companies: current.companies.filter((company) => company.id !== id) } : current); })} onSaveSettings={(settings) => void run<AppSettings>("adminUpdateSettings", { settings }, (saved) => { setState((current) => current ? { ...current, settings: saved } : current); setAdminState((current) => current ? { ...current, settings: saved } : current); })} /> : <div className="boot-state"><LoaderCircle className="spinner" size={25} /></div>)}
    </div>
    <nav className={`bottom-nav ${state.currentUser.isServerAdmin ? "has-admin" : ""}`} aria-label="Services+ navigation">
      <button type="button" className={view === "directory" ? "active" : ""} onClick={() => setView("directory")} title={t(locale, "directory")} aria-label={t(locale, "directory")}><Building2 size={21} /></button>
      <button type="button" className={view === "activity" ? "active" : ""} onClick={() => void openActivity()} title={t(locale, "activity")} aria-label={t(locale, "activity")}><ClipboardList size={21} /></button>
      {state.currentUser.employment && <button type="button" className={view === "portal" ? "active" : ""} onClick={() => setView("portal")} title={t(locale, "portal")} aria-label={t(locale, "portal")}><BriefcaseBusiness size={21} /><i /></button>}
      {state.currentUser.isServerAdmin && <button type="button" className={view === "admin" ? "active" : ""} onClick={() => void openAdmin()} title={t(locale, "admin")} aria-label={t(locale, "admin")}><ShieldCheck size={21} /></button>}
    </nav>
    {requestCompany && <RequestComposer company={requestCompany} locale={locale} busy={busy} onClose={() => setRequestCompany(null)} onSubmit={createRequest} />}
    {toast && <div className="toast" role="status">{toast}</div>}
  </div>;
}
