import React from 'react'

export default function DurationBadge({ ms }) {
  if (ms == null) return null
  const color = ms >= 1000 ? 'bg-red-100 text-red-800'
    : ms >= 500 ? 'bg-yellow-100 text-yellow-800'
    : ms >= 100 ? 'bg-orange-100 text-orange-800'
    : 'bg-green-100 text-green-800'

  return (
    <span className={`inline-block px-2 py-0.5 text-xs font-medium rounded ${color}`}>
      {ms.toFixed(1)}ms
    </span>
  )
}
