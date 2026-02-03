import React from 'react'

export default function SuggestedFix({ text }) {
  if (!text) return null

  const lines = text.split('\n')
  const elements = []
  let i = 0

  while (i < lines.length) {
    const line = lines[i]

    // Check if this line is a standalone code line (entire line is backtick-wrapped)
    const trimmed = line.trim()
    if (trimmed.startsWith('`') && trimmed.endsWith('`') && trimmed.length > 2) {
      // Collect consecutive code-only lines into a single block
      const codeLines = []
      while (i < lines.length) {
        const t = lines[i].trim()
        if (t.startsWith('`') && t.endsWith('`') && t.length > 2) {
          codeLines.push(t.slice(1, -1))
          i++
        } else {
          break
        }
      }

      if (codeLines.length > 1) {
        // Render as a single code block
        elements.push(
          <pre key={`block-${i}`} className="my-2 p-3 bg-gray-800 text-gray-200 rounded text-xs font-mono overflow-x-auto">
            <code>{codeLines.join('\n')}</code>
          </pre>
        )
      } else {
        // Single code line — render inline
        elements.push(
          <code key={`code-${i}`} className="px-1 py-0.5 bg-gray-200 text-gray-800 rounded text-xs font-mono">
            {codeLines[0]}
          </code>
        )
      }
      continue
    }

    // Regular text line — may contain inline backtick spans
    const parts = line.split(/(`[^`]+`)/)
    const rendered = parts.map((part, j) => {
      if (part.startsWith('`') && part.endsWith('`')) {
        return (
          <code key={`${i}-${j}`} className="px-1 py-0.5 bg-gray-200 text-gray-800 rounded text-xs font-mono">
            {part.slice(1, -1)}
          </code>
        )
      }
      return <React.Fragment key={`${i}-${j}`}>{part}</React.Fragment>
    })

    if (i > 0) elements.push(<br key={`br-${i}`} />)
    elements.push(<React.Fragment key={`line-${i}`}>{rendered}</React.Fragment>)
    i++
  }

  return <div className="text-sm text-gray-800 leading-relaxed">{elements}</div>
}
