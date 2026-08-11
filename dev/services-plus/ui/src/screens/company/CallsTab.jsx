import { useEffect, useState } from 'react'
import { fetchNui, createCall } from '../../lib/nui.js'

const STATE_LABEL = { ringing: 'Ringing', answered: 'Answered', missed: 'Missed' }

// Call history (plan §38): a plain log, populated passively from lb-phone's
// own call events (see server/calls.lua) - Services+ never places calls.
export default function CallsTab() {
  const [calls, setCalls] = useState(null)

  useEffect(() => {
    fetchNui('getCallHistory', { page: 0 }).then((r) => r && setCalls(r))
  }, [])

  return (
    <div className="tab-panel">
      {calls === null && <div className="empty-state">Loading…</div>}
      {calls !== null && calls.length === 0 && <div className="empty-state">No calls yet.</div>}

      <div className="activity-list">
        {calls?.map((c) => (
          <div key={c.id} className="activity-row">
            <div className="company-info">
              <div className="company-name">{c.customer_number}</div>
              <div className={`last-message call-state ${c.state}`}>
                {c.label} · {STATE_LABEL[c.state] || c.state}
              </div>
            </div>
            <button className="icon-button call" onClick={() => createCall({ number: c.customer_number })} aria-label="Call back">
              📞
            </button>
          </div>
        ))}
      </div>
    </div>
  )
}
