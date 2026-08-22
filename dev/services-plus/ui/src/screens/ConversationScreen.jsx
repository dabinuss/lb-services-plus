import { useEffect, useRef, useState } from 'react'
import { fetchNui } from '../lib/nui.js'
import Icon from '../components/Icon.jsx'
import { useI18n } from '../lib/i18n.jsx'

// Mirrors Config.PageSize.messages in shared/config.lua - a page shorter
// than this means there's nothing older left to load (plan review round 4 §5).
const PAGE_SIZE = 25

// Full-screen chat, opened either from a company's Message button
// (numberId, no channel yet) or by reopening an Activity entry (channelId
// already known). Behaviour intentionally mirrors native LB-Phone messaging
// (plan §37).
export default function ConversationScreen({ target, incoming, onClose }) {
  const { t } = useI18n()
  const [channelId, setChannelId] = useState(target.channelId ?? null)
  const [messages, setMessages] = useState(null)
  const [text, setText] = useState('')
  const [sending, setSending] = useState(false)
  const [hasOlder, setHasOlder] = useState(false)
  const [loadingOlder, setLoadingOlder] = useState(false)
  // 'customer' or 'employee' - which sender_type this viewer's own messages
  // carry. The server decides this (it already knows which side `source`
  // is), not a raw phone-number comparison - that broke as soon as a
  // *different* employee than the sender opened the same company chat
  // (plan review round 4 §3).
  const [viewerRole, setViewerRole] = useState(target.viewerRole || null)
  const listRef = useRef(null)
  // Prepending older messages must not trigger the scroll-to-bottom effect
  // below (that's only for "a new message just arrived") - this flag tells
  // that effect to instead restore the pre-prepend scroll offset.
  const prependRef = useRef(false)

  useEffect(() => {
    const action = target.channelId ? 'getMessages' : 'openConversation'
    const payload = target.channelId ? { channelId: target.channelId } : { numberId: target.numberId }

    fetchNui(action, payload).then((result) => {
      if (!result) return
      setChannelId(result.channelId)
      setViewerRole(result.viewerRole)
      setMessages([...result.messages].reverse())
      setHasOlder(result.messages.length === PAGE_SIZE)
      fetchNui('markConversationRead', { channelId: result.channelId }).catch(() => {})
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
    const result = await fetchNui('getMessages', { channelId, beforeId: oldestId })
    setLoadingOlder(false)
    if (!result) return

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
    const content = text.trim()
    if (!content || !channelId || sending) return

    setSending(true)
    try {
      const message = await fetchNui('sendMessage', { channelId, content })
      if (message) {
        setText('')
        setMessages((prev) => [...(prev || []), message])
      }
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="screen conversation-screen">
      <div className="conversation-header">
        <button className="back-button" onClick={onClose} aria-label={t('Back')}>
          <Icon name="chevronLeft" size={20} />
        </button>
        {target.icon && <img className="conversation-icon" src={target.icon} alt="" />}
        <div className="conversation-title">{target.title}</div>
      </div>

      <div className="conversation-messages" ref={listRef} onScroll={onScroll}>
        {messages === null && <div className="empty-state">{t('Loading messages…')}</div>}
        {loadingOlder && <div className="empty-state">{t('Loading older messages…')}</div>}
        {messages?.map((m) => {
          const mine = viewerRole === 'employee' ? m.sender_type === 'company' : m.sender_type === 'customer'
          return (
            <div key={m.id} className={`bubble ${mine ? 'mine' : 'theirs'}`}>
              {m.content}
            </div>
          )
        })}
      </div>

      <div className="conversation-input">
        <input
          placeholder={t('Message')}
          value={text}
          disabled={sending}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && send()}
        />
        <button className="send-button" onClick={send} disabled={sending || !text.trim()} aria-label={t('Send')} aria-busy={sending}>
          <Icon name="send" size={16} />
        </button>
      </div>
    </div>
  )
}
