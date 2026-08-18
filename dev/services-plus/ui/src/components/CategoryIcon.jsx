import Icon from './Icon.jsx'

// Category icons are a plain key (see shared/categories.lua) so admins can
// add new categories later without shipping icon assets. Maps onto the
// app's one shared icon set (see Icon.jsx) instead of its own emoji map, so
// a category icon always matches the vector style used everywhere else.
const MAP = {
  police: 'shield',
  medical: 'medical',
  taxi: 'car',
  wrench: 'wrench',
  'tow-truck': 'towTruck',
  bank: 'bank',
  news: 'news',
}

export default function CategoryIcon({ icon, className, size, strokeWidth }) {
  return <Icon name={MAP[icon] || 'building'} className={className} size={size} strokeWidth={strokeWidth} />
}
