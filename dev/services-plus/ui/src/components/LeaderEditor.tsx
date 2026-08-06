import { Save, X } from "lucide-react";
import { useState } from "react";
import { t, type Locale } from "../lib/i18n";
import type { Company, NumberOperationsPatch } from "../types";
import { Switch } from "./Switch";

interface Props { company: Company; locale: Locale; busy: boolean; onSaveNumbers: (numbers: NumberOperationsPatch[]) => void; onClose: () => void; }

// Company-wide settings (messages/requests/notification style) are admin-only now -
// see AdminPanel. A leader can only ever change their own company's phone numbers here.
export function LeaderEditor({ company, locale, busy, onSaveNumbers, onClose }: Props) {
  const [numbers, setNumbers] = useState<NumberOperationsPatch[]>(company.numbers.map(({ id, enabled, callsEnabled, inboxEnabled, requestsEnabled, publicVisible, distribution }) => ({ id, enabled, callsEnabled, inboxEnabled, requestsEnabled, publicVisible, distribution })));
  const updateNumber = (id: string, patch: Partial<NumberOperationsPatch>) => setNumbers((current) => current.map((number) => number.id === id ? { ...number, ...patch } : number));
  return <div className="editor-overlay" role="dialog" aria-modal="true" aria-labelledby="editor-title"><section className="leader-editor">
    <header><div><span className="eyebrow">{t(locale, "leaderSettings")}</span><h2 id="editor-title">{t(locale, "phoneNumbers")}</h2></div><button type="button" className="icon-action" onClick={onClose} aria-label="Close"><X size={19} /></button></header>
    <div className="leader-number-settings">{company.numbers.map((number) => { const state = numbers.find((item) => item.id === number.id)!; return <section key={number.id}>
      <header><span>{number.label}</span><span className="number-master"><Switch checked={state.enabled} onChange={(checked) => updateNumber(number.id, { enabled: checked })} label={t(locale, "numberOn")} />{t(locale, "numberOn")}</span></header>
      <div className="capability-grid">
        <div><span>{t(locale, "calls")}</span><Switch checked={state.callsEnabled} onChange={(checked) => updateNumber(number.id, { callsEnabled: checked })} label={t(locale, "calls")} /></div>
        <div><span>{t(locale, "numberInbox")}</span><Switch checked={state.inboxEnabled} onChange={(checked) => updateNumber(number.id, { inboxEnabled: checked })} label={t(locale, "numberInbox")} /></div>
        <div><span>{t(locale, "requests")}</span><Switch checked={state.requestsEnabled} onChange={(checked) => updateNumber(number.id, { requestsEnabled: checked })} label={t(locale, "requests")} /></div>
        <div><span>{t(locale, "public")}</span><Switch checked={state.publicVisible} onChange={(checked) => updateNumber(number.id, { publicVisible: checked })} label={t(locale, "public")} /></div>
      </div>
    </section>; })}</div>
    <button type="button" className="save-button" disabled={busy} onClick={() => onSaveNumbers(numbers)}><Save size={17} />{t(locale, "save")}</button>
  </section></div>;
}
