import { CheckCircle2, Clock3, MapPin, MessageCircle, Phone, Send, XCircle } from "lucide-react";
import { t, type Locale } from "../lib/i18n";
import type { AppSettings, Company } from "../types";

interface Props {
  company: Company;
  locale: Locale;
  settings: AppSettings;
  onCall: (company: Company) => void;
  onRequest: (company: Company) => void;
  onMessage: (company: Company) => void;
}

export function CompanyCard({ company, locale, settings, onCall, onRequest, onMessage }: Props) {
  const callEnabled = settings.callsEnabled && company.numbers.some((number) => number.enabled && number.publicVisible && number.callsEnabled && number.available);
  const requestEnabled = settings.requestsEnabled && company.requestsEnabled;
  return <article className={`company-card ${company.available ? "" : "is-unavailable"}`}>
    <img className="company-card-background" src={company.backgroundImage || company.logo || "./icon.svg"} alt="" loading="lazy" onError={(event) => { event.currentTarget.src = "./icon.svg"; }} />
    <div className="company-card-shade" />
    <div className="company-card-content"><div className="company-card-top">
      <img className="company-logo" src={company.logo || "./icon.svg"} alt="" loading="lazy" onError={(event) => { event.currentTarget.src = "./icon.svg"; }} />
      <h3 title={company.displayName}>{company.displayName}</h3>
      <span className={`availability-icon ${company.available ? "online" : "offline"}`} title={company.available ? t(locale, "available") : t(locale, "unavailable")}>
        {company.available ? <CheckCircle2 size={16} /> : <XCircle size={16} />}
      </span>
      <div className="company-actions">
        <button type="button" className="company-action call" disabled={!callEnabled} onClick={() => onCall(company)} title={t(locale, "call")} aria-label={`${t(locale, "call")}: ${company.displayName}`}><Phone size={16} /></button>
        {company.requestsEnabled && <button type="button" className="company-action request" disabled={!requestEnabled} onClick={() => onRequest(company)} title={t(locale, "request")} aria-label={`${t(locale, "request")}: ${company.displayName}`}><Send size={16} /></button>}
        {company.messagesEnabled && company.numbers.some((number) => number.enabled && number.publicVisible && number.sharedInbox && number.inboxEnabled) && <button type="button" className="company-action message" onClick={() => onMessage(company)} title={t(locale, "messages")} aria-label={`${t(locale, "messages")}: ${company.displayName}`}><MessageCircle size={16} /></button>}
      </div>
    </div>
    <div className="company-card-meta">
      <span title={company.location || t(locale, "locationMissing")}><MapPin size={13} />{company.location || t(locale, "locationMissing")}</span>
      <span title={company.openingHours || t(locale, "hoursMissing")}><Clock3 size={13} />{company.openingHours || t(locale, "hoursMissing")}</span>
    </div>
    </div>
  </article>;
}
