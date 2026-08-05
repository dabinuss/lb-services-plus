import { Phone, PhoneOff } from "lucide-react";
import { t, type Locale } from "../lib/i18n";
import type { WorkOffer } from "../types";

interface Props { offer: WorkOffer; locale: Locale; busy: boolean; onAccept: () => void; onDecline: () => void; }

export function IncomingOffer({ offer, locale, busy, onAccept, onDecline }: Props) {
  return <div className="incoming-overlay" role="dialog" aria-modal="true">
    <section className="incoming-offer">
      <span className="incoming-icon"><Phone size={25} /></span>
      <span className="eyebrow">{t(locale, "incomingCall")}</span>
      <h2>{offer.title}</h2>
      <p>{offer.subtitle}</p>
      <div>
        <button type="button" className="decline" disabled={busy} onClick={onDecline} title={t(locale, "decline")} aria-label={t(locale, "decline")}><PhoneOff size={22} /></button>
        <button type="button" className="accept" disabled={busy} onClick={onAccept} title={t(locale, "accept")} aria-label={t(locale, "accept")}><Phone size={22} /></button>
      </div>
    </section>
  </div>;
}
