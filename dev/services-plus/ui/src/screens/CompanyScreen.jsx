import { useState } from 'react'
import { fetchNui } from '../lib/nui.js'
import CompanyDashboard from './company/CompanyDashboard.jsx'
import { useI18n } from '../lib/i18n.jsx'

// Company area (plan §17-19): fake-login is purely cosmetic, the server
// re-checks employment regardless. Everything past login is phase 2 -
// CompanyDashboard and its tabs. `session` is owned by App.jsx, not here -
// it needs to survive this component unmounting when the user switches to
// another bottom-nav tab and back (stays logged in until logout, going
// off-duty, or a real reload/phone switch - never just from leaving this tab).
export default function CompanyScreen({
  employee, companies, session, onLogin, onLogout, onOpenConversation, teamUpdate,
  messageBadge, requestBadge, messageRevision, requestRevision, onReadMessages, onReadRequests,
}) {
  const { t } = useI18n()
  const [loggingIn, setLoggingIn] = useState(false)

  const company = companies.find((c) => c.id === employee.companyId)

  const login = async () => {
    setLoggingIn(true)
    await new Promise((r) => setTimeout(r, 900))
    const result = await fetchNui('companyLogin', { companyId: employee.companyId })
    setLoggingIn(false)
    if (result) onLogin(result)
  }

  if (!session) {
    return (
      <div className="screen company-screen login-screen">
        <div className="login-card">
          {company?.icon && <img className="login-icon" src={company.icon} alt="" />}
          <div className="login-title">{t('Sign in to {company}', { company: company?.name || employee.jobLabel })}</div>
          <button className="login-button" onClick={login} disabled={loggingIn}>
            {t(loggingIn ? 'Signing in…' : 'Login')}
          </button>
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
      onReadMessages={onReadMessages}
      onReadRequests={onReadRequests}
    />
  )
}
