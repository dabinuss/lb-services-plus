import { MapPin, Send, X } from "lucide-react";
import { useState } from "react";
import { t, type Locale } from "../lib/i18n";
import type { Company } from "../types";

interface Props { company: Company; locale: Locale; busy: boolean; onClose: () => void; onSubmit: (details: string, location: string) => Promise<boolean>; }

export function RequestComposer({ company, locale, busy, onClose, onSubmit }: Props) {
  const [details, setDetails] = useState("");
  const [location, setLocation] = useState("");
  const submit = async () => { if (await onSubmit(details.trim(), location.trim())) onClose(); };
  return <div className="editor-overlay" role="dialog" aria-modal="true" aria-labelledby="request-title"><section className="leader-editor request-editor">
    <header><div><span className="eyebrow">{company.displayName}</span><h2 id="request-title">{t(locale, "requestTitle")}</h2></div><button type="button" className="icon-action" onClick={onClose} aria-label={t(locale, "cancel")}><X size={19} /></button></header>
    <label className="request-field"><span>{t(locale, "details")}</span><textarea value={details} maxLength={1000} rows={5} onChange={(event) => setDetails(event.target.value)} autoFocus /></label>
    <label className="request-field"><span><MapPin size={14} />{t(locale, "location")}</span><input value={location} maxLength={150} onChange={(event) => setLocation(event.target.value)} /></label>
    <button type="button" className="save-button" disabled={busy || details.trim().length < 3} onClick={() => void submit()}><Send size={17} />{t(locale, "sendRequest")}</button>
  </section></div>;
}
