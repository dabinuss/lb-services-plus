// Tiny pub/sub so any screen can report "this action just worked/failed"
// without threading state through App.jsx - deliberately only used after a
// deliberate Save button (a Sheet closing silently used to be the only
// feedback), not on every instant toggle flip, where the switch's own
// visual state already is the feedback.
let listener = null
let hideTimer = null

export function subscribeToast(cb) {
  listener = cb
  return () => {
    if (listener === cb) listener = null
  }
}

export function showToast(message, variant = 'success') {
  if (!listener) return
  clearTimeout(hideTimer)
  listener({ message, variant })
  hideTimer = setTimeout(() => listener?.(null), 2200)
}
