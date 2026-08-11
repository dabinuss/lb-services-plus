import { useState } from 'react'

import DashboardHome from './DashboardHome.jsx'
import RequestsTab from './RequestsTab.jsx'
import MessagesTab from './MessagesTab.jsx'
import CallsTab from './CallsTab.jsx'
import SettingsTab from './SettingsTab.jsx'

// "Team" used to be its own tab here, but a 6-way segmented control no
// longer fits the phone screen width and got clipped - it now lives under
// Home, right below Hotlines (plan review UX follow-up).
const TABS = [
  { key: 'home', label: 'Home' },
  { key: 'requests', label: 'Requests' },
  { key: 'messages', label: 'Messages' },
  { key: 'calls', label: 'Calls' },
  { key: 'settings', label: 'Settings', bossOnly: true },
]

// Everything past the fake-login (plan §19, §35-38, §20-24, §33-34).
export default function CompanyDashboard({ session, employee, company, onLogout, onOpenConversation }) {
  const [tab, setTab] = useState('home')
  const tabs = TABS.filter((t) => !t.bossOnly || session.employee.isBoss)

  // `company` (from the public companies list, incl. background) can be
  // missing if it's currently hidden from that list (e.g. unavailable and
  // UnavailableCompanyMode is "hide") - session.company still has the
  // basics from the login RPC, just never a background photo.
  const icon = company?.icon || session.company.icon
  const background = company?.background

  return (
    <div className="screen company-screen">
      <div className={`dashboard-header${background ? ' has-bg' : ''}`}>
        {background && <div className="dashboard-header-bg" style={{ backgroundImage: `url(${background})` }} />}
        {background && <div className="dashboard-header-scrim" />}

        <div className="dashboard-header-info">
          <div className="dashboard-logo">{icon ? <img src={icon} alt="" /> : <span>{session.company.name[0]}</span>}</div>
          <div className="dashboard-company">{session.company.name}</div>
        </div>

        <button className="icon-button logout" onClick={onLogout} aria-label="Logout">
          ⇥
        </button>
      </div>

      <div className="category-row subtab-row">
        {tabs.map((t) => (
          <button
            key={t.key}
            className={`category-chip${tab === t.key ? ' active' : ''}`}
            onClick={() => setTab(t.key)}
          >
            {t.label}
          </button>
        ))}
      </div>

      <div className="dashboard-body">
        {tab === 'home' && (
          <DashboardHome
            companyId={employee.companyId}
            initialOnDuty={employee.onDuty}
            initialStatus={employee.status}
            employeeName={session.employee.name}
            employeeGrade={session.employee.gradeLabel}
            onLogout={onLogout}
          />
        )}
        {tab === 'requests' && <RequestsTab />}
        {tab === 'messages' && <MessagesTab onOpenConversation={onOpenConversation} />}
        {tab === 'calls' && <CallsTab />}
        {tab === 'settings' && session.employee.isBoss && <SettingsTab />}
      </div>
    </div>
  )
}
