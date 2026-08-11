import { useEffect, useState } from 'react'
import { fetchNui, createCall } from '../../lib/nui.js'

const STATE_LABEL = { ringing: 'Ringing', answered: 'Answered', missed: 'Missed' }

// Mirrors Config.PageSize.calls in shared/config.lua - a page shorter than
// this means there's nothing left to load (plan §68, plan review round 3 §11).
const PAGE_SIZE = 25

// Call history (plan §38): a plain log, populated passively from lb-phone's
// own call events (see server/calls.lua) - Services+ never places calls.
export default function CallsTab() {
  const [calls, setCalls] = useState(null)
  const [hasMore, setHasMore] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)

  const loadPage = (page) => {
    if (page > 0) setLoadingMore(true)

    fetchNui('getCallHistory', { page }).then((r) => {
      setLoadingMore(false)
      if (!r) return

      setCalls((prev) => (page === 0 ? r : [...(prev || []), ...r]))
      setHasMore(r.length === PAGE_SIZE)
    })
  }

  useEffect(() => loadPage(0), [])

  const loadMore = () => loadPage(Math.floor((calls?.length || 0) / PAGE_SIZE))

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

      {hasMore && (
        <button className="sheet-option" onClick={loadMore} disabled={loadingMore}>
          {loadingMore ? 'Loading…' : 'Load more'}
        </button>
      )}
    </div>
  )
}
