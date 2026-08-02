import { ImagePlus, MessageCircle, Send, Smile, X } from "lucide-react";
import { useState } from "react";
import { t, type Locale } from "../lib/i18n";
import { openMediaPicker } from "../lib/phoneComponents";
import type { Company } from "../types";
import { EmojiPicker } from "./EmojiPicker";

interface Props { company: Company; locale: Locale; busy: boolean; onClose: () => void; onSubmit: (numberId: string, body: string, attachments: string[]) => Promise<boolean>; }
export function MessageComposer({ company, locale, busy, onClose, onSubmit }: Props) {
  const inboxes = company.numbers.filter((number) => number.enabled && number.publicVisible && number.sharedInbox && number.inboxEnabled);
  const [numberId, setNumberId] = useState(inboxes[0]?.id ?? ""); const [body, setBody] = useState(""); const [attachments, setAttachments] = useState<string[]>([]); const [emojiOpen, setEmojiOpen] = useState(false);
  const addMedia = () => openMediaPicker((selected) => setAttachments((current) => [...new Set([...current, ...selected])].slice(0, 4)));
  const submit = async () => { if (await onSubmit(numberId, body.trim(), attachments)) onClose(); };
  return <div className="editor-overlay" role="dialog" aria-modal="true"><section className="leader-editor request-editor"><header><div><span className="eyebrow">{company.displayName}</span><h2>{t(locale, "newMessage")}</h2></div><button type="button" className="icon-action" onClick={onClose} aria-label={t(locale, "cancel")}><X size={19} /></button></header>
    {inboxes.length > 1 && <label className="request-field"><span>{t(locale, "inbox")}</span><select value={numberId} onChange={(event) => setNumberId(event.target.value)}>{inboxes.map((number) => <option key={number.id} value={number.id}>{number.label}</option>)}</select></label>}
    <label className="request-field"><span><MessageCircle size={14} />{t(locale, "message")}</span><textarea rows={5} maxLength={2000} value={body} onChange={(event) => setBody(event.target.value)} autoFocus /></label>
    {attachments.length > 0 && <div className="selected-media">{attachments.map((url, index) => <span key={url}><ImagePlus size={13} />{t(locale, "media")} {index + 1}<button type="button" onClick={() => setAttachments((current) => current.filter((item) => item !== url))} aria-label={t(locale, "removeAttachment")}><X size={12} /></button></span>)}</div>}
    {emojiOpen && <EmojiPicker label={t(locale, "emojis")} onSelect={(emoji) => setBody((current) => `${current}${emoji}`)} />}
    <div className="composer-tools"><button type="button" onClick={addMedia} disabled={busy || attachments.length >= 4} title={t(locale, "chooseMedia")} aria-label={t(locale, "chooseMedia")}><ImagePlus size={18} /></button><button type="button" className={emojiOpen ? "active" : ""} onClick={() => setEmojiOpen((current) => !current)} title={t(locale, "emojis")} aria-label={t(locale, "emojis")}><Smile size={18} /></button><button type="button" className="save-button" disabled={busy || !numberId || (!body.trim() && attachments.length === 0)} onClick={() => void submit()}><Send size={17} />{t(locale, "send")}</button></div>
  </section></div>;
}
