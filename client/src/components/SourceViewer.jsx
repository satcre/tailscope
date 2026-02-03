import React from 'react'
import { api } from '../api'
import { useHighlightedLines, HighlightedCode } from './HighlightedLine'
import OpenInEditor from './OpenInEditor'
import OpenInDebugger from './OpenInDebugger'

export default function SourceViewer({ file, line }) {
  const [source, setSource] = React.useState(null)
  const [loading, setLoading] = React.useState(true)

  React.useEffect(() => {
    if (!file || !line) return
    setLoading(true)
    api.get(`/source?file=${encodeURIComponent(file)}&line=${line}`)
      .then(setSource)
      .catch(() => setSource(null))
      .finally(() => setLoading(false))
  }, [file, line])

  const highlightedLines = useHighlightedLines(source?.lines || [], file)

  if (!file) return null
  if (loading) return <div className="text-sm text-gray-400">Loading source...</div>
  if (!source) return <div className="text-sm text-red-400">Could not load source</div>

  return (
    <div>
      <div className="flex items-center justify-between mb-1">
        <div className="text-xs text-gray-500 font-mono">{source.short_path}</div>
        <div className="flex items-center gap-1">
          <OpenInEditor file={file} line={line} />
          <OpenInDebugger file={file} line={line} />
        </div>
      </div>
      <div className="bg-gray-900 rounded overflow-x-auto">
        <table className="text-sm font-mono w-full">
          <tbody>
            {source.lines.map((l, i) => (
              <tr key={l.number} className={l.current ? 'bg-yellow-900/30' : ''}>
                <td className="px-3 py-0.5 text-right text-gray-500 select-none w-12 border-r border-gray-700">
                  {l.number}
                </td>
                <td className="px-3 py-0.5 text-gray-300 whitespace-pre"><HighlightedCode html={highlightedLines[i] || l.content} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
