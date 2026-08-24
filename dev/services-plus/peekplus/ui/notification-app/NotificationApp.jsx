import { useCallback, useEffect, useMemo, useRef, useState } from 'react'

import Frame from '../../../ui/src/components/Frame.jsx'
import { devMode, fetchNui, getSettings, onNuiEvent, onSettingsChange } from '../../../ui/src/lib/nui.js'
import { useI18n } from '../../../ui/src/lib/i18n.jsx'
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

function Progress({ progress }) {
  const { t } = useI18n()
  if (!progress) return null
  const percent = Math.max(0, Math.min(100, (progress.value / progress.max) * 100))
  return (
    <div className="pn-progress">
      <div className="pn-progress-label"><span>{progress.label ? t(progress.label) : t('Progress')}</span><span>{Math.round(percent)}%</span></div>
      <div className="pn-progress-track"><span style={{ width: `${percent}%` }} /></div>
    </div>
  )
}

function Timer({ timer }) {
  const { t } = useI18n()
  if (!timer) return null
  const value = timer.countdown ? Math.max(0, Number(timer.duration) - Number(timer.elapsed)) : Number(timer.elapsed)
  const total = Math.max(0, Math.floor(value / 1000))
  const minutes = Math.floor(total / 60)
  const seconds = total % 60
  return <div className="pn-history-timer"><span>{timer.label ? t(timer.label) : t('Timer')}</span><strong>{minutes}:{String(seconds).padStart(2, '0')}</strong></div>
}

function HistoryCard({ entry, expanded, onOpen, onDelete, disabled }) {
  const { t } = useI18n()
  const card = entry.card || {}
  const variant = card.variant || 'neutral'
  return (
    <article className={`pn-card variant-${variant}${entry.read ? '' : ' unread'}`}>
      <button className="pn-card-main" onClick={onOpen} disabled={disabled}>
        <span className="pn-variant-icon">{VARIANT_ICON[variant] || '●'}</span>
        <span className="pn-copy">
          <span className="pn-title">{card.title ? t(card.title) : t('Notification')}</span>
          {card.subtitle && <span className="pn-subtitle">{t(card.subtitle)}</span>}
          {card.description && <span className={`pn-description${expanded ? ' expanded' : ''}`}>{t(card.description)}</span>}
        </span>
        <span className="pn-time">{entry.ageSeconds < 60 ? t('now') : entry.ageSeconds < 3600 ? t('{count}m', { count: Math.floor(entry.ageSeconds / 60) }) : entry.ageSeconds < 86400 ? t('{count}h', { count: Math.floor(entry.ageSeconds / 3600) }) : t('{count}d', { count: Math.floor(entry.ageSeconds / 86400) })}</span>
      </button>
      {expanded && (
        <div className="pn-details">
          {Array.isArray(card.details) && card.details.map((row, index) => (
            <div className="pn-detail-row" key={`${row.label}-${index}`}><span>{t(row.label)}</span><strong>{t(row.value)}</strong></div>
          ))}
          <Progress progress={card.progress} />
          <Timer timer={card.timer} />
          <div className="pn-meta"><span>{entry.owner}</span><span>{t(entry.result)}</span></div>
          <button className="pn-delete" onClick={onDelete} disabled={disabled}>{t('Delete')}</button>
        </div>
      )}
    </article>
  )
}

export default function NotificationApp() {
  const { t } = useI18n()
  const [theme, setTheme] = useState('light')
  const [entries, setEntries] = useState(null)
  const [filter, setFilter] = useState('all')
  const [expanded, setExpanded] = useState(null)
  const [error, setError] = useState(false)
  const [busy, setBusy] = useState(false)
  const actionLock = useRef(false)

  const load = useCallback(async () => {
    if (devMode) {
      setEntries(DEV_HISTORY)
      return
    }
    try {
      const result = await fetchNui('peekplusGetHistory')
      if (!Array.isArray(result)) throw new Error('history_unavailable')
      setEntries(result)
      setError(false)
    } catch {
      setEntries((current) => current || [])
      setError(true)
    }
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
    return onSettingsChange((settings) => setTheme(settings.display.theme))
  }, [])

  useEffect(() => { load() }, [load])
  useEffect(() => onNuiEvent('peekplusHistoryChanged', load), [load])
  useEffect(() => {
    const timer = window.setInterval(() => {
      setEntries((current) => !current || current.length === 0 ? current : current.map((entry) => ({
          ...entry,
          ageSeconds: Number(entry.ageSeconds || 0) + 60,
        })))
    }, 60000)
    return () => window.clearInterval(timer)
  }, [])
  useEffect(() => { document.body.setAttribute('data-theme', theme) }, [theme])

  const visible = useMemo(() => {
    const list = entries || []
    return filter === 'unread' ? list.filter((entry) => !entry.read) : list
  }, [entries, filter])
  const unread = (entries || []).reduce((count, entry) => count + (entry.read ? 0 : 1), 0)

  const runAction = async (operation, apply) => {
    if (actionLock.current) return
    actionLock.current = true
    setBusy(true)
    setError(false)
    try {
      const result = await operation()
      if (result === false || (result && typeof result === 'object' && 'ok' in result && !result.ok)) {
        throw new Error('history_action_failed')
      }
      apply()
    } catch {
      setError(true)
    } finally {
      actionLock.current = false
      setBusy(false)
    }
  }

  const markAllRead = async () => {
    await runAction(
      () => devMode ? true : fetchNui('peekplusMarkHistoryRead', { read: true }),
      () => setEntries((current) => current.map((entry) => ({ ...entry, read: true }))),
    )
  }
  const open = async (entry) => {
    setExpanded((current) => current === entry.id ? null : entry.id)
    if (!entry.read) {
      await runAction(
        () => devMode ? true : fetchNui('peekplusMarkHistoryRead', { id: entry.id, read: true }),
        () => setEntries((current) => current.map((item) => item.id === entry.id ? { ...item, read: true } : item)),
      )
    }
  }
  const remove = async (id) => {
    await runAction(
      () => devMode ? true : fetchNui('peekplusClearHistory', { id }),
      () => {
        setEntries((current) => current.filter((entry) => entry.id !== id))
        setExpanded(null)
      },
    )
  }
  const clear = async () => {
    await runAction(
      () => devMode ? true : fetchNui('peekplusClearHistory'),
      () => {
        setEntries([])
        setExpanded(null)
      },
    )
  }

  const app = (
    <div className="notification-app" data-theme={theme}>
      <header className="pn-header">
        <div><h1>{t('Notifications')}</h1><p>{unread ? t('{count} unread', { count: unread }) : t('All caught up')}</p></div>
        {(entries?.length || 0) > 0 && <button onClick={clear} disabled={busy}>{t('Clear')}</button>}
      </header>
      <div className="pn-toolbar">
        <div className="pn-filter">
          <button className={filter === 'all' ? 'active' : ''} onClick={() => setFilter('all')} disabled={busy}>{t('All')}</button>
          <button className={filter === 'unread' ? 'active' : ''} onClick={() => setFilter('unread')} disabled={busy}>{t('Unread')}</button>
        </div>
        {unread > 0 && <button className="pn-read-all" onClick={markAllRead} disabled={busy}>{t('Read all')}</button>}
      </div>
      <main className="pn-list">
        {entries === null && <div className="pn-empty"><strong>{t('Loading notifications…')}</strong></div>}
        {error && (
          <div className="notice pn-error">
            <span>{t('Could not update notifications. Try again.')}</span>
            <button onClick={load} disabled={busy}>{t('Try again')}</button>
          </div>
        )}
        {visible.map((entry) => <HistoryCard key={entry.id} entry={entry} expanded={expanded === entry.id} onOpen={() => open(entry)} onDelete={() => remove(entry.id)} disabled={busy} />)}
        {entries !== null && !error && visible.length === 0 && <div className="pn-empty"><span>✓</span><strong>{t('No notifications')}</strong><p>{t('New PeekPlus notifications will appear here.')}</p></div>}
      </main>
    </div>
  )

  return devMode ? <Frame>{app}</Frame> : app
}
