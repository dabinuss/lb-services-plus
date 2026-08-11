// Single switch control used everywhere a checkbox would otherwise be
// (hotlines, company/number/category/request-type toggles) - the app has
// exactly one on/off visual language, the same pill-and-knob as the "On
// duty" toggle, never a native checkbox square.
export default function Switch({ checked, onChange, disabled, small = true }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      disabled={disabled}
      className={`toggle${small ? ' small' : ''}${checked ? ' on' : ''}`}
      onClick={() => onChange(!checked)}
    >
      <span className="toggle-knob" />
    </button>
  )
}
