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

// Single-column, flat-surface card - not a 2-column photo-overlay grid. Checked LB
// Phone's own Marketplace and Yellow Pages (its only two native "browse listings"
// screens): both are always a single-column stack of full-width, plain-surface cards
// (image on top as a normal block, never a full-bleed background with a text scrim).
// No LB Phone app anywhere uses a multi-column card grid for this kind of content.
export function CompanyCard({ company, locale, settings, onCall, onRequest, onMessage }: Props) {
  const callEnabled = settings.callsEnabled && company.numbers.some((number) => number.enabled && number.publicVisible && number.callsEnabled && number.available);
  const requestEnabled = settings.requestsEnabled && company.requestsEnabled && company.hasRequestTemplates !== false;
  return <article className={`company-card ${company.available ? "" : "is-unavailable"}`}>
    <header className="company-card-header">
      <span className="company-logo-wrap">
        <img className="company-logo" src={company.logo || "./icon.svg"} alt="" loading="lazy" onError={(event) => { event.currentTarget.src = "./icon.svg"; }} />
        <span className={`availability-icon ${company.available ? "online" : "offline"}`} title={company.available ? t(locale, "available") : t(locale, "unavailable")}>
          {company.available ? <CheckCircle2 size={13} /> : <XCircle size={13} />}
        </span>
      </span>
      <div className="company-card-title">
        <h3 title={company.displayName}>{company.displayName}</h3>
        <span className="company-meta-line">
          <span title={company.location || t(locale, "locationMissing")}><MapPin size={12} />{company.location || t(locale, "locationMissing")}</span>
          <span title={company.openingHours || t(locale, "hoursMissing")}><Clock3 size={12} />{company.openingHours || t(locale, "hoursMissing")}</span>
        </span>
      </div>
    </header>
    {company.backgroundImage && <img className="company-card-banner" src={company.backgroundImage} alt="" loading="lazy" onError={(event) => { event.currentTarget.style.display = "none"; }} />}
    <div className="company-actions">
      <button type="button" className="company-action call" disabled={!callEnabled} onClick={() => onCall(company)} aria-label={`${t(locale, "call")}: ${company.displayName}`}><Phone size={16} />{t(locale, "call")}</button>
      {company.requestsEnabled && company.hasRequestTemplates !== false && <button type="button" className="company-action request" disabled={!requestEnabled} onClick={() => onRequest(company)} aria-label={`${t(locale, "requestAction")}: ${company.displayName}`}><Send size={16} />{t(locale, "requestAction")}</button>}
      {company.messagesEnabled && company.numbers.some((number) => number.enabled && number.publicVisible && number.sharedInbox && number.inboxEnabled) && <button type="button" className="company-action message" onClick={() => onMessage(company)} aria-label={`${t(locale, "messages")}: ${company.displayName}`}><MessageCircle size={16} />{t(locale, "messages")}</button>}
    </div>
  </article>;
}
