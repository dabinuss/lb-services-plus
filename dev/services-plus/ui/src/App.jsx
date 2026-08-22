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

import './App.css'

const TABS = [
  { key: 'services', label: 'Services', icon: 'building' },
  { key: 'activity', label: 'Activity', icon: 'clock' },
  { key: 'company', label: 'Company', icon: 'briefcase', requires: 'employee' },
  { key: 'admin', label: 'Admin', icon: 'settings', requires: 'admin' },
]

export default function App() {
  const { t, setLanguage } = useI18n()
  const [theme, setTheme] = useState('light')
  const [tab, setTab] = useState('services')
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
  const [incomingRequest, setIncomingRequest] = useState(null)
  const [teamUpdate, setTeamUpdate] = useState(null)
  const [unread, setUnread] = useState({ activityMessages: 0, companyMessages: 0, companyRequests: 0 })

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
  const readActivityMessages = useCallback(() => markRead('activity_messages', 'activityMessages'), [markRead])
  const readCompanyMessages = useCallback(() => markRead('company_messages', 'companyMessages'), [markRead])
  const readCompanyRequests = useCallback(() => markRead('company_requests', 'companyRequests'), [markRead])

  const logoutCompany = useCallback(() => {
    setCompanySession(null)
    fetchNui('companyLogout').catch(() => {})
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
      setIncomingRequest(data.request)
      setUnread((current) => ({ ...current, companyRequests: current.companyRequests + 1 }))
    })
  }, [])

  // Same idea, for a colleague's status/hotline change (plan review round 5
  // §8) - keeps the Team view current without polling.
  useEffect(() => {
    return onNuiEvent('employeeStateChanged', (data) => setTeamUpdate(data))
  }, [])

  // External framework duty/job changes bypass the app's toggle callback.
  // Keep the employee bootstrap/session current from the server push; the
  // client-side Lua handler separately applies the same snapshot to native
  // LB-Phone company calls.
  useEffect(() => {
    return onNuiEvent('employeeDutyChanged', (data) => {
      const employee = data.employee || null
      setBootstrap((prev) => (prev ? { ...prev, employee } : prev))
      if (data.jobChanged || !employee?.onDuty) setCompanySession(null)
    })
  }, [])

  const visibleTabs = TABS.filter((t) => !t.requires || bootstrap?.[t.requires])

  useEffect(() => {
    if (bootstrap && !visibleTabs.some((t) => t.key === tab)) setTab('services')
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bootstrap])

  const openMessage = (company) => {
    const numbers = company.numbers.filter((n) => n.messagesEnabled)
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

    const target = await fetchNui('resolveCall', { companyId: company.id, numberId: number.id })
    if (!target) return

    createCall(target.company ? { company: target.company } : { number: target.number })
  }

  const content = !bootstrap ? (
    <div className="empty-state">{t('Loading Services+…')}</div>
  ) : (
    <>
      {tab === 'services' && (
        <ServicesScreen
          companies={bootstrap.companies}
          categories={bootstrap.categories}
          onCall={callCompany}
          onMessage={openMessage}
          onRequest={(company) => setRequestSheet({ company })}
        />
      )}
      {tab === 'activity' && (
        <ActivityScreen
          onOpen={setConversation}
          messageBadge={unread.activityMessages}
          messageRevision={incomingMessage?.message?.id}
          onReadMessages={readActivityMessages}
        />
      )}
      {tab === 'company' && bootstrap.employee && (
        <CompanyScreen
          employee={bootstrap.employee}
          companies={bootstrap.companies}
          session={companySession}
          onLogin={setCompanySession}
          onLogout={logoutCompany}
          onOpenConversation={setConversation}
          teamUpdate={teamUpdate}
          messageBadge={unread.companyMessages}
          requestBadge={unread.companyRequests}
          messageRevision={incomingMessage?.message?.id}
          requestRevision={incomingRequest?.requestId}
          onReadMessages={readCompanyMessages}
          onReadRequests={readCompanyRequests}
        />
      )}
      {tab === 'admin' && bootstrap.admin && <AdminScreen />}
    </>
  )

  const app = (
    <div className="app" data-theme={theme}>
      <div className="app-body">{content}</div>

      {bootstrap && (
        <div className="nav-bar">
          {visibleTabs.map((item) => (
            <button key={item.key} className={`nav-item${tab === item.key ? ' active' : ''}`} onClick={() => setTab(item.key)}>
              <Icon name={item.icon} size={22} className="nav-icon" />
              <span className="nav-label">{t(item.label)}</span>
              {item.key === 'activity' && <Badge count={unread.activityMessages} className="nav-badge" />}
              {item.key === 'company' && <Badge count={unread.companyMessages + unread.companyRequests} className="nav-badge" />}
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
