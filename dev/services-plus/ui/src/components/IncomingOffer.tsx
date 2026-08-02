import { CarFront, Clock3, FileText, MapPin, Minus, Phone, Plus, UsersRound } from "lucide-react";
import type { ReactNode } from "react";
import { t, type Locale } from "../lib/i18n";
import type { WorkOffer } from "../types";
import { CategoryIcon } from "./CategoryIcon";
interface Props { offer: WorkOffer; locale: Locale; busy: boolean; onAccept: () => void; onDecline: () => void; }

const labels: Record<Locale, Record<string, string>> = {
  en: { location: "Location", people: "People", requested_time: "Requested time", vehicle_plate: "Vehicle plate", description: "Details", notes: "Notes", phone: "Phone" },
  de: { location: "Standort", people: "Personen", requested_time: "Gewünschte Zeit", vehicle_plate: "Kennzeichen", description: "Details", notes: "Hinweise", phone: "Telefon" }
};

function detailIcon(key: string): ReactNode {
  if (key === "location") return <MapPin size={17} />;
  if (key === "people") return <UsersRound size={17} />;
  if (key === "requested_time") return <Clock3 size={17} />;
  if (key === "vehicle_plate") return <CarFront size={17} />;
  if (key === "phone") return <Phone size={17} />;
  return <FileText size={17} />;
}

function detailLabel(key: string, locale: Locale) {
  return labels[locale][key] || key.replaceAll("_", " ").replace(/^./, (value) => value.toUpperCase());
}

export function IncomingOffer({ offer, locale, busy, onAccept, onDecline }: Props) {
  if (offer.kind === "request") {
    const details = Object.entries(offer.payload || {}).filter(([, value]) => value !== "" && value !== null && value !== undefined).slice(0, 3);
    return <div className="incoming-overlay request" role="dialog" aria-modal="true">
      <section className="incoming-request">
        <div className="request-visual">
          <img className="request-background" src={offer.companyBackground || offer.companyLogo || "./icon.svg"} alt="" onError={(event) => { event.currentTarget.src = "./icon.svg"; }} />
          <div className="request-image-shade" />
          <header><img src={offer.companyLogo || "./icon.svg"} alt="" onError={(event) => { event.currentTarget.src = "./icon.svg"; }} /><div><strong>{offer.companyName || "Services+"}</strong><span><CategoryIcon name={offer.categoryIcon || "briefcase-business"} size={14} />{offer.categoryName || t(locale, "incomingRequest")}</span></div></header>
        </div>
        <div className="request-offer-body">
          <span className="request-kicker">{t(locale, "incomingRequest")}</span>
          <h2>{offer.title}</h2>
          <div className="request-details">{details.map(([key, value]) => <div key={key}><span>{detailIcon(key)}</span><p><small>{detailLabel(key, locale)}</small><strong>{String(value)}</strong></p></div>)}</div>
          {!details.length && <p className="request-summary">{offer.subtitle}</p>}
          <div className="request-actions"><button type="button" className="decline" disabled={busy} onClick={onDecline} title={t(locale, "decline")} aria-label={t(locale, "decline")}><Minus size={27} /></button><button type="button" className="accept" disabled={busy} onClick={onAccept} title={t(locale, "accept")} aria-label={t(locale, "accept")}><Plus size={27} /></button></div>
        </div>
      </section>
    </div>;
  }
  return <div className="incoming-overlay" role="dialog" aria-modal="true"><section className="incoming-offer"><span className="incoming-icon"><Phone size={25} /></span><span className="eyebrow">{t(locale, "incomingCall")}</span><h2>{offer.title}</h2><p>{offer.subtitle}</p><div><button type="button" className="decline" disabled={busy} onClick={onDecline} title={t(locale, "decline")} aria-label={t(locale, "decline")}><Minus size={22} /></button><button type="button" className="accept" disabled={busy} onClick={onAccept} title={t(locale, "accept")} aria-label={t(locale, "accept")}><Plus size={22} /></button></div></section></div>;
}
