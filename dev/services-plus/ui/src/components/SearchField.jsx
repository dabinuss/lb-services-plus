import Icon from './Icon.jsx'

export default function SearchField({ value, onChange, placeholder, clearLabel }) {
  return (
    <div className="search-field">
      <input
        className="search-input"
        type="search"
        placeholder={placeholder}
        aria-label={placeholder}
        value={value}
        onChange={(event) => onChange(event.target.value)}
      />
      {value && (
        <button className="search-clear" onClick={() => onChange('')} aria-label={clearLabel} title={clearLabel}>
          <Icon name="x" size={13} />
        </button>
      )}
    </div>
  )
}
