import { useI18n } from '../lib/i18n.jsx'

export default function Badge({ count, className = '' }) {
  const { t } = useI18n()
  if (!count) return null

  const label = count > 99 ? '99+' : String(count)
  return (
    <span className={`count-badge${className ? ` ${className}` : ''}`} aria-label={t('{count} new', { count })}>
      {label}
    </span>
  )
}
