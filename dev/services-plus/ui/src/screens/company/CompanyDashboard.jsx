import { useState } from 'react'

import DashboardHome from './DashboardHome.jsx'
import RequestsTab from './RequestsTab.jsx'
import TeamTab from './TeamTab.jsx'
import MessagesTab from './MessagesTab.jsx'
import CallsTab from './CallsTab.jsx'
import SettingsTab from './SettingsTab.jsx'

const TABS = [
  { key: 'home', label: 'Home' },
  { key: 'requests', label: 'Requests' },
  { key: 'team', label: 'Team' },
  { key: 'messages', label: 'Messages' },
  { key: 'calls', label: 'Calls' },
  { key: 'settings', label: 'Settings', bossOnly: true },
]

// Everything past the fake-login (plan §19, §35-38, §20-24, §33-34).
export default function CompanyDashboard({ session, employee, onOpenConversation }) {
  const [tab, setTab] = useState('home')
  const tabs = TABS.filter((t) => !t.bossOnly || session.employee.isBoss)

  return (
    <div className="screen company-screen">
      <div className="dashboard-header">
        <div className="dashboard-company">{session.company.name}</div>
        <div className="dashboard-employee">{session.employee.name}</div>
        <div className="dashboard-grade">{session.employee.gradeLabel}</div>
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
        {tab === 'home' && <DashboardHome companyId={employee.companyId} initialOnDuty={employee.onDuty} initialStatus={employee.status} />}
        {tab === 'requests' && <RequestsTab />}
        {tab === 'team' && <TeamTab />}
        {tab === 'messages' && <MessagesTab onOpenConversation={onOpenConversation} />}
        {tab === 'calls' && <CallsTab />}
        {tab === 'settings' && session.employee.isBoss && <SettingsTab />}
      </div>
    </div>
  )
}
