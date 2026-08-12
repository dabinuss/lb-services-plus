import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'

export default function ServiceSettingsTab() {
  const [graceMinutes, setGraceMinutes] = useState('5')
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState('')

  useEffect(() => {
    fetchNui('admin:getServiceSettings').then((result) => {
      if (result) setGraceMinutes(String(result.activeRequestDisconnectGraceMinutes))
      setLoading(false)
    })
  }, [])

  const save = async () => {
    const value = Number(graceMinutes)
    if (!Number.isInteger(value) || value < 1 || value > 60) {
      setNotice('Enter a whole number between 1 and 60 minutes.')
      return
    }

    const ok = await fetchNui('admin:updateServiceSettings', {
      activeRequestDisconnectGraceMinutes: value,
    })
    setNotice(ok ? 'Settings saved.' : 'Could not save settings.')
  }

  return (
    <div className="tab-panel">
      <div className="settings-section">
        <div className="section-title">Active request disconnect grace period</div>
        <div className="hint">
          If an assigned employee does not reconnect within this time, their active request is cancelled automatically.
        </div>
        <input
          className="search-input"
          type="number"
          min="1"
          max="60"
          step="1"
          value={graceMinutes}
          disabled={loading}
          onChange={(event) => setGraceMinutes(event.target.value)}
        />
        <button className="login-button" disabled={loading} onClick={save}>Save settings</button>
        {notice && <div className="notice">{notice}</div>}
      </div>
    </div>
  )
}
