import { useI18n } from '../lib/i18n.jsx'

// Small native-style bottom sheet used for the phone-number picker (plan §9).
export default function Sheet({ title, onClose, children }) {
  const { t } = useI18n()
  return (
    <div className="sheet-overlay" onClick={onClose}>
      <div className="sheet" onClick={(e) => e.stopPropagation()}>
        {title && <div className="sheet-title">{title}</div>}
        {children}
        <button className="sheet-cancel" onClick={onClose}>
          {t('Cancel')}
        </button>
      </div>
    </div>
  )
}
