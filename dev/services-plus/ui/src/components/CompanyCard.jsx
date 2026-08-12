// One card of the Services overview (plan §5-9): a background/branding
// image with the company's logo and name overlaid, an availability dot, and
// a labeled action row below. Buttons only show when the company actually
// allows that action.
export default function CompanyCard({ company, categoryName, onCall, onMessage, onRequest }) {
  const canMessage = company.available && company.messagesEnabled && company.numbers.some((n) => n.messagesEnabled)
  const canCall = company.available && company.callsEnabled
  const canRequest = company.available && company.requestsEnabled
  const mainNumber = company.numbers?.find((n) => n.isMain) ?? null

  return (
    <div className={`company-card${company.available ? '' : ' unavailable'}`}>
      <div className="company-banner">
        {company.background && (
          <div className="company-banner-bg" style={{ backgroundImage: `url(${company.background})` }} />
        )}
        <div className="company-banner-scrim" />

        <div className="company-logo">
          {company.icon ? <img src={company.icon} alt="" /> : <span>{company.name[0]}</span>}
          <span className={`company-status-dot ${company.available ? 'available' : 'unavailable'}`} />
        </div>

        <div className="company-banner-text">
          <div className="company-name">{company.name}</div>
          <div className="company-subtitle">
            {!company.available
              ? mainNumber?.number || categoryName || 'Company'
              : `${categoryName || 'Company'}${mainNumber?.number ? ` · ${mainNumber.number}` : ''}`}
          </div>
        </div>
      </div>

      <div className="company-actions-row">
        {canCall && (
          <button className="company-action call" onClick={onCall}>
            <span className="company-action-icon">📞</span>
            Call
          </button>
        )}
        {canRequest && (
          <button className="company-action request" onClick={onRequest}>
            <span className="company-action-icon">📋</span>
            Request
          </button>
        )}
        {canMessage && (
          <button className="company-action message" onClick={onMessage}>
            <span className="company-action-icon">💬</span>
            Message
          </button>
        )}
      </div>
    </div>
  )
}
