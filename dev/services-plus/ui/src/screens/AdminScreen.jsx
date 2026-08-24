import { useState } from 'react'
import CompaniesTab from './admin/CompaniesTab.jsx'
import CategoriesTab from './admin/CategoriesTab.jsx'
import RequestTypesTab from './admin/RequestTypesTab.jsx'
import ServiceSettingsTab from './admin/ServiceSettingsTab.jsx'
import { useI18n } from '../lib/i18n.jsx'

const TABS = [
  { key: 'companies', label: 'Companies' },
  { key: 'categories', label: 'Categories' },
  { key: 'requestTypes', label: 'Request Types' },
  { key: 'settings', label: 'Settings' },
]

// Services+ admin area (plan §50-58) - independent of company boss rights.
export default function AdminScreen() {
  const { t } = useI18n()
  const [tab, setTab] = useState('companies')
  const [visitedTabs, setVisitedTabs] = useState(() => new Set(['companies']))

  const openTab = (next) => {
    setVisitedTabs((current) => current.has(next) ? current : new Set([...current, next]))
    setTab(next)
  }

  return (
    <div className="screen admin-screen">
      <div className="screen-header">{t('Admin')}</div>

      <div className="category-row subtab-row admin-tabs">
        {TABS.map((item) => (
          <button key={item.key} className={`category-chip${tab === item.key ? ' active' : ''}`} onClick={() => openTab(item.key)}>
            {t(item.label)}
          </button>
        ))}
      </div>

      <div className="dashboard-body">
        {visitedTabs.has('companies') && <div className={`subtab-view${tab === 'companies' ? ' active' : ''}`}><CompaniesTab /></div>}
        {visitedTabs.has('categories') && <div className={`subtab-view${tab === 'categories' ? ' active' : ''}`}><CategoriesTab /></div>}
        {visitedTabs.has('requestTypes') && <div className={`subtab-view${tab === 'requestTypes' ? ' active' : ''}`}><RequestTypesTab /></div>}
        {visitedTabs.has('settings') && <div className={`subtab-view${tab === 'settings' ? ' active' : ''}`}><ServiceSettingsTab /></div>}
      </div>
    </div>
  )
}
