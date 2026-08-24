import { useI18n } from '../lib/i18n.jsx'

export default function Badge({ count, className = '' }) {
  const { t } = useI18n()
  const numericCount = Number(count) || 0
  if (numericCount <= 0) return null

  const label = numericCount > 99 ? '99+' : String(numericCount)
  return (
    <span className={`count-badge${className ? ` ${className}` : ''}`} aria-label={t('{count} new', { count: numericCount })}>
      {label}
    </span>
  )
}
