import Icon from './Icon.jsx'

// One card of the Services overview (plan §5-9): a background/branding
// image with the company's logo and name overlaid, an availability dot, and
// a labeled action row below. Buttons only show when the company actually
// allows that action.
export default function CompanyCard({ company, categoryName, onCall, onMessage, onRequest }) {
  // Call mirrors Message's own check - a company can have its calls toggle
  // on overall while every individual number has calls switched off (boss
  // settings, per number), same as messages/mailbox. Request has no
  // per-number concept at all - requests aren't tied to a phone number, so
  // company.requestsEnabled alone is already the complete picture.
  const canMessage = company.available && company.messagesEnabled && company.numbers.some((n) => n.messagesEnabled)
  const canCall = company.available && company.callsEnabled && company.numbers.some((n) => n.callsEnabled)
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
          <span
            className={`company-status-dot ${company.available ? 'available' : 'unavailable'}`}
            title={company.available ? 'Available' : 'Unavailable'}
          />
        </div>

        <div className="company-banner-text">
          <div className="company-name">{company.name}</div>
          {/* The dot alone only ever said "available/unavailable" through
              color - this spells it out in words too, not just for the
              unavailable case where it used to be implicit from the action
              row disappearing. */}
          <div className="company-subtitle">
            {!company.available
              ? `Unavailable${mainNumber?.number ? ` · ${mainNumber.number}` : categoryName ? ` · ${categoryName}` : ''}`
              : `${categoryName || 'Company'}${mainNumber?.number ? ` · ${mainNumber.number}` : ''}`}
          </div>
        </div>
      </div>

      <div className="company-actions-row">
        {canCall && (
          <button className="company-action call" onClick={onCall}>
            <Icon name="phone" size={15} className="company-action-icon" />
            Call
          </button>
        )}
        {canRequest && (
          <button className="company-action request" onClick={onRequest}>
            <Icon name="clipboard" size={15} className="company-action-icon" />
            Request
          </button>
        )}
        {canMessage && (
          <button className="company-action message" onClick={onMessage}>
            <Icon name="message" size={15} className="company-action-icon" />
            Message
          </button>
        )}
      </div>
    </div>
  )
}
