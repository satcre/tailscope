import React from 'react'

export default function SuggestedFix({ text }) {
  if (!text) return null

  // Split on backtick-wrapped segments, render as <code>
  const parts = text.split(/(`[^`]+`)/)
  const rendered = parts.map((part, i) => {
    if (part.startsWith('`') && part.endsWith('`')) {
      return (
        <code key={i} className="px-1 py-0.5 bg-gray-200 text-gray-800 rounded text-xs font-mono">
          {part.slice(1, -1)}
        </code>
      )
    }
    // Split on newlines
    return part.split('\n').map((line, j) => (
      <React.Fragment key={`${i}-${j}`}>
        {j > 0 && <br />}
        {line}
      </React.Fragment>
    ))
  })

  return <div className="text-sm text-gray-800 leading-relaxed">{rendered}</div>
}
