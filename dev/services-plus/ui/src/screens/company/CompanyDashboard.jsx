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
  messageBadge = 0, requestBadge = 0, callBadge = 0,
  messageRefreshToken, requestRefresh, callRefreshToken,
  onReadConversation, onReadRequests, onReadCalls,
}) {
  const { t } = useI18n()
  const [tab, setTab] = useState('home')
  const [visitedTabs, setVisitedTabs] = useState(() => new Set(['home']))
  const tabs = TABS.filter((t) => !t.bossOnly || session.employee.isBoss)

  const openTab = (next) => {
    setVisitedTabs((current) => current.has(next) ? current : new Set([...current, next]))
    setTab(next)
  }

  useEffect(() => {
    if (tab === 'requests') onReadRequests?.()
  }, [tab, requestRefresh, onReadRequests])

  useEffect(() => {
    if (tab === 'calls') onReadCalls?.()
  }, [tab, callRefreshToken, onReadCalls])

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
            onClick={() => openTab(item.key)}
          >
            {t(item.label)}
            {item.key === 'messages' && <Badge count={messageBadge} className="tab-badge" />}
            {item.key === 'requests' && <Badge count={requestBadge} className="tab-badge" />}
            {item.key === 'calls' && <Badge count={callBadge} className="tab-badge" />}
          </button>
        ))}
      </div>

      <div className="dashboard-body">
        {visitedTabs.has('home') && (
          <div className={`subtab-view${tab === 'home' ? ' active' : ''}`}><DashboardHome
            active={tab === 'home'}
            companyId={employee.companyId}
            initialOnDuty={employee.onDuty}
            initialStatus={employee.status}
            employeeMemberId={employee.memberId}
            employeeName={session.employee.name}
            employeeRankTitle={session.employee.gradeLabel || employee.jobLabel || session.company.name}
            onLogout={onLogout}
            teamUpdate={teamUpdate}
          /></div>
        )}
        {visitedTabs.has('requests') && <div className={`subtab-view${tab === 'requests' ? ' active' : ''}`}><RequestsTab refresh={requestRefresh} /></div>}
        {visitedTabs.has('messages') && <div className={`subtab-view${tab === 'messages' ? ' active' : ''}`}><MessagesTab refreshToken={messageRefreshToken} onOpenConversation={onOpenConversation} onReadConversation={onReadConversation} /></div>}
        {visitedTabs.has('calls') && <div className={`subtab-view${tab === 'calls' ? ' active' : ''}`}><CallsTab refreshToken={callRefreshToken} /></div>}
        {visitedTabs.has('settings') && session.employee.isBoss && <div className={`subtab-view${tab === 'settings' ? ' active' : ''}`}><SettingsTab /></div>}
      </div>
    </div>
  )
}
