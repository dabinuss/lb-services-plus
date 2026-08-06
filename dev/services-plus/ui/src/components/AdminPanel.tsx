import { BellRing, Building2, Plus, RotateCcw, Save, Send, Settings2, Trash2, X } from "lucide-react";
import { useState } from "react";
import { t, type Locale } from "../lib/i18n";
import type { AdminCompany, AdminState, AppSettings, Category, CompanyPatch } from "../types";
import { ConfirmDialog } from "./ConfirmDialog";
import { Switch } from "./Switch";

interface Props {
  data: AdminState; locale: Locale; busy: boolean;
  onSaveCompany: (company: CompanyPatch) => Promise<boolean>;
  onDeleteCompany: (companyId: string) => void;
  onRestoreCompany: (companyId: string) => void;
  onSaveSettings: (settings: AppSettings) => void;
  onSaveCategory: (categoryId: string, requestCompetition: boolean) => void;
}

const emptyCompany = (categoryId: string): CompanyPatch => ({
  id: "", job: "", displayName: "", logo: "", backgroundImage: "", categoryId, description: "", location: "", openingHours: "",
  keywords: [], requestsEnabled: false, messagesEnabled: true, dispatchMode: "ring_all", requestNotificationActionable: false, numbers: []
});

function toPatch(company: AdminCompany): CompanyPatch {
  return { id: company.id, job: company.job, displayName: company.displayName, logo: company.logo || "", backgroundImage: company.backgroundImage || "", categoryId: company.categoryId,
    description: company.description, location: company.location, openingHours: company.openingHours, keywords: company.keywords,
    requestsEnabled: company.requestsEnabled, messagesEnabled: company.messagesEnabled, dispatchMode: company.dispatchMode, requestNotificationActionable: company.requestNotificationActionable,
    numbers: company.numbers.map(({ id, label, number, distribution, sharedInbox, enabled, callsEnabled, inboxEnabled, requestsEnabled, publicVisible }) => ({ id, label, number, distribution, sharedInbox, enabled, callsEnabled, inboxEnabled, requestsEnabled, publicVisible })) };
}

export function AdminPanel({ data, locale, busy, onSaveCompany, onDeleteCompany, onRestoreCompany, onSaveSettings, onSaveCategory }: Props) {
  const [editing, setEditing] = useState<CompanyPatch | null>(null);
  const [settings, setSettings] = useState<AppSettings>(data.settings);
  const [confirmState, setConfirmState] = useState<{ message: string; onConfirm: () => void } | null>(null);
  const confirmAction = (message: string, action: () => void) => setConfirmState({ message, onConfirm: () => { setConfirmState(null); action(); } });
  const field = <K extends keyof CompanyPatch>(key: K, value: CompanyPatch[K]) => setEditing((current) => current ? { ...current, [key]: value } : current);
  const saveCompany = async () => { if (editing && await onSaveCompany(editing)) setEditing(null); };
  const requestTemplatesAvailable = editing ? data.categories.find((category) => category.id === editing.categoryId)?.hasRequestTemplates !== false : false;

  return <main className="admin-panel">
    <section className="admin-section"><header><div><span className="eyebrow">Services+</span><h2>{t(locale, "system")}</h2></div><Settings2 size={20} /></header>
      <label className="admin-text-field"><span>{t(locale, "directoryTitle")}</span><input maxLength={80} value={settings.directoryTitle} onChange={(event) => setSettings({ ...settings, directoryTitle: event.target.value })} /></label>
      <div className="switch-list compact"><div><span><strong>{t(locale, "globalCalls")}</strong></span><Switch checked={settings.callsEnabled} onChange={(checked) => setSettings({ ...settings, callsEnabled: checked })} label={t(locale, "globalCalls")} /></div><div><span><strong>{t(locale, "globalRequests")}</strong></span><Switch checked={settings.requestsEnabled} onChange={(checked) => setSettings({ ...settings, requestsEnabled: checked })} label={t(locale, "globalRequests")} /></div></div>
      <button type="button" className="save-button" disabled={busy || settings.directoryTitle.trim().length < 2} onClick={() => onSaveSettings(settings)}><Save size={17} />{t(locale, "save")}</button>
    </section>
    <section className="admin-section"><header><div><span className="eyebrow">Requests</span><h2>{t(locale, "categoryCompetition")}</h2></div><Send size={20} /></header>
      <div className="switch-list category-settings">{data.categories.map((category: Category) => <div key={category.id}><span><strong>{category.names[locale] || category.name}</strong><small>{t(locale, "categoryCompetitionHint")}</small></span><Switch checked={category.requestCompetition} disabled={busy} onChange={(checked) => onSaveCategory(category.id, checked)} label={category.names[locale] || category.name} /></div>)}</div>
    </section>
    <section className="admin-section company-management"><header><div><span className="eyebrow">{data.framework}</span><h2>{t(locale, "companyManagement")}</h2></div><button type="button" className="icon-action add" onClick={() => setEditing(emptyCompany(data.categories[0]?.id ?? "other"))} aria-label={t(locale, "addCompany")} title={t(locale, "addCompany")}><Plus size={19} /></button></header>
      <div className="admin-company-list">{data.companies.map((company) => <article key={company.id}><img src={company.logo || "./icon.svg"} alt="" onError={(event) => { event.currentTarget.src = "./icon.svg"; }} /><button type="button" className="admin-company-main" onClick={() => setEditing(toPatch(company))}><strong>{company.displayName}</strong><small>{company.job} · {company.categoryName}</small></button><button type="button" className="delete-icon" onClick={() => confirmAction(`${t(locale, "deleteCompany")}: ${company.displayName}?`, () => onDeleteCompany(company.id))} aria-label={t(locale, "deleteCompany")}><Trash2 size={17} /></button></article>)}</div>
    </section>
    {data.deletedCompanies.length > 0 && <section className="admin-section company-management deleted-companies"><header><div><span className="eyebrow">{t(locale, "companyManagement")}</span><h2>{t(locale, "deletedCompanies")}</h2></div><Trash2 size={20} /></header>
      <div className="admin-company-list">{data.deletedCompanies.map((company) => <article key={company.id}><img src={company.logo || "./icon.svg"} alt="" onError={(event) => { event.currentTarget.src = "./icon.svg"; }} /><div className="admin-company-main"><strong>{company.displayName}</strong><small>{company.job} · {t(locale, "deletedOn")} {new Date(company.deletedAt).toLocaleDateString(locale)}</small></div><button type="button" className="icon-action" disabled={busy} onClick={() => confirmAction(`${t(locale, "restoreCompany")}: ${company.displayName}?`, () => onRestoreCompany(company.id))} aria-label={t(locale, "restoreCompany")} title={t(locale, "restoreCompany")}><RotateCcw size={17} /></button></article>)}</div>
    </section>}
    {editing && <div className="editor-overlay" role="dialog" aria-modal="true"><section className="leader-editor admin-editor">
      <header><div><span className="eyebrow">{editing.id || t(locale, "addCompany")}</span><h2>{t(locale, "saveCompany")}</h2></div><button type="button" className="icon-action" onClick={() => setEditing(null)} aria-label="Close"><X size={19} /></button></header>
      <div className="form-grid">
        <label><span>ID</span><input disabled={Boolean(data.companies.some((item) => item.id === editing.id))} value={editing.id} maxLength={64} onChange={(event) => field("id", event.target.value.toLowerCase().replace(/[^a-z0-9_-]/g, ""))} /></label>
        <label><span>{t(locale, "job")}</span><input value={editing.job} maxLength={64} onChange={(event) => field("job", event.target.value)} /></label>
        <label className="full"><span>{t(locale, "name")}</span><input value={editing.displayName} maxLength={100} onChange={(event) => field("displayName", event.target.value)} /></label>
        <label><span>{t(locale, "category")}</span><select value={editing.categoryId} onChange={(event) => field("categoryId", event.target.value)}>{data.categories.map((category) => <option key={category.id} value={category.id}>{category.names[locale] || category.name}</option>)}</select></label>
        <label><span>{t(locale, "openingHours")}</span><input value={editing.openingHours} maxLength={100} onChange={(event) => field("openingHours", event.target.value)} /></label>
        <label className="full"><span>{t(locale, "logo")}</span><input value={editing.logo} maxLength={500} onChange={(event) => field("logo", event.target.value)} /></label>
        <label className="full"><span>{t(locale, "backgroundImage")}</span><input value={editing.backgroundImage} maxLength={500} onChange={(event) => field("backgroundImage", event.target.value)} /></label>
        <label className="full"><span>{t(locale, "description")}</span><textarea rows={3} value={editing.description} maxLength={500} onChange={(event) => field("description", event.target.value)} /></label>
        <label><span>{t(locale, "location")}</span><input value={editing.location} maxLength={150} onChange={(event) => field("location", event.target.value)} /></label>
        <label><span>{t(locale, "keywords")}</span><input value={editing.keywords.join(", ")} onChange={(event) => field("keywords", event.target.value.split(",").map((value) => value.trim()).filter(Boolean).slice(0, 20))} /></label>
      </div>
      <label className="admin-text-field"><span>{t(locale, "dispatchMode")}</span><select value={editing.dispatchMode} onChange={(event) => field("dispatchMode", event.target.value as CompanyPatch["dispatchMode"])}><option value="ring_all">{t(locale, "ringAll")}</option><option value="random">{t(locale, "random")}</option><option value="dispatch_only">{t(locale, "dispatchOnly")}</option></select></label>
      <div className="switch-list compact"><div><span><Send size={17} /><span><strong>{t(locale, "requests")}</strong>{!requestTemplatesAvailable && <small>{t(locale, "noSpecialRequests")}</small>}</span></span><Switch checked={editing.requestsEnabled && requestTemplatesAvailable} disabled={!requestTemplatesAvailable} onChange={(checked) => field("requestsEnabled", checked)} label={t(locale, "requests")} /></div><div><span><Building2 size={17} /><strong>{t(locale, "messages")}</strong></span><Switch checked={editing.messagesEnabled} onChange={(checked) => field("messagesEnabled", checked)} label={t(locale, "messages")} /></div><div><span><BellRing size={17} /><span><strong>{t(locale, "requestNotificationActionable")}</strong><small>{t(locale, "requestNotificationActionableHint")}</small></span></span><Switch checked={editing.requestsEnabled && requestTemplatesAvailable && editing.requestNotificationActionable} disabled={!requestTemplatesAvailable || !editing.requestsEnabled} onChange={(checked) => field("requestNotificationActionable", checked)} label={t(locale, "requestNotificationActionable")} /></div></div>
      <div className="number-editor"><header><strong>{t(locale, "phoneNumbers")}</strong><button type="button" className="icon-action" onClick={() => field("numbers", [...editing.numbers, { label: "Main Line", number: "", distribution: "ring_all", sharedInbox: true, enabled: true, callsEnabled: true, inboxEnabled: true, requestsEnabled: true, publicVisible: true }])} aria-label={t(locale, "addNumber")}><Plus size={17} /></button></header>{editing.numbers.map((number, index) => { const update = (patch: Partial<typeof number>) => field("numbers", editing.numbers.map((item, itemIndex) => itemIndex === index ? { ...item, ...patch } : item)); return <div className="number-row" key={index}><label className="number-field"><span>{t(locale, "numberLabel")}</span><input value={number.label} maxLength={80} onChange={(event) => update({ label: event.target.value })} /></label><label className="number-field"><span>{t(locale, "phoneNumber")}</span><input value={number.number} maxLength={32} onChange={(event) => update({ number: event.target.value })} /></label><label className="number-field"><span>{t(locale, "callDistribution")}</span><select value={number.distribution} onChange={(event) => update({ distribution: event.target.value as typeof number.distribution })}><option value="ring_all">{t(locale, "ringAll")}</option><option value="random">{t(locale, "random")}</option><option value="dispatch_only">{t(locale, "dispatchOnly")}</option></select></label><div className="number-capabilities"><strong>{t(locale, "numberCapabilities")}</strong><div className="capability-grid"><div><span>{t(locale, "numberOn")}</span><Switch checked={number.enabled} onChange={(checked) => update({ enabled: checked })} label={t(locale, "numberOn")} /></div><div><span>{t(locale, "calls")}</span><Switch checked={number.callsEnabled} onChange={(checked) => update({ callsEnabled: checked })} label={t(locale, "calls")} /></div><div><span>{t(locale, "numberInbox")}</span><Switch checked={number.sharedInbox && number.inboxEnabled} onChange={(checked) => update({ sharedInbox: checked, inboxEnabled: checked })} label={t(locale, "numberInbox")} /></div><div><span>{t(locale, "requests")}</span><Switch checked={number.requestsEnabled} onChange={(checked) => update({ requestsEnabled: checked })} label={t(locale, "requests")} /></div><div><span>{t(locale, "public")}</span><Switch checked={number.publicVisible} onChange={(checked) => update({ publicVisible: checked })} label={t(locale, "public")} /></div></div><small className="capability-help">{t(locale, "numberCapabilitiesHint")}</small></div><button type="button" className="delete-icon" onClick={() => field("numbers", editing.numbers.filter((_, itemIndex) => itemIndex !== index))} aria-label="Remove"><Trash2 size={16} /></button></div>; })}</div>
      <button type="button" className="save-button" disabled={busy || editing.id.length < 2 || editing.job.length < 1 || editing.displayName.length < 2} onClick={() => void saveCompany()}><Save size={17} />{t(locale, "saveCompany")}</button>
    </section></div>}
    {confirmState && <ConfirmDialog message={confirmState.message} locale={locale} busy={busy} onConfirm={confirmState.onConfirm} onCancel={() => setConfirmState(null)} />}
  </main>;
}
