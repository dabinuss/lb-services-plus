import { useEffect, useState } from 'react'
import { fetchNui, isValidBrandingUrl } from '../../lib/nui.js'
import Sheet from '../../components/Sheet.jsx'
import ConfirmButton from '../../components/ConfirmButton.jsx'
import Switch from '../../components/Switch.jsx'
import Icon from '../../components/Icon.jsx'
import { showToast } from '../../lib/toast.js'

const EMPTY_FORM = { job: '', name: '', categoryId: '', icon: '', background: '', bossGrade: 100, mainNumber: '', enabled: true }

// One compact tile instead of a full-width row - three of these side by
// side fit on one line instead of stacking three separate rows just for
// three toggles.
function CeilingToggle({ label, allowed, onToggle }) {
  return (
    <div className="ceiling-item">
      <span>{label}</span>
      <Switch checked={allowed} onChange={onToggle} />
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
  const categoryName = (id) => categories.find((c) => c.id === id)?.name || 'Uncategorized'

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
      background: c.background || '', bossGrade: c.boss_grade, enabled: c.enabled === 1,
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
      setSaveError('Icon and background must be valid public HTTPS URLs (maximum 255 characters).')
      return
    }

    const payload = { ...form, icon, background, categoryId: form.categoryId || null }
    if (editingId === 'new') {
      const result = await fetchNui('admin:createCompany', payload)
      if (result) {
        closeSheet()
        load()
        showToast('Company created.')
      } else {
        setSaveError('Could not create the company. Check the required fields, phone number and HTTPS URLs.')
      }
    } else {
      const ok = await fetchNui('admin:updateCompany', { id: editingId, ...payload })
      if (ok) {
        closeSheet()
        load()
        showToast('Company saved.')
      } else {
        setSaveError('Could not save the company. Check the required fields, phone number and HTTPS URLs.')
      }
    }
  }

  // Soft-delete only server-side - this disables the company instead of
  // removing it, so its message/call history survives.
  const disableCompany = async (id, closeAfter = false) => {
    if (await fetchNui('admin:deleteCompany', { id })) {
      if (closeAfter) closeSheet()
      load()
    }
  }

  const setCeiling = async (patch) => {
    await fetchNui('admin:setCompanyCeiling', {
      id: company.id,
      callsAllowed: company.admin_calls_allowed === 1,
      messagesAllowed: company.admin_messages_allowed === 1,
      requestsAllowed: company.admin_requests_allowed === 1,
      ...patch,
    })
    load()
  }

  const assignBoss = async () => {
    if (!playerId) return
    if (await fetchNui('admin:assignBoss', { companyId: company.id, playerId: Number(playerId) })) {
      setPlayerId('')
      showToast('Company leader updated.')
    } else {
      showToast('Could not assign that player. Check the player ID.', 'error')
    }
  }

  const addNumber = async () => {
    if (!newNumber.label || !newNumber.number) return
    const ok = await fetchNui('admin:createNumber', {
      companyId: company.id, label: newNumber.label, number: newNumber.number,
      callsEnabled: true, messagesEnabled: true, mailboxEnabled: true,
    })
    if (ok) {
      setNewNumber({ label: '', number: '' })
      load()
      showToast('Number added.')
    } else {
      showToast('Could not add that number. It may already be in use.', 'error')
    }
  }

  // Soft-delete only server-side - keeps that number's chat/call history intact.
  const deleteNumber = async (id) => {
    if (await fetchNui('admin:deleteNumber', { id })) load()
  }

  const enableNumber = async (id) => {
    if (await fetchNui('admin:enableNumber', { id })) load()
  }

  // Server re-checks uniqueness itself - this is just so a plain
  // typo/duplicate doesn't round-trip for nothing.
  const saveNumber = async () => {
    if (!editingNumber.label || !editingNumber.number) return
    const ok = await fetchNui('admin:updateNumber', editingNumber)
    if (ok) {
      setEditingNumber(null)
      load()
      showToast('Number saved.')
    } else {
      showToast('Could not save that number. It may already be in use.', 'error')
    }
  }

  return (
    <div className="tab-panel">
      <button className="login-button" onClick={openNew}>
        + New company
      </button>

      {companies === null && <div className="empty-state">Loading companies…</div>}

      <div className="admin-list">
        {companies?.map((c) => (
          <div key={c.id} className="admin-row">
            <div className="admin-row-info">
              <div className="admin-row-title">{c.name}</div>
              <div className="admin-row-meta">
                {c.job} · {categoryName(c.category_id)} · {c.enabled ? 'enabled' : 'disabled'}
              </div>
            </div>
            <div className="admin-row-actions">
              <button className="request-action complete" onClick={() => openEdit(c)}>
                Edit
              </button>
              {c.enabled === 1 && <ConfirmButton onConfirm={() => disableCompany(c.id)}>Disable</ConfirmButton>}
            </div>
          </div>
        ))}
      </div>

      {editingId && form && (
        <Sheet title={editingId === 'new' ? 'New company' : 'Edit company'} onClose={closeSheet}>
          {saveError && <div className="notice">{saveError}</div>}
          {editingId === 'new' && (
            <input
              className="search-input"
              placeholder="Framework job"
              value={form.job}
              onChange={(e) => setForm({ ...form, job: e.target.value })}
            />
          )}
          <input
            className="search-input"
            placeholder="Name"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
          />
          <select
            className="search-input"
            value={form.categoryId}
            onChange={(e) => setForm({ ...form, categoryId: e.target.value ? Number(e.target.value) : '' })}
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
            type="url"
            maxLength={255}
            inputMode="url"
            autoCapitalize="none"
            spellCheck={false}
            placeholder="Icon URL (https://…)"
            value={form.icon}
            onChange={(e) => {
              setSaveError('')
              setForm({ ...form, icon: e.target.value })
            }}
          />
          <input
            className="search-input"
            type="url"
            maxLength={255}
            inputMode="url"
            autoCapitalize="none"
            spellCheck={false}
            placeholder="Background image URL (optional, https://…)"
            value={form.background}
            onChange={(e) => {
              setSaveError('')
              setForm({ ...form, background: e.target.value })
            }}
          />
          <input
            className="search-input"
            type="number"
            placeholder="Boss grade (standalone only)"
            value={form.bossGrade}
            onChange={(e) => setForm({ ...form, bossGrade: Number(e.target.value) })}
          />
          {editingId === 'new' && (
            <input
              className="search-input"
              placeholder="Main phone number"
              value={form.mainNumber}
              onChange={(e) => setForm({ ...form, mainNumber: e.target.value })}
            />
          )}
          {editingId !== 'new' && (
            <div className="hotline-row">
              <span>Enabled</span>
              <Switch checked={form.enabled} onChange={(next) => setForm({ ...form, enabled: next })} />
            </div>
          )}
          <button className="login-button" onClick={save}>
            Save
          </button>

          {/* Everything below needs a real company id, so it only shows up
              once one exists - not for a brand new company still being
              created above. Unlike the identity fields above, these apply
              immediately on their own (no separate Save) - same as they
              always have. */}
          {company && (
            <div className="sheet-section">
              <div className="section-title">Feature ceiling</div>
              <div className="ceiling-row">
                <CeilingToggle label="Calls" allowed={company.admin_calls_allowed === 1} onToggle={() => setCeiling({ callsAllowed: company.admin_calls_allowed !== 1 })} />
                <CeilingToggle label="Messages" allowed={company.admin_messages_allowed === 1} onToggle={() => setCeiling({ messagesAllowed: company.admin_messages_allowed !== 1 })} />
                <CeilingToggle label="Requests" allowed={company.admin_requests_allowed === 1} onToggle={() => setCeiling({ requestsAllowed: company.admin_requests_allowed !== 1 })} />
              </div>

              <div className="section-title">Phone numbers</div>
              {company.numbers.map((n) =>
                editingNumber?.id === n.id ? (
                  <div key={n.id} className="admin-inline-form">
                    <input
                      className="search-input"
                      placeholder="Label"
                      value={editingNumber.label}
                      onChange={(e) => setEditingNumber({ ...editingNumber, label: e.target.value })}
                    />
                    <input
                      className="search-input"
                      placeholder="Number"
                      value={editingNumber.number}
                      onChange={(e) => setEditingNumber({ ...editingNumber, number: e.target.value })}
                    />
                    <button className="request-action accept" onClick={saveNumber}>
                      Save
                    </button>
                    <button className="icon-button subtle" onClick={() => setEditingNumber(null)} aria-label="Cancel editing this number">
                      <Icon name="x" size={13} />
                    </button>
                  </div>
                ) : (
                  <div key={n.id} className="hotline-row">
                    <span>
                      {n.label} <span className="hint">{n.number}</span> {n.is_main === 1 && <span className="hint">(main)</span>}
                      {n.enabled !== 1 && <span className="hint"> (disabled)</span>}
                    </span>
                    <div className="admin-row-actions">
                      <button
                        className="request-action complete"
                        onClick={() => setEditingNumber({ id: n.id, label: n.label, number: n.number })}
                      >
                        Edit
                      </button>
                      {n.is_main !== 1 &&
                        (n.enabled === 1 ? (
                          <ConfirmButton className="icon-button subtle" ariaLabel="delete this number" onConfirm={() => deleteNumber(n.id)}>
                            <Icon name="x" size={13} />
                          </ConfirmButton>
                        ) : (
                          <button className="request-action complete" onClick={() => enableNumber(n.id)}>
                            Re-enable
                          </button>
                        ))}
                    </div>
                  </div>
                ),
              )}
              <div className="admin-inline-form">
                <input className="search-input" placeholder="Label" value={newNumber.label} onChange={(e) => setNewNumber({ ...newNumber, label: e.target.value })} />
                <input className="search-input" placeholder="Number" value={newNumber.number} onChange={(e) => setNewNumber({ ...newNumber, number: e.target.value })} />
                <button className="request-action accept" onClick={addNumber}>
                  Add
                </button>
              </div>

              <div className="section-title">Company leader</div>
              <div className="admin-inline-form">
                <input className="search-input" placeholder="Player ID" value={playerId} onChange={(e) => setPlayerId(e.target.value)} />
                <button className="request-action accept" onClick={assignBoss}>
                  Make leader
                </button>
              </div>

              {company.enabled === 1 && (
                <>
                  <div className="section-title">Danger zone</div>
                  <div className="hotline-row">
                    <span>Delete this company</span>
                    <ConfirmButton onConfirm={() => disableCompany(company.id, true)}>Delete company</ConfirmButton>
                  </div>
                  <div className="hint">The company is disabled; its call, message and request history is preserved.</div>
                </>
              )}
            </div>
          )}
        </Sheet>
      )}
    </div>
  )
}
