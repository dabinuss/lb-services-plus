import { useI18n } from '../../lib/i18n.jsx'
import Badge from '../../components/Badge.jsx'
import { useCursorList } from '../../lib/useCursorList.js'
import ListError from '../../components/ListError.jsx'

// Mirrors Config.PageSize.messages in shared/config.lua - a page shorter
// than this means there's nothing left to load (plan §68, plan review
// round 3 §11).
const PAGE_SIZE = 25

// Employee-side inbox (plan §37), grouped implicitly by number label since
// each mailbox-enabled number gets its own conversations.
export default function MessagesTab({ onOpenConversation, onReadConversation, refreshToken }) {
  const { t } = useI18n()
  const { items: conversations, setItems: setConversations, hasMore, loadingMore, error, loadMore, reload } = useCursorList('getCompanyConversations', {
    key: 'channel_id', pageSize: PAGE_SIZE, refreshToken,
  })

  const open = (conversation) => {
    onReadConversation?.(conversation.channel_id, conversation.unread_count)
    setConversations((current) => current?.map((item) => item.channel_id === conversation.channel_id ? { ...item, unread_count: 0 } : item))
    onOpenConversation({ channelId: conversation.channel_id, title: `${conversation.contact_number} (${conversation.label})` })
  }

  return (
    <div className="tab-panel">
      {conversations === null && <div className="empty-state">{t('Loading conversations…')}</div>}
      {error && <ListError onRetry={reload} />}
      {!error && conversations !== null && conversations.length === 0 && (
        <div className="empty-state">{t('No conversations yet. Customer messages will show up here.')}</div>
      )}

      <div className="activity-list">
        {conversations?.map((c) => (
          <button
            key={c.channel_id}
            className={`activity-row${Number(c.unread_count) > 0 ? ' unread' : ''}`}
            onClick={() => open(c)}
          >
            <div className="company-info">
              <div className="company-name">{c.contact_number}</div>
              <div className="last-message">{c.last_message}</div>
            </div>
            <div className="activity-meta">
              <span className="activity-time">{c.label}</span>
              <Badge count={c.unread_count} className="conversation-badge" />
            </div>
          </button>
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
