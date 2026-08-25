import { useEffect, useRef, useState } from 'react'
import { fetchNui, isValidBrandingUrl } from '../../lib/nui.js'
import Sheet from '../../components/Sheet.jsx'
import ConfirmButton from '../../components/ConfirmButton.jsx'
import Switch from '../../components/Switch.jsx'
import Icon from '../../components/Icon.jsx'
import { showToast } from '../../lib/toast.js'
import { useI18n } from '../../lib/i18n.jsx'
import { databaseBoolean } from '../../lib/database.js'
import FormField from '../../components/FormField.jsx'

const EMPTY_FORM = { job: '', name: '', categoryId: '', icon: '', background: '', bossGrade: 100, mainNumber: '', enabled: true }

// One compact tile instead of a full-width row - three of these side by
// side fit on one line instead of stacking three separate rows just for
// three toggles.
function CeilingToggle({ label, allowed, onToggle, disabled }) {
  return (
    <div className="ceiling-item">
      <span>{label}</span>
      <Switch checked={allowed} onChange={onToggle} disabled={disabled} />
    </div>
  )
}

// Company CRUD, numbers, feature ceilings and boss assignment (plan §51-53,
// §56-57). One Edit button, one Sheet with everything about that company in
// it (plan review round 6 §3) - this used to be split across a separate
// click-to-expand row (ceilings/numbers/leader) *and* the Edit button's own
// Sheet (name/icon/etc.), two different "edit"-shaped surfaces for the same
// company that stayed confusing even after the first pass just added a
// dedicated chevron button for the expand side. Now there's exactly one:
// Edit opens the Sheet, everything editable about that company lives in it.
export default function CompaniesTab() {
  const { t } = useI18n()
  const [companies, setCompanies] = useState(null)
  const [categories, setCategories] = useState([])
  const [editingId, setEditingId] = useState(null) // company id, 'new', or null (Sheet closed)
  const [form, setForm] = useState(null) // draft identity fields, meaningful only while editingId is set
  const [playerId, setPlayerId] = useState('')
  const [newNumber, setNewNumber] = useState({ label: '', number: '' })
  // { id, label, number } of whichever number row is currently being
  // renamed inline, or null - includes the main number, which can be
  // relabeled/renumbered but never deleted.
  const [editingNumber, setEditingNumber] = useState(null)
  const [saveError, setSaveError] = useState('')
  const [saving, setSaving] = useState(false)
  const mutationLock = useRef(false)

  const runMutation = async (operation) => {
    if (mutationLock.current) return false
    mutationLock.current = true
    setSaving(true)
    try {
      return await operation()
    } catch {
      return false
    } finally {
      mutationLock.current = false
      setSaving(false)
    }
  }

  const load = () => fetchNui('admin:getCompanies').then((r) => r && setCompanies(r))

  useEffect(() => {
    load()
    fetchNui('admin:getCategories').then((r) => r && setCategories(r))
  }, [])

  // Always read live from `companies` (refreshed via load() after every
  // mutation below) rather than a stale snapshot captured when the Sheet
  // opened - so toggling a ceiling or adding a number reflects immediately
  // without needing its own separate refresh/resync logic.
  const company = editingId && editingId !== 'new' ? companies?.find((c) => c.id === editingId) : null
  const categoryName = (id) => categories.find((c) => c.id === id)?.name || t('Uncategorized')

  const openNew = () => {
    setSaveError('')
    setEditingId('new')
    setForm({ ...EMPTY_FORM })
  }

  const openEdit = (c) => {
    setSaveError('')
    setEditingId(c.id)
    setForm({
      name: c.name, categoryId: c.category_id || '', icon: c.icon || '',
      background: c.background || '', bossGrade: c.boss_grade, enabled: databaseBoolean(c.enabled),
    })
    setPlayerId('')
    setEditingNumber(null)
    setNewNumber({ label: '', number: '' })
  }

  const closeSheet = () => {
    setSaveError('')
    setEditingId(null)
    setForm(null)
  }

  const save = async () => {
    const icon = form.icon.trim()
    const background = form.background.trim()
    if (!isValidBrandingUrl(icon) || !isValidBrandingUrl(background)) {
      setSaveError(t('Icon and background must be valid public HTTPS URLs (maximum 255 characters).'))
      return
    }

    const payload = { ...form, icon, background, categoryId: form.categoryId || null }
    if (editingId === 'new') {
      const result = await runMutation(() => fetchNui('admin:createCompany', payload))
      if (result) {
        closeSheet()
        load()
        showToast(t('Company created.'))
      } else {
        setSaveError(t('Could not create the company. Check the required fields, phone number and HTTPS URLs.'))
      }
    } else {
      const ok = await runMutation(() => fetchNui('admin:updateCompany', { id: editingId, ...payload }))
      if (ok) {
        closeSheet()
        load()
        showToast(t('Company saved.'))
      } else {
        setSaveError(t('Could not save the company. Check the required fields, phone number and HTTPS URLs.'))
      }
    }
  }

  // Soft-delete only server-side - this disables the company instead of
  // removing it, so its message/call history survives.
  const disableCompany = async (id, closeAfter = false) => {
    if (await runMutation(() => fetchNui('admin:deleteCompany', { id }))) {
      if (closeAfter) closeSheet()
      load()
    }
  }

  const setCeiling = async (patch) => {
    const ok = await runMutation(() => fetchNui('admin:setCompanyCeiling', {
      id: company.id,
      callsAllowed: databaseBoolean(company.admin_calls_allowed),
      messagesAllowed: databaseBoolean(company.admin_messages_allowed),
      requestsAllowed: databaseBoolean(company.admin_requests_allowed),
      ...patch,
    }))
    if (ok) load()
  }

  const assignBoss = async () => {
    if (!playerId) return
    if (await runMutation(() => fetchNui('admin:assignBoss', { companyId: company.id, playerId: Number(playerId) }))) {
      setPlayerId('')
      showToast(t('Company leader updated.'))
    } else {
      showToast(t('Could not assign that player. Check the player ID.'), 'error')
    }
  }

  const addNumber = async () => {
    if (!newNumber.label || !newNumber.number) return
    const ok = await runMutation(() => fetchNui('admin:createNumber', {
      companyId: company.id, label: newNumber.label, number: newNumber.number,
      callsEnabled: true, messagesEnabled: true, mailboxEnabled: true,
    }))
    if (ok) {
      setNewNumber({ label: '', number: '' })
      load()
      showToast(t('Number added.'))
    } else {
      showToast(t('Could not add that number. It may already be in use.'), 'error')
    }
  }

  // Soft-delete only server-side - keeps that number's chat/call history intact.
  const deleteNumber = async (id) => {
    if (await runMutation(() => fetchNui('admin:deleteNumber', { id }))) load()
  }

  const enableNumber = async (id) => {
    if (await runMutation(() => fetchNui('admin:enableNumber', { id }))) load()
  }

  // Server re-checks uniqueness itself - this is just so a plain
  // typo/duplicate doesn't round-trip for nothing.
  const saveNumber = async () => {
    if (!editingNumber.label || !editingNumber.number) return
    const ok = await runMutation(() => fetchNui('admin:updateNumber', editingNumber))
    if (ok) {
      setEditingNumber(null)
      load()
      showToast(t('Number saved.'))
    } else {
      showToast(t('Could not save that number. It may already be in use.'), 'error')
    }
  }

  return (
    <div className="tab-panel">
      <button className="login-button" onClick={openNew} disabled={saving}>
        {t('+ New company')}
      </button>

      {companies === null && <div className="empty-state loading-state" aria-busy="true">{t('Loading companies…')}</div>}

      <div className="admin-list">
        {companies?.map((c) => (
          <div key={c.id} className="admin-row">
            <div className="admin-row-info">
              <div className="admin-row-title">{c.name}</div>
              <div className="admin-row-meta">
                {c.job} · {categoryName(c.category_id)} · {t(databaseBoolean(c.enabled) ? 'enabled' : 'disabled')}
              </div>
            </div>
            <div className="admin-row-actions">
              <button className="request-action complete" onClick={() => openEdit(c)} disabled={saving}>
                {t('Edit')}
              </button>
              {databaseBoolean(c.enabled) && <ConfirmButton disabled={saving} onConfirm={() => disableCompany(c.id)}>{t('Disable')}</ConfirmButton>}
            </div>
          </div>
        ))}
      </div>

      {editingId && form && (
        <Sheet title={t(editingId === 'new' ? 'New company' : 'Edit company')} onClose={closeSheet}>
          {saveError && <div className="notice">{saveError}</div>}
          {editingId === 'new' && (
            <FormField label={t('Framework job')}>
              <input className="search-input" value={form.job} onChange={(e) => setForm({ ...form, job: e.target.value })} />
            </FormField>
          )}
          <FormField label={t('Name')}>
            <input className="search-input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          </FormField>
          <FormField label={t('Category')}>
            <select className="search-input" value={form.categoryId} onChange={(e) => setForm({ ...form, categoryId: e.target.value ? Number(e.target.value) : '' })}>
              <option value="">{t('No category')}</option>
              {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </FormField>
          <FormField label={t('Icon URL (https://…)')}>
            <input
              className="search-input" type="url" maxLength={255} inputMode="url" autoCapitalize="none" spellCheck={false}
              value={form.icon} onChange={(e) => { setSaveError(''); setForm({ ...form, icon: e.target.value }) }}
            />
          </FormField>
          <FormField label={t('Background image URL (optional, https://…)')}>
            <input
              className="search-input" type="url" maxLength={255} inputMode="url" autoCapitalize="none" spellCheck={false}
              value={form.background} onChange={(e) => { setSaveError(''); setForm({ ...form, background: e.target.value }) }}
            />
          </FormField>
          <FormField label={t('Boss grade (standalone only)')}>
            <input className="search-input" type="number" value={form.bossGrade} onChange={(e) => setForm({ ...form, bossGrade: Number(e.target.value) })} />
          </FormField>
          {editingId === 'new' && (
            <FormField label={t('Main phone number')}>
              <input className="search-input" value={form.mainNumber} onChange={(e) => setForm({ ...form, mainNumber: e.target.value })} />
            </FormField>
          )}
          {editingId !== 'new' && (
            <div className="hotline-row">
              <span>{t('Enabled')}</span>
              <Switch checked={form.enabled} disabled={saving} onChange={(next) => setForm({ ...form, enabled: next })} />
            </div>
          )}
          <button className="login-button" onClick={save} disabled={saving} aria-busy={saving}>
            {t('Save')}
          </button>

          {/* Everything below needs a real company id, so it only shows up
              once one exists - not for a brand new company still being
              created above. Unlike the identity fields above, these apply
              immediately on their own (no separate Save) - same as they
              always have. */}
          {company && (
            <div className="sheet-section">
              <div className="section-title">{t('Feature ceiling')}</div>
              <div className="ceiling-row">
                <CeilingToggle disabled={saving} label={t('Calls')} allowed={databaseBoolean(company.admin_calls_allowed)} onToggle={() => setCeiling({ callsAllowed: !databaseBoolean(company.admin_calls_allowed) })} />
                <CeilingToggle disabled={saving} label={t('Messages')} allowed={databaseBoolean(company.admin_messages_allowed)} onToggle={() => setCeiling({ messagesAllowed: !databaseBoolean(company.admin_messages_allowed) })} />
                <CeilingToggle disabled={saving} label={t('Requests')} allowed={databaseBoolean(company.admin_requests_allowed)} onToggle={() => setCeiling({ requestsAllowed: !databaseBoolean(company.admin_requests_allowed) })} />
              </div>

              <div className="section-title">{t('Phone numbers')}</div>
              {company.numbers.map((n) =>
                editingNumber?.id === n.id ? (
                  <div key={n.id} className="admin-inline-form">
                    <FormField label={t('Label')}>
                      <input className="search-input" value={editingNumber.label} onChange={(e) => setEditingNumber({ ...editingNumber, label: e.target.value })} />
                    </FormField>
                    <FormField label={t('Number')}>
                      <input className="search-input" value={editingNumber.number} onChange={(e) => setEditingNumber({ ...editingNumber, number: e.target.value })} />
                    </FormField>
                    <button className="request-action accept" onClick={saveNumber} disabled={saving}>
                      {t('Save')}
                    </button>
                    <button className="icon-button subtle" onClick={() => setEditingNumber(null)} aria-label={t('Cancel editing this number')}>
                      <Icon name="x" size={13} />
                    </button>
                  </div>
                ) : (
                  <div key={n.id} className="hotline-row">
                    <span>
                      {n.label} <span className="hint">{n.number}</span> {databaseBoolean(n.is_main) && <span className="hint">({t('main')})</span>}
                      {!databaseBoolean(n.enabled) && <span className="hint"> ({t('disabled')})</span>}
                    </span>
                    <div className="admin-row-actions">
                      <button
                        className="request-action complete"
                        disabled={saving}
                        onClick={() => setEditingNumber({ id: n.id, label: n.label, number: n.number })}
                      >
                        {t('Edit')}
                      </button>
                      {!databaseBoolean(n.is_main) &&
                        (databaseBoolean(n.enabled) ? (
                          <ConfirmButton disabled={saving} className="icon-button subtle" ariaLabel="delete this number" onConfirm={() => deleteNumber(n.id)}>
                            <Icon name="x" size={13} />
                          </ConfirmButton>
                        ) : (
                          <button className="request-action complete" onClick={() => enableNumber(n.id)} disabled={saving}>
                            {t('Re-enable')}
                          </button>
                        ))}
                    </div>
                  </div>
                ),
              )}
              <div className="admin-inline-form">
                <FormField label={t('Label')}><input className="search-input" value={newNumber.label} onChange={(e) => setNewNumber({ ...newNumber, label: e.target.value })} /></FormField>
                <FormField label={t('Number')}><input className="search-input" value={newNumber.number} onChange={(e) => setNewNumber({ ...newNumber, number: e.target.value })} /></FormField>
                <button className="request-action accept" onClick={addNumber} disabled={saving}>
                  {t('Add')}
                </button>
              </div>

              <div className="section-title">{t('Company leader')}</div>
              <div className="admin-inline-form">
                <FormField label={t('Player ID')}><input className="search-input" inputMode="numeric" value={playerId} onChange={(e) => setPlayerId(e.target.value)} /></FormField>
                <button className="request-action accept" onClick={assignBoss} disabled={saving}>
                  {t('Make leader')}
                </button>
              </div>

              {databaseBoolean(company.enabled) && (
                <>
                  <div className="section-title">{t('Danger zone')}</div>
                  <div className="hotline-row">
                    <span>{t('Delete this company')}</span>
                    <ConfirmButton disabled={saving} onConfirm={() => disableCompany(company.id, true)}>{t('Delete company')}</ConfirmButton>
                  </div>
                  <div className="hint">{t('The company is disabled; its call, message and request history is preserved.')}</div>
                </>
              )}
            </div>
          )}
        </Sheet>
      )}
    </div>
  )
}
