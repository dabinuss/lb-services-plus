import { useState } from 'react'
import MessagesTab from './activity/MessagesTab.jsx'
import RequestsTab from './activity/RequestsTab.jsx'
import CallsTab from './activity/CallsTab.jsx'
import { useI18n } from '../lib/i18n.jsx'
import Badge from '../components/Badge.jsx'

const TABS = [
  { key: 'messages', label: 'Messages' },
  { key: 'requests', label: 'Requests' },
  { key: 'calls', label: 'Calls' },
]

// Personal history (plan §39-41), split into its three kinds instead of one
// merged feed - deliberately still compact, not a CRM-style history.
export default function ActivityScreen({ onOpen, messageBadge = 0, messageRefreshToken, requestUpdate, onReadConversation }) {
  const { t } = useI18n()
  const [tab, setTab] = useState('messages')
  const [visitedTabs, setVisitedTabs] = useState(() => new Set(['messages']))

  const openTab = (next) => {
    setVisitedTabs((current) => current.has(next) ? current : new Set([...current, next]))
    setTab(next)
  }

  return (
    <div className="screen activity-screen">
      <div className="screen-header">{t('Activity')}</div>

      <div className="category-row subtab-row">
        {TABS.map((item) => (
          <button key={item.key} className={`category-chip${tab === item.key ? ' active' : ''}`} onClick={() => openTab(item.key)}>
            {t(item.label)}
            {item.key === 'messages' && <Badge count={messageBadge} className="tab-badge" />}
          </button>
        ))}
      </div>

      <div className="dashboard-body">
        {visitedTabs.has('messages') && <div className={`subtab-view${tab === 'messages' ? ' active' : ''}`}><MessagesTab refreshToken={messageRefreshToken} onOpen={onOpen} onReadConversation={onReadConversation} /></div>}
        {visitedTabs.has('requests') && <div className={`subtab-view${tab === 'requests' ? ' active' : ''}`}><RequestsTab update={requestUpdate} /></div>}
        {visitedTabs.has('calls') && <div className={`subtab-view${tab === 'calls' ? ' active' : ''}`}><CallsTab /></div>}
      </div>
    </div>
  )
}
