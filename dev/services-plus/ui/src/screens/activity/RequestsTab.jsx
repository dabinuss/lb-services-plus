import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'

function timeAgo(iso) {
  const seconds = Math.floor((Date.now() - new Date(iso).getTime()) / 1000)
  if (seconds < 60) return 'now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  return `${Math.floor(seconds / 86400)}d`
}

// Own requests (plan §39-41) - open ones can still be cancelled from here.
export default function RequestsTab() {
  const [entries, setEntries] = useState(null)

  const load = () => {
    fetchNui('getMyRequests', { page: 0 }).then((result) => result && setEntries(result))
  }

  useEffect(load, [])

  const cancel = async (entry) => {
    if (await fetchNui('cancelRequest', { requestId: entry.id })) load()
  }

  return (
    <div className="tab-panel">
      {entries === null && <div className="empty-state">Loading…</div>}
      {entries !== null && entries.length === 0 && <div className="empty-state">No requests yet.</div>}

      <div className="activity-list">
        {entries?.map((entry) => (
          <div key={entry.id} className="activity-row">
            <div className="company-icon small">
              {entry.company_icon ? <img src={entry.company_icon} alt="" /> : <span>{entry.type_name?.[0] || '?'}</span>}
            </div>
            <div className="company-info">
              <div className="company-name">{entry.company_name || entry.type_name}</div>
              <div className="last-message">
                {entry.type_name} · {entry.status}
              </div>
            </div>
            <div className="activity-meta">
              <span className="activity-time">{timeAgo(entry.created_at)}</span>
              {entry.status === 'open' && (
                <button className="icon-button subtle" onClick={() => cancel(entry)} aria-label="Cancel">
                  ✕
                </button>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
