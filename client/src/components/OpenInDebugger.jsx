import React from 'react'
import { useNavigate } from 'react-router-dom'

export default function OpenInDebugger({ file, line }) {
  const navigate = useNavigate()

  if (!file) return null

  const handleClick = (e) => {
    e.stopPropagation()
    e.preventDefault()
    const params = new URLSearchParams({ file })
    if (line) params.set('line', line)
    navigate(`/debugger?${params}`)
  }

  return (
    <button
      onClick={handleClick}
      className="inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded border transition-colors border-yellow-300 bg-white text-yellow-700 hover:bg-yellow-50 hover:border-yellow-400"
      title={`Open ${file}${line ? `:${line}` : ''} in debugger`}
    >
      <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      Open in debugger
    </button>
  )
}
