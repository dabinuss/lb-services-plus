import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'

// Employee-side inbox (plan §37), grouped implicitly by number label since
// each mailbox-enabled number gets its own conversations.
export default function MessagesTab({ onOpenConversation }) {
  const [conversations, setConversations] = useState(null)

  useEffect(() => {
    fetchNui('getCompanyConversations', { page: 0 }).then((r) => r && setConversations(r))
  }, [])

  return (
    <div className="tab-panel">
      {conversations === null && <div className="empty-state">Loading…</div>}
      {conversations !== null && conversations.length === 0 && <div className="empty-state">No conversations.</div>}

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
    </div>
  )
}
