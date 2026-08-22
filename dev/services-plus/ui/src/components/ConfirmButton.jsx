import { useEffect, useRef, useState } from 'react'
import { useI18n } from '../lib/i18n.jsx'

// One confirm pattern for every critical/destructive action in the app -
// admin deletes used to be the only place asking "press again to confirm";
// cancelling a request or removing a conversation elsewhere just fired
// immediately on a single tap. Same two-tap-within-a-few-seconds behaviour
// everywhere now, mirroring the Sibling-NUI overlay's own confirm-with-
// timeout actions so a player never has to learn two different "are you
// sure" gestures.
const DEFAULT_TIMEOUT = 4000

export default function ConfirmButton({ onConfirm, className = 'request-action cancel', children, timeout = DEFAULT_TIMEOUT, ariaLabel, disabled = false }) {
  const { t } = useI18n()
  const [confirming, setConfirming] = useState(false)
  const [executing, setExecuting] = useState(false)
  const resetTimer = useRef(null)

  useEffect(() => () => clearTimeout(resetTimer.current), [])

  const arm = () => {
    setConfirming(true)
    clearTimeout(resetTimer.current)
    resetTimer.current = setTimeout(() => setConfirming(false), timeout)
  }

  const disarm = () => {
    clearTimeout(resetTimer.current)
    setConfirming(false)
  }

  if (confirming) {
    return (
      <button
        className={className}
        disabled={disabled || executing}
        aria-busy={executing}
        aria-label={ariaLabel ? t('Confirm {action}', { action: t(ariaLabel) }) : undefined}
        onClick={async () => {
          if (executing) return
          disarm()
          setExecuting(true)
          try {
            await onConfirm()
          } finally {
            setExecuting(false)
          }
        }}
        onBlur={disarm}
      >
        {t('Confirm?')}
      </button>
    )
  }

  return (
    <button className={className} aria-label={ariaLabel} onClick={arm} disabled={disabled || executing}>
      {children ?? t('Delete')}
    </button>
  )
}
