// Category icons are a plain key (see shared/categories.lua) so admins can
// add new categories later without shipping icon assets. Emoji keeps this
// dependency-free; swap for a real icon set later if desired.
const MAP = {
  police: '🚓',
  medical: '🚑',
  taxi: '🚕',
  wrench: '🔧',
  'tow-truck': '🚛',
  bank: '🏛️',
  news: '📰',
}

export default function CategoryIcon({ icon, className }) {
  return <span className={className}>{MAP[icon] || '🏢'}</span>
}
