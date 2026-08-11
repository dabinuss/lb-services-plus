import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'

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
  }

  return (
    <div className="tab-panel settings-tab">
      <div className="section-title">Features</div>
      {[
        ['callsEnabled', 'Calls'],
        ['messagesEnabled', 'Messages'],
        ['requestsEnabled', 'Requests'],
      ].map(([key, label]) => (
        <div className="dashboard-row" key={key}>
          <div className="dashboard-label">{label}</div>
          <button className={`toggle${settings[key] ? ' on' : ''}`} onClick={() => save({ [key]: !settings[key] })}>
            <span className="toggle-knob" />
          </button>
        </div>
      ))}

      <div className="section-title">Call routing</div>
      <div className="category-row subtab-row">
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

      <div className="section-title">Request routing</div>
      <div className="category-row subtab-row">
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

      <div className="section-title">Phone numbers</div>
      <div className="number-list">
        {settings.numbers.map((n) => (
          <div key={n.id} className="number-row">
            <div className="dashboard-label">
              {n.label} {n.isMain && <span className="hint">(main)</span>}
            </div>
            <div className="number-toggles">
              <label className="hotline-row">
                <input
                  type="checkbox"
                  checked={n.callsEnabled}
                  disabled={n.isMain}
                  onChange={() => saveNumber(n.id, { callsEnabled: !n.callsEnabled, messagesEnabled: n.messagesEnabled, mailboxEnabled: n.mailboxEnabled })}
                />
                Calls
              </label>
              <label className="hotline-row">
                <input
                  type="checkbox"
                  checked={n.messagesEnabled}
                  disabled={n.isMain}
                  onChange={() => saveNumber(n.id, { callsEnabled: n.callsEnabled, messagesEnabled: !n.messagesEnabled, mailboxEnabled: n.mailboxEnabled })}
                />
                Messages
              </label>
              <label className="hotline-row">
                <input
                  type="checkbox"
                  checked={n.mailboxEnabled}
                  onChange={() => saveNumber(n.id, { callsEnabled: n.callsEnabled, messagesEnabled: n.messagesEnabled, mailboxEnabled: !n.mailboxEnabled })}
                />
                Mailbox
              </label>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
