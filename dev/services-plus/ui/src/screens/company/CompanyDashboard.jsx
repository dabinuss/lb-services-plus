import { useEffect, useState } from 'react'

import DashboardHome from './DashboardHome.jsx'
import RequestsTab from './RequestsTab.jsx'
import MessagesTab from './MessagesTab.jsx'
import CallsTab from './CallsTab.jsx'
import SettingsTab from './SettingsTab.jsx'
import Icon from '../../components/Icon.jsx'
import { useI18n } from '../../lib/i18n.jsx'
import Badge from '../../components/Badge.jsx'

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
export default function CompanyDashboard({
  session, employee, company, onLogout, onOpenConversation, teamUpdate,
  messageBadge = 0, requestBadge = 0, messageRefreshToken, requestRefresh, onReadConversation, onReadRequests,
}) {
  const { t } = useI18n()
  const [tab, setTab] = useState('home')
  const tabs = TABS.filter((t) => !t.bossOnly || session.employee.isBoss)

  useEffect(() => {
    if (tab === 'requests') onReadRequests?.()
  }, [tab, onReadRequests])

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

        <button className="icon-button logout" onClick={onLogout} aria-label={t('Logout')}>
          <Icon name="logout" size={16} />
        </button>
      </div>

      <div className="category-row subtab-row">
        {tabs.map((item) => (
          <button
            key={item.key}
            className={`category-chip${tab === item.key ? ' active' : ''}`}
            onClick={() => setTab(item.key)}
          >
            {t(item.label)}
            {item.key === 'messages' && <Badge count={messageBadge} className="tab-badge" />}
            {item.key === 'requests' && <Badge count={requestBadge} className="tab-badge" />}
          </button>
        ))}
      </div>

      <div className="dashboard-body">
        {tab === 'home' && (
          <DashboardHome
            companyId={employee.companyId}
            initialOnDuty={employee.onDuty}
            initialStatus={employee.status}
            employeeMemberId={employee.memberId}
            employeeName={session.employee.name}
            employeeRankTitle={session.employee.gradeLabel || employee.jobLabel || session.company.name}
            onLogout={onLogout}
            teamUpdate={teamUpdate}
          />
        )}
        {tab === 'requests' && <RequestsTab refresh={requestRefresh} />}
        {tab === 'messages' && <MessagesTab refreshToken={messageRefreshToken} onOpenConversation={onOpenConversation} onReadConversation={onReadConversation} />}
        {tab === 'calls' && <CallsTab />}
        {tab === 'settings' && session.employee.isBoss && <SettingsTab />}
      </div>
    </div>
  )
}
