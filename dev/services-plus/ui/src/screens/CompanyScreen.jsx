import { useState } from 'react'
import { fetchNui } from '../lib/nui.js'
import CompanyDashboard from './company/CompanyDashboard.jsx'

// Company area (plan §17-19): fake-login is purely cosmetic, the server
// re-checks employment regardless. Everything past login is phase 2 -
// CompanyDashboard and its tabs. `session` is owned by App.jsx, not here -
// it needs to survive this component unmounting when the user switches to
// another bottom-nav tab and back (stays logged in until logout, going
// off-duty, or a real reload/phone switch - never just from leaving this tab).
export default function CompanyScreen({ employee, companies, session, onLogin, onLogout, onOpenConversation, teamUpdate }) {
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
          <div className="login-title">Sign in to {company?.name || employee.jobLabel}</div>
          <button className="login-button" onClick={login} disabled={loggingIn}>
            {loggingIn ? 'Signing in…' : 'Login'}
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
    />
  )
}
