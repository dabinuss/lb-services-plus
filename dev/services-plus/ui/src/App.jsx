import { useCallback, useEffect, useState } from 'react'

import Frame from './components/Frame.jsx'
import Sheet from './components/Sheet.jsx'
import RequestSheet from './components/RequestSheet.jsx'
import Icon from './components/Icon.jsx'
import Toast from './components/Toast.jsx'
import Badge from './components/Badge.jsx'
import ServicesScreen from './screens/ServicesScreen.jsx'
import ActivityScreen from './screens/ActivityScreen.jsx'
import CompanyScreen from './screens/CompanyScreen.jsx'
import AdminScreen from './screens/AdminScreen.jsx'
import ConversationScreen from './screens/ConversationScreen.jsx'
import { fetchNui, getSettings, onSettingsChange, onNuiEvent, createCall, devMode } from './lib/nui.js'
import { useI18n } from './lib/i18n.jsx'
import { showToast } from './lib/toast.js'

import './App.css'

const TABS = [
  { key: 'services', label: 'Services', icon: 'building' },
  { key: 'activity', label: 'Activity', icon: 'clock' },
  { key: 'company', label: 'Company', icon: 'briefcase', requires: 'employee' },
  { key: 'admin', label: 'Admin', icon: 'settings', requires: 'admin' },
]

function applyCompanyDirectoryChange(current, data) {
  if (!current) return current

  let companies = current.companies
  if (Array.isArray(data.companies)) {
    companies = data.companies
  } else if (Number.isFinite(Number(data.companyId))) {
    const companyId = Number(data.companyId)
    companies = current.companies.filter((company) => Number(company.id) !== companyId)
    if (data.company) companies = [...companies, data.company].sort((a, b) => a.name.localeCompare(b.name))
  }

  return {
    ...current,
    companies,
    categories: Array.isArray(data.categories) ? data.categories : current.categories,
  }
}

export default function App() {
  const { t, setLanguage } = useI18n()
  const [theme, setTheme] = useState('light')
  const [tab, setTab] = useState('services')
  const [visitedTabs, setVisitedTabs] = useState(() => new Set(['services']))
  const [bootstrap, setBootstrap] = useState(null)
  // Lifted out of CompanyScreen so switching away to another tab and back
  // doesn't unmount-and-lose it - the fake-login should only ever end via
  // an explicit logout, going off-duty, or a real reload (switching to a
  // different phone number), never just from leaving the Company tab.
  const [companySession, setCompanySession] = useState(null)
  const [conversation, setConversation] = useState(null)
  const [numberPicker, setNumberPicker] = useState(null) // { mode: 'call'|'message', company, numbers }
  const [requestSheet, setRequestSheet] = useState(null) // { company }
  const [incomingMessage, setIncomingMessage] = useState(null)
  const [requestUpdate, setRequestUpdate] = useState(null)
  const [requestRefresh, setRequestRefresh] = useState(null)
  const [callRefresh, setCallRefresh] = useState({ activity: 0, company: 0 })
  const [teamUpdate, setTeamUpdate] = useState(null)
  const [unread, setUnread] = useState({
    activityMessages: 0, activityRequests: 0, activityCalls: 0,
    companyMessages: 0, companyRequests: 0, companyCalls: 0,
  })

  useEffect(() => {
    if (devMode) {
      const media = window.matchMedia('(prefers-color-scheme: dark)')
      const apply = () => setTheme(media.matches ? 'dark' : 'light')
      apply()
      media.addEventListener('change', apply)
      return () => media.removeEventListener('change', apply)
    }

    getSettings().then((settings) => settings && setTheme(settings.display.theme))
    return onSettingsChange((settings) => setTheme(settings.display.theme))
  }, [])

  useEffect(() => {
    document.body.setAttribute('data-theme', theme)
  }, [theme])

  useEffect(() => {
    fetchNui('bootstrap').then((result) => {
      if (!result) return
      setBootstrap(result)
      setCompanySession(result.companySession || null)
      if (result.locale) setLanguage(result.locale)
      if (result.unread) setUnread(result.unread)
    })
    // Bootstrap is an app-open snapshot. Language changes are persisted by
    // LanguageProvider itself and must not trigger a second bootstrap.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const markRead = useCallback((scope, key) => {
    setUnread((current) => current[key] ? { ...current, [key]: 0 } : current)
    fetchNui('markRead', { scope }).catch(() => {})
  }, [])
  const readCompanyRequests = useCallback(() => markRead('company_requests', 'companyRequests'), [markRead])
  const readActivityRequests = useCallback(() => markRead('activity_requests', 'activityRequests'), [markRead])
  const readActivityCalls = useCallback(() => markRead('activity_calls', 'activityCalls'), [markRead])
  const readCompanyCalls = useCallback(() => markRead('company_calls', 'companyCalls'), [markRead])

  const readConversation = useCallback((channelId, count, key) => {
    const unreadCount = Number(count) || 0
    if (unreadCount > 0) {
      setUnread((current) => ({ ...current, [key]: Math.max(0, current[key] - unreadCount) }))
    }
    fetchNui('markConversationRead', { channelId }).catch(() => {})
  }, [])

  const logoutCompany = useCallback(() => {
    setCompanySession(null)
    setUnread((current) => ({
      ...current,
      companyMessages: 0,
      companyRequests: 0,
      companyCalls: 0,
    }))
    fetchNui('companyLogout').catch(() => {})
  }, [])

  const loginCompany = useCallback((session) => {
    setCompanySession(session)
    if (!session) return
    if ('directoryCompany' in session) {
      setBootstrap((current) => applyCompanyDirectoryChange(current, {
        companyId: session.company.id,
        company: session.directoryCompany,
      }))
    }
    fetchNui('getUnreadCounts').then((counts) => {
      if (counts) setUnread((current) => ({ ...current, ...counts }))
    }).catch(() => {})
  }, [])

  // Realtime delta for an already-open conversation (plan review §15) -
  // the actual merge-into-open-conversation happens in ConversationScreen,
  // this just routes the push to whichever one (if any) is currently open.
  useEffect(() => {
    return onNuiEvent('newMessage', (data) => {
      setIncomingMessage(data)
      if (conversation?.channelId === data.channelId) return

      const key = data.message?.sender_type === 'company' ? 'activityMessages' : 'companyMessages'
      setUnread((current) => ({ ...current, [key]: current[key] + 1 }))
    })
  }, [conversation?.channelId])

  useEffect(() => {
    return onNuiEvent('newRequest', (data) => {
      setRequestRefresh((current) => ({
        sequence: (current?.sequence || 0) + 1,
        requestId: data.request?.id || data.request?.requestId || null,
        status: data.request?.status || 'open',
      }))
      setUnread((current) => ({ ...current, companyRequests: current.companyRequests + 1 }))
    })
  }, [])

  useEffect(() => {
    return onNuiEvent('requestQueueChanged', (data) => {
      const delta = Number(data.unreadDelta) || 0
      if (delta) setUnread((current) => ({ ...current, companyRequests: Math.max(0, current.companyRequests + delta) }))
      setRequestRefresh((current) => ({
        sequence: (current?.sequence || 0) + 1,
        requestId: data.requestId || null,
        status: data.status || null,
      }))
    })
  }, [])

  useEffect(() => {
    return onNuiEvent('requestUpdated', (data) => {
      setRequestUpdate(data.request)
      const delta = Number(data.unreadDelta) || 0
      if (delta) setUnread((current) => ({ ...current, activityRequests: current.activityRequests + delta }))
    })
  }, [])

  useEffect(() => {
    return onNuiEvent('callChanged', (data) => {
      const mapping = {
        activity_calls: { unreadKey: 'activityCalls', refreshKey: 'activity' },
        company_calls: { unreadKey: 'companyCalls', refreshKey: 'company' },
      }
      const target = mapping[data.scope]
      if (!target) return
      const delta = Number(data.unreadDelta) || 0
      if (delta) setUnread((current) => ({ ...current, [target.unreadKey]: Math.max(0, current[target.unreadKey] + delta) }))
      setCallRefresh((current) => ({ ...current, [target.refreshKey]: current[target.refreshKey] + 1 }))
    })
  }, [])

  // Same idea, for a colleague's status/hotline change (plan review round 5
  // §8) - keeps the Team view current without polling.
  useEffect(() => {
    return onNuiEvent('employeeStateChanged', (data) => setTeamUpdate(data))
  }, [])

  useEffect(() => {
    return onNuiEvent('companiesChanged', (data) => {
      setBootstrap((current) => applyCompanyDirectoryChange(current, data))
    })
  }, [])

  // External framework duty/job changes bypass the app's toggle callback.
  // Keep the employee bootstrap/session current from the server push; the
  // client-side Lua handler separately applies the same snapshot to native
  // LB-Phone company calls.
  useEffect(() => {
    return onNuiEvent('employeeDutyChanged', (data) => {
      const employee = data.employee || null
      setBootstrap((prev) => (prev ? { ...prev, employee } : prev))
      if (data.jobChanged || !employee?.onDuty) {
        setCompanySession(null)
        setUnread((current) => ({
          ...current,
          companyMessages: 0,
          companyRequests: 0,
          companyCalls: 0,
        }))
      }
    })
  }, [])

  const visibleTabs = TABS.filter((t) => !t.requires || bootstrap?.[t.requires])

  const openTab = (next) => {
    setVisitedTabs((current) => current.has(next) ? current : new Set([...current, next]))
    setTab(next)
  }

  useEffect(() => {
    if (bootstrap && !visibleTabs.some((t) => t.key === tab)) openTab('services')
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bootstrap])

  const openMessage = (company) => {
    const numbers = company.numbers.filter((n) => n.messagesEnabled)
    if (numbers.length === 0) {
      showToast(t('Messages are disabled for this phone number.'), 'error')
      return
    }
    if (numbers.length <= 1) {
      openConversationFor(company, numbers[0])
    } else {
      setNumberPicker({ mode: 'message', company, numbers })
    }
  }

  const openConversationFor = (company, number) => {
    setConversation({ numberId: number.id, title: `${company.name} (${number.label})`, icon: company.icon })
    setNumberPicker(null)
  }

  const callCompany = (company) => {
    const numbers = company.numbers.filter((n) => n.callsEnabled)
    if (numbers.length <= 1) {
      placeCall(company, numbers[0])
    } else {
      setNumberPicker({ mode: 'call', company, numbers })
    }
  }

  // Resolves who should actually receive the call server-side (plan §25-29)
  // then places a fully native lb-phone call - see server/calls.lua for why.
  const placeCall = async (company, number) => {
    setNumberPicker(null)
    if (!number) return

    try {
      const target = await fetchNui('resolveCall', { companyId: company.id, numberId: number.id })
      if (!target) {
        showToast(t('This company is currently unavailable by phone.'), 'error')
        return
      }
      createCall(target.company ? { company: target.company } : { number: target.number })
    } catch {
      showToast(t('This company is currently unavailable by phone.'), 'error')
    }
  }

  const content = !bootstrap ? (
    <div className="empty-state">{t('Loading Services+…')}</div>
  ) : (
    <>
      {visitedTabs.has('services') && (
        <div className={`main-tab-view${tab === 'services' ? ' active' : ''}`}>
          <ServicesScreen
            companies={bootstrap.companies}
            categories={bootstrap.categories}
            onCall={callCompany}
            onMessage={openMessage}
            onRequest={(company) => setRequestSheet({ company })}
          />
        </div>
      )}
      {visitedTabs.has('activity') && (
        <div className={`main-tab-view${tab === 'activity' ? ' active' : ''}`}>
          <ActivityScreen
            onOpen={setConversation}
            messageBadge={unread.activityMessages}
            requestBadge={unread.activityRequests}
            callBadge={unread.activityCalls}
            messageRefreshToken={incomingMessage?.message?.id}
            requestUpdate={requestUpdate}
            callRefreshToken={callRefresh.activity}
            onReadConversation={(channelId, count) => readConversation(channelId, count, 'activityMessages')}
            onReadRequests={readActivityRequests}
            onReadCalls={readActivityCalls}
          />
        </div>
      )}
      {visitedTabs.has('company') && bootstrap.employee && (
        <div className={`main-tab-view${tab === 'company' ? ' active' : ''}`}>
          <CompanyScreen
            employee={bootstrap.employee}
            companies={bootstrap.companies}
            session={companySession}
            onLogin={loginCompany}
            onLogout={logoutCompany}
            onOpenConversation={setConversation}
            teamUpdate={teamUpdate}
            messageBadge={unread.companyMessages}
            requestBadge={unread.companyRequests}
            callBadge={unread.companyCalls}
            messageRefreshToken={incomingMessage?.message?.id}
            requestRefresh={requestRefresh}
            callRefreshToken={callRefresh.company}
            onReadConversation={(channelId, count) => readConversation(channelId, count, 'companyMessages')}
            onReadRequests={readCompanyRequests}
            onReadCalls={readCompanyCalls}
          />
        </div>
      )}
      {visitedTabs.has('admin') && bootstrap.admin && (
        <div className={`main-tab-view${tab === 'admin' ? ' active' : ''}`}><AdminScreen /></div>
      )}
    </>
  )

  const app = (
    <div className="app" data-theme={theme}>
      <div className="app-body">{content}</div>

      {bootstrap && (
        <div className="nav-bar">
          {visibleTabs.map((item) => (
            <button key={item.key} className={`nav-item${tab === item.key ? ' active' : ''}`} onClick={() => openTab(item.key)}>
              <Icon name={item.icon} size={22} className="nav-icon" />
              <span className="nav-label">{t(item.label)}</span>
              {item.key === 'activity' && <Badge count={unread.activityMessages + unread.activityRequests + unread.activityCalls} className="nav-badge" />}
              {item.key === 'company' && <Badge count={unread.companyMessages + unread.companyRequests + unread.companyCalls} className="nav-badge" />}
            </button>
          ))}
        </div>
      )}

      {conversation && (
        <ConversationScreen
          target={conversation}
          incoming={incomingMessage}
          onClose={() => setConversation(null)}
        />
      )}

      {numberPicker && (
        <Sheet title={t(numberPicker.mode === 'call' ? 'Call' : 'Message')} onClose={() => setNumberPicker(null)}>
          {numberPicker.numbers.map((n) => (
            <button
              key={n.id}
              className="sheet-option"
              onClick={() =>
                numberPicker.mode === 'call' ? placeCall(numberPicker.company, n) : openConversationFor(numberPicker.company, n)
              }
            >
              <span>{n.label}</span>
              {n.number && <span className="sheet-option-number">{n.number}</span>}
            </button>
          ))}
        </Sheet>
      )}

      {requestSheet && <RequestSheet company={requestSheet.company} onClose={() => setRequestSheet(null)} />}

      <Toast />
    </div>
  )

  // Dev-only theme toggle, outside the phone frame - lb-phone provides the
  // real theme via getSettings()/onSettingsChange in the actual build, this
  // is purely so both themes are reachable while testing in a plain browser.
  return devMode ? (
    <>
      <button
        className="dev-theme-toggle"
        onClick={() => setTheme((t) => (t === 'dark' ? 'light' : 'dark'))}
        title={t('Toggle light/dark (dev only)')}
      >
        <Icon name={theme === 'dark' ? 'sun' : 'moon'} size={14} />
        {t(theme === 'dark' ? 'Light' : 'Dark')}
      </button>
      <Frame>{app}</Frame>
    </>
  ) : (
    app
  )
}
