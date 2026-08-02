import { Phone, X } from "lucide-react";
import { t, type Locale } from "../lib/i18n";
import type { Company, CompanyNumber } from "../types";
interface Props { company: Company; locale: Locale; onSelect: (number: CompanyNumber) => void; onClose: () => void; }
export function NumberSelector({ company, locale, onSelect, onClose }: Props) { return <div className="editor-overlay" role="dialog" aria-modal="true"><section className="leader-editor number-selector"><header><div><span className="eyebrow">{company.displayName}</span><h2>{t(locale, "selectNumber")}</h2></div><button type="button" className="icon-action" onClick={onClose}><X size={18} /></button></header>{company.numbers.map((number) => <button type="button" key={number.id} onClick={() => onSelect(number)}><Phone size={17} /><span><strong>{number.label}</strong><small>{number.number}</small></span></button>)}</section></div>; }
