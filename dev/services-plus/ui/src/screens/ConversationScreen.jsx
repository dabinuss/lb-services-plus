import { useEffect, useRef, useState } from 'react'
import { fetchNui } from '../lib/nui.js'

// Full-screen chat, opened either from a company's Message button
// (numberId, no channel yet) or by reopening an Activity entry (channelId
// already known). Behaviour intentionally mirrors native LB-Phone messaging
// (plan §37).
export default function ConversationScreen({ target, myNumber, onClose }) {
  const [channelId, setChannelId] = useState(target.channelId ?? null)
  const [messages, setMessages] = useState(null)
  const [text, setText] = useState('')
  const listRef = useRef(null)

  useEffect(() => {
    const action = target.channelId ? 'getMessages' : 'openConversation'
    const payload = target.channelId ? { channelId: target.channelId } : { numberId: target.numberId }

    fetchNui(action, payload).then((result) => {
      if (!result) return
      setChannelId(result.channelId)
      setMessages([...result.messages].reverse())
    })
  }, [target])

  useEffect(() => {
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight })
  }, [messages])

  const send = async () => {
    const content = text.trim()
    if (!content || !channelId) return

    setText('')
    const message = await fetchNui('sendMessage', { channelId, content })
    if (message) setMessages((prev) => [...(prev || []), message])
  }

  return (
    <div className="screen conversation-screen">
      <div className="conversation-header">
        <button className="back-button" onClick={onClose}>
          ‹
        </button>
        {target.icon && <img className="conversation-icon" src={target.icon} alt="" />}
        <div className="conversation-title">{target.title}</div>
      </div>

      <div className="conversation-messages" ref={listRef}>
        {messages === null && <div className="empty-state">Loading…</div>}
        {messages?.map((m) => (
          <div key={m.id} className={`bubble ${m.sender === myNumber ? 'mine' : 'theirs'}`}>
            {m.content}
          </div>
        ))}
      </div>

      <div className="conversation-input">
        <input
          placeholder="Message"
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && send()}
        />
        <button className="send-button" onClick={send} disabled={!text.trim()}>
          ➤
        </button>
      </div>
    </div>
  )
}
