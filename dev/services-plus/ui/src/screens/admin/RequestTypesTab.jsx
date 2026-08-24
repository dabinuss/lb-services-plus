import { useEffect, useRef, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import Sheet from '../../components/Sheet.jsx'
import ConfirmButton from '../../components/ConfirmButton.jsx'
import Switch from '../../components/Switch.jsx'
import { showToast } from '../../lib/toast.js'
import { useI18n } from '../../lib/i18n.jsx'
import { databaseBoolean, requestTypeNoteMode, requestTypePassengerMode } from '../../lib/database.js'
import FormField from '../../components/FormField.jsx'

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
  const [saving, setSaving] = useState(false)
  const savingLock = useRef(false)

  const load = () => fetchNui('admin:getRequestTypes').then((r) => r && setTypes(r))

  useEffect(() => {
    load()
    fetchNui('admin:getCategories').then((r) => r && setCategories(r))
  }, [])

  const categoryName = (id) => categories.find((c) => c.id === id)?.name || '—'

  const save = async () => {
    if (savingLock.current) return
    savingLock.current = true
    setSaving(true)
    const action = editing.id ? 'admin:updateRequestType' : 'admin:createRequestType'
    const wasNew = !editing.id
    try {
      if (await fetchNui(action, { ...editing, categoryId: editing.categoryId || null })) {
        setEditing(null)
        load()
        showToast(t(wasNew ? 'Request type created.' : 'Request type saved.'))
      } else showToast(t('Could not save this request type.'), 'error')
    } catch {
      showToast(t('Could not save this request type.'), 'error')
    } finally {
      savingLock.current = false
      setSaving(false)
    }
  }

  // Soft-delete only server-side (plan review round 3 §9) - this disables
  // the type instead of removing it, so its request history survives.
  const disable = async (id) => {
    if (savingLock.current) return
    savingLock.current = true
    setSaving(true)
    try {
      if (await fetchNui('admin:deleteRequestType', { id })) {
        load()
        showToast(t('Request type disabled.'))
        return
      }
      showToast(t('Could not disable this request type.'), 'error')
    } catch {
      showToast(t('Could not disable this request type.'), 'error')
    } finally {
      savingLock.current = false
      setSaving(false)
    }
  }

  return (
    <div className="tab-panel">
      <button className="login-button" disabled={saving} onClick={() => setEditing({ ...EMPTY })}>
        {t('+ New request type')}
      </button>

      {types === null && <div className="empty-state">{t('Loading request types…')}</div>}

      <div className="admin-list">
        {types?.map((type) => (
          <div key={type.id} className="admin-row">
            <div className="admin-row-info">
              <div className="admin-row-title">{type.name}</div>
              <div className="admin-row-meta">
                {categoryName(type.category_id)} · {t(databaseBoolean(type.competition_enabled) ? 'competition' : 'exclusive')}
                {requestTypePassengerMode(type) !== 'disabled' ? ` · ${t('passengers')}` : ''}
                {type.feature ? ` · ${t(FEATURE_OPTIONS.find((f) => f.key === type.feature)?.label || type.feature)}` : ''}
                {' · '}{t(databaseBoolean(type.enabled) ? 'enabled' : 'disabled')}
              </div>
            </div>
            <div className="admin-row-actions">
              <button
                className="request-action complete"
                disabled={saving}
                onClick={() =>
                  setEditing({
                    id: type.id, categoryId: type.category_id || '', name: type.name,
                    description: type.description || '',
                    passengerMode: requestTypePassengerMode(type),
                    countLabel: type.count_label || t('Passenger count'),
                    noteMode: requestTypeNoteMode(type),
                    competitionEnabled: databaseBoolean(type.competition_enabled),
                    enabled: databaseBoolean(type.enabled),
                    feature: type.feature || '',
                  })
                }
              >
                {t('Edit')}
              </button>
              {databaseBoolean(type.enabled) && (
                <ConfirmButton disabled={saving} onConfirm={() => disable(type.id)}>{t('Disable')}</ConfirmButton>
              )}
            </div>
          </div>
        ))}
      </div>

      {editing && (
        <Sheet title={t(editing.id ? 'Edit request type' : 'New request type')} onClose={() => setEditing(null)}>
          <FormField label={t('Category')}>
            <select className="search-input" value={editing.categoryId} onChange={(e) => setEditing({ ...editing, categoryId: e.target.value ? Number(e.target.value) : '' })}>
              <option value="">{t('No category')}</option>
              {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </FormField>
          <FormField label={t('Name')}>
            <input className="search-input" value={editing.name} onChange={(e) => setEditing({ ...editing, name: e.target.value })} />
          </FormField>
          <FormField label={t('Description shown to the requester')}>
            <input className="search-input" value={editing.description} onChange={(e) => setEditing({ ...editing, description: e.target.value })} />
          </FormField>
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
            <FormField label={t('Number field label')}>
              <input className="search-input" value={editing.countLabel} onChange={(e) => setEditing({ ...editing, countLabel: e.target.value })} />
            </FormField>
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
          <button className="login-button" disabled={saving} aria-busy={saving} onClick={save}>
            {t('Save')}
          </button>
        </Sheet>
      )}
    </div>
  )
}
