export function formatDuration(seconds?: number | null): string | null {
  if (seconds === null || seconds === undefined || seconds < 0) return null;
  const minutes = Math.floor(seconds / 60);
  const remaining = Math.floor(seconds % 60);
  return minutes > 0 ? `${minutes}m ${remaining}s` : `${remaining}s`;
}
