import { createCall } from '../../lib/nui.js'
import Icon from '../../components/Icon.jsx'
import { useI18n } from '../../lib/i18n.jsx'
import { useCursorList } from '../../lib/useCursorList.js'
import ListError from '../../components/ListError.jsx'

const STATE_LABEL = { ringing: 'Ringing', answered: 'Answered', missed: 'Missed' }

// Mirrors Config.PageSize.calls in shared/config.lua - a page shorter than
// this means there's nothing left to load (plan §68, plan review round 3 §11).
const PAGE_SIZE = 25

// Call history (plan §38): a plain log, populated passively from lb-phone's
// own call events (see server/calls.lua) - Services+ never places calls.
export default function CallsTab({ refreshToken }) {
  const { t } = useI18n()
  const { items: calls, hasMore, loadingMore, error, loadMore, reload } = useCursorList('getCallHistory', { pageSize: PAGE_SIZE, refreshToken })

  return (
    <div className="tab-panel">
      {calls === null && <div className="empty-state">{t('Loading call history…')}</div>}
      {error && <ListError onRetry={reload} />}
      {!error && calls !== null && calls.length === 0 && (
        <div className="empty-state">{t('No calls yet. Incoming and outgoing company calls will show up here.')}</div>
      )}

      <div className="activity-list">
        {calls?.map((c) => (
          <div key={c.id} className="activity-row">
            <div className="company-info">
              <div className="company-name">{c.customer_number}</div>
              <div className={`last-message call-state ${c.state}`}>
                {c.label} · {t(STATE_LABEL[c.state] || c.state)}
              </div>
            </div>
            <button className="icon-button call" onClick={() => createCall({ number: c.customer_number })} aria-label={t('Call back')}>
              <Icon name="phone" size={15} />
            </button>
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
