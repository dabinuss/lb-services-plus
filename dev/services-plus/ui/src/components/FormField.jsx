export default function FormField({ label, hint, children, className = '' }) {
  return (
    <label className={`form-field${className ? ` ${className}` : ''}`}>
      <span className="form-field-label">{label}</span>
      {children}
      {hint && <span className="form-field-hint">{hint}</span>}
    </label>
  )
}
