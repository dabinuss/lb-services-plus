import { LayoutGrid, Search, X } from "lucide-react";
import { useMemo, useState } from "react";
import { t, type Locale } from "../lib/i18n";
import { filterCompanies } from "../lib/search";
import type { AppSettings, Category, Company } from "../types";
import { CategoryIcon } from "./CategoryIcon";
import { CompanyCard } from "./CompanyCard";

interface Props {
  companies: Company[]; categories: Category[]; settings: AppSettings; locale: Locale;
  onCall: (company: Company) => void; onRequest: (company: Company) => void; onMessage: (company: Company) => void;
}

export function Directory({ companies, categories, settings, locale, onCall, onRequest, onMessage }: Props) {
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("all");
  const filtered = useMemo(() => filterCompanies(companies, categories, query, category), [companies, categories, query, category]);
  const groups = useMemo(() => categories.map((item) => ({ category: item, companies: filtered.filter((company) => company.categoryId === item.id) })).filter((group) => group.companies.length > 0), [categories, filtered]);

  return <main className="directory">
    <div className="search-wrap"><Search size={18} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={t(locale, "search")} aria-label={t(locale, "search")} />{query && <button type="button" className="clear-search" onClick={() => setQuery("")} aria-label="Clear search"><X size={17} /></button>}</div>
    <div className="category-strip" aria-label={t(locale, "all")}>
      <button type="button" className={category === "all" ? "active" : ""} onClick={() => setCategory("all")} title={t(locale, "all")} aria-label={t(locale, "all")}><LayoutGrid size={18} /></button>
      {categories.map((item) => <button type="button" key={item.id} className={category === item.id ? "active" : ""} onClick={() => setCategory(item.id)} title={item.names[locale] || item.name} aria-label={item.names[locale] || item.name}><CategoryIcon name={item.icon} /></button>)}
    </div>
    <div className="result-summary"><strong>{filtered.length}</strong> {t(locale, "services")}</div>
    <div className="category-groups">
      {groups.map((group) => <section className="category-section" key={group.category.id}>
        <header><CategoryIcon name={group.category.icon} size={17} /><h2>{group.category.names[locale] || group.category.name}</h2><span>{group.companies.length}</span></header>
        <div className="company-grid">{group.companies.map((company) => <CompanyCard key={company.id} company={company} locale={locale} settings={settings} onCall={onCall} onRequest={onRequest} onMessage={onMessage} />)}</div>
      </section>)}
      {filtered.length === 0 && <div className="empty-state"><Search size={24} /><h2>{t(locale, "noServices")}</h2><p>{t(locale, "noServicesHint")}</p></div>}
    </div>
  </main>;
}
