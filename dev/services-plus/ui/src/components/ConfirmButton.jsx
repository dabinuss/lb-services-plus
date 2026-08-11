import { useState } from 'react'

// Two-tap delete: avoids a native confirm() dialog (unreliable inside NUI)
// while still guarding against a stray click on a destructive admin action.
export default function ConfirmButton({ onConfirm, className = 'request-action cancel', children = 'Delete' }) {
  const [confirming, setConfirming] = useState(false)

  if (confirming) {
    return (
      <button
        className={className}
        onClick={() => {
          setConfirming(false)
          onConfirm()
        }}
        onBlur={() => setConfirming(false)}
      >
        Confirm?
      </button>
    )
  }

  return (
    <button className={className} onClick={() => setConfirming(true)}>
      {children}
    </button>
  )
}
