import { BriefcaseBusiness, CheckCircle2, Coffee, LogOut, MessageCircle, Phone, Radio, Settings, ShieldCheck, UserRoundCheck } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { t, type Locale } from "../lib/i18n";
import type { Company, CompanyOperationsPatch, CurrentUser, Employee, EmployeeStatus } from "../types";
import { LeaderEditor } from "./LeaderEditor";

interface Props {
  user: CurrentUser; companies: Company[]; locale: Locale; busy: boolean;
  onEnter: () => Promise<unknown>; onLeave: () => void; onStatus: (status: EmployeeStatus) => void;
  onDispatch: (enabled: boolean) => void; onCompanySave: (companyId: string, patch: CompanyOperationsPatch) => void;
  onCallEmployee: (employee: Employee) => void; onContactEmployee: (employee: Employee) => void;
}

const statusIcon = (status: EmployeeStatus) => status === "available" ? <CheckCircle2 size={14} /> : status === "on_break" ? <Coffee size={14} /> : <Radio size={14} />;

export function Portal({ user, companies, locale, busy, onEnter, onLeave, onStatus, onDispatch, onCompanySave, onCallEmployee, onContactEmployee }: Props) {
  const employment = user.employment;
  const [loginStep, setLoginStep] = useState(0);
  const [editing, setEditing] = useState(false);
  const timers = useRef<number[]>([]);
  const company = companies.find((item) => item.id === employment?.companyId);
  useEffect(() => () => { timers.current.forEach((timer) => window.clearTimeout(timer)); }, []);
  const wait = (milliseconds: number) => new Promise<void>((resolve) => { timers.current.push(window.setTimeout(resolve, milliseconds)); });
  const login = async () => { setLoginStep(1); await wait(380); setLoginStep(2); await wait(380); setLoginStep(3); await onEnter(); setLoginStep(0); };

  if (!employment || !company) return <main className="portal-center"><BriefcaseBusiness size={32} /><h2>{t(locale, "noCompany")}</h2><p>{t(locale, "noCompanyHint")}</p></main>;
  if (!employment.onDuty || !employment.employee) return <main className="portal-login">
    <img src={company.logo || "./icon.svg"} alt="" onError={(event) => { event.currentTarget.src = "./icon.svg"; }} />
    <span className="eyebrow">{t(locale, "employeeAccess")}</span><h1>{company.displayName}</h1>
    <p>{loginStep === 1 ? t(locale, "identifying") : loginStep === 2 ? t(locale, "checking") : loginStep === 3 ? t(locale, "connecting") : `${t(locale, "signedIn")} ${user.name}`}</p>
    <button type="button" className="login-button" onClick={login} disabled={busy || loginStep > 0}><UserRoundCheck size={18} />{t(locale, "enterDuty")}</button>
  </main>;

  const self = employment.employee;
  const dispatchers = employment.activeEmployees.filter((employee) => employee.dispatchEnabled);
  return <main className="portal">
    <section className="portal-banner"><img src={company.logo || "./icon.svg"} alt="" onError={(event) => { event.currentTarget.src = "./icon.svg"; }} /><div><span className="eyebrow">{t(locale, "onDuty")}</span><h1>{company.displayName}</h1><p>{user.name}{self.isLeader ? " · Leader" : " · Employee"}</p></div>{self.isLeader && <button type="button" className="icon-action" onClick={() => setEditing(true)} aria-label={t(locale, "leaderSettings")} title={t(locale, "leaderSettings")}><Settings size={19} /></button>}</section>
    <section className="control-band">
      <div><span className="section-label">{t(locale, "yourStatus")}</span><div className="segmented"><button type="button" className={self.status === "available" ? "active" : ""} onClick={() => onStatus("available")} disabled={busy || self.status === "busy"}><CheckCircle2 size={15} />{t(locale, "available")}</button><button type="button" className={self.status === "on_break" ? "active" : ""} onClick={() => onStatus("on_break")} disabled={busy || self.status === "busy"}><Coffee size={15} />{t(locale, "onBreak")}</button></div></div>
      <label className={`dispatch-control ${self.dispatchForced ? "forced" : ""}`}><span><Radio size={18} /><span><strong>{t(locale, "dispatch")}</strong><small>{self.dispatchForced ? t(locale, "requiredAlone") : t(locale, "receiveDispatch")}</small></span></span><input type="checkbox" checked={self.dispatchEnabled} disabled={busy || self.dispatchForced} onChange={(event) => onDispatch(event.target.checked)} /></label>
      <div className="dispatch-roster"><span className="section-label">{t(locale, "currentDispatch")}</span><strong>{dispatchers.length ? dispatchers.map((employee) => employee.name).join(", ") : t(locale, "noDispatch")}</strong></div>
    </section>
    <section className="employee-section"><header><div><span className="section-label">{t(locale, "activeTeam")}</span><h2>{employment.activeEmployees.length} {t(locale, "onDuty")}</h2></div><ShieldCheck size={21} /></header><div className="employee-list">{employment.activeEmployees.map((employee: Employee) => <div className="employee-row" key={employee.source}><span className={`avatar status-${employee.status}`}>{employee.name.slice(0, 1).toUpperCase()}</span><span className="employee-details"><strong>{employee.name}</strong><small>{employee.role || t(locale, "role")}</small><small className="employee-status">{statusIcon(employee.status)}{employee.status === "available" ? t(locale, "available") : employee.status === "on_break" ? t(locale, "onBreak") : employee.status}</small></span><span className="employee-actions">{employee.dispatchEnabled && <Radio size={15} className="dispatch-icon" />}{employee.source !== user.source && <><button type="button" className="icon-action" disabled={busy} onClick={() => onCallEmployee(employee)} title={t(locale, "callEmployee")} aria-label={t(locale, "callEmployee")}><Phone size={15} /></button><button type="button" className="icon-action" disabled={busy} onClick={() => onContactEmployee(employee)} title={t(locale, "contactEmployee")} aria-label={t(locale, "contactEmployee")}><MessageCircle size={15} /></button></>}</span></div>)}</div></section>
    <button type="button" className="logout-button" onClick={onLeave} disabled={busy || self.status === "busy"}><LogOut size={17} />{t(locale, "leaveDuty")}</button>
    {editing && <LeaderEditor company={company} locale={locale} busy={busy} onClose={() => setEditing(false)} onSave={(patch) => { onCompanySave(company.id, patch); setEditing(false); }} />}
  </main>;
}
