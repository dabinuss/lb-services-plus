import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'

function timeAgo(iso) {
  const seconds = Math.floor((Date.now() - new Date(iso).getTime()) / 1000)
  if (seconds < 60) return 'now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  return `${Math.floor(seconds / 86400)}d`
}

// Own conversations (plan §39-41).
export default function MessagesTab({ onOpen }) {
  const [entries, setEntries] = useState(null)

  const load = () => {
    fetchNui('getActivity', { page: 0 }).then((result) => result && setEntries(result))
  }

  useEffect(load, [])

  const archive = async (entry) => {
    if (await fetchNui('archiveConversation', { channelId: entry.channel_id })) load()
  }

  return (
    <div className="tab-panel">
      {entries === null && <div className="empty-state">Loading…</div>}
      {entries !== null && entries.length === 0 && <div className="empty-state">No messages yet.</div>}

      <div className="activity-list">
        {entries?.map((entry) => (
          <div
            key={entry.channel_id}
            className="activity-row"
            onClick={() => onOpen({ channelId: entry.channel_id, title: entry.company?.name || 'Conversation', icon: entry.company?.icon })}
          >
            <div className="company-icon small">
              {entry.company?.icon ? <img src={entry.company.icon} alt="" /> : <span>{entry.company?.name?.[0] || '?'}</span>}
            </div>
            <div className="company-info">
              <div className="company-name">{entry.company?.name || 'Unknown company'}</div>
              <div className="last-message">{entry.last_message}</div>
            </div>
            <div className="activity-meta">
              <span className="activity-time">{timeAgo(entry.updated_at)}</span>
              <button
                className="icon-button subtle"
                onClick={(e) => {
                  e.stopPropagation()
                  archive(entry)
                }}
                aria-label="Remove"
              >
                ✕
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
