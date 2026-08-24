import { useEffect, useId, useRef } from 'react'
import { useI18n } from '../lib/i18n.jsx'

// Small native-style bottom sheet used for the phone-number picker (plan §9).
export default function Sheet({ title, onClose, children }) {
  const { t } = useI18n()
  const sheetRef = useRef(null)
  const closeRef = useRef(onClose)
  const titleId = useId()
  closeRef.current = onClose

  useEffect(() => {
    const previousFocus = document.activeElement
    const sheet = sheetRef.current
    const focusableSelector = 'button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])'
    requestAnimationFrame(() => sheet?.querySelector(focusableSelector)?.focus())

    const handleKeyDown = (event) => {
      if (event.key === 'Escape') {
        event.preventDefault()
        closeRef.current()
        return
      }
      if (event.key !== 'Tab' || !sheet) return
      const focusable = [...sheet.querySelectorAll(focusableSelector)]
      if (focusable.length === 0) return
      const first = focusable[0]
      const last = focusable.at(-1)
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault()
        last.focus()
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault()
        first.focus()
      }
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => {
      document.removeEventListener('keydown', handleKeyDown)
      previousFocus?.focus?.()
    }
  }, [])

  return (
    <div className="sheet-overlay" onClick={onClose}>
      <div
        ref={sheetRef}
        className="sheet"
        role="dialog"
        aria-modal="true"
        aria-labelledby={title ? titleId : undefined}
        aria-label={title ? undefined : t('Dialog')}
        onClick={(e) => e.stopPropagation()}
      >
        {title && <div className="sheet-title" id={titleId}>{title}</div>}
        {children}
        <button className="sheet-cancel" onClick={onClose}>
          {t('Cancel')}
        </button>
      </div>
    </div>
  )
}
