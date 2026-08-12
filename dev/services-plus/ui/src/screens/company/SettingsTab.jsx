import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import Switch from '../../components/Switch.jsx'

const ROUTING_OPTIONS = [
  { key: 'all', label: 'All' },
  { key: 'random', label: 'Random' },
  { key: 'hotline', label: 'Hotline only' },
]

// Boss-only company settings (plan §33-34). Every change saves immediately -
// there is no separate "save" step, same as toggles elsewhere in the app.
export default function SettingsTab() {
  const [settings, setSettings] = useState(null)

  useEffect(() => {
    fetchNui('getCompanySettings').then((r) => r && setSettings(r))
  }, [])

  if (!settings) return <div className="tab-panel empty-state">Loading…</div>

  const save = async (patch) => {
    const next = { ...settings, ...patch }
    setSettings(next)
    await fetchNui('updateCompanySettings', { settings: next })
  }

  const saveNumber = async (numberId, patch) => {
    const nextNumbers = settings.numbers.map((n) => (n.id === numberId ? { ...n, ...patch } : n))
    setSettings({ ...settings, numbers: nextNumbers })
    await fetchNui('updateNumberSettings', { numberId, settings: patch })

    // The server can derive a different outcome than the patch alone would
    // suggest (Mailbox OFF forces Messages OFF too) - re-fetch instead of
    // trusting the optimistic merge above so the toggles never silently
    // drift from what's actually saved.
    fetchNui('getCompanySettings').then((r) => r && setSettings(r))
  }

  return (
    <div className="tab-panel settings-tab">
      <div className="section-title compact-title">Routing</div>
      <div className="routing-row">
        <div className="routing-label">Call routing</div>
        <div className="category-row subtab-row routing-options">
          {ROUTING_OPTIONS.map((o) => (
            <button
              key={o.key}
              className={`category-chip${settings.callRouting === o.key ? ' active' : ''}`}
              onClick={() => save({ callRouting: o.key })}
            >
              {o.label}
            </button>
          ))}
        </div>
      </div>

      <div className="routing-row">
        <div className="routing-label">Request routing</div>
        <div className="category-row subtab-row routing-options">
          {ROUTING_OPTIONS.map((o) => (
            <button
              key={o.key}
              className={`category-chip${settings.requestRouting === o.key ? ' active' : ''}`}
              onClick={() => save({ requestRouting: o.key })}
            >
              {o.label}
            </button>
          ))}
        </div>
      </div>

      <div className="section-title compact-title">Phone numbers</div>
      <div className="number-list">
        {settings.numbers.map((n) => (
          <div key={n.id} className="number-row">
            <div className="dashboard-label">
              {n.label} {n.isMain && <span className="hint">(main)</span>}
            </div>
            <div className="number-toggles">
              <div className="hotline-row">
                <span>Calls</span>
                <Switch
                  checked={n.callsEnabled}
                  disabled={n.isMain}
                  onChange={(next) => saveNumber(n.id, { callsEnabled: next, messagesEnabled: n.messagesEnabled, mailboxEnabled: n.mailboxEnabled })}
                />
              </div>
              <div className="hotline-row">
                <span>Messages</span>
                <Switch
                  checked={n.messagesEnabled}
                  disabled={n.isMain}
                  onChange={(next) => saveNumber(n.id, { callsEnabled: n.callsEnabled, messagesEnabled: next, mailboxEnabled: n.mailboxEnabled })}
                />
              </div>
              <div className="hotline-row">
                <span>Mailbox</span>
                <Switch
                  checked={n.mailboxEnabled}
                  disabled={n.isMain}
                  onChange={(next) => saveNumber(n.id, { callsEnabled: n.callsEnabled, messagesEnabled: n.messagesEnabled, mailboxEnabled: next })}
                />
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
