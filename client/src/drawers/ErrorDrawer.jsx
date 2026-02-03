import React from 'react'
import { api } from '../api'
import SourceViewer from '../components/SourceViewer'
import OpenInEditor from '../components/OpenInEditor'
import OpenInDebugger from '../components/OpenInDebugger'

export default function ErrorDrawer({ errorId }) {
  const [error, setError] = React.useState(null)
  const [loading, setLoading] = React.useState(true)

  React.useEffect(() => {
    api.get(`/errors/${errorId}`).then((d) => setError(d.error)).finally(() => setLoading(false))
  }, [errorId])

  if (loading) return <div className="text-gray-400">Loading...</div>
  if (!error) return <div className="text-red-400">Error not found</div>

  const backtrace = error.backtrace ? error.backtrace.split('\n') : []

  return (
    <div className="space-y-4">
      <div>
        <div className="text-xl font-bold text-red-800">{error.exception_class}</div>
        <div className="text-sm text-gray-600 mt-1">{error.message}</div>
      </div>

      <div className="grid grid-cols-2 gap-4 text-sm">
        <div>
          <div className="text-xs text-gray-500">Request</div>
          <div>{error.request_method} {error.request_path || '—'}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">Recorded</div>
          <div>{error.recorded_at}</div>
        </div>
      </div>

      {backtrace.length > 0 && (
        <div>
          <div className="text-sm font-semibold text-gray-700 mb-1">Backtrace</div>
          <pre className="bg-gray-100 p-3 rounded text-xs text-gray-600 overflow-x-auto max-h-60">
            <code>{backtrace.join('\n')}</code>
          </pre>
        </div>
      )}

      {error.source_file && (
        <div>
          <div className="text-sm font-semibold text-gray-700 mb-1 flex items-center gap-1">
            Source
            <span className="inline-flex items-center gap-1 ml-auto">
              <OpenInEditor file={error.source_file} line={error.source_line} />
              <OpenInDebugger file={error.source_file} line={error.source_line} />
            </span>
          </div>
          <SourceViewer file={error.source_file} line={error.source_line} />
        </div>
      )}
    </div>
  )
}
