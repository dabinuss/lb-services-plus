// One row of the Services overview (plan §5-9). Buttons are only shown when
// the company actually allows the action.
export default function CompanyCard({ company, onCall, onMessage, onRequest }) {
  const canMessage = company.messagesEnabled && company.numbers.some((n) => n.messagesEnabled)
  const canCall = company.callsEnabled
  const canRequest = company.requestsEnabled

  return (
    <div className={`company-card${company.available ? '' : ' unavailable'}`}>
      <div className="company-icon">
        {company.icon ? <img src={company.icon} alt="" /> : <span>{company.name[0]}</span>}
      </div>

      <div className="company-info">
        <div className="company-name">{company.name}</div>
        <div className={`company-status ${company.available ? 'available' : 'unavailable'}`}>
          {company.available ? 'Available' : 'No employees available'}
        </div>
      </div>

      <div className="company-actions">
        {canRequest && (
          <button className="icon-button" onClick={onRequest} aria-label="Request">
            📋
          </button>
        )}
        {canMessage && (
          <button className="icon-button" onClick={onMessage} aria-label="Message">
            💬
          </button>
        )}
        {canCall && (
          <button className="icon-button call" onClick={onCall} aria-label="Call">
            📞
          </button>
        )}
      </div>
    </div>
  )
}
