import { useEffect, useState } from 'react'
import { subscribeToast } from '../lib/toast.js'
import Icon from './Icon.jsx'

// Mounted once in App.jsx. A short, non-blocking confirmation after a
// deliberate Save/Create/Delete - closing a Sheet used to be the only
// signal that an action went through (or silently didn't).
export default function Toast() {
  const [toast, setToast] = useState(null)

  useEffect(() => subscribeToast(setToast), [])

  if (!toast) return null

  return (
    <div className={`toast toast-${toast.variant}`} role="status">
      <Icon name={toast.variant === 'error' ? 'x' : 'check'} size={16} />
      <span>{toast.message}</span>
    </div>
  )
}
