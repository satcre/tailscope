import React from 'react'
import { api } from '../api'
import DurationBadge from '../components/DurationBadge'
import { parseUTCTimestamp } from '../components/TimeAgo'
import SqlBlock from '../components/SqlBlock'
import OpenInEditor from '../components/OpenInEditor'

function Timeline({ totalMs, events }) {
  if (events.length === 0 || !events.some((e) => e.startMs != null)) return null

  // Build timeline spans: each event + gaps between them
  const sorted = events
    .filter((e) => e.startMs != null)
    .sort((a, b) => a.startMs - b.startMs)

  const spans = []
  let cursor = 0

  sorted.forEach((ev) => {
    const start = Math.max(ev.startMs, 0)
    if (start > cursor + 0.1) {
      spans.push({ type: 'app', startMs: cursor, durationMs: start - cursor })
    }
    spans.push({ ...ev, startMs: start })
    cursor = Math.max(cursor, start + ev.durationMs)
  })

  if (cursor < totalMs - 0.1) {
    spans.push({ type: 'app', startMs: cursor, durationMs: totalMs - cursor })
  }

  const colors = {
    query: 'bg-amber-400',
    view: 'bg-blue-400',
    callback: 'bg-orange-400',
    action: 'bg-cyan-400',
    http: 'bg-violet-400',
    job: 'bg-indigo-400',
    mailer: 'bg-pink-400',
    cache: 'bg-teal-400',
    app: 'bg-emerald-300',
  }

  return (
    <div>
      <div className="text-xs font-semibold text-gray-500 uppercase mb-2">Request Timeline</div>
      <div className="h-5 w-full rounded overflow-hidden flex" title={`${totalMs.toFixed(1)}ms total`}>
        {spans.map((s, i) => {
          const widthPct = Math.max((s.durationMs / totalMs) * 100, 0.5)
          return (
            <div
              key={i}
              className={`${colors[s.type] || 'bg-gray-300'} relative group`}
              style={{ width: `${widthPct}%`, minWidth: s.durationMs > 0 ? '2px' : '0' }}
              title={`${s.type}: ${s.durationMs.toFixed(1)}ms at ${s.startMs.toFixed(1)}ms${s.label ? ` — ${s.label}` : ''}`}
            />
          )
        })}
      </div>
      <div className="flex gap-3 mt-1.5 text-xs text-gray-500 flex-wrap">
        <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-blue-400 inline-block" /> View</span>
        <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-amber-400 inline-block" /> DB</span>
        <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-cyan-400 inline-block" /> Action</span>
        <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-orange-400 inline-block" /> Callback</span>
        <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-violet-400 inline-block" /> HTTP</span>
        <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-emerald-300 inline-block" /> App Code</span>
      </div>
    </div>
  )
}

function TraceList({ totalMs, events }) {
  if (events.length === 0 || !events.some((e) => e.startMs != null)) return null

  const sorted = events
    .filter((e) => e.startMs != null)
    .sort((a, b) => a.startMs - b.startMs)

  // Build full trace with gaps
  const trace = []
  let cursor = 0

  sorted.forEach((ev) => {
    const start = Math.max(ev.startMs, 0)
    if (start > cursor + 0.5) {
      trace.push({ type: 'app', startMs: cursor, durationMs: start - cursor })
    }
    trace.push(ev)
    cursor = Math.max(cursor, start + ev.durationMs)
  })

  if (cursor < totalMs - 0.5) {
    trace.push({ type: 'app', startMs: cursor, durationMs: totalMs - cursor })
  }

  const typeColors = {
    query: 'border-amber-300 bg-amber-50',
    view: 'border-blue-300 bg-blue-50',
    callback: 'border-orange-300 bg-orange-50',
    action: 'border-cyan-300 bg-cyan-50',
    http: 'border-violet-300 bg-violet-50',
    job: 'border-indigo-300 bg-indigo-50',
    mailer: 'border-pink-300 bg-pink-50',
    cache: 'border-teal-300 bg-teal-50',
    app: 'border-emerald-300 bg-emerald-50',
  }

  const typeBadge = {
    query: { label: 'DB', cls: 'bg-amber-100 text-amber-800' },
    view: { label: 'VIEW', cls: 'bg-blue-100 text-blue-800' },
    callback: { label: 'CB', cls: 'bg-orange-100 text-orange-800' },
    action: { label: 'ACTION', cls: 'bg-cyan-100 text-cyan-800' },
    http: { label: 'HTTP', cls: 'bg-violet-100 text-violet-800' },
    job: { label: 'JOB', cls: 'bg-indigo-100 text-indigo-800' },
    mailer: { label: 'MAIL', cls: 'bg-pink-100 text-pink-800' },
    cache: { label: 'CACHE', cls: 'bg-teal-100 text-teal-800' },
    app: { label: 'APP', cls: 'bg-emerald-100 text-emerald-800' },
  }

  return (
    <div>
      <div className="text-xs font-semibold text-gray-500 uppercase mb-2">Trace ({trace.length} spans)</div>
      <div className="space-y-1">
        {trace.map((ev, i) => {
          const badge = typeBadge[ev.type] || { label: ev.type, cls: 'bg-gray-100 text-gray-800' }
          return (
            <div key={i} className={`border rounded px-2.5 py-1.5 ${typeColors[ev.type] || ''}`}>
              <div className="flex items-center gap-2">
                <span className="text-xs text-gray-400 font-mono w-14 shrink-0 text-right">{ev.startMs.toFixed(1)}ms</span>
                <span className={`px-1.5 py-0.5 text-xs font-bold rounded ${badge.cls}`}>{badge.label}</span>
                <DurationBadge ms={ev.durationMs} />
                {ev.type === 'app' ? (
                  <span className="text-xs text-emerald-700 italic">
                    Application code (controller, callbacks, Ruby)
                    {ev.sourceFile && <> — {ev.sourceFile.replace(/.*\/app\//, 'app/')}</>}
                  </span>
                ) : (
                  <span className="text-xs font-mono text-gray-700 truncate">{ev.label}</span>
                )}
              </div>
              {ev.sourceFile && ev.type !== 'app' && (
                <div className="mt-1 ml-16 flex items-center gap-2">
                  <span className="text-xs font-mono text-blue-600">
                    {ev.sourceFile.replace(/.*\/app\//, 'app/')}:{ev.sourceLine}
                    {ev.sourceMethod && <span className="text-gray-400"> in {ev.sourceMethod}</span>}
                  </span>
                  <OpenInEditor file={ev.sourceFile} line={ev.sourceLine} />
                </div>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}

export default function RequestDrawer({ requestId }) {
  const [data, setData] = React.useState(null)
  const [loading, setLoading] = React.useState(true)

  React.useEffect(() => {
    api.get(`/requests/${requestId}`).then(setData).finally(() => setLoading(false))
  }, [requestId])

  if (loading) return <div className="text-gray-400">Loading...</div>
  if (!data) return <div className="text-red-400">Request not found</div>

  const r = data.request
  const totalMs = r.duration_ms || 1

  // Build unified event list with timing offsets
  const timelineEvents = []

  ;(data.queries || []).forEach((q) => {
    timelineEvents.push({
      type: 'query',
      startMs: q.started_at_ms,
      durationMs: q.duration_ms || 0,
      label: `${q.name || 'SQL'}: ${(q.sql_text || '').slice(0, 80)}`,
      sourceFile: q.source_file,
      sourceLine: q.source_line,
      sourceMethod: q.source_method,
    })
  })

  ;(data.services || []).forEach((s) => {
    timelineEvents.push({
      type: s.category,
      startMs: s.started_at_ms,
      durationMs: s.duration_ms || 0,
      label: s.name,
      sourceFile: s.source_file,
      sourceLine: s.source_line,
      sourceMethod: s.source_method,
    })
  })

  // Compute breakdown from actual recorded data
  const views = (data.services || []).filter((s) => s.category === 'view')
  const callbacks = (data.services || []).filter((s) => s.category === 'callback')
  const actions = (data.services || []).filter((s) => s.category === 'action')
  const otherServices = (data.services || []).filter((s) => s.category !== 'view' && s.category !== 'callback' && s.category !== 'action')

  const actualDbMs = (data.queries || []).reduce((sum, q) => sum + (q.duration_ms || 0), 0)
  const actualViewMs = views.reduce((sum, s) => sum + (s.duration_ms || 0), 0)
  const callbackMs = callbacks.reduce((sum, s) => sum + (s.duration_ms || 0), 0)
  const actionMs = actions.reduce((sum, s) => sum + (s.duration_ms || 0), 0)
  const serviceMs = otherServices.reduce((sum, s) => sum + (s.duration_ms || 0), 0)
  const appMs = Math.max(0, totalMs - actualViewMs - actualDbMs - callbackMs - actionMs - serviceMs)

  const pct = (ms) => (ms / totalMs * 100).toFixed(1)

  let params = null
  if (r.params) {
    try {
      const parsed = typeof r.params === 'string' ? JSON.parse(r.params) : r.params
      if (Object.keys(parsed).length > 0) params = parsed
    } catch { /* ignore */ }
  }

  const segments = [
    { label: 'View', ms: actualViewMs, pct: pct(actualViewMs), color: 'bg-blue-500', dot: 'bg-blue-500' },
    { label: 'DB', ms: actualDbMs, pct: pct(actualDbMs), color: 'bg-amber-500', dot: 'bg-amber-500' },
    { label: 'Action', ms: actionMs, pct: pct(actionMs), color: 'bg-cyan-500', dot: 'bg-cyan-500', hide: actionMs === 0 },
    { label: 'Callbacks', ms: callbackMs, pct: pct(callbackMs), color: 'bg-orange-500', dot: 'bg-orange-500', hide: callbackMs === 0 },
    { label: 'Services', ms: serviceMs, pct: pct(serviceMs), color: 'bg-violet-500', dot: 'bg-violet-500', hide: serviceMs === 0 },
    { label: 'App Code', ms: appMs, pct: pct(appMs), color: 'bg-emerald-500', dot: 'bg-emerald-500' },
  ].filter((s) => !s.hide)

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
          {segments.map((s) => s.ms > 0 && (
            <div key={s.label} className={`${s.color} text-white flex items-center justify-center`} style={{ width: `${Math.max(s.pct, 2)}%` }}>
              {s.pct > 8 ? `${s.label} ${s.ms.toFixed(1)}ms` : ''}
            </div>
          ))}
        </div>
        <div className="flex gap-4 mt-1.5 text-xs text-gray-500 flex-wrap">
          {segments.map((s) => (
            <span key={s.label} className="flex items-center gap-1">
              <span className={`w-2.5 h-2.5 rounded ${s.dot} inline-block`}></span>
              {s.label} {s.ms.toFixed(1)}ms ({s.pct}%)
            </span>
          ))}
        </div>
      </div>

      {/* Waterfall timeline */}
      <Timeline totalMs={totalMs} events={timelineEvents} />

      {/* Full trace */}
      <TraceList totalMs={totalMs} events={timelineEvents} />

      {/* Params */}
      {params && (
        <div>
          <div className="text-xs font-semibold text-gray-500 uppercase mb-1.5">Params</div>
          <pre className="bg-gray-100 p-3 rounded text-xs text-gray-700 overflow-x-auto">
            <code>{JSON.stringify(params, null, 2)}</code>
          </pre>
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
