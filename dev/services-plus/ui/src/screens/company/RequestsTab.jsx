import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'

// Mirrors Config.PageSize.requests in shared/config.lua - a page shorter
// than this means there's nothing left to load (plan §68, plan review
// round 3 §11).
const PAGE_SIZE = 25

// Employee-side request queue (plan §36, §45, §47). Open requests can be
// accepted by anyone eligible; only the employee who accepted one can
// complete or cancel it.
export default function RequestsTab() {
  const [requests, setRequests] = useState(null)
  const [hasMore, setHasMore] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)

  const loadPage = (page) => {
    if (page > 0) setLoadingMore(true)

    fetchNui('getCompanyRequests', { page }).then((r) => {
      setLoadingMore(false)
      if (!r) return

      setRequests((prev) => (page === 0 ? r : [...(prev || []), ...r]))
      setHasMore(r.length === PAGE_SIZE)
    })
  }

  useEffect(() => loadPage(0), [])

  // Any action can reorder or drop rows (open-first sort, status changes),
  // so a refresh after one always restarts from page 0 rather than trying
  // to patch the loaded pages in place.
  const loadMore = () => loadPage(Math.floor((requests?.length || 0) / PAGE_SIZE))

  const accept = async (request) => {
    const result = await fetchNui('acceptRequest', { requestId: request.id })
    if (!result) return
    if (result.x && result.y) fetchNui('setWaypoint', { x: result.x, y: result.y })
    loadPage(0)
  }

  const complete = async (request) => {
    if (await fetchNui('completeRequest', { requestId: request.id })) loadPage(0)
  }

  const cancel = async (request) => {
    if (await fetchNui('cancelRequest', { requestId: request.id })) loadPage(0)
  }

  return (
    <div className="tab-panel">
      {requests === null && <div className="empty-state">Loading…</div>}
      {requests !== null && requests.length === 0 && <div className="empty-state">No requests.</div>}

      <div className="request-list">
        {requests?.map((r) => (
          <div key={r.id} className={`request-row status-${r.status}`}>
            <div className="request-info">
              <div className="request-type">{r.type_name}</div>
              <div className="request-meta">
                {r.passenger_count ? `${r.passenger_count} passengers · ` : ''}
                {r.description || 'No description'}
              </div>
            </div>

            {r.status === 'open' && (
              <button className="request-action accept" onClick={() => accept(r)}>
                Accept
              </button>
            )}
            {r.status === 'active' && r.is_mine && (
              <div className="request-actions">
                <button className="request-action complete" onClick={() => complete(r)}>
                  Complete
                </button>
                <button className="request-action cancel" onClick={() => cancel(r)}>
                  Cancel
                </button>
              </div>
            )}
            {r.status === 'active' && !r.is_mine && <div className="request-status">In progress</div>}
            {(r.status === 'completed' || r.status === 'cancelled') && (
              <div className="request-status">{r.status}</div>
            )}
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
