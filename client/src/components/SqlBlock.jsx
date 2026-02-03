import React from 'react'

export default function SqlBlock({ sql, maxLength = null }) {
  if (!sql) return null
  const display = maxLength && sql.length > maxLength ? sql.slice(0, maxLength) + '...' : sql

  return (
    <pre className="bg-gray-800 text-green-300 p-2 rounded text-xs overflow-x-auto">
      <code>{display}</code>
    </pre>
  )
}
