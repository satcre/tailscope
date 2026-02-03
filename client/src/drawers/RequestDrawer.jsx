import React from 'react'
import { api } from '../api'
import DurationBadge from '../components/DurationBadge'
import SqlBlock from '../components/SqlBlock'

export default function RequestDrawer({ requestId }) {
  const [data, setData] = React.useState(null)
  const [loading, setLoading] = React.useState(true)

  React.useEffect(() => {
    api.get(`/requests/${requestId}`).then(setData).finally(() => setLoading(false))
  }, [requestId])

  if (loading) return <div className="text-gray-400">Loading...</div>
  if (!data) return <div className="text-red-400">Request not found</div>

  const r = data.request

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <span className="px-2 py-0.5 text-xs font-bold rounded bg-gray-800 text-white">{r.method}</span>
        <span className="font-mono text-sm">{r.path}</span>
        <span className={`px-2 py-0.5 text-xs rounded font-medium ${r.status < 300 ? 'bg-green-100 text-green-800' : r.status < 400 ? 'bg-blue-100 text-blue-800' : r.status < 500 ? 'bg-yellow-100 text-yellow-800' : 'bg-red-100 text-red-800'}`}>
          {r.status}
        </span>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div>
          <div className="text-xs text-gray-500">Duration</div>
          <DurationBadge ms={r.duration_ms} />
        </div>
        <div>
          <div className="text-xs text-gray-500">Controller</div>
          <div className="text-sm font-mono">{r.controller}#{r.action}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">View</div>
          <div className="text-sm">{r.view_runtime_ms ? `${r.view_runtime_ms.toFixed(1)}ms` : '—'}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">DB</div>
          <div className="text-sm">{r.db_runtime_ms ? `${r.db_runtime_ms.toFixed(1)}ms` : '—'}</div>
        </div>
      </div>

      {data.queries.length > 0 && (
        <div>
          <h3 className="text-sm font-semibold text-gray-700 mb-2">Queries ({data.queries.length})</h3>
          <div className="space-y-2">
            {data.queries.map((q) => (
              <div key={q.id} className="border rounded p-2">
                <div className="flex items-center gap-2 mb-1">
                  <DurationBadge ms={q.duration_ms} />
                  {q.n_plus_one === 1 && <span className="text-xs bg-red-100 text-red-700 px-1 rounded">N+1 ({q.n_plus_one_count}x)</span>}
                </div>
                <SqlBlock sql={q.sql_text} maxLength={150} />
              </div>
            ))}
          </div>
        </div>
      )}

      {data.errors.length > 0 && (
        <div>
          <h3 className="text-sm font-semibold text-red-700 mb-2">Errors ({data.errors.length})</h3>
          {data.errors.map((e) => (
            <div key={e.id} className="border border-red-200 rounded p-2 mb-2">
              <div className="font-semibold text-red-800 text-sm">{e.exception_class}</div>
              <div className="text-sm text-gray-600">{e.message}</div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
