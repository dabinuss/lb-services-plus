import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import ConfirmButton from '../../components/ConfirmButton.jsx'
import Icon from '../../components/Icon.jsx'
import { useI18n } from '../../lib/i18n.jsx'
import Badge from '../../components/Badge.jsx'

// Mirrors Config.PageSize.activity in shared/config.lua - a page shorter
// than this means there's nothing left to load (plan §68, plan review
// round 3 §11).
const PAGE_SIZE = 25

// Own conversations (plan §39-41).
export default function MessagesTab({ onOpen, onReadConversation }) {
  const { t, formatRelativeTime } = useI18n()
  const [entries, setEntries] = useState(null)
  const [hasMore, setHasMore] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)

  const loadPage = (page) => {
    if (page > 0) setLoadingMore(true)

    fetchNui('getActivity', { page }).then((result) => {
      setLoadingMore(false)
      if (!result) return

      setEntries((prev) => (page === 0 ? result : [...(prev || []), ...result]))
      setHasMore(result.length === PAGE_SIZE)
    })
  }

  useEffect(() => loadPage(0), [])

  const loadMore = () => loadPage(Math.floor((entries?.length || 0) / PAGE_SIZE))

  const archive = async (entry) => {
    if (await fetchNui('archiveConversation', { channelId: entry.channel_id })) {
      onReadConversation?.(entry.channel_id, entry.unread_count)
      loadPage(0)
    }
  }

  const open = (entry) => {
    onReadConversation?.(entry.channel_id, entry.unread_count)
    setEntries((current) => current?.map((item) => item.channel_id === entry.channel_id ? { ...item, unread_count: 0 } : item))
    onOpen({ channelId: entry.channel_id, title: entry.company?.name || t('Conversation'), icon: entry.company?.icon })
  }

  return (
    <div className="tab-panel">
      {entries === null && <div className="empty-state">{t('Loading your conversations…')}</div>}
      {entries !== null && entries.length === 0 && (
        <div className="empty-state">{t("No messages yet. Start a conversation from a company's page in Services.")}</div>
      )}

      <div className="activity-list">
        {entries?.map((entry) => (
          <div
            key={entry.channel_id}
            className={`activity-row${Number(entry.unread_count) > 0 ? ' unread' : ''}`}
            onClick={() => open(entry)}
          >
            <div className="company-icon small">
              {entry.company?.icon ? <img src={entry.company.icon} alt="" /> : <span>{entry.company?.name?.[0] || '?'}</span>}
            </div>
            <div className="company-info">
              <div className="company-name">{entry.company?.name || t('Unknown company')}</div>
              <div className="last-message">{entry.last_message}</div>
            </div>
            <div className="activity-meta">
              <span className="activity-time">{formatRelativeTime(entry.updated_at)}</span>
              <Badge count={entry.unread_count} className="conversation-badge" />
              <div onClick={(e) => e.stopPropagation()}>
                <ConfirmButton className="icon-button subtle" ariaLabel="remove conversation" onConfirm={() => archive(entry)}>
                  <Icon name="x" size={13} />
                </ConfirmButton>
              </div>
            </div>
          </div>
        ))}
      </div>

      {hasMore && (
        <button className="sheet-option" onClick={loadMore} disabled={loadingMore}>
          {t(loadingMore ? 'Loading…' : 'Load more')}
        </button>
      )}
    </div>
  )
}
