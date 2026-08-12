import { useMemo, useState } from 'react'
import CompanyCard from '../components/CompanyCard.jsx'
import CategoryIcon from '../components/CategoryIcon.jsx'

export default function ServicesScreen({ companies, categories, onCall, onMessage, onRequest }) {
  const [search, setSearch] = useState('')
  const [activeCategory, setActiveCategory] = useState(null)

  // The company list is small and already fully loaded, so search/filter
  // stays entirely client-side - no request per keystroke (plan §69).
  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase()

    return companies.filter((company) => {
      if (activeCategory !== null && company.categoryId !== activeCategory) return false
      if (term && !company.name.toLowerCase().includes(term)) return false
      return true
    })
  }, [companies, search, activeCategory])

  const categoryNames = useMemo(() => {
    const map = new Map()
    categories.forEach((cat) => map.set(cat.id, cat.name))
    return map
  }, [categories])

  return (
    <div className="screen services-screen">
      <div className="screen-header">Services</div>

      <input
        className="search-input"
        placeholder="Search companies"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />

      {/* Icon-only (plan review: text pills ran out of room / overflowed the
          screen's safe interaction area) - `icon-only` scopes this sizing to
          just this row, the same .category-chip class is reused as a plain
          text pill for sub-tab navigation elsewhere (Admin, Company, Settings). */}
      <div className="category-row icon-only">
        <div className="category-group">
          <button
            className={`category-chip all-btn${activeCategory === null ? ' active' : ''}`}
            onClick={() => setActiveCategory(null)}
            aria-label="All"
            title="All"
          >
            <svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" strokeWidth="2.5" fill="none" strokeLinecap="round">
              <line x1="4" y1="7" x2="20" y2="7"></line>
              <line x1="4" y1="12" x2="20" y2="12"></line>
              <line x1="4" y1="17" x2="20" y2="17"></line>
            </svg>
          </button>

          <div className="category-divider" />

          {categories.map((cat) => (
            <button
              key={cat.id}
              className={`category-chip${activeCategory === cat.id ? ' active' : ''}`}
              onClick={() => setActiveCategory(activeCategory === cat.id ? null : cat.id)}
              aria-label={cat.name}
              title={cat.name}
            >
              <CategoryIcon icon={cat.icon} />
            </button>
          ))}
        </div>
      </div>

      <div className="company-list">
        {filtered.length === 0 && <div className="empty-state">No companies found.</div>}
        {filtered.map((company) => (
          <CompanyCard
            key={company.id}
            company={company}
            categoryName={categoryNames.get(company.categoryId)}
            onCall={() => onCall(company)}
            onMessage={() => onMessage(company)}
            onRequest={() => onRequest(company)}
          />
        ))}
      </div>
    </div>
  )
}
