import { useEffect, useState } from 'react'
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
export default function ActivityScreen({ onOpen, messageBadge = 0, messageRevision, onReadMessages }) {
  const { t } = useI18n()
  const [tab, setTab] = useState('messages')

  const selectTab = (key) => {
    setTab(key)
    if (key === 'messages') onReadMessages?.()
  }

  // Messages is the initial tab, so entering Activity counts as viewing it.
  useEffect(() => {
    if (tab === 'messages') onReadMessages?.()
  }, [tab, onReadMessages])

  return (
    <div className="screen activity-screen">
      <div className="screen-header">{t('Activity')}</div>

      <div className="category-row subtab-row">
        {TABS.map((item) => (
          <button key={item.key} className={`category-chip${tab === item.key ? ' active' : ''}`} onClick={() => selectTab(item.key)}>
            {t(item.label)}
            {item.key === 'messages' && <Badge count={messageBadge} className="tab-badge" />}
          </button>
        ))}
      </div>

      <div className="dashboard-body">
        {tab === 'messages' && <MessagesTab key={`messages-${messageRevision || 0}`} onOpen={onOpen} />}
        {tab === 'requests' && <RequestsTab />}
        {tab === 'calls' && <CallsTab />}
      </div>
    </div>
  )
}
