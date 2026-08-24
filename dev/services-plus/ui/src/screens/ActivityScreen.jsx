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

  return (
    <div className="screen activity-screen">
      <div className="screen-header">{t('Activity')}</div>

      <div className="category-row subtab-row">
        {TABS.map((item) => (
          <button key={item.key} className={`category-chip${tab === item.key ? ' active' : ''}`} onClick={() => setTab(item.key)}>
            {t(item.label)}
            {item.key === 'messages' && <Badge count={messageBadge} className="tab-badge" />}
          </button>
        ))}
      </div>

      <div className="dashboard-body">
        {tab === 'messages' && <MessagesTab refreshToken={messageRefreshToken} onOpen={onOpen} onReadConversation={onReadConversation} />}
        {tab === 'requests' && <RequestsTab update={requestUpdate} />}
        {tab === 'calls' && <CallsTab />}
      </div>
    </div>
  )
}
