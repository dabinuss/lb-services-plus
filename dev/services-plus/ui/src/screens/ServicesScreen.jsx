import { useMemo, useState } from 'react'
import CompanyCard from '../components/CompanyCard.jsx'
import CategoryIcon from '../components/CategoryIcon.jsx'
import Icon from '../components/Icon.jsx'

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
            <Icon name="list" size={20} strokeWidth={2.5} />
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
              <CategoryIcon icon={cat.icon} size={19} strokeWidth={2.3} />
            </button>
          ))}
        </div>
      </div>

      <div className="company-list">
        {filtered.length === 0 && (
          <div className="empty-state">
            {companies.length === 0
              ? 'No companies have been set up yet. Check back later.'
              : 'No companies match your search. Try a different name or category.'}
          </div>
        )}
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
