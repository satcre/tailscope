import React from 'react'

const colors = {
  critical: 'bg-red-100 text-red-800',
  warning: 'bg-yellow-100 text-yellow-800',
  info: 'bg-blue-100 text-blue-800',
}

export default function SeverityBadge({ severity }) {
  return (
    <span className={`inline-block px-2 py-0.5 text-xs font-bold rounded ${colors[severity] || 'bg-gray-100 text-gray-800'}`}>
      {String(severity).toUpperCase()}
    </span>
  )
}
