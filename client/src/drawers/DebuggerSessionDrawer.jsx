import React from 'react'
import { api } from '../api'
import { useHighlightedLines, HighlightedCode } from '../components/HighlightedLine'
import OpenInEditor from '../components/OpenInEditor'

function HighlightedSource({ lines, file }) {
  const highlightedLines = useHighlightedLines(lines, file)
  return (
    <div className="bg-gray-900 rounded overflow-x-auto">
      <table className="text-sm font-mono w-full">
        <tbody>
          {lines.map((l, i) => (
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
  )
}

export default function DebuggerSessionDrawer({ sessionId, onSessionUpdate }) {
  const [session, setSession] = React.useState(null)
  const [loading, setLoading] = React.useState(true)
  const [expression, setExpression] = React.useState('')
  const [evaluating, setEvaluating] = React.useState(false)
  const replEndRef = React.useRef(null)

  const loadSession = React.useCallback(() => {
    api.get(`/debugger/sessions/${sessionId}`).then((d) => setSession(d.session)).catch(() => setSession(null)).finally(() => setLoading(false))
  }, [sessionId])

  React.useEffect(() => {
    loadSession()
    const interval = setInterval(loadSession, 2000)
    return () => clearInterval(interval)
  }, [loadSession])

  React.useEffect(() => {
    replEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [session?.eval_history?.length])

  const evaluate = async (e) => {
    e.preventDefault()
    if (!expression.trim()) return
    setEvaluating(true)
    await api.post(`/debugger/sessions/${sessionId}/evaluate`, { expression })
    setExpression('')
    setEvaluating(false)
    loadSession()
  }

  const stepAction = async (action) => {
    await api.post(`/debugger/sessions/${sessionId}/${action}`)
    loadSession()
    onSessionUpdate?.()
  }

  if (loading) return <div className="text-gray-400">Loading...</div>
  if (!session) return <div className="text-red-400">Session not found</div>

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-3">
        <span className={`px-2 py-0.5 text-xs rounded font-medium ${session.paused ? 'bg-yellow-100 text-yellow-800' : 'bg-gray-100 text-gray-600'}`}>
          {session.status}
        </span>
        <span className="text-sm text-gray-600 font-mono">
          {session.file.replace(/.*\/(app\/)/, '$1')}:{session.line}
        </span>
        <OpenInEditor file={session.file} line={session.line} />
        <span className="text-sm text-gray-400">in {session.method_name}</span>
      </div>

      {session.paused && (
        <div className="flex gap-2">
          <button onClick={() => stepAction('continue')} className="px-3 py-1 text-sm bg-green-600 text-white rounded hover:bg-green-700">Continue</button>
          <button onClick={() => stepAction('step_into')} className="px-3 py-1 text-sm bg-gray-800 text-white rounded hover:bg-gray-700">Step Into</button>
          <button onClick={() => stepAction('step_over')} className="px-3 py-1 text-sm bg-gray-800 text-white rounded hover:bg-gray-700">Step Over</button>
          <button onClick={() => stepAction('step_out')} className="px-3 py-1 text-sm bg-gray-800 text-white rounded hover:bg-gray-700">Step Out</button>
        </div>
      )}

      {/* Source */}
      <div>
        <h3 className="text-sm font-semibold text-gray-700 mb-2">Source</h3>
        {session.source_context && (
          <HighlightedSource lines={session.source_context} file={session.file} />
        )}
      </div>

      {/* REPL */}
      <div>
        <h3 className="text-sm font-semibold text-gray-700 mb-2">Evaluate</h3>
        <div className="bg-gray-900 rounded p-3 max-h-48 overflow-y-auto mb-2">
          {(!session.eval_history || session.eval_history.length === 0) ? (
            <div className="text-gray-500 text-sm font-mono">No evaluations yet.</div>
          ) : (
            session.eval_history.map((entry, i) => (
              <div key={i} className="mb-2 font-mono text-sm">
                <div className="text-blue-400">&gt; {entry.expression}</div>
                <div className={entry.error ? 'text-red-400' : 'text-green-400'}>{entry.error || entry.result}</div>
              </div>
            ))
          )}
          <div ref={replEndRef} />
        </div>
        {session.paused && (
          <form onSubmit={evaluate} className="flex gap-2">
            <input
              value={expression}
              onChange={(e) => setExpression(e.target.value)}
              placeholder="Ruby expression..."
              className="flex-1 border rounded px-3 py-1 text-sm font-mono"
              disabled={evaluating}
            />
            <button type="submit" disabled={evaluating} className="px-3 py-1 bg-gray-900 text-white rounded text-sm hover:bg-gray-700 disabled:opacity-50">
              {evaluating ? '...' : 'Eval'}
            </button>
          </form>
        )}
      </div>

      {/* Local Variables */}
      <div>
        <h3 className="text-sm font-semibold text-gray-700 mb-2">Local Variables</h3>
        {session.local_variables && Object.keys(session.local_variables).length > 0 ? (
          <div className="bg-gray-50 rounded p-3 space-y-1">
            {Object.entries(session.local_variables).map(([name, value]) => (
              <div key={name} className="text-sm font-mono">
                <span className="text-purple-700">{name}</span>
                <span className="text-gray-400"> = </span>
                <span className="text-gray-700">{value}</span>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-sm text-gray-400">No locals</p>
        )}
      </div>

      {/* Call Stack */}
      <div>
        <h3 className="text-sm font-semibold text-gray-700 mb-2">Call Stack</h3>
        {session.call_stack && session.call_stack.length > 0 ? (
          <div className="space-y-1">
            {session.call_stack.map((frame, i) => {
              const label = typeof frame === 'string' ? frame : `${(frame.file || '').replace(/.*\/(app\/)/, '$1')}:${frame.line} in ${frame.method}`
              const frameFile = typeof frame === 'object' ? frame.file : null
              const frameLine = typeof frame === 'object' ? frame.line : null
              return (
                <div key={i} className={`text-xs font-mono py-1 px-2 rounded flex items-center gap-1 ${i === 0 ? 'bg-yellow-50 text-yellow-800' : 'text-gray-600'}`}>
                  <span className="flex-1 truncate">{label}</span>
                  {frameFile && <OpenInEditor file={frameFile} line={frameLine} />}
                </div>
              )
            })}
          </div>
        ) : (
          <p className="text-sm text-gray-400">No call stack</p>
        )}
      </div>
    </div>
  )
}
