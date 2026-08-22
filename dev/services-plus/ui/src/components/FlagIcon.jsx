export default function FlagIcon({ country }) {
  if (country === 'de') {
    return (
      <svg className="flag-icon" viewBox="0 0 30 20" aria-hidden="true">
        <path fill="#000" d="M0 0h30v6.67H0z" />
        <path fill="#dd0000" d="M0 6.67h30v6.66H0z" />
        <path fill="#ffce00" d="M0 13.33h30V20H0z" />
      </svg>
    )
  }

  return (
    <svg className="flag-icon" viewBox="0 0 38 20" aria-hidden="true">
      <path fill="#fff" d="M0 0h38v20H0z" />
      {[0, 3.08, 6.16, 9.24, 12.32, 15.4, 18.48].map((y) => (
        <path key={y} fill="#b22234" d={`M0 ${y}h38v1.54H0z`} />
      ))}
      <path fill="#3c3b6e" d="M0 0h15.2v10.77H0z" />
      {[2, 5, 8, 11, 14].flatMap((x, column) => [2, 5.3, 8.6].map((y) => (
        <circle key={`${x}-${y}`} cx={x + (column % 2 ? 0.5 : 0)} cy={y} r="0.55" fill="#fff" />
      )))}
    </svg>
  )
}
