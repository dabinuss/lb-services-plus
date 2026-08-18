import { useEffect, useState } from 'react'
import { fetchNui, createCall } from '../../lib/nui.js'
import Icon from '../../components/Icon.jsx'

function timeAgo(iso) {
  const seconds = Math.floor((Date.now() - new Date(iso).getTime()) / 1000)
  if (seconds < 60) return 'now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  return `${Math.floor(seconds / 86400)}d`
}

const STATE_LABEL = { ringing: 'Calling…', answered: 'Call', missed: 'Missed call' }

// Mirrors Config.PageSize.calls in shared/config.lua - a page shorter than
// this means there's nothing left to load (plan §68, plan review round 3 §11).
const PAGE_SIZE = 25

// Own call history (plan §38-41) - read-only, logged passively from
// lb-phone's own call events (see server/calls.lua).
export default function CallsTab() {
  const [entries, setEntries] = useState(null)
  const [hasMore, setHasMore] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)

  const loadPage = (page) => {
    if (page > 0) setLoadingMore(true)

    fetchNui('getMyCalls', { page }).then((result) => {
      setLoadingMore(false)
      if (!result) return

      setEntries((prev) => (page === 0 ? result : [...(prev || []), ...result]))
      setHasMore(result.length === PAGE_SIZE)
    })
  }

  useEffect(() => loadPage(0), [])

  const loadMore = () => loadPage(Math.floor((entries?.length || 0) / PAGE_SIZE))

  // Re-resolves and places a fresh call the same way ServicesScreen's own
  // Call button does (plan §39-41 wants "call the company again" here) -
  // resolveCall re-validates calls_enabled/routing server-side, so a number
  // disabled since this call happened just quietly does nothing.
  const callBack = async (entry) => {
    const target = await fetchNui('resolveCall', { companyId: entry.company_id, numberId: entry.number_id })
    if (!target) return
    createCall(target.company ? { company: target.company } : { number: target.number })
  }

  return (
    <div className="tab-panel">
      {entries === null && <div className="empty-state">Loading your calls…</div>}
      {entries !== null && entries.length === 0 && (
        <div className="empty-state">No calls yet. Call a company from Services to see it here.</div>
      )}

      <div className="activity-list">
        {entries?.map((entry) => (
          <div key={entry.id} className="activity-row" onClick={() => callBack(entry)}>
            <div className="company-icon small">
              {entry.company_icon ? <img src={entry.company_icon} alt="" /> : <span>{entry.company_name?.[0] || '?'}</span>}
            </div>
            <div className="company-info">
              <div className="company-name">{entry.company_name}</div>
              <div className={`last-message call-state ${entry.state}`}>{STATE_LABEL[entry.state] || entry.state}</div>
            </div>
            <div className="activity-meta">
              <span className="activity-time">{timeAgo(entry.created_at)}</span>
              <button
                className="icon-button subtle"
                onClick={(e) => {
                  e.stopPropagation()
                  callBack(entry)
                }}
                aria-label="Call back"
              >
                <Icon name="phone" size={13} />
              </button>
            </div>
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
