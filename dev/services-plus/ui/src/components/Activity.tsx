import { Clock3, LoaderCircle, Phone, Send } from "lucide-react";
import { t, type Locale } from "../lib/i18n";
import type { MyActivity } from "../types";

interface Props { data: MyActivity | null; locale: Locale; loading: boolean; }

export function Activity({ data, locale, loading }: Props) {
  if (loading) return <main className="activity empty-state"><LoaderCircle className="spinner" size={25} /></main>;
  return <main className="activity">
    <section className="activity-section"><header><Phone size={18} /><h2>{t(locale, "calls")}</h2></header><div className="activity-list">{data?.calls.map((call) => <article key={call.id}><span className="activity-icon"><Phone size={17} /></span><div><strong>{call.displayName}</strong><small>{call.number} · {call.result}</small></div><time>{new Date(call.created_at).toLocaleDateString(locale)}</time></article>)}{!data?.calls.length && <div className="activity-empty"><Phone size={21} />{t(locale, "noCalls")}</div>}</div></section>
    <section className="activity-section"><header><Send size={18} /><h2>{t(locale, "requests")}</h2></header><div className="activity-list">{data?.requests.map((request) => <article key={request.id}><span className="activity-icon request"><Send size={17} /></span><div><strong>{request.companyName ?? request.companyId}</strong><small>{request.payload?.details || request.details || t(locale, "request")}</small></div><span className="status-chip"><Clock3 size={12} />{request.status || t(locale, "pending")}</span></article>)}{!data?.requests.length && <div className="activity-empty"><Send size={21} />{t(locale, "noRequests")}</div>}</div></section>
  </main>;
}
