import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import Sheet from '../../components/Sheet.jsx'
import ConfirmButton from '../../components/ConfirmButton.jsx'
import CategoryIcon from '../../components/CategoryIcon.jsx'
import Switch from '../../components/Switch.jsx'

const EMPTY = { key: '', name: '', icon: '', sort: 0, competitionAllowed: false }

// Category CRUD (plan §54).
export default function CategoriesTab() {
  const [categories, setCategories] = useState(null)
  const [editing, setEditing] = useState(null) // { ...EMPTY, id? }

  const load = () => fetchNui('admin:getCategories').then((r) => r && setCategories(r))

  useEffect(() => {
    load()
  }, [])

  const save = async () => {
    const action = editing.id ? 'admin:updateCategory' : 'admin:createCategory'
    if (await fetchNui(action, editing)) {
      setEditing(null)
      load()
    }
  }

  const remove = async (id) => {
    if (await fetchNui('admin:deleteCategory', { id })) load()
  }

  return (
    <div className="tab-panel">
      <button className="login-button" onClick={() => setEditing({ ...EMPTY })}>
        + New category
      </button>

      {categories === null && <div className="empty-state">Loading…</div>}

      <div className="admin-list">
        {categories?.map((cat) => (
          <div key={cat.id} className="admin-row">
            <CategoryIcon icon={cat.icon} className="admin-row-icon" />
            <div className="admin-row-info">
              <div className="admin-row-title">{cat.name}</div>
              <div className="admin-row-meta">
                sort {cat.sort_order} · competition {cat.competition_allowed ? 'allowed' : 'off'}
              </div>
            </div>
            <div className="admin-row-actions">
              <button
                className="request-action complete"
                onClick={() =>
                  setEditing({
                    id: cat.id, key: cat.key, name: cat.name, icon: cat.icon || '',
                    sort: cat.sort_order, competitionAllowed: cat.competition_allowed === 1,
                  })
                }
              >
                Edit
              </button>
              <ConfirmButton onConfirm={() => remove(cat.id)} />
            </div>
          </div>
        ))}
      </div>

      {editing && (
        <Sheet title={editing.id ? 'Edit category' : 'New category'} onClose={() => setEditing(null)}>
          <input
            className="search-input"
            placeholder="Key (e.g. taxi)"
            value={editing.key}
            disabled={!!editing.id}
            onChange={(e) => setEditing({ ...editing, key: e.target.value })}
          />
          <input
            className="search-input"
            placeholder="Name"
            value={editing.name}
            onChange={(e) => setEditing({ ...editing, name: e.target.value })}
          />
          <input
            className="search-input"
            placeholder="Icon (police, medical, taxi, wrench, tow-truck, bank)"
            value={editing.icon}
            onChange={(e) => setEditing({ ...editing, icon: e.target.value })}
          />
          <input
            className="search-input"
            type="number"
            placeholder="Sort order"
            value={editing.sort}
            onChange={(e) => setEditing({ ...editing, sort: Number(e.target.value) })}
          />
          <div className="hotline-row">
            <span>Allow competition requests</span>
            <Switch
              checked={editing.competitionAllowed}
              onChange={(next) => setEditing({ ...editing, competitionAllowed: next })}
            />
          </div>
          <button className="login-button" onClick={save}>
            Save
          </button>
        </Sheet>
      )}
    </div>
  )
}
