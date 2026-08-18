import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'

// Mirrors Config.PageSize.messages in shared/config.lua - a page shorter
// than this means there's nothing left to load (plan §68, plan review
// round 3 §11).
const PAGE_SIZE = 25

// Employee-side inbox (plan §37), grouped implicitly by number label since
// each mailbox-enabled number gets its own conversations.
export default function MessagesTab({ onOpenConversation }) {
  const [conversations, setConversations] = useState(null)
  const [hasMore, setHasMore] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)

  const loadPage = (page) => {
    if (page > 0) setLoadingMore(true)

    fetchNui('getCompanyConversations', { page }).then((r) => {
      setLoadingMore(false)
      if (!r) return

      setConversations((prev) => (page === 0 ? r : [...(prev || []), ...r]))
      setHasMore(r.length === PAGE_SIZE)
    })
  }

  useEffect(() => loadPage(0), [])

  const loadMore = () => loadPage(Math.floor((conversations?.length || 0) / PAGE_SIZE))

  return (
    <div className="tab-panel">
      {conversations === null && <div className="empty-state">Loading conversations…</div>}
      {conversations !== null && conversations.length === 0 && (
        <div className="empty-state">No conversations yet. Customer messages will show up here.</div>
      )}

      <div className="activity-list">
        {conversations?.map((c) => (
          <div
            key={c.channel_id}
            className="activity-row"
            onClick={() => onOpenConversation({ channelId: c.channel_id, title: `${c.contact_number} (${c.label})` })}
          >
            <div className="company-info">
              <div className="company-name">{c.contact_number}</div>
              <div className="last-message">{c.last_message}</div>
            </div>
            <div className="activity-meta">
              <span className="activity-time">{c.label}</span>
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
