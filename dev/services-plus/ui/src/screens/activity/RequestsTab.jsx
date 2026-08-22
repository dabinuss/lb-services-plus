import { useEffect, useRef, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import Sheet from '../../components/Sheet.jsx'
import ConfirmButton from '../../components/ConfirmButton.jsx'
import Icon from '../../components/Icon.jsx'
import { useI18n } from '../../lib/i18n.jsx'

// Mirrors Config.PageSize.requests in shared/config.lua - a page shorter
// than this means there's nothing left to load (plan §68, plan review
// round 3 §11).
const PAGE_SIZE = 25

// Own requests (plan §39-41) - open ones can still be cancelled from here.
export default function RequestsTab({ update }) {
  const { t, formatRelativeTime } = useI18n()
  const [entries, setEntries] = useState(null)
  const [details, setDetails] = useState(null) // the entry currently shown in the details sheet
  const [hasMore, setHasMore] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)
  const [cancellingId, setCancellingId] = useState(null)
  const cancelLock = useRef(false)

  const loadPage = (page) => {
    if (page > 0) setLoadingMore(true)

    fetchNui('getMyRequests', { page }).then((result) => {
      setLoadingMore(false)
      if (!result) return

      setEntries((prev) => (page === 0 ? result : [...(prev || []), ...result]))
      setHasMore(result.length === PAGE_SIZE)
    })
  }

  useEffect(() => loadPage(0), [])

  useEffect(() => {
    if (!update?.id) return
    const patch = (entry) => entry.id === update.id ? { ...entry, ...update } : entry
    setEntries((current) => current?.map(patch))
    setDetails((current) => current ? patch(current) : current)
  }, [update])

  const loadMore = () => loadPage(Math.floor((entries?.length || 0) / PAGE_SIZE))
  const statusLabel = (status) => t(status === 'active' ? 'Employee on the way' : status)

  const cancel = async (entry) => {
    if (cancelLock.current) return
    cancelLock.current = true
    setCancellingId(entry.id)
    try {
      if (await fetchNui('cancelRequest', { requestId: entry.id })) {
        setDetails(null)
        loadPage(0)
      }
    } finally {
      cancelLock.current = false
      setCancellingId(null)
    }
  }

  return (
    <div className="tab-panel">
      {entries === null && <div className="empty-state">{t('Loading your requests…')}</div>}
      {entries !== null && entries.length === 0 && (
        <div className="empty-state">{t("No requests yet. Create one from a company's page in Services.")}</div>
      )}

      <div className="activity-list">
        {entries?.map((entry) => (
          <div key={entry.id} className="activity-row" onClick={() => setDetails(entry)}>
            <div className="company-icon small">
              {entry.company_icon ? <img src={entry.company_icon} alt="" /> : <span>{entry.type_name?.[0] || '?'}</span>}
            </div>
            <div className="company-info">
              <div className="company-name">{entry.company_name || t(entry.type_name)}</div>
              <div className="last-message">
                {t(entry.type_name)} · {statusLabel(entry.status)}
              </div>
            </div>
            <div className="activity-meta">
              <span className="activity-time">{formatRelativeTime(entry.created_at)}</span>
              {entry.status === 'open' && (
                <div onClick={(e) => e.stopPropagation()}>
                  <ConfirmButton className="icon-button subtle" ariaLabel="cancel request" disabled={cancellingId !== null} onConfirm={() => cancel(entry)}>
                    <Icon name="x" size={13} />
                  </ConfirmButton>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {hasMore && (
        <button className="sheet-option" onClick={loadMore} disabled={loadingMore}>
          {t(loadingMore ? 'Loading…' : 'Load more')}
        </button>
      )}

      {details && (
        <Sheet title={t(details.type_name)} onClose={() => setDetails(null)}>
          <div className="request-details">
            <div className="request-detail-row">
              <span className="hint">{t('Company')}</span>
              <span>{details.company_name || t('Unclaimed')}</span>
            </div>
            <div className="request-detail-row">
              <span className="hint">{t('Status')}</span>
              <span>{statusLabel(details.status)}</span>
            </div>
            {details.passenger_count != null && (
              <div className="request-detail-row">
                <span className="hint">{details.count_label || t('Passenger count')}</span>
                <span>{details.passenger_count}</span>
              </div>
            )}
            {details.description && (
              <div className="request-detail-row">
                <span className="hint">{t('Notes')}</span>
                <span>{t(details.description)}</span>
              </div>
            )}
            <div className="request-detail-row">
              <span className="hint">{t('Requested')}</span>
              <span>{t('{time} ago', { time: formatRelativeTime(details.created_at) })}</span>
            </div>
          </div>

          {details.status === 'open' && (
            <ConfirmButton className="sheet-option" disabled={cancellingId !== null} onConfirm={() => cancel(details)}>
              {t('Cancel request')}
            </ConfirmButton>
          )}
        </Sheet>
      )}
    </div>
  )
}
