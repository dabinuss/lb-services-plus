import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import Sheet from '../../components/Sheet.jsx'
import ConfirmButton from '../../components/ConfirmButton.jsx'
import Switch from '../../components/Switch.jsx'
import { showToast } from '../../lib/toast.js'
import { useI18n } from '../../lib/i18n.jsx'

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
  const { t } = useI18n()
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
      showToast(t(wasNew ? 'Request type created.' : 'Request type saved.'))
    } else {
      showToast(t('Could not save this request type.'), 'error')
    }
  }

  // Soft-delete only server-side (plan review round 3 §9) - this disables
  // the type instead of removing it, so its request history survives.
  const disable = async (id) => {
    if (await fetchNui('admin:deleteRequestType', { id })) {
      load()
      showToast(t('Request type disabled.'))
    } else {
      showToast(t('Could not disable this request type.'), 'error')
    }
  }

  return (
    <div className="tab-panel">
      <button className="login-button" onClick={() => setEditing({ ...EMPTY })}>
        {t('+ New request type')}
      </button>

      {types === null && <div className="empty-state">{t('Loading request types…')}</div>}

      <div className="admin-list">
        {types?.map((type) => (
          <div key={type.id} className="admin-row">
            <div className="admin-row-info">
              <div className="admin-row-title">{type.name}</div>
              <div className="admin-row-meta">
                {categoryName(type.category_id)} · {t(type.competition_enabled ? 'competition' : 'exclusive')}
                {(type.passenger_mode || (type.passenger_count ? 'required' : 'disabled')) !== 'disabled' ? ` · ${t('passengers')}` : ''}
                {type.feature ? ` · ${t(FEATURE_OPTIONS.find((f) => f.key === type.feature)?.label || type.feature)}` : ''}
                {' · '}{t(type.enabled ? 'enabled' : 'disabled')}
              </div>
            </div>
            <div className="admin-row-actions">
              <button
                className="request-action complete"
                onClick={() =>
                  setEditing({
                    id: type.id, categoryId: type.category_id || '', name: type.name,
                    description: type.description || '',
                    passengerMode: type.passenger_mode || (type.passenger_count === 1 ? 'required' : 'disabled'),
                    countLabel: type.count_label || t('Passenger count'),
                    noteMode: type.note_mode || (type.description_enabled === 1 ? 'optional' : 'disabled'),
                    competitionEnabled: type.competition_enabled === 1,
                    enabled: type.enabled === 1,
                    feature: type.feature || '',
                  })
                }
              >
                {t('Edit')}
              </button>
              {type.enabled === 1 && (
                <ConfirmButton onConfirm={() => disable(type.id)}>{t('Disable')}</ConfirmButton>
              )}
            </div>
          </div>
        ))}
      </div>

      {editing && (
        <Sheet title={t(editing.id ? 'Edit request type' : 'New request type')} onClose={() => setEditing(null)}>
          <select
            className="search-input"
            value={editing.categoryId}
            onChange={(e) => setEditing({ ...editing, categoryId: e.target.value ? Number(e.target.value) : '' })}
          >
            <option value="">{t('No category')}</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
          <input
            className="search-input"
            placeholder={t('Name')}
            value={editing.name}
            onChange={(e) => setEditing({ ...editing, name: e.target.value })}
          />
          <input
            className="search-input"
            placeholder={t('Description shown to the requester')}
            value={editing.description}
            onChange={(e) => setEditing({ ...editing, description: e.target.value })}
          />
          <div className="request-type-setting">
            <label htmlFor="request-type-passenger-mode">{t('Passenger count')}</label>
            <select
              id="request-type-passenger-mode"
              className="search-input"
              value={editing.passengerMode}
              onChange={(e) => setEditing({ ...editing, passengerMode: e.target.value })}
            >
              <option value="disabled">{t('Disabled')}</option>
              <option value="optional">{t('Optional')}</option>
              <option value="required">{t('Required')}</option>
            </select>
          </div>
          {editing.passengerMode !== 'disabled' && (
            <input
              className="search-input"
              placeholder={t('Number field label')}
              value={editing.countLabel}
              onChange={(e) => setEditing({ ...editing, countLabel: e.target.value })}
            />
          )}
          <div className="request-type-setting">
            <label htmlFor="request-type-note-mode">{t('Additional note')}</label>
            <select
              id="request-type-note-mode"
              className="search-input"
              value={editing.noteMode}
              onChange={(e) => setEditing({ ...editing, noteMode: e.target.value })}
            >
              <option value="disabled">{t('Disabled')}</option>
              <option value="optional">{t('Optional')}</option>
              <option value="required">{t('Required')}</option>
            </select>
          </div>
          <div className="request-type-setting">
            <label htmlFor="request-type-feature">{t('Special feature')}</label>
            <select
              id="request-type-feature"
              className="search-input"
              value={editing.feature}
              onChange={(e) => setEditing({ ...editing, feature: e.target.value })}
            >
              {FEATURE_OPTIONS.map((f) => (
                <option key={f.key} value={f.key}>
                  {t(f.label)}
                </option>
              ))}
            </select>
          </div>
          <div className="hotline-row">
            <div className="hotline-info">
              <span>{t('Competition request')}</span>
              <span className="hint">
                {t('Send this request to all available companies in this category. The first company to accept gets the request.')}
              </span>
            </div>
            <Switch checked={editing.competitionEnabled} onChange={(next) => setEditing({ ...editing, competitionEnabled: next })} />
          </div>
          {editing.id && (
            <div className="hotline-row">
              <span>{t('Enabled')}</span>
              <Switch checked={editing.enabled} onChange={(next) => setEditing({ ...editing, enabled: next })} />
            </div>
          )}
          <button className="login-button" onClick={save}>
            {t('Save')}
          </button>
        </Sheet>
      )}
    </div>
  )
}
