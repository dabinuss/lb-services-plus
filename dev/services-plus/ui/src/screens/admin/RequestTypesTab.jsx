import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import Sheet from '../../components/Sheet.jsx'
import ConfirmButton from '../../components/ConfirmButton.jsx'
import Switch from '../../components/Switch.jsx'
import { showToast } from '../../lib/toast.js'

const EMPTY = {
  categoryId: '', name: '', description: '',
  passengerMode: 'disabled', countLabel: 'Passenger count', noteMode: 'disabled', competitionEnabled: false, enabled: true,
  feature: '',
}

// Every "special feature" a request type can expose - see server/admin.lua's
// own VALID_FEATURES, which is what actually enforces this, not this list.
const FEATURE_OPTIONS = [
  { key: '', label: 'None' },
  { key: 'taxi_pricing', label: 'Taxi pricing (Taxameter)' },
]

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
    const wasNew = !editing.id
    if (await fetchNui(action, { ...editing, categoryId: editing.categoryId || null })) {
      setEditing(null)
      load()
      showToast(wasNew ? 'Request type created.' : 'Request type saved.')
    } else {
      showToast('Could not save this request type.', 'error')
    }
  }

  // Soft-delete only server-side (plan review round 3 §9) - this disables
  // the type instead of removing it, so its request history survives.
  const disable = async (id) => {
    if (await fetchNui('admin:deleteRequestType', { id })) {
      load()
      showToast('Request type disabled.')
    } else {
      showToast('Could not disable this request type.', 'error')
    }
  }

  return (
    <div className="tab-panel">
      <button className="login-button" onClick={() => setEditing({ ...EMPTY })}>
        + New request type
      </button>

      {types === null && <div className="empty-state">Loading request types…</div>}

      <div className="admin-list">
        {types?.map((t) => (
          <div key={t.id} className="admin-row">
            <div className="admin-row-info">
              <div className="admin-row-title">{t.name}</div>
              <div className="admin-row-meta">
                {categoryName(t.category_id)} · {t.competition_enabled ? 'competition' : 'exclusive'}
                {(t.passenger_mode || (t.passenger_count ? 'required' : 'disabled')) !== 'disabled' ? ' · passengers' : ''}
                {t.feature ? ` · ${FEATURE_OPTIONS.find((f) => f.key === t.feature)?.label || t.feature}` : ''}
                {' · '}{t.enabled ? 'enabled' : 'disabled'}
              </div>
            </div>
            <div className="admin-row-actions">
              <button
                className="request-action complete"
                onClick={() =>
                  setEditing({
                    id: t.id, categoryId: t.category_id || '', name: t.name,
                    description: t.description || '',
                    passengerMode: t.passenger_mode || (t.passenger_count === 1 ? 'required' : 'disabled'),
                    countLabel: t.count_label || 'Passenger count',
                    noteMode: t.note_mode || (t.description_enabled === 1 ? 'optional' : 'disabled'),
                    competitionEnabled: t.competition_enabled === 1,
                    enabled: t.enabled === 1,
                    feature: t.feature || '',
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
            placeholder="Description shown to the requester"
            value={editing.description}
            onChange={(e) => setEditing({ ...editing, description: e.target.value })}
          />
          <div className="request-type-setting">
            <label htmlFor="request-type-passenger-mode">Passenger count</label>
            <select
              id="request-type-passenger-mode"
              className="search-input"
              value={editing.passengerMode}
              onChange={(e) => setEditing({ ...editing, passengerMode: e.target.value })}
            >
              <option value="disabled">Disabled</option>
              <option value="optional">Optional</option>
              <option value="required">Required</option>
            </select>
          </div>
          {editing.passengerMode !== 'disabled' && (
            <input
              className="search-input"
              placeholder="Number field label"
              value={editing.countLabel}
              onChange={(e) => setEditing({ ...editing, countLabel: e.target.value })}
            />
          )}
          <div className="request-type-setting">
            <label htmlFor="request-type-note-mode">Additional note</label>
            <select
              id="request-type-note-mode"
              className="search-input"
              value={editing.noteMode}
              onChange={(e) => setEditing({ ...editing, noteMode: e.target.value })}
            >
              <option value="disabled">Disabled</option>
              <option value="optional">Optional</option>
              <option value="required">Required</option>
            </select>
          </div>
          <div className="request-type-setting">
            <label htmlFor="request-type-feature">Special feature</label>
            <select
              id="request-type-feature"
              className="search-input"
              value={editing.feature}
              onChange={(e) => setEditing({ ...editing, feature: e.target.value })}
            >
              {FEATURE_OPTIONS.map((f) => (
                <option key={f.key} value={f.key}>
                  {f.label}
                </option>
              ))}
            </select>
          </div>
          <div className="hotline-row">
            <div className="hotline-info">
              <span>Competition request</span>
              <span className="hint">
                Send this request to all available companies in this category. The first company to accept gets the request.
              </span>
            </div>
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
