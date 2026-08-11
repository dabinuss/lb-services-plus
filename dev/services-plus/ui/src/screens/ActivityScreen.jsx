import { useState } from 'react'
import MessagesTab from './activity/MessagesTab.jsx'
import RequestsTab from './activity/RequestsTab.jsx'
import CallsTab from './activity/CallsTab.jsx'

const TABS = [
  { key: 'messages', label: 'Messages' },
  { key: 'requests', label: 'Requests' },
  { key: 'calls', label: 'Calls' },
]

// Personal history (plan §39-41), split into its three kinds instead of one
// merged feed - deliberately still compact, not a CRM-style history.
export default function ActivityScreen({ onOpen }) {
  const [tab, setTab] = useState('messages')

  return (
    <div className="screen activity-screen">
      <div className="screen-header">Activity</div>

      <div className="category-row subtab-row">
        {TABS.map((t) => (
          <button key={t.key} className={`category-chip${tab === t.key ? ' active' : ''}`} onClick={() => setTab(t.key)}>
            {t.label}
          </button>
        ))}
      </div>

      <div className="dashboard-body">
        {tab === 'messages' && <MessagesTab onOpen={onOpen} />}
        {tab === 'requests' && <RequestsTab />}
        {tab === 'calls' && <CallsTab />}
      </div>
    </div>
  )
}
