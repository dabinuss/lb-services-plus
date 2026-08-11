// Small native-style bottom sheet used for the phone-number picker (plan §9).
export default function Sheet({ title, onClose, children }) {
  return (
    <div className="sheet-overlay" onClick={onClose}>
      <div className="sheet" onClick={(e) => e.stopPropagation()}>
        {title && <div className="sheet-title">{title}</div>}
        {children}
        <button className="sheet-cancel" onClick={onClose}>
          Cancel
        </button>
      </div>
    </div>
  )
}
