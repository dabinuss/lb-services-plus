import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import Sheet from '../../components/Sheet.jsx'

function timeAgo(iso) {
  const seconds = Math.floor((Date.now() - new Date(iso).getTime()) / 1000)
  if (seconds < 60) return 'now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  return `${Math.floor(seconds / 86400)}d`
}

// Mirrors Config.PageSize.requests in shared/config.lua - a page shorter
// than this means there's nothing left to load (plan §68, plan review
// round 3 §11).
const PAGE_SIZE = 25

// Own requests (plan §39-41) - open ones can still be cancelled from here.
export default function RequestsTab() {
  const [entries, setEntries] = useState(null)
  const [details, setDetails] = useState(null) // the entry currently shown in the details sheet
  const [hasMore, setHasMore] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)

  const loadPage = (page) => {
    if (page > 0) setLoadingMore(true)

    fetchNui('getMyRequests', { page }).then((result) => {
      setLoadingMore(false)
      if (!result) return

      setEntries((prev) => (page === 0 ? result : [...(prev || []), ...result]))
      setHasMore(result.length === PAGE_SIZE)
    })
  }

  useEffect(() => loadPage(0), [])

  const loadMore = () => loadPage(Math.floor((entries?.length || 0) / PAGE_SIZE))

  const cancel = async (entry) => {
    if (await fetchNui('cancelRequest', { requestId: entry.id })) {
      setDetails(null)
      loadPage(0)
    }
  }

  return (
    <div className="tab-panel">
      {entries === null && <div className="empty-state">Loading…</div>}
      {entries !== null && entries.length === 0 && <div className="empty-state">No requests yet.</div>}

      <div className="activity-list">
        {entries?.map((entry) => (
          <div key={entry.id} className="activity-row" onClick={() => setDetails(entry)}>
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
                <button
                  className="icon-button subtle"
                  onClick={(e) => {
                    e.stopPropagation()
                    cancel(entry)
                  }}
                  aria-label="Cancel"
                >
                  ✕
                </button>
              )}
            </div>
          </div>
        ))}
      </div>

      {hasMore && (
        <button className="sheet-option" onClick={loadMore} disabled={loadingMore}>
          {loadingMore ? 'Loading…' : 'Load more'}
        </button>
      )}

      {details && (
        <Sheet title={details.type_name} onClose={() => setDetails(null)}>
          <div className="request-details">
            <div className="request-detail-row">
              <span className="hint">Company</span>
              <span>{details.company_name || 'Unclaimed'}</span>
            </div>
            <div className="request-detail-row">
              <span className="hint">Status</span>
              <span>{details.status}</span>
            </div>
            {details.passenger_count != null && (
              <div className="request-detail-row">
                <span className="hint">Passengers</span>
                <span>{details.passenger_count}</span>
              </div>
            )}
            {details.description && (
              <div className="request-detail-row">
                <span className="hint">Notes</span>
                <span>{details.description}</span>
              </div>
            )}
            <div className="request-detail-row">
              <span className="hint">Requested</span>
              <span>{timeAgo(details.created_at)} ago</span>
            </div>
          </div>

          {details.status === 'open' && (
            <button className="sheet-option" onClick={() => cancel(details)}>
              Cancel request
            </button>
          )}
        </Sheet>
      )}
    </div>
  )
}
