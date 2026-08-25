import { fetchNui, createCall } from '../../lib/nui.js'
import Icon from '../../components/Icon.jsx'
import { useI18n } from '../../lib/i18n.jsx'
import { showToast } from '../../lib/toast.js'
import { useCursorList } from '../../lib/useCursorList.js'
import { useMinuteTick } from '../../lib/time.js'
import ListError from '../../components/ListError.jsx'

const STATE_LABEL = { ringing: 'Calling…', answered: 'Call', missed: 'Missed call' }

// Mirrors Config.PageSize.calls in shared/config.lua - a page shorter than
// this means there's nothing left to load (plan §68, plan review round 3 §11).
const PAGE_SIZE = 25

// Own call history (plan §38-41) - read-only, logged passively from
// lb-phone's own call events (see server/calls.lua).
export default function CallsTab({ refreshToken }) {
  const { t, formatRelativeTime } = useI18n()
  const { items: entries, hasMore, loadingMore, error, loadMore, reload } = useCursorList('getMyCalls', { pageSize: PAGE_SIZE, refreshToken })
  useMinuteTick()

  // Re-resolves and places a fresh call the same way ServicesScreen's own
  // Call button does (plan §39-41 wants "call the company again" here) -
  // resolveCall re-validates calls_enabled/routing server-side, so a number
  // disabled since this call happened just quietly does nothing.
  const callBack = async (entry) => {
    try {
      const target = await fetchNui('resolveCall', { companyId: entry.company_id, numberId: entry.number_id })
      if (!target) throw new Error('unavailable')
      createCall(target.company ? { company: target.company } : { number: target.number })
    } catch {
      showToast(t('This company is currently unavailable by phone.'), 'error')
    }
  }

  return (
    <div className="tab-panel">
      {entries === null && <div className="empty-state loading-state" aria-busy="true">{t('Loading your calls…')}</div>}
      {error && <ListError onRetry={reload} />}
      {!error && entries !== null && entries.length === 0 && (
        <div className="empty-state">{t('No calls yet. Call a company from Services to see it here.')}</div>
      )}

      <div className="activity-list">
        {entries?.map((entry) => (
          <div key={entry.id} className="activity-row">
            <button className="activity-row-open" onClick={() => callBack(entry)}>
              <div className="company-icon small">
                {entry.company_icon ? <img src={entry.company_icon} alt="" /> : <span>{entry.company_name?.[0] || '?'}</span>}
              </div>
              <div className="company-info">
                <div className="company-name">{entry.company_name}</div>
                <div className={`last-message call-state ${entry.state}`}>{t(STATE_LABEL[entry.state] || entry.state)}</div>
              </div>
            </button>
            <div className="activity-meta">
              <span className="activity-time">{formatRelativeTime(entry.created_at)}</span>
              <button
                className="icon-button subtle"
                onClick={(e) => {
                  e.stopPropagation()
                  callBack(entry)
                }}
                aria-label={t('Call back')}
              >
                <Icon name="phone" size={13} />
              </button>
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
