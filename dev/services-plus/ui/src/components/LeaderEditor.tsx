import { MessageCircle, Save, Send, X } from "lucide-react";
import { useState } from "react";
import { t, type Locale } from "../lib/i18n";
import type { Company, CompanyOperationsPatch } from "../types";

interface Props { company: Company; locale: Locale; busy: boolean; onSave: (patch: CompanyOperationsPatch) => void; onClose: () => void; }

export function LeaderEditor({ company, locale, busy, onSave, onClose }: Props) {
  const [form, setForm] = useState<CompanyOperationsPatch>({ requestsEnabled: company.requestsEnabled, messagesEnabled: company.messagesEnabled, dispatchMode: company.dispatchMode });
  return <div className="editor-overlay" role="dialog" aria-modal="true" aria-labelledby="editor-title"><section className="leader-editor">
    <header><div><span className="eyebrow">{t(locale, "leaderSettings")}</span><h2 id="editor-title">{t(locale, "operations")}</h2></div><button type="button" className="icon-action" onClick={onClose} aria-label="Close"><X size={19} /></button></header>
    <div className="switch-list">
      <label><span><MessageCircle size={18} /><span><strong>{t(locale, "messages")}</strong><small>Shared company inbox</small></span></span><input type="checkbox" checked={form.messagesEnabled} onChange={(event) => setForm((current) => ({ ...current, messagesEnabled: event.target.checked }))} /></label>
      <label><span><Send size={18} /><span><strong>{t(locale, "requests")}</strong><small>Customer service requests</small></span></span><input type="checkbox" checked={form.requestsEnabled} onChange={(event) => setForm((current) => ({ ...current, requestsEnabled: event.target.checked }))} /></label>
    </div>
    <label className="admin-text-field"><span>{t(locale, "dispatchMode")}</span><select value={form.dispatchMode} onChange={(event) => setForm((current) => ({ ...current, dispatchMode: event.target.value as CompanyOperationsPatch["dispatchMode"] }))}><option value="ring_all">{t(locale, "ringAll")}</option><option value="random">{t(locale, "random")}</option><option value="dispatch_only">{t(locale, "dispatchOnly")}</option></select></label>
    <button type="button" className="save-button" disabled={busy} onClick={() => onSave(form)}><Save size={17} />{t(locale, "save")}</button>
  </section></div>;
}
