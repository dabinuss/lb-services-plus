// Single icon system for the whole app (plan review UX follow-up: emoji and
// hand-drawn SVG were mixed across screens - tabs/actions/status all used
// platform emoji while the Services "All" filter button already used a
// plain stroke SVG). One vector style everywhere instead, so every icon
// renders identically regardless of the CEF build's emoji font and reads as
// one consistent visual language.
const ICONS = {
  building: (
    <>
      <rect x="4" y="3" width="16" height="18" rx="1" />
      <rect x="7" y="6.5" width="2.4" height="2.4" />
      <rect x="14.6" y="6.5" width="2.4" height="2.4" />
      <rect x="7" y="11" width="2.4" height="2.4" />
      <rect x="14.6" y="11" width="2.4" height="2.4" />
      <rect x="9.5" y="15.5" width="5" height="5.5" />
    </>
  ),
  clock: (
    <>
      <circle cx="12" cy="12" r="9" />
      <polyline points="12 7 12 12 15.5 14" />
    </>
  ),
  briefcase: (
    <>
      <rect x="3" y="7" width="18" height="13" rx="2" />
      <path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
      <line x1="3" y1="13" x2="21" y2="13" />
    </>
  ),
  settings: (
    <>
      <line x1="4" y1="6" x2="20" y2="6" />
      <circle cx="15" cy="6" r="2" />
      <line x1="4" y1="12" x2="20" y2="12" />
      <circle cx="9" cy="12" r="2" />
      <line x1="4" y1="18" x2="20" y2="18" />
      <circle cx="17" cy="18" r="2" />
    </>
  ),
  sun: (
    <>
      <circle cx="12" cy="12" r="4" />
      <line x1="12" y1="2" x2="12" y2="4.5" />
      <line x1="12" y1="19.5" x2="12" y2="22" />
      <line x1="4.2" y1="4.2" x2="6" y2="6" />
      <line x1="18" y1="18" x2="19.8" y2="19.8" />
      <line x1="2" y1="12" x2="4.5" y2="12" />
      <line x1="19.5" y1="12" x2="22" y2="12" />
      <line x1="4.2" y1="19.8" x2="6" y2="18" />
      <line x1="18" y1="6" x2="19.8" y2="4.2" />
    </>
  ),
  moon: <path d="M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5z" />,
  phone: (
    <path d="M21 16.4v2.9a1.7 1.7 0 0 1-1.9 1.7 16.8 16.8 0 0 1-7.3-2.6 16.6 16.6 0 0 1-5.1-5.1A16.8 16.8 0 0 1 4.1 5a1.7 1.7 0 0 1 1.7-1.9h2.9a1.7 1.7 0 0 1 1.7 1.5c.1.8.3 1.6.6 2.4a1.7 1.7 0 0 1-.4 1.8l-1 1a13.4 13.4 0 0 0 5.1 5.1l1-1a1.7 1.7 0 0 1 1.8-.4c.8.3 1.6.5 2.4.6a1.7 1.7 0 0 1 1.5 1.7z" />
  ),
  clipboard: (
    <>
      <rect x="6" y="4" width="12" height="17" rx="2" />
      <rect x="9" y="2" width="6" height="4" rx="1" />
      <line x1="9" y1="11.5" x2="15" y2="11.5" />
      <line x1="9" y1="15.5" x2="15" y2="15.5" />
    </>
  ),
  message: (
    <path d="M21 11.5a8.4 8.4 0 0 1-4.5 7.4A8.4 8.4 0 0 1 12.5 20a8.3 8.3 0 0 1-3.8-.9L3 21l1.9-5.7A8.3 8.3 0 0 1 4 11.5 8.5 8.5 0 0 1 12.5 3a8.5 8.5 0 0 1 8.5 8.5z" />
  ),
  shield: <path d="M12 3l7 3v6c0 5-3.5 8-7 9-3.5-1-7-4-7-9V6z" />,
  medical: (
    <>
      <circle cx="12" cy="12" r="9" />
      <line x1="12" y1="8" x2="12" y2="16" />
      <line x1="8" y1="12" x2="16" y2="12" />
    </>
  ),
  car: (
    <>
      <path d="M5 11l1.4-4.3A2 2 0 0 1 8.3 5.3h7.4a2 2 0 0 1 1.9 1.4L19 11" />
      <rect x="3" y="11" width="18" height="6" rx="2" />
      <circle cx="7.5" cy="17" r="1.5" />
      <circle cx="16.5" cy="17" r="1.5" />
    </>
  ),
  wrench: (
    <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.5-3.5a6 6 0 0 1-8 8l-6.6 6.6a2.1 2.1 0 0 1-3-3l6.6-6.6a6 6 0 0 1 8-8z" />
  ),
  towTruck: (
    <>
      <rect x="1" y="8" width="12" height="9" rx="1" />
      <path d="M13 11h4l3 3v3h-7z" />
      <circle cx="6" cy="18.5" r="1.5" />
      <circle cx="17" cy="18.5" r="1.5" />
    </>
  ),
  bank: (
    <>
      <polygon points="12 3 21 9 3 9" />
      <line x1="5" y1="9" x2="5" y2="19" />
      <line x1="9.5" y1="9" x2="9.5" y2="19" />
      <line x1="14.5" y1="9" x2="14.5" y2="19" />
      <line x1="19" y1="9" x2="19" y2="19" />
      <line x1="4" y1="21" x2="20" y2="21" />
    </>
  ),
  news: (
    <>
      <path d="M4 4h12a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z" />
      <line x1="7" y1="8" x2="14" y2="8" />
      <line x1="7" y1="12" x2="14" y2="12" />
      <line x1="7" y1="16" x2="11.5" y2="16" />
      <path d="M18 8h1a1 1 0 0 1 1 1v9a2 2 0 0 1-2 2" />
    </>
  ),
  list: (
    <>
      <line x1="4" y1="7" x2="20" y2="7" />
      <line x1="4" y1="12" x2="20" y2="12" />
      <line x1="4" y1="17" x2="20" y2="17" />
    </>
  ),
  chevronLeft: <polyline points="15 18 9 12 15 6" />,
  send: (
    <>
      <line x1="22" y1="2" x2="11" y2="13" />
      <polygon points="22 2 15 22 11 13 2 9 22 2" />
    </>
  ),
  x: (
    <>
      <line x1="18" y1="6" x2="6" y2="18" />
      <line x1="6" y1="6" x2="18" y2="18" />
    </>
  ),
  check: <polyline points="20 6 9 17 4 12" />,
  target: (
    <>
      <circle cx="12" cy="12" r="8" />
      <circle cx="12" cy="12" r="0.6" fill="currentColor" />
      <line x1="12" y1="2" x2="12" y2="5" />
      <line x1="12" y1="19" x2="12" y2="22" />
      <line x1="2" y1="12" x2="5" y2="12" />
      <line x1="19" y1="12" x2="22" y2="12" />
    </>
  ),
  logout: (
    <>
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <polyline points="16 17 21 12 16 7" />
      <line x1="21" y1="12" x2="9" y2="12" />
    </>
  ),
  dot: <circle cx="12" cy="12" r="7" fill="currentColor" stroke="none" />,
}

export default function Icon({ name, size = 20, className, strokeWidth = 2 }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      className={className}
      stroke="currentColor"
      strokeWidth={strokeWidth}
      fill="none"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {ICONS[name] || ICONS.building}
    </svg>
  )
}
