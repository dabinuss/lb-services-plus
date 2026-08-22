import { useState } from 'react'
import { fetchNui } from '../lib/nui.js'
import CompanyDashboard from './company/CompanyDashboard.jsx'
import { useI18n } from '../lib/i18n.jsx'
import Icon from '../components/Icon.jsx'

// Company area (plan §17-19): fake-login is purely cosmetic, the server
// re-checks employment regardless. Everything past login is phase 2 -
// CompanyDashboard and its tabs. `session` is owned by App.jsx, not here -
// it needs to survive this component unmounting when the user switches to
// another bottom-nav tab and back (stays logged in until logout, going
// off-duty, or a real reload/phone switch - never just from leaving this tab).
export default function CompanyScreen({
  employee, companies, session, onLogin, onLogout, onOpenConversation, teamUpdate,
  messageBadge, requestBadge, messageRevision, requestRevision, onReadConversation, onReadRequests,
}) {
  const { t } = useI18n()
  const [loggingIn, setLoggingIn] = useState(false)

  const company = companies.find((c) => c.id === employee.companyId)

  const login = async () => {
    setLoggingIn(true)
    await new Promise((r) => setTimeout(r, 900))
    let result = false
    try {
      result = await fetchNui('companyLogin', { companyId: employee.companyId })
    } catch {
      result = false
    } finally {
      setLoggingIn(false)
    }
    if (result) onLogin(result)
  }

  if (!session) {
    const employeeName = employee.playerName || employee.jobLabel
    const initial = employeeName?.trim()?.[0]?.toUpperCase() || '?'

    return (
      <div className="screen company-screen login-screen">
        <div className={`login-card${loggingIn ? ' is-verifying' : ''}`}>
          <div className="login-brand">
            {company?.icon ? <img className="login-icon" src={company.icon} alt="" /> : <div className="login-icon login-icon-fallback">{company?.name?.[0] || '?'}</div>}
            <div className="login-brand-mark"><Icon name="shield" size={13} /></div>
          </div>

          <div className="login-eyebrow">{t('Employee portal')}</div>
          <div className="login-title">{t('Sign in to {company}', { company: company?.name || employee.jobLabel })}</div>

          <div className="login-identity">
            <div className="login-avatar">{initial}</div>
            <div className="login-identity-copy">
              <span>{employeeName}</span>
              <small>{employee.gradeLabel || employee.jobLabel}</small>
            </div>
            <Icon name="shield" size={16} className="login-verified" />
          </div>

          <div className="login-security">
            <Icon name="shield" size={14} />
            <span>{t('Secure online session')}</span>
          </div>

          <button className="login-button login-submit" onClick={login} disabled={loggingIn} aria-busy={loggingIn}>
            {t(loggingIn ? 'Verifying session…' : 'Login')}
          </button>
          <div className="login-progress" aria-hidden="true"><span /></div>
          <div className="login-session-hint">{t('Session stays active on this phone')}</div>
        </div>
      </div>
    )
  }

  return (
    <CompanyDashboard
      session={session}
      employee={employee}
      company={company}
      onLogout={onLogout}
      onOpenConversation={onOpenConversation}
      teamUpdate={teamUpdate}
      messageBadge={messageBadge}
      requestBadge={requestBadge}
      messageRevision={messageRevision}
      requestRevision={requestRevision}
      onReadConversation={onReadConversation}
      onReadRequests={onReadRequests}
    />
  )
}
