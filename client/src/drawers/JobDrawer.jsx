import React from 'react'
import { api } from '../api'
import DurationBadge from '../components/DurationBadge'
import { parseUTCTimestamp } from '../components/TimeAgo'
import OpenInEditor from '../components/OpenInEditor'

const statusStyle = (s) =>
  s === 'performed' ? 'bg-green-100 text-green-800'
  : s === 'enqueued' ? 'bg-blue-100 text-blue-800'
  : 'bg-red-100 text-red-800'

const typeColors = {
  query: 'border-amber-300 bg-amber-50',
  http: 'border-violet-300 bg-violet-50',
  cache: 'border-teal-300 bg-teal-50',
  mailer: 'border-pink-300 bg-pink-50',
  job: 'border-indigo-300 bg-indigo-50',
}

const typeBadge = {
  query: { label: 'DB', cls: 'bg-amber-100 text-amber-800' },
  http: { label: 'HTTP', cls: 'bg-violet-100 text-violet-800' },
  cache: { label: 'CACHE', cls: 'bg-teal-100 text-teal-800' },
  mailer: { label: 'MAIL', cls: 'bg-pink-100 text-pink-800' },
  job: { label: 'JOB', cls: 'bg-indigo-100 text-indigo-800' },
}

const timelineColors = {
  query: 'bg-amber-400',
  http: 'bg-violet-400',
  cache: 'bg-teal-400',
  mailer: 'bg-pink-400',
  job: 'bg-indigo-400',
}

function JobTimeline({ totalMs, events }) {
  const timed = events.filter((e) => e.startMs != null)
  if (timed.length === 0) return null

  const sorted = [...timed].sort((a, b) => a.startMs - b.startMs)

  const spans = []
  let cursor = 0

  sorted.forEach((ev) => {
    const start = Math.max(ev.startMs, 0)
    // No gap spans — just show actual events
    spans.push({ ...ev, startMs: start })
    cursor = Math.max(cursor, start + ev.durationMs)
  })

  return (
    <div>
      <div className="text-xs font-semibold text-gray-500 uppercase mb-2">Job Timeline</div>
      <div className="h-5 w-full rounded overflow-hidden bg-gray-100 relative" title={`${totalMs.toFixed(1)}ms total`}>
        {spans.map((s, i) => {
          const leftPct = (s.startMs / totalMs) * 100
          const widthPct = Math.max((s.durationMs / totalMs) * 100, 0.5)
          return (
            <div
              key={i}
              className={`${timelineColors[s.type] || 'bg-gray-400'} absolute h-5 rounded-sm`}
              style={{ left: `${leftPct}%`, width: `${widthPct}%`, minWidth: '2px' }}
              title={`${s.type}: ${s.durationMs.toFixed(1)}ms at ${s.startMs.toFixed(1)}ms${s.label ? ` — ${s.label}` : ''}`}
            />
          )
        })}
      </div>
      <div className="flex gap-3 mt-1.5 text-xs text-gray-500 flex-wrap">
        <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-amber-400 inline-block" /> DB</span>
        <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-violet-400 inline-block" /> HTTP</span>
        <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded bg-teal-400 inline-block" /> Cache</span>
      </div>
    </div>
  )
}

function JobTrace({ events }) {
  if (events.length === 0) return null

  const hasTiming = events.some((e) => e.startMs != null)

  // Sort by timing if available, otherwise by original order
  const sorted = hasTiming
    ? [...events].sort((a, b) => (a.startMs ?? Infinity) - (b.startMs ?? Infinity))
    : events

  return (
    <div>
      <div className="text-xs font-semibold text-gray-500 uppercase mb-2">Trace ({events.length} spans)</div>
      <div className="space-y-1">
        {sorted.map((ev, i) => {
          const badge = typeBadge[ev.type] || { label: ev.type, cls: 'bg-gray-100 text-gray-800' }
          return (
            <div key={i} className={`border rounded px-2.5 py-1.5 min-w-0 ${typeColors[ev.type] || ''}`}>
              <div className="flex items-center gap-2 flex-wrap">
                {ev.startMs != null && (
                  <span className="text-xs text-gray-400 font-mono w-14 shrink-0 text-right">{ev.startMs.toFixed(1)}ms</span>
                )}
                <span className={`px-1.5 py-0.5 text-xs font-bold rounded shrink-0 ${badge.cls}`}>{badge.label}</span>
                <DurationBadge ms={ev.durationMs} />
                <span className="text-xs font-mono text-gray-700 break-all">{ev.label}</span>
              </div>
              {ev.sourceFile && (
                <div className={`mt-1 ${ev.startMs != null ? 'ml-16' : 'ml-0'} flex items-center gap-2 flex-wrap`}>
                  <span className="text-xs font-mono text-blue-600 break-all">
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

export default function JobDrawer({ jobId }) {
  const [data, setData] = React.useState(null)
  const [loading, setLoading] = React.useState(true)

  React.useEffect(() => {
    api.get(`/jobs/${jobId}`).then(setData).finally(() => setLoading(false))
  }, [jobId])

  if (loading) return <div className="text-gray-400">Loading...</div>
  if (!data) return <div className="text-red-400">Job not found</div>

  const j = data.job
  const queries = data.queries || []
  const services = data.services || []
  const totalMs = j.duration_ms || 1

  // Build unified event list
  const timelineEvents = []

  queries.forEach((q) => {
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

  services.forEach((s) => {
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

  const dbMs = queries.reduce((sum, q) => sum + (q.duration_ms || 0), 0)
  const serviceMs = services.reduce((sum, s) => sum + (s.duration_ms || 0), 0)

  return (
    <div className="space-y-5">
      {/* Job class + status */}
      <div className="flex items-center gap-2 flex-wrap">
        <span className="font-mono text-sm font-semibold">{j.job_class}</span>
        <span className={`px-2 py-0.5 text-xs rounded font-medium ${statusStyle(j.status)}`}>
          {j.status}
        </span>
      </div>

      {/* Metadata grid */}
      <div className="grid grid-cols-2 gap-4">
        <div>
          <div className="text-xs text-gray-500">Duration</div>
          {j.duration_ms != null ? <DurationBadge ms={j.duration_ms} /> : <span className="text-sm text-gray-400">—</span>}
        </div>
        <div>
          <div className="text-xs text-gray-500">Queue</div>
          <div className="text-sm font-mono">{j.queue_name || 'default'}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">Job ID</div>
          <div className="text-sm font-mono break-all">{j.job_id || '—'}</div>
        </div>
        <div>
          <div className="text-xs text-gray-500">Recorded</div>
          <div className="text-sm">{j.recorded_at ? parseUTCTimestamp(j.recorded_at).toLocaleString() : '—'}</div>
        </div>
      </div>

      {/* Source */}
      {j.source_file && (
        <div className="flex items-center gap-3 flex-wrap">
          <span className="text-blue-600 font-mono text-sm break-all">
            {j.source_file.replace(/.*\/app\//, 'app/')}:{j.source_line}
          </span>
          <OpenInEditor file={j.source_file} line={j.source_line} />
        </div>
      )}

      {/* Summary counts */}
      {(queries.length > 0 || services.length > 0) && (
        <div className="flex gap-4 text-sm">
          {queries.length > 0 && (
            <span className="text-amber-700 font-medium">{queries.length} {queries.length === 1 ? 'query' : 'queries'} ({dbMs.toFixed(1)}ms)</span>
          )}
          {services.length > 0 && (
            <span className="text-violet-700 font-medium">{services.length} {services.length === 1 ? 'service' : 'services'} ({serviceMs.toFixed(1)}ms)</span>
          )}
        </div>
      )}

      {/* Timeline */}
      <JobTimeline totalMs={totalMs} events={timelineEvents} />

      {/* Trace */}
      <JobTrace events={timelineEvents} />

      {/* Error */}
      {j.error_class && (
        <div>
          <div className="text-xs font-semibold text-red-600 uppercase mb-2">Error</div>
          <div className="border border-red-200 bg-red-50 rounded p-2.5">
            <div className="font-semibold text-red-800 text-sm">{j.error_class}</div>
            <div className="text-sm text-gray-600 mt-0.5">{j.error_message}</div>
          </div>
        </div>
      )}
    </div>
  )
}
