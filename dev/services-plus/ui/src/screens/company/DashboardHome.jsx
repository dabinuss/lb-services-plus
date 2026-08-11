import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'

const STATUSES = [
  { key: 'available', label: 'Available' },
  { key: 'pause', label: 'Pause' },
  { key: 'busy', label: 'Busy' },
]

// Duty, status and hotlines (plan §19-23).
export default function DashboardHome({ initialOnDuty, initialStatus, onLogout }) {
  const [onDuty, setOnDuty] = useState(initialOnDuty)
  const [status, setStatus] = useState(initialStatus)
  const [hotlines, setHotlines] = useState(null)
  const [notice, setNotice] = useState('')

  useEffect(() => {
    fetchNui('getHotlines').then((result) => result && setHotlines(result))
  }, [])

  // Going off-duty ends the fake-login session, not just the duty flag -
  // "offline" is one of the only three things allowed to log the player
  // out (explicit logout, going off-duty, switching to a different phone
  // number).
  const toggleDuty = async () => {
    const next = !onDuty
    if (!(await fetchNui('toggleDuty', { onDuty: next }))) return

    if (next) {
      setOnDuty(true)
    } else {
      onLogout()
    }
  }

  const changeStatus = async (next) => {
    if (await fetchNui('setStatus', { status: next })) setStatus(next)
  }

  const toggleHotline = async (line) => {
    const result = await fetchNui('toggleHotline', { numberId: line.numberId, active: !line.active })
    if (result?.ok) {
      setHotlines(result.hotlines)
      setNotice('')
    } else if (result?.reason === 'sole_employee') {
      setNotice("Main hotline stays on while you're the only one on duty.")
    }
  }

  return (
    <div className="tab-panel">
      <div className="dashboard-row">
        <div className="dashboard-label">On duty</div>
        <button className={`toggle${onDuty ? ' on' : ''}`} onClick={toggleDuty}>
          <span className="toggle-knob" />
        </button>
      </div>

      {onDuty && (
        <>
          <div className="status-row">
            {STATUSES.map((s) => (
              <button
                key={s.key}
                className={`status-pill ${s.key}${status === s.key ? ' active' : ''}`}
                onClick={() => changeStatus(s.key)}
              >
                {s.label}
              </button>
            ))}
          </div>

          <div className="section-title">Hotlines</div>
          <div className="hotline-list">
            {hotlines === null && <div className="empty-state">Loading…</div>}
            {hotlines?.map((line) => (
              <label key={line.numberId} className="hotline-row">
                <input
                  type="checkbox"
                  checked={line.active}
                  disabled={line.locked}
                  onChange={() => toggleHotline(line)}
                />
                {line.label}
                {line.locked && <span className="hint"> (locked)</span>}
              </label>
            ))}
          </div>
          {notice && <div className="notice">{notice}</div>}
        </>
      )}
    </div>
  )
}
