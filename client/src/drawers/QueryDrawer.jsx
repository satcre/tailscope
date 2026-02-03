import React from 'react'
import { api } from '../api'
import DurationBadge from '../components/DurationBadge'
import SqlBlock from '../components/SqlBlock'
import SourceViewer from '../components/SourceViewer'

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

      <table className="w-full text-sm border border-gray-200 rounded overflow-hidden">
        <tbody className="divide-y divide-gray-100">
          <tr>
            <td className="px-3 py-2 text-gray-500 font-medium bg-gray-50 w-28">Duration</td>
            <td className="px-3 py-2"><DurationBadge ms={query.duration_ms} /></td>
          </tr>
          <tr>
            <td className="px-3 py-2 text-gray-500 font-medium bg-gray-50">Name</td>
            <td className="px-3 py-2">{query.name || '—'}</td>
          </tr>
          <tr>
            <td className="px-3 py-2 text-gray-500 font-medium bg-gray-50">Request ID</td>
            <td className="px-3 py-2 font-mono break-all">{query.request_id || '—'}</td>
          </tr>
          <tr>
            <td className="px-3 py-2 text-gray-500 font-medium bg-gray-50">Recorded</td>
            <td className="px-3 py-2">{query.recorded_at}</td>
          </tr>
        </tbody>
      </table>

      {query.n_plus_one === 1 && (
        <div className="bg-red-50 border border-red-200 rounded p-3">
          <span className="text-red-700 font-semibold">N+1 Detected</span>
          <span className="text-red-600 text-sm ml-2">Executed {query.n_plus_one_count} times in a single request</span>
        </div>
      )}

      {query.source_file && (
        <div>
          <div className="text-sm text-gray-500 mb-1">Source</div>
          <SourceViewer file={query.source_file} line={query.source_line} />
        </div>
      )}
    </div>
  )
}
