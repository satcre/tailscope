import React from 'react'
import { api } from '../api'
import DurationBadge from '../components/DurationBadge'
import SqlBlock from '../components/SqlBlock'
import SourceViewer from '../components/SourceViewer'
import OpenInEditor from '../components/OpenInEditor'
import OpenInDebugger from '../components/OpenInDebugger'

export default function QueryDrawer({ queryId }) {
  const [query, setQuery] = React.useState(null)
  const [loading, setLoading] = React.useState(true)

  React.useEffect(() => {
    api.get(`/queries/${queryId}`)
      .then((d) => setQuery(d.query))
      .finally(() => setLoading(false))
  }, [queryId])

  if (loading) return <div className="text-gray-400">Loading...</div>
  if (!query) return <div className="text-red-400">Query not found</div>

  return (
    <div className="space-y-4">
      <div>
        <div className="text-sm text-gray-500 mb-1">SQL</div>
        <SqlBlock sql={query.sql_text} />
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div>
          <div className="text-xs text-gray-500">Duration</div>
          <DurationBadge ms={query.duration_ms} />
        </div>
        <div>
          <div className="text-xs text-gray-500">Name</div>
          <div className="text-sm">{query.name || '—'}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">Request ID</div>
          <div className="text-sm font-mono truncate">{query.request_id || '—'}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">Recorded</div>
          <div className="text-sm">{query.recorded_at}</div>
        </div>
      </div>

      {query.n_plus_one === 1 && (
        <div className="bg-red-50 border border-red-200 rounded p-3">
          <span className="text-red-700 font-semibold">N+1 Detected</span>
          <span className="text-red-600 text-sm ml-2">Executed {query.n_plus_one_count} times in a single request</span>
        </div>
      )}

      {query.source_file && (
        <div>
          <div className="text-sm text-gray-500 mb-1 flex items-center gap-1">
            Source
            <span className="inline-flex items-center gap-1 ml-auto">
              <OpenInEditor file={query.source_file} line={query.source_line} />
              <OpenInDebugger file={query.source_file} line={query.source_line} />
            </span>
          </div>
          <SourceViewer file={query.source_file} line={query.source_line} />
        </div>
      )}
    </div>
  )
}
