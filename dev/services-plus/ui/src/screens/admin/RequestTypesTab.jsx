import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import Sheet from '../../components/Sheet.jsx'
import ConfirmButton from '../../components/ConfirmButton.jsx'
import Switch from '../../components/Switch.jsx'

const EMPTY = {
  categoryId: '', name: '', icon: '', description: '',
  passengerCount: false, descriptionEnabled: false, competitionEnabled: false, enabled: true,
}

// Request type CRUD (plan §55). Location is always automatic (plan §14) -
// there's nothing else implemented to choose here, so it isn't a field.
export default function RequestTypesTab() {
  const [types, setTypes] = useState(null)
  const [categories, setCategories] = useState([])
  const [editing, setEditing] = useState(null)

  const load = () => fetchNui('admin:getRequestTypes').then((r) => r && setTypes(r))

  useEffect(() => {
    load()
    fetchNui('admin:getCategories').then((r) => r && setCategories(r))
  }, [])

  const categoryName = (id) => categories.find((c) => c.id === id)?.name || '—'

  const save = async () => {
    const action = editing.id ? 'admin:updateRequestType' : 'admin:createRequestType'
    if (await fetchNui(action, { ...editing, categoryId: editing.categoryId || null })) {
      setEditing(null)
      load()
    }
  }

  // Soft-delete only server-side (plan review round 3 §9) - this disables
  // the type instead of removing it, so its request history survives.
  const disable = async (id) => {
    if (await fetchNui('admin:deleteRequestType', { id })) load()
  }

  return (
    <div className="tab-panel">
      <button className="login-button" onClick={() => setEditing({ ...EMPTY })}>
        + New request type
      </button>

      {types === null && <div className="empty-state">Loading…</div>}

      <div className="admin-list">
        {types?.map((t) => (
          <div key={t.id} className="admin-row">
            <div className="admin-row-info">
              <div className="admin-row-title">{t.name}</div>
              <div className="admin-row-meta">
                {categoryName(t.category_id)} · {t.competition_enabled ? 'competition' : 'exclusive'}
                {t.passenger_count ? ' · passengers' : ''} · {t.enabled ? 'enabled' : 'disabled'}
              </div>
            </div>
            <div className="admin-row-actions">
              <button
                className="request-action complete"
                onClick={() =>
                  setEditing({
                    id: t.id, categoryId: t.category_id || '', name: t.name, icon: t.icon || '',
                    description: t.description || '', passengerCount: t.passenger_count === 1,
                    descriptionEnabled: t.description_enabled === 1, competitionEnabled: t.competition_enabled === 1,
                    enabled: t.enabled === 1,
                  })
                }
              >
                Edit
              </button>
              {t.enabled === 1 && (
                <ConfirmButton onConfirm={() => disable(t.id)}>Disable</ConfirmButton>
              )}
            </div>
          </div>
        ))}
      </div>

      {editing && (
        <Sheet title={editing.id ? 'Edit request type' : 'New request type'} onClose={() => setEditing(null)}>
          <select
            className="search-input"
            value={editing.categoryId}
            onChange={(e) => setEditing({ ...editing, categoryId: e.target.value ? Number(e.target.value) : '' })}
          >
            <option value="">No category</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
          <input
            className="search-input"
            placeholder="Name"
            value={editing.name}
            onChange={(e) => setEditing({ ...editing, name: e.target.value })}
          />
          <input
            className="search-input"
            placeholder="Icon"
            value={editing.icon}
            onChange={(e) => setEditing({ ...editing, icon: e.target.value })}
          />
          <input
            className="search-input"
            placeholder="Description shown to the requester"
            value={editing.description}
            onChange={(e) => setEditing({ ...editing, description: e.target.value })}
          />
          <div className="hotline-row">
            <span>Ask for passenger count</span>
            <Switch checked={editing.passengerCount} onChange={(next) => setEditing({ ...editing, passengerCount: next })} />
          </div>
          <div className="hotline-row">
            <span>Allow an optional note</span>
            <Switch checked={editing.descriptionEnabled} onChange={(next) => setEditing({ ...editing, descriptionEnabled: next })} />
          </div>
          <div className="hotline-row">
            <span>Competition (broadcast to every company in the category)</span>
            <Switch checked={editing.competitionEnabled} onChange={(next) => setEditing({ ...editing, competitionEnabled: next })} />
          </div>
          {editing.id && (
            <div className="hotline-row">
              <span>Enabled</span>
              <Switch checked={editing.enabled} onChange={(next) => setEditing({ ...editing, enabled: next })} />
            </div>
          )}
          <button className="login-button" onClick={save}>
            Save
          </button>
        </Sheet>
      )}
    </div>
  )
}
