import React from 'react'
import { api } from '../api'
import DurationBadge from '../components/DurationBadge'
import { parseUTCTimestamp } from '../components/TimeAgo'
import SqlBlock from '../components/SqlBlock'
import OpenInEditor from '../components/OpenInEditor'

export default function RequestDrawer({ requestId }) {
  const [data, setData] = React.useState(null)
  const [loading, setLoading] = React.useState(true)

  React.useEffect(() => {
    api.get(`/requests/${requestId}`).then(setData).finally(() => setLoading(false))
  }, [requestId])

  if (loading) return <div className="text-gray-400">Loading...</div>
  if (!data) return <div className="text-red-400">Request not found</div>

  const r = data.request
  const viewMs = r.view_runtime_ms || 0
  const dbMs = r.db_runtime_ms || 0
  const totalMs = r.duration_ms || 1
  const serviceMs = (data.services || []).reduce((sum, s) => sum + (s.duration_ms || 0), 0)
  const otherMs = Math.max(0, totalMs - viewMs - dbMs - serviceMs)

  const viewPct = (viewMs / totalMs * 100).toFixed(1)
  const dbPct = (dbMs / totalMs * 100).toFixed(1)
  const servicePct = (serviceMs / totalMs * 100).toFixed(1)
  const otherPct = (otherMs / totalMs * 100).toFixed(1)

  let params = null
  if (r.params) {
    try {
      const parsed = typeof r.params === 'string' ? JSON.parse(r.params) : r.params
      if (Object.keys(parsed).length > 0) params = parsed
    } catch { /* ignore */ }
  }

  return (
    <div className="space-y-5">
      {/* Route */}
      <div className="flex items-center gap-2">
        <span className="px-2 py-0.5 text-xs font-bold rounded bg-gray-800 text-white">{r.method}</span>
        <span className="font-mono text-sm">{r.path}</span>
        <span className={`px-2 py-0.5 text-xs rounded font-medium ${r.status < 300 ? 'bg-green-100 text-green-800' : r.status < 400 ? 'bg-blue-100 text-blue-800' : r.status < 500 ? 'bg-yellow-100 text-yellow-800' : 'bg-red-100 text-red-800'}`}>
          {r.status}
        </span>
      </div>

      {/* Metadata grid */}
      <div className="grid grid-cols-2 gap-4">
        <div>
          <div className="text-xs text-gray-500">Total Duration</div>
          <DurationBadge ms={r.duration_ms} />
        </div>
        <div>
          <div className="text-xs text-gray-500">Controller</div>
          <div className="text-sm font-mono">{r.controller}#{r.action}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">Recorded</div>
          <div className="text-sm">{r.recorded_at ? parseUTCTimestamp(r.recorded_at).toLocaleString() : '—'}</div>
        </div>
        {r.request_id && (
          <div>
            <div className="text-xs text-gray-500">Request ID</div>
            <div className="text-sm font-mono truncate">{r.request_id}</div>
          </div>
        )}
      </div>

      {/* Controller source + open in editor */}
      {r.source_file && (
        <div className="flex items-center gap-3 flex-wrap">
          <span className="text-blue-600 font-mono text-sm">
            {r.source_file.replace(/.*\/app\//, 'app/')}:{r.source_line}
          </span>
          <OpenInEditor file={r.source_file} line={r.source_line} />
        </div>
      )}

      {/* Time breakdown bar */}
      <div>
        <div className="text-xs font-semibold text-gray-500 uppercase mb-2">Time Breakdown</div>
        <div className="h-6 w-full rounded overflow-hidden flex text-xs font-medium">
          {viewMs > 0 && (
            <div className="bg-blue-500 text-white flex items-center justify-center" style={{ width: `${Math.max(viewPct, 2)}%` }}>
              {viewPct > 8 ? `View ${viewMs.toFixed(1)}ms` : ''}
            </div>
          )}
          {dbMs > 0 && (
            <div className="bg-amber-500 text-white flex items-center justify-center" style={{ width: `${Math.max(dbPct, 2)}%` }}>
              {dbPct > 8 ? `DB ${dbMs.toFixed(1)}ms` : ''}
            </div>
          )}
          {serviceMs > 0 && (
            <div className="bg-violet-500 text-white flex items-center justify-center" style={{ width: `${Math.max(servicePct, 2)}%` }}>
              {servicePct > 8 ? `Services ${serviceMs.toFixed(1)}ms` : ''}
            </div>
          )}
          {otherMs > 0 && (
            <div className="bg-gray-300 text-gray-700 flex items-center justify-center" style={{ width: `${Math.max(otherPct, 2)}%` }}>
              {otherPct > 8 ? `Other ${otherMs.toFixed(1)}ms` : ''}
            </div>
          )}
        </div>
        <div className="flex gap-4 mt-1.5 text-xs text-gray-500 flex-wrap">
          <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-blue-500 inline-block"></span> View {viewMs.toFixed(1)}ms ({viewPct}%)</span>
          <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-amber-500 inline-block"></span> DB {dbMs.toFixed(1)}ms ({dbPct}%)</span>
          {serviceMs > 0 && <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-violet-500 inline-block"></span> Services {serviceMs.toFixed(1)}ms ({servicePct}%)</span>}
          <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-gray-300 inline-block"></span> Other {otherMs.toFixed(1)}ms ({otherPct}%)</span>
        </div>
      </div>

      {/* Params */}
      {params && (
        <div>
          <div className="text-xs font-semibold text-gray-500 uppercase mb-1.5">Params</div>
          <pre className="bg-gray-100 p-3 rounded text-xs text-gray-700 overflow-x-auto">
            <code>{JSON.stringify(params, null, 2)}</code>
          </pre>
        </div>
      )}

      {/* Services */}
      {data.services && data.services.length > 0 && (
        <div>
          <div className="text-xs font-semibold text-gray-500 uppercase mb-2">
            Services ({data.services.length})
          </div>
          <div className="space-y-2">
            {['http', 'job', 'mailer', 'cache'].map((cat) => {
              const items = data.services.filter((s) => s.category === cat)
              if (items.length === 0) return null
              const catConfig = {
                http: { label: 'HTTP', color: 'bg-violet-100 text-violet-800' },
                job: { label: 'Jobs', color: 'bg-indigo-100 text-indigo-800' },
                mailer: { label: 'Mailer', color: 'bg-pink-100 text-pink-800' },
                cache: { label: 'Cache', color: 'bg-teal-100 text-teal-800' },
              }[cat]
              return (
                <div key={cat}>
                  <div className="flex items-center gap-2 mb-1.5">
                    <span className={`px-2 py-0.5 text-xs font-medium rounded ${catConfig.color}`}>{catConfig.label}</span>
                    <span className="text-xs text-gray-400">{items.length} call{items.length !== 1 ? 's' : ''} · {items.reduce((sum, s) => sum + (s.duration_ms || 0), 0).toFixed(1)}ms</span>
                  </div>
                  {items.map((s) => {
                    let detail = null
                    try { detail = typeof s.detail === 'string' ? JSON.parse(s.detail) : s.detail } catch {}
                    return (
                      <div key={s.id} className="border rounded p-2.5 mb-1.5">
                        <div className="flex items-center gap-2">
                          <DurationBadge ms={s.duration_ms} />
                          <span className="text-sm font-mono truncate">{s.name}</span>
                          {detail?.status && (
                            <span className={`px-1.5 py-0.5 text-xs rounded font-medium ${detail.status < 300 ? 'bg-green-100 text-green-800' : detail.status < 500 ? 'bg-yellow-100 text-yellow-800' : 'bg-red-100 text-red-800'}`}>
                              {detail.status}
                            </span>
                          )}
                        </div>
                        {s.source_file && (
                          <div className="mt-1.5 flex items-center gap-2 flex-wrap">
                            <span className="text-xs font-mono text-blue-600">
                              {s.source_file.replace(/.*\/app\//, 'app/')}:{s.source_line}
                              {s.source_method && <span className="text-gray-400"> in {s.source_method}</span>}
                            </span>
                            <OpenInEditor file={s.source_file} line={s.source_line} />
                          </div>
                        )}
                      </div>
                    )
                  })}
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Queries */}
      {data.queries.length > 0 && (
        <div>
          <div className="text-xs font-semibold text-gray-500 uppercase mb-2">
            Queries ({data.queries.length})
          </div>
          <div className="space-y-2">
            {data.queries.map((q) => (
              <div key={q.id} className="border rounded p-2.5">
                <div className="flex items-center gap-2 mb-1.5">
                  <DurationBadge ms={q.duration_ms} />
                  {q.name && <span className="text-xs text-gray-500">{q.name}</span>}
                  {q.n_plus_one === 1 && <span className="text-xs bg-red-100 text-red-700 px-1.5 py-0.5 rounded font-medium">N+1 ({q.n_plus_one_count}x)</span>}
                </div>
                <SqlBlock sql={q.sql_text} maxLength={200} />
                {q.source_file && (
                  <div className="mt-1.5 flex items-center gap-2 flex-wrap">
                    <span className="text-xs font-mono text-blue-600">
                      {q.source_file.replace(/.*\/app\//, 'app/')}:{q.source_line}
                      {q.source_method && <span className="text-gray-400"> in {q.source_method}</span>}
                    </span>
                    <OpenInEditor file={q.source_file} line={q.source_line} />
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Errors */}
      {data.errors.length > 0 && (
        <div>
          <div className="text-xs font-semibold text-red-600 uppercase mb-2">Errors ({data.errors.length})</div>
          {data.errors.map((e) => (
            <div key={e.id} className="border border-red-200 bg-red-50 rounded p-2.5 mb-2">
              <div className="font-semibold text-red-800 text-sm">{e.exception_class}</div>
              <div className="text-sm text-gray-600 mt-0.5">{e.message}</div>
              {e.source_file && (
                <div className="mt-1.5 flex items-center gap-2 flex-wrap">
                  <span className="text-xs font-mono text-red-600">
                    {e.source_file.replace(/.*\/app\//, 'app/')}:{e.source_line}
                    {e.source_method && <span className="text-gray-400"> in {e.source_method}</span>}
                  </span>
                  <OpenInEditor file={e.source_file} line={e.source_line} />
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
