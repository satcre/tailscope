import React from 'react'
import { api } from '../api'
import { useHighlightedLines, HighlightedCode } from './HighlightedLine'
import OpenInEditor from './OpenInEditor'
import OpenInDebugger from './OpenInDebugger'

const sourceCache = {}

function coverageClass(coverage, lineNumber) {
  if (!coverage) return ''
  const val = coverage[lineNumber - 1]
  if (val === null || val === undefined) return ''
  return val > 0 ? 'bg-green-900/20' : 'bg-red-900/30'
}

export default function SourceViewer({ file, line, full, coverage }) {
  const [source, setSource] = React.useState(null)
  const [loading, setLoading] = React.useState(true)

  React.useEffect(() => {
    if (!file || !line) return
    const fullParam = full ? '&full=1' : ''
    const cacheKey = `${file}:${line}:${full ? 1 : 0}`
    if (sourceCache[cacheKey]) {
      setSource(sourceCache[cacheKey])
      setLoading(false)
      return
    }
    setLoading(true)
    api.get(`/source?file=${encodeURIComponent(file)}&line=${line}${fullParam}`)
      .then((data) => { sourceCache[cacheKey] = data; setSource(data) })
      .catch(() => setSource(null))
      .finally(() => setLoading(false))
  }, [file, line, full])

  const highlightedLines = useHighlightedLines(source?.lines || [], file)

  if (!file) return null
  if (loading) return <div className="text-sm text-gray-400">Loading source...</div>
  if (!source) return <div className="text-sm text-red-400">Could not load source</div>

  return (
    <div className="flex flex-col h-full">
      <div className="flex items-center justify-between mb-1 shrink-0">
        <div className="text-xs text-gray-500 font-mono">{source.short_path}</div>
        <div className="flex items-center gap-1">
          <OpenInEditor file={file} line={line} />
          <OpenInDebugger file={file} line={line} />
        </div>
      </div>
      <div className="bg-gray-900 rounded overflow-y-auto flex-1">
        <table className="text-sm font-mono w-full">
          <tbody>
            {source.lines.map((l, i) => (
              <tr key={l.number} className={l.current ? 'bg-yellow-900/30' : coverageClass(coverage, l.number)}>
                <td className="px-3 py-0.5 text-right text-gray-500 select-none w-12 border-r border-gray-700">
                  {l.number}
                </td>
                <td className="px-3 py-0.5 text-gray-300 whitespace-pre-wrap break-all"><HighlightedCode html={highlightedLines[i] || l.content} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
