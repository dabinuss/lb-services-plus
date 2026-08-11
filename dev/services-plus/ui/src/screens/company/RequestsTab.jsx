import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'

// Employee-side request queue (plan §36, §45, §47). Open requests can be
// accepted by anyone eligible; only the employee who accepted one can
// complete or cancel it.
export default function RequestsTab() {
  const [requests, setRequests] = useState(null)

  const load = () => fetchNui('getCompanyRequests', { page: 0 }).then((r) => r && setRequests(r))

  useEffect(() => {
    load()
  }, [])

  const accept = async (request) => {
    const result = await fetchNui('acceptRequest', { requestId: request.id })
    if (!result) return
    if (result.x && result.y) fetchNui('setWaypoint', { x: result.x, y: result.y })
    load()
  }

  const complete = async (request) => {
    if (await fetchNui('completeRequest', { requestId: request.id })) load()
  }

  const cancel = async (request) => {
    if (await fetchNui('cancelRequest', { requestId: request.id })) load()
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
    </div>
  )
}
