import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'

function timeAgo(iso) {
  const seconds = Math.floor((Date.now() - new Date(iso).getTime()) / 1000)
  if (seconds < 60) return 'now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  return `${Math.floor(seconds / 86400)}d`
}

const STATE_LABEL = { ringing: 'Calling…', answered: 'Call', missed: 'Missed call' }

// Own call history (plan §38-41) - read-only, logged passively from
// lb-phone's own call events (see server/calls.lua).
export default function CallsTab() {
  const [entries, setEntries] = useState(null)

  useEffect(() => {
    fetchNui('getMyCalls', { page: 0 }).then((result) => result && setEntries(result))
  }, [])

  return (
    <div className="tab-panel">
      {entries === null && <div className="empty-state">Loading…</div>}
      {entries !== null && entries.length === 0 && <div className="empty-state">No calls yet.</div>}

      <div className="activity-list">
        {entries?.map((entry) => (
          <div key={entry.id} className="activity-row">
            <div className="company-icon small">
              {entry.company_icon ? <img src={entry.company_icon} alt="" /> : <span>{entry.company_name?.[0] || '?'}</span>}
            </div>
            <div className="company-info">
              <div className="company-name">{entry.company_name}</div>
              <div className={`last-message call-state ${entry.state}`}>{STATE_LABEL[entry.state] || entry.state}</div>
            </div>
            <div className="activity-meta">
              <span className="activity-time">{timeAgo(entry.created_at)}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
