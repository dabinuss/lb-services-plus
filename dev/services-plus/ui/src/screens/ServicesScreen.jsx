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

  return (
    <div className="screen services-screen">
      <div className="screen-header">Services</div>

      <input
        className="search-input"
        placeholder="Search companies"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />

      <div className="category-row">
        <button
          className={`category-chip${activeCategory === null ? ' active' : ''}`}
          onClick={() => setActiveCategory(null)}
        >
          All
        </button>
        {categories.map((cat) => (
          <button
            key={cat.id}
            className={`category-chip${activeCategory === cat.id ? ' active' : ''}`}
            onClick={() => setActiveCategory(activeCategory === cat.id ? null : cat.id)}
          >
            <CategoryIcon icon={cat.icon} /> {cat.name}
          </button>
        ))}
      </div>

      <div className="company-list">
        {filtered.length === 0 && <div className="empty-state">No companies found.</div>}
        {filtered.map((company) => (
          <CompanyCard
            key={company.id}
            company={company}
            onCall={() => onCall(company)}
            onMessage={() => onMessage(company)}
            onRequest={() => onRequest(company)}
          />
        ))}
      </div>
    </div>
  )
}
