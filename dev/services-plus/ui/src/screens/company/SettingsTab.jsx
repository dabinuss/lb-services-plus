import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import Switch from '../../components/Switch.jsx'
import { showToast } from '../../lib/toast.js'
import TaxiPricingSettings from './TaxiPricingSettings.jsx'
import { useI18n } from '../../lib/i18n.jsx'

const ROUTING_OPTIONS = [
  { key: 'all', label: 'All' },
  { key: 'random', label: 'Random' },
  { key: 'hotline', label: 'Hotline only' },
]

// Boss-only company settings (plan §33-34). Every change saves immediately -
// there is no separate "save" step, same as toggles elsewhere in the app.
export default function SettingsTab() {
  const { t } = useI18n()
  const [settings, setSettings] = useState(null)

  useEffect(() => {
    fetchNui('getCompanySettings').then((r) => r && setSettings(r))
  }, [])

  if (!settings) return <div className="tab-panel empty-state">{t('Loading settings…')}</div>

  // Every toggle/chip here saves itself immediately - the control's own
  // visual state is the feedback for a normal save. A failed save used to
  // be silently swallowed (the optimistic change just stuck around, wrong,
  // until the next full reload) - this now reverts it and says so.
  const save = async (patch) => {
    const previous = settings
    const next = { ...settings, ...patch }
    setSettings(next)
    if (!(await fetchNui('updateCompanySettings', { settings: next }))) {
      setSettings(previous)
      showToast(t('Could not save that change. Try again.'), 'error')
    }
  }

  const saveNumber = async (numberId, patch) => {
    const nextNumbers = settings.numbers.map((n) => (n.id === numberId ? { ...n, ...patch } : n))
    setSettings({ ...settings, numbers: nextNumbers })
    const ok = await fetchNui('updateNumberSettings', { numberId, settings: patch })
    if (!ok) showToast(t('Could not save that change. Try again.'), 'error')

    // The server can derive a different outcome than the patch alone would
    // suggest (Calls always stays on for the main number regardless of what
    // was sent) - re-fetch instead of trusting the optimistic merge above
    // so the toggles never silently drift from what's actually saved. This
    // also self-heals the optimistic update above if the save just failed.
    fetchNui('getCompanySettings').then((r) => r && setSettings(r))
  }

  return (
    <div className="tab-panel settings-tab">
      <div className="section-title compact-title">{t('Routing')}</div>
      <div className="routing-row">
        <div className="routing-label">{t('Call routing')}</div>
        <div className="category-row subtab-row routing-options">
          {ROUTING_OPTIONS.map((o) => (
            <button
              key={o.key}
              className={`category-chip${settings.callRouting === o.key ? ' active' : ''}`}
              onClick={() => save({ callRouting: o.key })}
            >
              {t(o.label)}
            </button>
          ))}
        </div>
      </div>

      <div className="routing-row">
        <div className="routing-label">{t('Request routing')}</div>
        <div className="category-row subtab-row routing-options">
          {ROUTING_OPTIONS.map((o) => (
            <button
              key={o.key}
              className={`category-chip${settings.requestRouting === o.key ? ' active' : ''}`}
              onClick={() => save({ requestRouting: o.key })}
            >
              {t(o.label)}
            </button>
          ))}
        </div>
      </div>

      {/* Requests aren't tied to any one number - a customer only ever
          picks a company, never a number, when creating one, and
          distribution goes through Request routing above, not a specific
          line. This is the only place a boss can turn the whole feature
          off. */}
      <div className="hotline-row">
        <span>{t('Requests enabled')}</span>
        <Switch checked={settings.requestsEnabled} onChange={(next) => save({ requestsEnabled: next })} />
      </div>

      <TaxiPricingSettings />

      <div className="section-title compact-title">{t('Phone numbers')}</div>
      <div className="number-list">
        {settings.numbers.map((n) => (
          <div key={n.id} className="number-row">
            <div className="dashboard-label">
              {n.label} {n.isMain && <span className="hint">({t('main')})</span>}
            </div>
            <div className="number-toggles">
              {/* Calls stays forced on for Main - a company must always be
                  reachable by call. Messages is freely toggleable even for
                  Main. One switch, not a separate Messages/Mailbox pair -
                  both still exist as separate DB columns (mailbox controls
                  whether an incoming chat shows up in the company inbox,
                  messages controls whether a customer can send at all) but
                  a boss only ever needs "can customers message this number
                  or not", so this sets both together. */}
              <div className="hotline-row">
                <span>{t('Calls')}</span>
                <Switch
                  checked={n.callsEnabled}
                  disabled={n.isMain}
                  onChange={(next) => saveNumber(n.id, { callsEnabled: next, messagesEnabled: n.messagesEnabled, mailboxEnabled: n.mailboxEnabled })}
                />
              </div>
              <div className="hotline-row">
                <span>{t('Messages')}</span>
                <Switch
                  checked={n.messagesEnabled}
                  onChange={(next) => saveNumber(n.id, { callsEnabled: n.callsEnabled, messagesEnabled: next, mailboxEnabled: next })}
                />
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
