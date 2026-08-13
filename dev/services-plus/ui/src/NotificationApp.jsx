import { useCallback, useEffect, useMemo, useState } from 'react'

import Frame from './components/Frame.jsx'
import { devMode, fetchNui, getSettings, onNuiEvent, onSettingsChange } from './lib/nui.js'
import './NotificationApp.css'

const DEV_HISTORY = [
  {
    id: 3, read: false, result: 'shown', ageSeconds: 0, owner: 'navigation-plus',
    card: { title: 'Route updated', subtitle: 'Navigation', description: 'Turn right in 350 m', variant: 'info', layout: 'details', details: [{ label: 'Arrival', value: '4 min' }] },
  },
  {
    id: 2, read: true, result: 'active', ageSeconds: 240, owner: 'services-plus',
    card: { title: 'Taxi request accepted', subtitle: 'Downtown Cab Co.', description: 'Legion Square', variant: 'success', layout: 'actions' },
  },
  {
    id: 1, read: true, result: 'expired', ageSeconds: 3600, owner: 'weather-plus',
    card: { title: 'Storm warning', description: 'Heavy rain expected downtown.', variant: 'warning', layout: 'text' },
  },
]

const VARIANT_ICON = { neutral: '●', info: 'i', success: '✓', warning: '!', error: '×' }

function timeLabel(ageSeconds) {
  const seconds = Math.max(0, Number(ageSeconds || 0))
  if (seconds < 60) return 'now'
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h`
  return `${Math.floor(seconds / 86400)}d`
}

function Progress({ progress }) {
  if (!progress) return null
  const percent = Math.max(0, Math.min(100, (progress.value / progress.max) * 100))
  return (
    <div className="pn-progress">
      <div className="pn-progress-label"><span>{progress.label || 'Progress'}</span><span>{Math.round(percent)}%</span></div>
      <div className="pn-progress-track"><span style={{ width: `${percent}%` }} /></div>
    </div>
  )
}

function Timer({ timer }) {
  if (!timer) return null
  const value = timer.countdown ? Math.max(0, Number(timer.duration) - Number(timer.elapsed)) : Number(timer.elapsed)
  const total = Math.max(0, Math.floor(value / 1000))
  const minutes = Math.floor(total / 60)
  const seconds = total % 60
  return <div className="pn-history-timer"><span>{timer.label || 'Timer'}</span><strong>{minutes}:{String(seconds).padStart(2, '0')}</strong></div>
}

function HistoryCard({ entry, expanded, onOpen, onDelete }) {
  const card = entry.card || {}
  const variant = card.variant || 'neutral'
  return (
    <article className={`pn-card variant-${variant}${entry.read ? '' : ' unread'}`}>
      <button className="pn-card-main" onClick={onOpen}>
        <span className="pn-variant-icon">{VARIANT_ICON[variant] || '●'}</span>
        <span className="pn-copy">
          <span className="pn-title">{card.title || 'Notification'}</span>
          {card.subtitle && <span className="pn-subtitle">{card.subtitle}</span>}
          {card.description && <span className={`pn-description${expanded ? ' expanded' : ''}`}>{card.description}</span>}
        </span>
        <span className="pn-time">{timeLabel(entry.ageSeconds)}</span>
      </button>
      {expanded && (
        <div className="pn-details">
          {Array.isArray(card.details) && card.details.map((row, index) => (
            <div className="pn-detail-row" key={`${row.label}-${index}`}><span>{row.label}</span><strong>{row.value}</strong></div>
          ))}
          <Progress progress={card.progress} />
          <Timer timer={card.timer} />
          <div className="pn-meta"><span>{entry.owner}</span><span>{entry.result}</span></div>
          <button className="pn-delete" onClick={onDelete}>Delete</button>
        </div>
      )}
    </article>
  )
}

export default function NotificationApp() {
  const [theme, setTheme] = useState('light')
  const [entries, setEntries] = useState([])
  const [filter, setFilter] = useState('all')
  const [expanded, setExpanded] = useState(null)

  const load = useCallback(async () => {
    if (devMode) return setEntries(DEV_HISTORY)
    const result = await fetchNui('peekplusGetHistory')
    setEntries(Array.isArray(result) ? result : [])
  }, [])

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

  useEffect(() => { load() }, [load])
  useEffect(() => onNuiEvent('peekplusHistoryChanged', load), [load])
  useEffect(() => { document.body.setAttribute('data-theme', theme) }, [theme])

  const visible = useMemo(() => filter === 'unread' ? entries.filter((entry) => !entry.read) : entries, [entries, filter])
  const unread = entries.reduce((count, entry) => count + (entry.read ? 0 : 1), 0)

  const markAllRead = async () => {
    if (!devMode) await fetchNui('peekplusMarkHistoryRead', { read: true })
    setEntries((current) => current.map((entry) => ({ ...entry, read: true })))
  }
  const open = async (entry) => {
    setExpanded((current) => current === entry.id ? null : entry.id)
    if (!entry.read) {
      if (!devMode) await fetchNui('peekplusMarkHistoryRead', { id: entry.id, read: true })
      setEntries((current) => current.map((item) => item.id === entry.id ? { ...item, read: true } : item))
    }
  }
  const remove = async (id) => {
    if (!devMode) await fetchNui('peekplusClearHistory', { id })
    setEntries((current) => current.filter((entry) => entry.id !== id))
    setExpanded(null)
  }
  const clear = async () => {
    if (!devMode) await fetchNui('peekplusClearHistory')
    setEntries([])
    setExpanded(null)
  }

  const app = (
    <div className="notification-app" data-theme={theme}>
      <header className="pn-header">
        <div><h1>Notifications</h1><p>{unread ? `${unread} unread` : 'All caught up'}</p></div>
        {entries.length > 0 && <button onClick={clear}>Clear</button>}
      </header>
      <div className="pn-toolbar">
        <div className="pn-filter">
          <button className={filter === 'all' ? 'active' : ''} onClick={() => setFilter('all')}>All</button>
          <button className={filter === 'unread' ? 'active' : ''} onClick={() => setFilter('unread')}>Unread</button>
        </div>
        {unread > 0 && <button className="pn-read-all" onClick={markAllRead}>Read all</button>}
      </div>
      <main className="pn-list">
        {visible.map((entry) => <HistoryCard key={entry.id} entry={entry} expanded={expanded === entry.id} onOpen={() => open(entry)} onDelete={() => remove(entry.id)} />)}
        {visible.length === 0 && <div className="pn-empty"><span>✓</span><strong>No notifications</strong><p>New PeekPlus notifications will appear here.</p></div>}
      </main>
    </div>
  )

  return devMode ? <Frame>{app}</Frame> : app
}
