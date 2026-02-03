// SQLite datetime('now') returns "2026-02-03 10:48:27" (UTC, no timezone).
// Convert to valid ISO 8601 by replacing space with T and appending Z.
export function parseUTCTimestamp(timestamp) {
  if (!timestamp) return null
  const iso = timestamp.replace(' ', 'T').replace(/T(\d)/, 'T$1')
  return new Date(iso.endsWith('Z') ? iso : iso + 'Z')
}

export default function TimeAgo({ timestamp }) {
  if (!timestamp) return <span>—</span>
  const date = parseUTCTimestamp(timestamp)
  if (!date || isNaN(date.getTime())) return <span>—</span>
  const diff = (Date.now() - date.getTime()) / 1000
  if (diff < 0) return <span>just now</span>
  const text = diff < 60 ? `${Math.floor(diff)}s ago`
    : diff < 3600 ? `${Math.floor(diff / 60)}m ago`
    : diff < 86400 ? `${Math.floor(diff / 3600)}h ago`
    : `${Math.floor(diff / 86400)}d ago`
  return <span>{text}</span>
}
