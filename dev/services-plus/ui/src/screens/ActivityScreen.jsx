import { useEffect, useState } from 'react'
import { fetchNui } from '../lib/nui.js'

function timeAgo(iso) {
  const seconds = Math.floor((Date.now() - new Date(iso).getTime()) / 1000)
  if (seconds < 60) return 'now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  return `${Math.floor(seconds / 86400)}d`
}

const CALL_STATE_LABEL = { ringing: 'Calling…', answered: 'Call', missed: 'Missed call' }

// Personal history (plan §39-41): messages, requests and calls merged into
// one compact, chronological feed - deliberately not a CRM-style history.
// Each source paginates independently (page 0 only for now); a unified
// cursor across three different tables isn't worth the complexity yet.
export default function ActivityScreen({ onOpen }) {
  const [entries, setEntries] = useState(null)

  const load = () => {
    Promise.all([
      fetchNui('getActivity', { page: 0 }),
      fetchNui('getMyRequests', { page: 0 }),
      fetchNui('getMyCalls', { page: 0 }),
    ]).then(([messages, requests, calls]) => {
      const merged = [
        ...(messages || []).map((m) => ({
          kind: 'message',
          key: `m${m.channel_id}`,
          icon: m.company?.icon,
          name: m.company?.name || 'Unknown company',
          subtitle: m.last_message,
          time: m.updated_at,
          raw: m,
        })),
        ...(requests || []).map((r) => ({
          kind: 'request',
          key: `r${r.id}`,
          icon: r.company_icon,
          name: r.company_name || r.type_name,
          subtitle: `${r.type_name} · ${r.status}`,
          time: r.created_at,
          raw: r,
        })),
        ...(calls || []).map((c) => ({
          kind: 'call',
          key: `c${c.id}`,
          icon: c.company_icon,
          name: c.company_name,
          subtitle: CALL_STATE_LABEL[c.state] || c.state,
          time: c.created_at,
          raw: c,
        })),
      ].sort((a, b) => new Date(b.time) - new Date(a.time))

      setEntries(merged)
    })
  }

  useEffect(load, [])

  const archive = async (entry) => {
    if (entry.kind === 'message') {
      if (await fetchNui('archiveConversation', { channelId: entry.raw.channel_id })) load()
    } else if (entry.kind === 'request' && entry.raw.status === 'open') {
      if (await fetchNui('cancelRequest', { requestId: entry.raw.id })) load()
    }
  }

  return (
    <div className="screen activity-screen">
      <div className="screen-header">Activity</div>

      <div className="activity-list">
        {entries === null && <div className="empty-state">Loading…</div>}
        {entries !== null && entries.length === 0 && <div className="empty-state">No activity yet.</div>}

        {entries?.map((entry) => (
          <div key={entry.key} className="activity-row" onClick={() => onOpen(entry)}>
            <div className="company-icon small">
              {entry.icon ? <img src={entry.icon} alt="" /> : <span>{entry.name?.[0] || '?'}</span>}
            </div>
            <div className="company-info">
              <div className="company-name">{entry.name}</div>
              <div className="last-message">{entry.subtitle}</div>
            </div>
            <div className="activity-meta">
              <span className="activity-time">{timeAgo(entry.time)}</span>
              {(entry.kind === 'message' || (entry.kind === 'request' && entry.raw.status === 'open')) && (
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
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
