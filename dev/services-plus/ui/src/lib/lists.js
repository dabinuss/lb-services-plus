export function listCursor(items, { id = 'id', time = 'cursor_time', open = false } = {}) {
  const last = items?.at(-1)
  const cursorTime = last?.[time] ?? last?.created_at ?? last?.updated_at
  if (!last || last[id] == null || cursorTime == null) return null
  return {
    id: Number(last[id]),
    time: cursorTime,
    ...(open ? { open: last.status === 'open' } : {}),
  }
}

export function appendUnique(current, incoming, key) {
  const known = new Set((current || []).map((item) => item[key]))
  return [...(current || []), ...incoming.filter((item) => !known.has(item[key]))]
}

// Refreshing the newest page after a realtime event must not throw away
// already-loaded older pages. Fresh rows win, while older rows retain their
// current order and local UI state.
export function mergeNewestPage(current, incoming, key, removedId = null) {
  const fresh = new Set(incoming.map((item) => item[key]))
  return [
    ...incoming,
    ...(current || []).filter((item) => item[key] !== removedId && !fresh.has(item[key])),
  ]
}
