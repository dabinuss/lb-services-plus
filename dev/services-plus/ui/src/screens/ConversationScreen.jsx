import { Fragment, useEffect, useRef, useState } from 'react'
import { createCall, fetchNui, onNuiEvent } from '../lib/nui.js'
import Icon from '../components/Icon.jsx'
import { useI18n } from '../lib/i18n.jsx'
import { showToast } from '../lib/toast.js'

// Mirrors Config.PageSize.messages in shared/config.lua - a page shorter
// than this means there's nothing older left to load (plan review round 4 §5).
const PAGE_SIZE = 25
const REACTION_EMOJIS = ['❤️', '👍', '👎', '😂']

function LocationBubble({ message, label, mapName, mapIcon }) {
  const mapRef = useRef(null)

  useEffect(() => {
    const GameMap = window.components?.GameMap
    if (!GameMap || !mapRef.current) return

    let disposed = false
    let gameMap

    const mount = async () => {
      gameMap = new GameMap(mapRef.current, {
        allowMoving: false,
        center: { x: Number(message.x), y: Number(message.y) },
        defaultZoom: 4,
        minZoom: 4,
        maxZoom: 4,
      })
      await gameMap.ready
      if (disposed) return gameMap.destroy()
    }

    mount().catch(() => {})
    return () => {
      disposed = true
      gameMap?.destroy()
    }
  }, [message.x, message.y])

  const setWaypoint = () => fetchNui('setWaypoint', { x: Number(message.x), y: Number(message.y) })

  const openInMaps = () => {
    if (!window.setApp) return setWaypoint()
    window.setApp({
      name: 'Maps',
      data: {
        location: [Number(message.y), Number(message.x)],
        name: mapName,
        icon: mapIcon,
      },
    })
  }

  const showLocationActions = () => {
    const setContextMenu = window.components?.setContextMenu
    if (!setContextMenu) return setWaypoint()

    setContextMenu({
      buttons: [
        { title: label.openInMaps, cb: openInMaps },
        { title: label.setWaypoint, cb: setWaypoint },
      ],
    })
  }

  return (
    <button className="message-location" onClick={showLocationActions} aria-label={label.shared}>
      <div className="message-location-map" aria-hidden="true">
        <span className="message-location-map-canvas" ref={mapRef} />
        <span className="message-location-grid" />
        <Icon name="location" size={24} className="message-location-pin" />
      </div>
      <span className="message-location-label">
        <Icon name="location" size={15} />
        {label.shared}
      </span>
    </button>
  )
}

// Full-screen chat, opened either from a company's Message button
// (numberId, no channel yet) or by reopening an Activity entry (channelId
// already known). Behaviour intentionally mirrors native LB-Phone messaging
// (plan §37).
export default function ConversationScreen({ target, incoming, onClose }) {
  const { t, formatTime, formatMessageDay } = useI18n()
  const [channelId, setChannelId] = useState(target.channelId ?? null)
  const [messages, setMessages] = useState(null)
  const [text, setText] = useState('')
  const [sending, setSending] = useState(false)
  const [sendingLocation, setSendingLocation] = useState(false)
  const [hasOlder, setHasOlder] = useState(false)
  const [loadingOlder, setLoadingOlder] = useState(false)
  const [messagesEnabled, setMessagesEnabled] = useState(true)
  const [loadError, setLoadError] = useState('')
  const [reactionPicker, setReactionPicker] = useState(null)
  const [reactionPending, setReactionPending] = useState('')
  // 'customer' or 'employee' - which sender_type this viewer's own messages
  // carry. The server decides this (it already knows which side `source`
  // is), not a raw phone-number comparison - that broke as soon as a
  // *different* employee than the sender opened the same company chat
  // (plan review round 4 §3).
  const [viewerRole, setViewerRole] = useState(target.viewerRole || null)
  const listRef = useRef(null)
  const sendingRef = useRef(false)
  // Prepending older messages must not trigger the scroll-to-bottom effect
  // below (that's only for "a new message just arrived") - this flag tells
  // that effect to instead restore the pre-prepend scroll offset.
  const prependRef = useRef(false)

  useEffect(() => {
    const action = target.channelId ? 'getMessages' : 'openConversation'
    const payload = target.channelId ? { channelId: target.channelId } : { numberId: target.numberId }

    setMessages(null)
    setLoadError('')
    setMessagesEnabled(true)
    setReactionPicker(null)

    fetchNui(action, payload).then((result) => {
      if (result?.error === 'messages_disabled') {
        setMessages([])
        setMessagesEnabled(false)
        setLoadError('Messages are disabled for this phone number.')
        return
      }
      if (!result) {
        setMessages([])
        setMessagesEnabled(false)
        setLoadError('This conversation is currently unavailable.')
        return
      }
      setChannelId(result.channelId)
      setViewerRole(result.viewerRole)
      setMessages([...result.messages].reverse())
      setMessagesEnabled(result.messagesEnabled !== false)
      setHasOlder(result.messages.length === PAGE_SIZE)
      fetchNui('markConversationRead', { channelId: result.channelId }).catch(() => {})
    }).catch(() => {
      setMessages([])
      setMessagesEnabled(false)
      setLoadError('This conversation is currently unavailable.')
    })
  }, [target])

  // Realtime delta (plan review §15): a message sent by the other side while
  // this exact conversation is open lands here instead of waiting for a
  // reopen. Own sent messages are appended locally by send() already, and
  // the server only ever relays to the *other* party, so no duplicates.
  useEffect(() => {
    if (incoming && channelId && incoming.channelId === channelId) {
      setMessages((prev) => (prev?.some((m) => m.id === incoming.message.id) ? prev : [...(prev || []), incoming.message]))
      fetchNui('markConversationRead', { channelId }).catch(() => {})
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [incoming])

  useEffect(() => onNuiEvent('reactionChanged', (data) => {
    if (!data || Number(data.channelId) !== Number(channelId)) return
    setMessages((current) => current?.map((message) => (
      Number(message.id) === Number(data.messageId)
        ? { ...message, reactions: data.reactions || [] }
        : message
    )))
  }), [channelId])

  useEffect(() => {
    const el = listRef.current
    if (!el) return

    if (prependRef.current) {
      // Keep whatever was on screen in place instead of jumping - only the
      // scroll *offset* changed (more content above), not what the user
      // was looking at.
      prependRef.current = false
    } else {
      el.scrollTo({ top: el.scrollHeight })
    }
  }, [messages])

  // Backend pagination already existed for getMessages, but nothing here
  // ever asked for anything beyond the first page - everything before the
  // most recent 25 messages was simply unreachable (plan review round 4 §5).
  // Loading older on scroll-to-top mirrors how the rest of the app's lists
  // got "Load more". Cursor-based on the oldest loaded message's id, not a
  // page number (plan review round 5 §6) - an OFFSET-based page 2 recounts
  // from whatever is newest *right now*, so a message arriving in this chat
  // between loads shifts every OFFSET after it and can re-show (or skip) a
  // row. `beforeId` is a fixed boundary that doesn't move underneath it.
  const loadOlder = async () => {
    if (!channelId || loadingOlder || !hasOlder) return
    const oldestId = messages?.[0]?.id
    if (oldestId == null) return

    setLoadingOlder(true)
    let result
    try {
      result = await fetchNui('getMessages', { channelId, beforeId: oldestId })
    } catch {
      showToast(t('Older messages could not be loaded.'), 'error')
      return
    } finally {
      setLoadingOlder(false)
    }
    if (!result) {
      showToast(t('Older messages could not be loaded.'), 'error')
      return
    }

    setMessagesEnabled(result.messagesEnabled !== false)

    const older = [...result.messages].reverse()
    const el = listRef.current
    const prevScrollHeight = el?.scrollHeight || 0

    prependRef.current = true
    setHasOlder(result.messages.length === PAGE_SIZE)
    setMessages((prev) => [...older, ...(prev || [])])

    // Restore scroll position once the prepended messages have actually
    // been laid out - a plain synchronous assignment races the render.
    requestAnimationFrame(() => {
      if (el) el.scrollTop = el.scrollHeight - prevScrollHeight
    })
  }

  const onScroll = (e) => {
    if (e.target.scrollTop < 60) loadOlder()
  }

  const send = async () => {
    const rawText = text
    const content = text.trim()
    if (!content || !channelId || sendingRef.current) return

    sendingRef.current = true
    setSending(true)
    try {
      const message = await fetchNui('sendMessage', { channelId, content })
      if (message?.error === 'messages_disabled') {
        setMessagesEnabled(false)
        showToast(t('Messages are disabled for this phone number.'), 'error')
      } else if (message) {
        setText((current) => current === rawText ? '' : current)
        setMessages((prev) => [...(prev || []), message])
      } else {
        showToast(t('Message could not be sent.'), 'error')
      }
    } catch {
      showToast(t('Message could not be sent.'), 'error')
    } finally {
      sendingRef.current = false
      setSending(false)
    }
  }

  const handleComposerKey = (event) => {
    if (event.key !== 'Enter' || event.nativeEvent?.isComposing) return
    event.preventDefault()
    event.stopPropagation()
    if (event.type === 'keydown' && !event.repeat) send()
  }

  const sendLocation = async () => {
    if (!channelId || sendingLocation || !messagesEnabled) return

    setSendingLocation(true)
    try {
      const message = await fetchNui('sendLocation', { channelId })
      if (message?.error === 'messages_disabled') {
        setMessagesEnabled(false)
        showToast(t('Messages are disabled for this phone number.'), 'error')
      } else if (message) {
        setMessages((prev) => [...(prev || []), message])
      } else {
        showToast(t('Location could not be sent.'), 'error')
      }
    } catch {
      showToast(t('Location could not be sent.'), 'error')
    } finally {
      setSendingLocation(false)
    }
  }

  const confirmLocation = () => {
    const setPopUp = window.components?.setPopUp
    if (!setPopUp) return sendLocation()

    setPopUp({
      title: t('Share location'),
      description: t('Send your current location to this conversation?'),
      buttons: [
        { title: t('Cancel') },
        { title: t('Send'), color: 'blue', cb: sendLocation },
      ],
    })
  }

  const openEmojiPicker = () => {
    const setEmojiPickerVisible = window.components?.setEmojiPickerVisible
    if (!setEmojiPickerVisible) return

    setEmojiPickerVisible({
      onSelect: (emoji) => {
        setEmojiPickerVisible(false)
        if (emoji?.emoji) setText((current) => `${current}${emoji.emoji}`)
      },
    })
  }

  const startCall = async () => {
    try {
      if (target.phoneNumber) {
        createCall({ number: target.phoneNumber })
        return
      }

      if (!target.companyId || !target.numberId) return
      const resolved = await fetchNui('resolveCall', { companyId: target.companyId, numberId: target.numberId })
      if (!resolved) {
        showToast(t('This company is currently unavailable by phone.'), 'error')
        return
      }
      createCall(resolved.company
        ? { company: resolved.company }
        : { number: resolved.number })
    } catch {
      showToast(t('This company is currently unavailable by phone.'), 'error')
    }
  }

  const toggleReaction = async (messageId, emoji) => {
    const pendingKey = `${messageId}:${emoji}`
    if (reactionPending) return

    setReactionPending(pendingKey)
    setReactionPicker(null)
    try {
      const result = await fetchNui('toggleMessageReaction', { messageId, emoji })
      if (!result) {
        showToast(t('Reaction could not be updated.'), 'error')
        return
      }
      setMessages((current) => current?.map((message) => (
        Number(message.id) === Number(result.messageId)
          ? { ...message, reactions: result.reactions || [] }
          : message
      )))
    } catch {
      showToast(t('Reaction could not be updated.'), 'error')
    } finally {
      setReactionPending('')
    }
  }

  const headerInitial = target.title?.trim()?.[0]?.toUpperCase() || '?'
  const canCall = Boolean(target.phoneNumber || (target.companyId && target.numberId))

  return (
    <div className="screen conversation-screen">
      <div className="conversation-header">
        <button className="back-button" onClick={onClose} aria-label={t('Back')}>
          <Icon name="chevronLeft" size={20} />
        </button>
        <div className="conversation-identity">
          {target.icon
            ? <img className="conversation-icon" src={target.icon} alt="" />
            : <span className="conversation-icon conversation-icon-fallback">{headerInitial}</span>}
          <div className="conversation-title">{target.title}</div>
        </div>
        <div className="conversation-header-actions">
          {canCall && (
            <button onClick={startCall} aria-label={t('Call')}>
              <Icon name="phone" size={20} strokeWidth={1.8} />
            </button>
          )}
        </div>
      </div>

      <div className="conversation-messages" ref={listRef} onScroll={onScroll}>
        {messages === null && <div className="empty-state loading-state" aria-busy="true">{t('Loading messages…')}</div>}
        {loadError && <div className="empty-state">{t(loadError)}</div>}
        {!loadError && messages !== null && !messagesEnabled && (
          <div className="empty-state">{t('Messages are disabled for this phone number.')}</div>
        )}
        {loadingOlder && <div className="empty-state loading-state" aria-busy="true">{t('Loading older messages…')}</div>}
        {messages?.map((m, index) => {
          const mine = viewerRole === 'employee' ? m.sender_type === 'company' : m.sender_type === 'customer'
          const day = formatMessageDay(m.created_at)
          const previousDay = index > 0 ? formatMessageDay(messages[index - 1].created_at) : null
          const previous = messages[index - 1]
          const previousMine = previous && (viewerRole === 'employee' ? previous.sender_type === 'company' : previous.sender_type === 'customer')
          const startsGroup = !previous || previousMine !== mine || previousDay !== day
          const next = messages[index + 1]
          const nextMine = next && (viewerRole === 'employee' ? next.sender_type === 'company' : next.sender_type === 'customer')
          const endsGroup = !next || nextMine !== mine || formatMessageDay(next.created_at) !== day
          const hasLocation = Number.isFinite(Number(m.x)) && Number.isFinite(Number(m.y))
          return (
            <Fragment key={m.id}>
              {day !== previousDay && <div className="message-day"><span>{day}</span></div>}
              <div className={`message-row ${mine ? 'mine' : 'theirs'}${endsGroup ? ' group-end' : ''}`}>
                {!mine && startsGroup && <span className="message-sender">{target.title}</span>}
                <div className="message-content-line">
                  <div className={`bubble${hasLocation ? ' location' : ''}`}>
                    {hasLocation
                      ? <LocationBubble
                          message={m}
                          label={{
                            shared: t('Shared location'),
                            openInMaps: t('Open in Maps'),
                            setWaypoint: t('Set Waypoint'),
                          }}
                          mapName={`${target.title} · ${t('Shared location')}`}
                          mapIcon={target.icon}
                        />
                      : <span className="bubble-content">{m.content}</span>}
                  </div>
                  <button
                    className="message-reaction-trigger"
                    onClick={() => setReactionPicker((current) => current === m.id ? null : m.id)}
                    aria-label={t('React')}
                    aria-expanded={reactionPicker === m.id}
                  >
                    <span aria-hidden="true">☺</span>
                  </button>
                </div>
                {reactionPicker === m.id && (
                  <div className="message-reaction-picker" role="group" aria-label={t('React')}>
                    {REACTION_EMOJIS.map((emoji) => (
                      <button key={emoji} onClick={() => toggleReaction(m.id, emoji)} disabled={Boolean(reactionPending)}>
                        {emoji}
                      </button>
                    ))}
                  </div>
                )}
                {m.reactions?.length > 0 && (
                  <div className="message-reactions">
                    {m.reactions.map((reaction) => (
                      <button
                        key={reaction.emoji}
                        className={reaction.mine ? 'mine' : ''}
                        onClick={() => toggleReaction(m.id, reaction.emoji)}
                        disabled={Boolean(reactionPending)}
                        aria-label={t('React')}
                      >
                        <span>{reaction.emoji}</span>
                        <span>{reaction.count}</span>
                      </button>
                    ))}
                  </div>
                )}
                {endsGroup && (
                  <time className="bubble-time" dateTime={m.created_at}>{formatTime(m.created_at)}</time>
                )}
              </div>
            </Fragment>
          )
        })}
      </div>

      <div className="conversation-input">
        <div className="conversation-composer">
          <input
            placeholder={t(messagesEnabled ? 'Text Message' : 'Messages are disabled for this phone number.')}
            value={text}
            maxLength={1000}
            disabled={!messagesEnabled}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={handleComposerKey}
            onKeyUp={handleComposerKey}
          />
          {text.trim() && (
            <button className="send-button" onClick={send} disabled={sending || !messagesEnabled} aria-label={t('Send')} aria-busy={sending}>
              <Icon name="send" size={15} />
            </button>
          )}
        </div>
        <div className="conversation-tools">
          <button className="composer-action emoji-action" onClick={openEmojiPicker} disabled={!messagesEnabled} aria-label={t('Emoji')}>
            <span aria-hidden="true">😃</span>
          </button>
          <button
            className="composer-action"
            onClick={confirmLocation}
            disabled={sendingLocation || !messagesEnabled}
            aria-label={t('Share location')}
            aria-busy={sendingLocation}
          >
            <Icon name="location" size={17} />
          </button>
        </div>
      </div>
    </div>
  )
}
