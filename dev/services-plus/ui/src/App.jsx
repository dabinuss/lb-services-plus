import { useEffect, useState } from 'react'

import Frame from './components/Frame.jsx'
import Sheet from './components/Sheet.jsx'
import RequestSheet from './components/RequestSheet.jsx'
import ServicesScreen from './screens/ServicesScreen.jsx'
import ActivityScreen from './screens/ActivityScreen.jsx'
import CompanyScreen from './screens/CompanyScreen.jsx'
import AdminScreen from './screens/AdminScreen.jsx'
import ConversationScreen from './screens/ConversationScreen.jsx'
import { fetchNui, getSettings, onSettingsChange, onNuiEvent, createCall, devMode } from './lib/nui.js'

import './App.css'

const TABS = [
  { key: 'services', label: 'Services', icon: '🏢' },
  { key: 'activity', label: 'Activity', icon: '🕓' },
  { key: 'company', label: 'Company', icon: '💼', requires: 'employee' },
  { key: 'admin', label: 'Admin', icon: '⚙️', requires: 'admin' },
]

export default function App() {
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

  useEffect(() => {
    if (devMode) {
      const media = window.matchMedia('(prefers-color-scheme: dark)')
      const apply = () => setTheme(media.matches ? 'dark' : 'light')
      apply()
      media.addEventListener('change', apply)
      return () => media.removeEventListener('change', apply)
    }

    getSettings().then((settings) => settings && setTheme(settings.display.theme))
    onSettingsChange((settings) => setTheme(settings.display.theme))
  }, [])

  useEffect(() => {
    document.body.setAttribute('data-theme', theme)
  }, [theme])

  useEffect(() => {
    fetchNui('bootstrap').then(setBootstrap)
  }, [])

  // Realtime delta for an already-open conversation (plan review §15) -
  // the actual merge-into-open-conversation happens in ConversationScreen,
  // this just routes the push to whichever one (if any) is currently open.
  useEffect(() => {
    onNuiEvent('newMessage', (data) => setIncomingMessage(data))
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
    <div className="empty-state">Loading…</div>
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
      {tab === 'activity' && <ActivityScreen onOpen={setConversation} />}
      {tab === 'company' && bootstrap.employee && (
        <CompanyScreen
          employee={bootstrap.employee}
          companies={bootstrap.companies}
          session={companySession}
          onLogin={setCompanySession}
          onLogout={() => setCompanySession(null)}
          onOpenConversation={setConversation}
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
          {visibleTabs.map((t) => (
            <button key={t.key} className={`nav-item${tab === t.key ? ' active' : ''}`} onClick={() => setTab(t.key)}>
              <span className="nav-icon">{t.icon}</span>
              <span className="nav-label">{t.label}</span>
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
        <Sheet title={numberPicker.mode === 'call' ? 'Call' : 'Message'} onClose={() => setNumberPicker(null)}>
          {numberPicker.numbers.map((n) => (
            <button
              key={n.id}
              className="sheet-option"
              onClick={() =>
                numberPicker.mode === 'call' ? placeCall(numberPicker.company, n) : openConversationFor(numberPicker.company, n)
              }
            >
              {n.label}
            </button>
          ))}
        </Sheet>
      )}

      {requestSheet && <RequestSheet company={requestSheet.company} onClose={() => setRequestSheet(null)} />}
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
        title="Toggle light/dark (dev only)"
      >
        {theme === 'dark' ? '☀️ Light' : '🌙 Dark'}
      </button>
      <Frame>{app}</Frame>
    </>
  ) : (
    app
  )
}
