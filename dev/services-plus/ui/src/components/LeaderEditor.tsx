import { Save, X } from "lucide-react";
import { useState } from "react";
import { t, type Locale } from "../lib/i18n";
import type { Company, NumberOperationsPatch } from "../types";

interface Props { company: Company; locale: Locale; busy: boolean; onSaveNumbers: (numbers: NumberOperationsPatch[]) => void; onClose: () => void; }

// Company-wide settings (messages/requests/notification style) are admin-only now -
// see AdminPanel. A leader can only ever change their own company's phone numbers here.
export function LeaderEditor({ company, locale, busy, onSaveNumbers, onClose }: Props) {
  const [numbers, setNumbers] = useState<NumberOperationsPatch[]>(company.numbers.map(({ id, enabled, callsEnabled, inboxEnabled, requestsEnabled, publicVisible, distribution }) => ({ id, enabled, callsEnabled, inboxEnabled, requestsEnabled, publicVisible, distribution })));
  const updateNumber = (id: string, patch: Partial<NumberOperationsPatch>) => setNumbers((current) => current.map((number) => number.id === id ? { ...number, ...patch } : number));
  return <div className="editor-overlay" role="dialog" aria-modal="true" aria-labelledby="editor-title"><section className="leader-editor">
    <header><div><span className="eyebrow">{t(locale, "leaderSettings")}</span><h2 id="editor-title">{t(locale, "phoneNumbers")}</h2></div><button type="button" className="icon-action" onClick={onClose} aria-label="Close"><X size={19} /></button></header>
    <div className="leader-number-settings">{company.numbers.map((number) => { const state = numbers.find((item) => item.id === number.id)!; return <section key={number.id}>
      <header><span>{number.label}</span><label className="number-master"><input type="checkbox" checked={state.enabled} onChange={(event) => updateNumber(number.id, { enabled: event.target.checked })} />{t(locale, "numberOn")}</label></header>
      <div className="capability-grid">
        <label><span>{t(locale, "calls")}</span><input type="checkbox" checked={state.callsEnabled} onChange={(event) => updateNumber(number.id, { callsEnabled: event.target.checked })} /></label>
        <label><span>{t(locale, "numberInbox")}</span><input type="checkbox" checked={state.inboxEnabled} onChange={(event) => updateNumber(number.id, { inboxEnabled: event.target.checked })} /></label>
        <label><span>{t(locale, "requests")}</span><input type="checkbox" checked={state.requestsEnabled} onChange={(event) => updateNumber(number.id, { requestsEnabled: event.target.checked })} /></label>
        <label><span>{t(locale, "public")}</span><input type="checkbox" checked={state.publicVisible} onChange={(event) => updateNumber(number.id, { publicVisible: event.target.checked })} /></label>
      </div>
    </section>; })}</div>
    <button type="button" className="save-button" disabled={busy} onClick={() => onSaveNumbers(numbers)}><Save size={17} />{t(locale, "save")}</button>
  </section></div>;
}
