import { useI18n } from '../lib/i18n.jsx'

export default function ListError({ onRetry }) {
  const { t } = useI18n()
  return (
    <div className="list-error notice">
      <span>{t('Could not load this list.')}</span>
      <button onClick={() => onRetry()}>{t('Try again')}</button>
    </div>
  )
}
