import { MessageCircle, Save, Send, X } from "lucide-react";
import { useState } from "react";
import { t, type Locale } from "../lib/i18n";
import type { Company, CompanyOperationsPatch, NumberOperationsPatch } from "../types";

interface Props { company: Company; locale: Locale; busy: boolean; onSave: (patch: CompanyOperationsPatch) => void; onSaveNumbers: (numbers: NumberOperationsPatch[]) => void; onClose: () => void; }

export function LeaderEditor({ company, locale, busy, onSave, onSaveNumbers, onClose }: Props) {
  const [form, setForm] = useState<CompanyOperationsPatch>({ requestsEnabled: company.requestsEnabled, messagesEnabled: company.messagesEnabled, dispatchMode: company.dispatchMode });
  const [numbers, setNumbers] = useState<NumberOperationsPatch[]>(company.numbers.map(({ id, enabled, callsEnabled, inboxEnabled, requestsEnabled, publicVisible, distribution }) => ({ id, enabled, callsEnabled, inboxEnabled, requestsEnabled, publicVisible, distribution })));
  const updateNumber = (id: string, patch: Partial<NumberOperationsPatch>) => setNumbers((current) => current.map((number) => number.id === id ? { ...number, ...patch } : number));
  return <div className="editor-overlay" role="dialog" aria-modal="true" aria-labelledby="editor-title"><section className="leader-editor">
    <header><div><span className="eyebrow">{t(locale, "leaderSettings")}</span><h2 id="editor-title">{t(locale, "operations")}</h2></div><button type="button" className="icon-action" onClick={onClose} aria-label="Close"><X size={19} /></button></header>
    <div className="switch-list">
      <label><span><MessageCircle size={18} /><span><strong>{t(locale, "messages")}</strong><small>Shared company inbox</small></span></span><input type="checkbox" checked={form.messagesEnabled} onChange={(event) => setForm((current) => ({ ...current, messagesEnabled: event.target.checked }))} /></label>
      <label><span><Send size={18} /><span><strong>{t(locale, "requests")}</strong><small>{company.hasRequestTemplates === false ? t(locale, "noSpecialRequests") : t(locale, "specialRequests")}</small></span></span><input type="checkbox" checked={form.requestsEnabled && company.hasRequestTemplates !== false} disabled={company.hasRequestTemplates === false} onChange={(event) => setForm((current) => ({ ...current, requestsEnabled: event.target.checked }))} /></label>
    </div>
    <label className="admin-text-field"><span>{t(locale, "dispatchMode")}</span><select value={form.dispatchMode} onChange={(event) => setForm((current) => ({ ...current, dispatchMode: event.target.value as CompanyOperationsPatch["dispatchMode"] }))}><option value="ring_all">{t(locale, "ringAll")}</option><option value="random">{t(locale, "random")}</option><option value="dispatch_only">{t(locale, "dispatchOnly")}</option></select></label>
    <div className="leader-number-settings"><strong>{t(locale, "phoneNumbers")}</strong>{company.numbers.map((number) => { const state = numbers.find((item) => item.id === number.id)!; return <section key={number.id}><header><span>{number.label}</span><input type="checkbox" checked={state.enabled} onChange={(event) => updateNumber(number.id, { enabled: event.target.checked })} /></header><div><label><input type="checkbox" checked={state.callsEnabled} onChange={(event) => updateNumber(number.id, { callsEnabled: event.target.checked })} />{t(locale, "calls")}</label><label><input type="checkbox" checked={state.inboxEnabled} onChange={(event) => updateNumber(number.id, { inboxEnabled: event.target.checked })} />{t(locale, "numberInbox")}</label><label><input type="checkbox" checked={state.requestsEnabled} onChange={(event) => updateNumber(number.id, { requestsEnabled: event.target.checked })} />{t(locale, "requests")}</label><label><input type="checkbox" checked={state.publicVisible} onChange={(event) => updateNumber(number.id, { publicVisible: event.target.checked })} />{t(locale, "public")}</label></div></section>; })}</div>
    <button type="button" className="save-button" disabled={busy} onClick={() => { onSave(form); onSaveNumbers(numbers); }}><Save size={17} />{t(locale, "save")}</button>
  </section></div>;
}
