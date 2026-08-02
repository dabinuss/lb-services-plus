import { Clock3, Hash, Image, LoaderCircle, MapPin, Phone, Send, Type, Users, X } from "lucide-react";
import { useEffect, useState } from "react";
import { fetchNui } from "../lib/api";
import { t, type Locale } from "../lib/i18n";
import type { Company, RequestField, RequestSettings } from "../types";

interface Props { company: Company; locale: Locale; busy: boolean; onClose: () => void; onSubmit: (templateId: string, values: Record<string, string | number>) => Promise<boolean>; }

const fieldIcon = (field: RequestField) => field.type === "location" ? <MapPin size={14} /> : field.type === "phone" ? <Phone size={14} /> : field.type === "requested_time" ? <Clock3 size={14} /> : field.type === "people" ? <Users size={14} /> : field.type === "vehicle_plate" ? <Hash size={14} /> : field.type === "image" ? <Image size={14} /> : <Type size={14} />;
const initialValues = (settings: RequestSettings, templateId: string): Record<string, string> => settings.templates.find((template) => template.id === templateId)?.fields.some((field) => field.type === "phone") && settings.defaultPhone ? { phone: settings.defaultPhone } : {};

export function RequestComposer({ company, locale, busy, onClose, onSubmit }: Props) {
  const [options, setOptions] = useState<RequestSettings | null>(null);
  const [templateId, setTemplateId] = useState("");
  const [values, setValues] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  useEffect(() => { let active = true; void fetchNui<RequestSettings>("getRequestOptions", { companyId: company.id, locale }).then((response) => { if (!active) return; if (response.success) { const first = response.data.templateIds[0] ?? ""; setOptions(response.data); setTemplateId(first); setValues(initialValues(response.data, first)); } else setError(response.error.message); }); return () => { active = false; }; }, [company.id, locale]);
  const enabledTemplates = options?.templates.filter((item) => options.templateIds.includes(item.id)) ?? [];
  const generalTemplates = enabledTemplates.filter((item) => item.kind === "general");
  const specializedTemplates = enabledTemplates.filter((item) => item.kind === "specialized");
  const template = enabledTemplates.find((item) => item.id === templateId);
  const visibleFields = template?.fields.filter((field) => field.enabled !== false) ?? [];
  const valid = Boolean(template && visibleFields.every((field) => !field.required || String(values[field.id] ?? "").trim().length > 0));
  const submit = async () => { if (template && await onSubmit(template.id, values)) onClose(); };
  return <div className="editor-overlay" role="dialog" aria-modal="true" aria-labelledby="request-title"><section className="leader-editor request-editor">
    <header><div><span className="eyebrow">{company.displayName}</span><h2 id="request-title">{options?.createLabel || t(locale, "requestTitle")}</h2></div><button type="button" className="icon-action" onClick={onClose} aria-label={t(locale, "cancel")}><X size={19} /></button></header>
    {!options && !error && <div className="inline-loading"><LoaderCircle className="spinner" size={20} /></div>}
    {error && <p className="form-error">{error}</p>}
    {options && <><label className="request-field"><span>{options.label}</span><select value={templateId} onChange={(event) => { const next = event.target.value; setTemplateId(next); setValues(initialValues(options, next)); }}>{specializedTemplates.length > 0 && <optgroup label={t(locale, "specialRequests")}>{specializedTemplates.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</optgroup>}{generalTemplates.length > 0 && <optgroup label={t(locale, "generalRequests")}>{generalTemplates.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</optgroup>}</select></label>
      {visibleFields.map((field) => <label className="request-field" key={field.id}><span>{fieldIcon(field)}{field.label}{field.required && " *"}</span>{field.type === "description" || field.type === "notes" ? <textarea rows={field.type === "description" ? 4 : 2} maxLength={field.maxLength} value={values[field.id] ?? ""} onChange={(event) => setValues((current) => ({ ...current, [field.id]: event.target.value }))} /> : field.type === "select" ? <select value={values[field.id] ?? ""} onChange={(event) => setValues((current) => ({ ...current, [field.id]: event.target.value }))}><option value="">{t(locale, "selectOption")}</option>{field.options?.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}</select> : <input type={field.type === "people" ? "number" : field.type === "requested_time" ? "datetime-local" : field.type === "phone" ? "tel" : "text"} min={field.minimum} max={field.maximum} maxLength={field.maxLength} value={values[field.id] ?? ""} onChange={(event) => setValues((current) => ({ ...current, [field.id]: event.target.value }))} />}</label>)}
      <button type="button" className="save-button" disabled={busy || !valid} onClick={() => void submit()}><Send size={17} />{t(locale, "sendRequest")}</button></>}
  </section></div>;
}
