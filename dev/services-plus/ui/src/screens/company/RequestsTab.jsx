import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import Sheet from '../../components/Sheet.jsx'
import ConfirmButton from '../../components/ConfirmButton.jsx'
import Icon from '../../components/Icon.jsx'
import { useI18n } from '../../lib/i18n.jsx'

// Mirrors Config.PageSize.requests in shared/config.lua - a page shorter
// than this means there's nothing left to load (plan §68, plan review
// round 3 §11).
const PAGE_SIZE = 25

// Employee-side request queue (plan §36, §45, §47). Open requests can be
// accepted by anyone eligible; only the employee who accepted one can
// complete or cancel it.
export default function RequestsTab() {
  const { t, formatDateTime } = useI18n()
  const [requests, setRequests] = useState(null)
  const [details, setDetails] = useState(null)
  const [hasMore, setHasMore] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)

  const loadPage = (page) => {
    if (page > 0) setLoadingMore(true)

    fetchNui('getCompanyRequests', { page }).then((r) => {
      setLoadingMore(false)
      if (!r) return

      setRequests((prev) => (page === 0 ? r : [...(prev || []), ...r]))
      setHasMore(r.length === PAGE_SIZE)
    })
  }

  useEffect(() => loadPage(0), [])

  // Any action can reorder or drop rows (open-first sort, status changes),
  // so a refresh after one always restarts from page 0 rather than trying
  // to patch the loaded pages in place.
  const loadMore = () => loadPage(Math.floor((requests?.length || 0) / PAGE_SIZE))

  const setLocation = (request) => {
    const x = request.x ?? request.pos_x
    const y = request.y ?? request.pos_y
    if (x != null && y != null) fetchNui('setWaypoint', { x, y })
  }

  const accept = async (request) => {
    const result = await fetchNui('acceptRequest', { requestId: request.id })
    if (!result) return
    if (result.x != null && result.y != null) fetchNui('setWaypoint', { x: result.x, y: result.y })
    setDetails(null)
    loadPage(0)
  }

  const complete = async (request) => {
    if (await fetchNui('completeRequest', { requestId: request.id })) {
      setDetails(null)
      loadPage(0)
    }
  }

  const cancel = async (request) => {
    if (await fetchNui('cancelRequest', { requestId: request.id })) {
      setDetails(null)
      loadPage(0)
    }
  }

  return (
    <div className="tab-panel">
      {requests === null && <div className="empty-state">{t('Loading requests…')}</div>}
      {requests !== null && requests.length === 0 && (
        <div className="empty-state">{t('No requests yet. New customer requests will show up here.')}</div>
      )}

      <div className="request-list">
        {requests?.map((r) => (
          <div key={r.id} className={`request-row status-${r.status}`} onClick={() => setDetails(r)}>
            <div className="request-info">
              <div className="request-type">{t(r.type_name)}</div>
              <div className="request-meta">
                {r.passenger_count ? `${r.count_label || t('Passenger count')}: ${r.passenger_count} · ` : ''}
                {r.description ? t(r.description) : t('No description')}
                {r.feature_data?.amount != null ? ` · $${r.feature_data.amount.toFixed(2)}` : ''}
              </div>
            </div>

            {r.status === 'open' && (
              <button className="request-action accept" onClick={(e) => { e.stopPropagation(); accept(r) }}>
                {t('Accept')}
              </button>
            )}
            {r.status === 'active' && r.is_mine && (
              <div className="request-actions" onClick={(e) => e.stopPropagation()}>
                <button className="request-action complete" onClick={() => complete(r)}>
                  {t('Complete')}
                </button>
                <ConfirmButton className="request-action cancel" onConfirm={() => cancel(r)}>
                  {t('Cancel')}
                </ConfirmButton>
              </div>
            )}
            {r.status === 'active' && !r.is_mine && <div className="request-status">{t('In progress')}</div>}
            {(r.status === 'completed' || r.status === 'cancelled') && (
              <div className="request-status">{t(r.status)}</div>
            )}
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
              <span>{t(details.company_id != null ? 'Company request' : 'Unclaimed')}</span>
            </div>
            <div className="request-detail-row">
              <span className="hint">{t('Status')}</span>
              <span>{t(details.status)}</span>
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
            {details.feature_data?.amount != null && (
              <div className="request-detail-row">
                <span className="hint">{t('Fare')}</span>
                <span>${details.feature_data.amount.toFixed(2)}</span>
              </div>
            )}
            {details.created_at && (
              <div className="request-detail-row">
                <span className="hint">{t('Requested')}</span>
                <span>{formatDateTime(details.created_at)}</span>
              </div>
            )}
          </div>

          {((details.x ?? details.pos_x) != null && (details.y ?? details.pos_y) != null) && (
            <button className="sheet-option" onClick={() => setLocation(details)}>
              <Icon name="target" size={16} className="sheet-option-icon" />
              <span className="sheet-option-label">{t('Set location')}</span>
            </button>
          )}
          {details.status === 'open' && (
            <button className="sheet-option" onClick={() => accept(details)}>
              <Icon name="check" size={16} className="sheet-option-icon" />
              <span className="sheet-option-label">{t('Accept request')}</span>
            </button>
          )}
          {details.status === 'active' && details.is_mine && (
            <>
              <button className="sheet-option" onClick={() => complete(details)}>
                <Icon name="check" size={16} className="sheet-option-icon" />
                <span className="sheet-option-label">{t('Complete request')}</span>
              </button>
              <ConfirmButton className="sheet-option" onConfirm={() => cancel(details)}>
                <Icon name="x" size={16} className="sheet-option-icon" />
                <span className="sheet-option-label">{t('Cancel request')}</span>
              </ConfirmButton>
            </>
          )}
        </Sheet>
      )}
    </div>
  )
}
