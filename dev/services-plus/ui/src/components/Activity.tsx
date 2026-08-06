import { Clock3, Inbox, LoaderCircle, Phone, Send, XCircle } from "lucide-react";
import { requestStatusLabel, t, type Locale } from "../lib/i18n";
import { formatDuration } from "../lib/format";
import type { InboxConversation, MyActivity } from "../types";

interface Props { data: MyActivity | null; locale: Locale; loading: boolean; onConversation: (conversation: InboxConversation) => void; onCancelRequest: (id: number) => void; }

export function Activity({ data, locale, loading, onConversation, onCancelRequest }: Props) {
  if (loading) return <main className="activity empty-state"><LoaderCircle className="spinner" size={25} /></main>;
  const active = data?.requests.filter((request) => ["pending", "active", "returned"].includes(request.status)) ?? [];
  const history = data?.requests.filter((request) => !["pending", "active", "returned"].includes(request.status)) ?? [];
  const requests = (items: typeof active) => <div className="activity-list">{items.map((request) => <article key={request.id}><span className="activity-icon request"><Send size={17} /></span><div><strong>{request.companyName ?? request.companyId}</strong><small>{Object.values(request.payload || {}).filter(Boolean).slice(0, 2).join(" · ") || request.details || t(locale, "request")}</small><em>{requestStatusLabel(locale, request.status)}</em></div>{["pending", "active", "returned"].includes(request.status) ? <button type="button" className="activity-cancel" onClick={() => onCancelRequest(request.id)} title={t(locale, "cancel")}><XCircle size={17} /></button> : <span className="status-chip"><Clock3 size={12} />{requestStatusLabel(locale, request.status)}</span>}</article>)}{!items.length && <div className="activity-empty"><Send size={21} />{t(locale, "noRequests")}</div>}</div>;
  return <main className="activity">
    <section className="activity-section"><header><Inbox size={18} /><h2>{t(locale, "messages")}</h2></header><div className="activity-list conversation-activity">{data?.conversations?.map((conversation) => <button type="button" className="conversation-row" key={conversation.id} onClick={() => onConversation(conversation)}><span><Inbox size={17} /></span><div><strong>{conversation.companyName}</strong><small>{conversation.numberLabel} · {conversation.lastMessage}</small></div></button>)}{!data?.conversations?.length && <div className="activity-empty"><Inbox size={21} />{t(locale, "noMessages")}</div>}</div></section>
    <section className="activity-section"><header><Phone size={18} /><h2>{t(locale, "calls")}</h2></header><div className="activity-list">{data?.calls.map((call) => { const queueDuration = formatDuration(call.queueDurationSeconds); const callDuration = formatDuration(call.callDurationSeconds); return <article key={call.id}><span className="activity-icon"><Phone size={17} /></span><div><strong>{call.displayName}</strong><small>{call.number} · {call.result}</small>{(queueDuration || callDuration) && <small className="call-duration">{queueDuration && `${t(locale, "queueDuration")}: ${queueDuration}`}{queueDuration && callDuration ? " · " : ""}{callDuration && `${t(locale, "callDuration")}: ${callDuration}`}</small>}</div><time>{new Date(call.created_at).toLocaleDateString(locale)}</time></article>; })}{!data?.calls.length && <div className="activity-empty"><Phone size={21} />{t(locale, "noCalls")}</div>}</div></section>
    <section className="activity-section active-request-section"><header><Send size={18} /><h2>{t(locale, "activeRequests")}</h2></header>{requests(active)}</section>
    {history.length > 0 && <section className="activity-section"><header><Clock3 size={18} /><h2>{t(locale, "requestHistory")}</h2></header>{requests(history)}</section>}
  </main>;
}
