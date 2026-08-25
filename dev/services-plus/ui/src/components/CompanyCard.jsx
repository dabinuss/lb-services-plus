import Icon from './Icon.jsx'
import { useI18n } from '../lib/i18n.jsx'

// One card of the Services overview (plan §5-9): a background/branding
// image with the company's logo and name overlaid, an availability dot, and
// a labeled action row below. Buttons only show when the company actually
// allows that action.
export default function CompanyCard({ company, categoryName, onCall, onMessage, onRequest }) {
  const { t } = useI18n()
  // Messages remain usable while the company is offline, matching the
  // server-side offline mailbox. Calls stay visible so the available
  // contact methods do not jump around, but are disabled until somebody
  // is available again. Requests follow the same stable-button behaviour.
  const numbers = company.numbers ?? []
  // Admin ceilings decide which actions exist in the public directory.
  // Company and number settings only decide whether an existing action is
  // currently usable. The fallback keeps older bootstrap payloads working.
  const hasCall = company.callsAllowed ?? company.callsEnabled
  const hasMessage = company.messagesAllowed ?? company.messagesEnabled
  const hasRequest = company.requestsAllowed ?? company.requestsEnabled
  const canCall = company.available && company.callsEnabled && numbers.some((n) => n.callsEnabled)
  const canMessage = hasMessage && numbers.some((n) => n.messagesEnabled)
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
            title={t(company.available ? 'Available' : 'Unavailable')}
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
              ? `${t('Unavailable')}${mainNumber?.number ? ` · ${mainNumber.number}` : categoryName ? ` · ${t(categoryName)}` : ''}`
              : `${categoryName ? t(categoryName) : t('Company')}${mainNumber?.number ? ` · ${mainNumber.number}` : ''}`}
          </div>
        </div>
      </div>

      <div className="company-actions-row">
        {hasCall && (
          <button className="company-action call" onClick={onCall} disabled={!canCall}>
            <Icon name="phone" size={15} className="company-action-icon" />
            {t('Call')}
          </button>
        )}
        {hasRequest && (
          <button className="company-action request" onClick={onRequest} disabled={!canRequest}>
            <Icon name="clipboard" size={15} className="company-action-icon" />
            {t('Request')}
          </button>
        )}
        {hasMessage && (
          <button className="company-action message" onClick={onMessage} disabled={!canMessage}>
            <Icon name="message" size={15} className="company-action-icon" />
            {t('Message')}
          </button>
        )}
      </div>
    </div>
  )
}
