export default function TimeAgo({ timestamp }) {
  if (!timestamp) return <span>—</span>
  const diff = (Date.now() - new Date(timestamp).getTime()) / 1000
  const text = diff < 60 ? `${Math.floor(diff)}s ago`
    : diff < 3600 ? `${Math.floor(diff / 60)}m ago`
    : diff < 86400 ? `${Math.floor(diff / 3600)}h ago`
    : `${Math.floor(diff / 86400)}d ago`
  return <span>{text}</span>
}
