import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import Sheet from '../../components/Sheet.jsx'
import ConfirmButton from '../../components/ConfirmButton.jsx'
import Switch from '../../components/Switch.jsx'

const EMPTY = { job: '', name: '', categoryId: '', icon: '', background: '', bossGrade: 100, mainNumber: '' }

function CeilingToggle({ label, allowed, onToggle }) {
  return (
    <div className="hotline-row">
      <span>{label}</span>
      <Switch checked={allowed} onChange={onToggle} />
    </div>
  )
}

function CompanyRow({ company, categories, onChanged, onEdit }) {
  const [expanded, setExpanded] = useState(false)
  const [playerId, setPlayerId] = useState('')
  const [newNumber, setNewNumber] = useState({ label: '', number: '' })

  const categoryName = categories.find((c) => c.id === company.category_id)?.name || 'Uncategorized'

  const setCeiling = async (patch) => {
    await fetchNui('admin:setCompanyCeiling', {
      id: company.id,
      callsAllowed: company.admin_calls_allowed === 1,
      messagesAllowed: company.admin_messages_allowed === 1,
      requestsAllowed: company.admin_requests_allowed === 1,
      ...patch,
    })
    onChanged()
  }

  const assignBoss = async () => {
    if (!playerId) return
    if (await fetchNui('admin:assignBoss', { companyId: company.id, playerId: Number(playerId) })) setPlayerId('')
  }

  const addNumber = async () => {
    if (!newNumber.label || !newNumber.number) return
    const ok = await fetchNui('admin:createNumber', {
      companyId: company.id, label: newNumber.label, number: newNumber.number,
      callsEnabled: true, messagesEnabled: true, mailboxEnabled: true,
    })
    if (ok) {
      setNewNumber({ label: '', number: '' })
      onChanged()
    }
  }

  const deleteNumber = async (id) => {
    if (await fetchNui('admin:deleteNumber', { id })) onChanged()
  }

  const deleteCompany = async () => {
    if (await fetchNui('admin:deleteCompany', { id: company.id })) onChanged()
  }

  return (
    <div className="admin-row-block">
      <div className="admin-row" onClick={() => setExpanded(!expanded)}>
        <div className="admin-row-info">
          <div className="admin-row-title">{company.name}</div>
          <div className="admin-row-meta">
            {company.job} · {categoryName} · {company.enabled ? 'enabled' : 'disabled'}
          </div>
        </div>
        <div className="admin-row-actions">
          <button
            className="request-action complete"
            onClick={(e) => {
              e.stopPropagation()
              onEdit(company)
            }}
          >
            Edit
          </button>
          <ConfirmButton onConfirm={deleteCompany} />
        </div>
      </div>

      {expanded && (
        <div className="admin-detail">
          <div className="section-title">Feature ceiling</div>
          <CeilingToggle label="Calls" allowed={company.admin_calls_allowed === 1} onToggle={() => setCeiling({ callsAllowed: company.admin_calls_allowed !== 1 })} />
          <CeilingToggle label="Messages" allowed={company.admin_messages_allowed === 1} onToggle={() => setCeiling({ messagesAllowed: company.admin_messages_allowed !== 1 })} />
          <CeilingToggle label="Requests" allowed={company.admin_requests_allowed === 1} onToggle={() => setCeiling({ requestsAllowed: company.admin_requests_allowed !== 1 })} />

          <div className="section-title">Phone numbers</div>
          {company.numbers.map((n) => (
            <div key={n.id} className="number-row">
              <div className="dashboard-label">
                {n.label} <span className="hint">{n.number}</span> {n.is_main === 1 && <span className="hint">(main)</span>}
              </div>
              {n.is_main !== 1 && (
                <ConfirmButton className="icon-button subtle" onConfirm={() => deleteNumber(n.id)}>
                  ✕
                </ConfirmButton>
              )}
            </div>
          ))}
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
        </div>
      )}
    </div>
  )
}

// Company CRUD, numbers, feature ceilings and boss assignment (plan §51-53, §56-57).
export default function CompaniesTab() {
  const [companies, setCompanies] = useState(null)
  const [categories, setCategories] = useState([])
  const [editing, setEditing] = useState(null)

  const load = () => fetchNui('admin:getCompanies').then((r) => r && setCompanies(r))

  useEffect(() => {
    load()
    fetchNui('admin:getCategories').then((r) => r && setCategories(r))
  }, [])

  const save = async () => {
    if (editing.id) {
      const ok = await fetchNui('admin:updateCompany', { ...editing, categoryId: editing.categoryId || null })
      if (ok) {
        setEditing(null)
        load()
      }
    } else {
      const result = await fetchNui('admin:createCompany', { ...editing, categoryId: editing.categoryId || null })
      if (result) {
        setEditing(null)
        load()
      }
    }
  }

  return (
    <div className="tab-panel">
      <button className="login-button" onClick={() => setEditing({ ...EMPTY })}>
        + New company
      </button>

      {companies === null && <div className="empty-state">Loading…</div>}

      <div className="admin-list">
        {companies?.map((c) => (
          <CompanyRow
            key={c.id}
            company={c}
            categories={categories}
            onChanged={load}
            onEdit={(company) =>
              setEditing({
                id: company.id, job: company.job, name: company.name, categoryId: company.category_id || '',
                icon: company.icon || '', background: company.background || '', bossGrade: company.boss_grade,
                enabled: company.enabled === 1,
              })
            }
          />
        ))}
      </div>

      {editing && (
        <Sheet title={editing.id ? 'Edit company' : 'New company'} onClose={() => setEditing(null)}>
          {!editing.id && (
            <input
              className="search-input"
              placeholder="Framework job"
              value={editing.job}
              onChange={(e) => setEditing({ ...editing, job: e.target.value })}
            />
          )}
          <input
            className="search-input"
            placeholder="Name"
            value={editing.name}
            onChange={(e) => setEditing({ ...editing, name: e.target.value })}
          />
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
            placeholder="Icon URL"
            value={editing.icon}
            onChange={(e) => setEditing({ ...editing, icon: e.target.value })}
          />
          <input
            className="search-input"
            placeholder="Background image URL (optional)"
            value={editing.background}
            onChange={(e) => setEditing({ ...editing, background: e.target.value })}
          />
          <input
            className="search-input"
            type="number"
            placeholder="Boss grade (standalone only)"
            value={editing.bossGrade}
            onChange={(e) => setEditing({ ...editing, bossGrade: Number(e.target.value) })}
          />
          {!editing.id && (
            <input
              className="search-input"
              placeholder="Main phone number"
              value={editing.mainNumber}
              onChange={(e) => setEditing({ ...editing, mainNumber: e.target.value })}
            />
          )}
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
