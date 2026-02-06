import React from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api'
import SeverityBadge from '../components/SeverityBadge'
import TimeAgo from '../components/TimeAgo'
import Drawer from '../components/Drawer'
import IssueDrawer from '../drawers/IssueDrawer'

const typeBadges = {
  n_plus_one: { label: 'N+1', cls: 'bg-purple-100 text-purple-800' },
  slow_query: { label: 'Query', cls: 'bg-blue-100 text-blue-800' },
  slow_request: { label: 'Request', cls: 'bg-green-100 text-green-800' },
  code_smell: { label: 'Code Smell', cls: 'bg-orange-100 text-orange-800' },
}

export default function Issues() {
  const [searchParams, setSearchParams] = useSearchParams()
  const tab = searchParams.get('tab') || 'active'
  const filter = searchParams.get('severity')
  const typeFilter = searchParams.get('type')
  const page = parseInt(searchParams.get('page') || '1', 10)
  const [data, setData] = React.useState(null)
  const [loading, setLoading] = React.useState(true)
  const [rescanning, setRescanning] = React.useState(false)
  const [selectedIssue, setSelectedIssue] = React.useState(null)
  const [selectedFingerprints, setSelectedFingerprints] = React.useState(new Set())
  const [bulkIgnoring, setBulkIgnoring] = React.useState(false)

  const loadData = React.useCallback((isRescan = false) => {
    if (isRescan) {
      setRescanning(true)
    } else {
      setLoading(true)
    }
    const p = new URLSearchParams()
    if (tab === 'ignored') p.set('tab', 'ignored')
    if (filter) p.set('severity', filter)
    if (typeFilter) p.set('type', typeFilter)
    p.set('page', page.toString())
    p.set('per_page', '20')
    api.get(`/issues?${p}`).then(setData).finally(() => {
      setLoading(false)
      setRescanning(false)
    })
  }, [tab, filter, typeFilter, page])

  React.useEffect(() => { loadData() }, [loadData])

  const handleIgnore = async (fp) => {
    await api.post(`/issues/${fp}/ignore`)
    setSelectedIssue(null)
    loadData()
  }

  const handleUnignore = async (fp) => {
    await api.post(`/issues/${fp}/unignore`)
    setSelectedIssue(null)
    loadData()
  }

  const handleRescan = () => {
    loadData(true)
  }

  const toggleSelection = (fingerprint) => {
    setSelectedFingerprints((prev) => {
      const next = new Set(prev)
      if (next.has(fingerprint)) {
        next.delete(fingerprint)
      } else {
        next.add(fingerprint)
      }
      return next
    })
  }

  const toggleSelectAll = () => {
    if (selectedFingerprints.size === issues.length) {
      setSelectedFingerprints(new Set())
    } else {
      setSelectedFingerprints(new Set(issues.map((i) => i.fingerprint)))
    }
  }

  const handleBulkIgnore = async () => {
    if (selectedFingerprints.size === 0) return
    setBulkIgnoring(true)
    try {
      await api.post('/issues/bulk_ignore', {
        fingerprints: Array.from(selectedFingerprints)
      })
      setSelectedFingerprints(new Set())
      loadData()
    } catch (e) {
      console.error('Bulk ignore failed:', e)
      alert('Failed to ignore selected issues')
    } finally {
      setBulkIgnoring(false)
    }
  }

  const changePage = (newPage) => {
    const params = {}
    if (tab === 'ignored') params.tab = 'ignored'
    if (filter) params.severity = filter
    if (typeFilter) params.type = typeFilter
    if (newPage > 1) params.page = newPage.toString()
    setSearchParams(params)
  }

  const isIgnored = tab === 'ignored'

  if (loading && !data) return <div className="text-gray-400">Loading...</div>
  if (!data) return <div className="text-red-400">Failed to load issues</div>

  const { issues, counts, ignored_count, pagination } = data
  const { total_count = 0, total_pages = 0 } = pagination || {}

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">Issues</h1>
        <button
          onClick={handleRescan}
          disabled={rescanning || loading}
          className="px-4 py-2 text-sm rounded bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
        >
          {rescanning ? (
            <>
              <svg className="w-4 h-4 animate-spin" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="8" cy="8" r="6" strokeDasharray="30" strokeDashoffset="10" strokeLinecap="round" />
              </svg>
              Rescanning...
            </>
          ) : (
            <>
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              Rescan Code
            </>
          )}
        </button>
      </div>

      {!isIgnored && (
        <div className="grid grid-cols-3 gap-4 mb-6">
          {[['critical', 'red'], ['warning', 'yellow'], ['info', 'blue']].map(([sev, color]) => (
            <div key={sev} className="bg-white rounded-lg shadow p-4 text-center">
              <div className={`text-3xl font-bold text-${color}-600`}>{counts[sev]}</div>
              <div className="text-sm text-gray-500 capitalize">{sev}</div>
            </div>
          ))}
        </div>
      )}

      <div className="mb-6 space-y-3">
        <div className="flex gap-2 flex-wrap">
          <button
            onClick={() => setSearchParams({})}
            className={`px-3 py-1 text-sm rounded ${!filter && !isIgnored && !typeFilter ? 'bg-gray-900 text-white' : 'bg-gray-200 text-gray-700'}`}
          >
            All ({total_count})
          </button>
          {!isIgnored && ['critical', 'warning', 'info'].map((sev) => {
            const colors = { critical: 'bg-red-600', warning: 'bg-yellow-600', info: 'bg-blue-600' }
            return (
              <button
                key={sev}
                onClick={() => setSearchParams({ severity: sev })}
                className={`px-3 py-1 text-sm rounded ${filter === sev ? `${colors[sev]} text-white` : 'bg-gray-200 text-gray-700'}`}
              >
                {sev.charAt(0).toUpperCase() + sev.slice(1)} ({counts[sev]})
              </button>
            )
          })}
          <button
            onClick={() => setSearchParams({ tab: 'ignored' })}
            className={`px-3 py-1 text-sm rounded ${isIgnored ? 'bg-gray-600 text-white' : 'bg-gray-200 text-gray-700'}`}
          >
            Ignored ({ignored_count})
          </button>
        </div>

        {!isIgnored && (
          <div className="flex gap-2 flex-wrap items-center">
            <span className="text-sm text-gray-500 font-medium">Filter by type:</span>
            {Object.entries(typeBadges).map(([type, badge]) => (
              <button
                key={type}
                onClick={() => {
                  const params = {}
                  if (filter) params.severity = filter
                  if (typeFilter === type) {
                    // Clicking same type clears it
                  } else {
                    params.type = type
                  }
                  setSearchParams(params)
                }}
                className={`px-3 py-1 text-sm rounded ${
                  typeFilter === type
                    ? badge.cls
                    : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                }`}
              >
                {badge.label}
              </button>
            ))}
          </div>
        )}
      </div>

      {selectedFingerprints.size > 0 && !isIgnored && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <span className="text-sm font-medium text-blue-900">
              {selectedFingerprints.size} issue{selectedFingerprints.size !== 1 ? 's' : ''} selected
            </span>
            <button
              onClick={handleBulkIgnore}
              disabled={bulkIgnoring}
              className="px-3 py-1.5 text-sm rounded bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50"
            >
              {bulkIgnoring ? 'Ignoring...' : 'Ignore Selected'}
            </button>
          </div>
          <button
            onClick={() => setSelectedFingerprints(new Set())}
            className="text-sm text-blue-600 hover:text-blue-800"
          >
            Clear Selection
          </button>
        </div>
      )}

      {issues.length === 0 && (
        <div className="bg-white rounded-lg shadow p-8 text-center text-gray-400">
          {isIgnored ? 'No ignored issues. Issues you ignore will appear here.' : 'No issues detected. Browse your app to generate traffic.'}
        </div>
      )}

      {issues.length > 0 && !isIgnored && (
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-3 mb-2 flex items-center gap-3">
          <input
            type="checkbox"
            checked={selectedFingerprints.size === issues.length}
            onChange={toggleSelectAll}
            className="w-4 h-4 rounded border-gray-300"
          />
          <span className="text-sm text-gray-600 font-medium">
            Select All
          </span>
        </div>
      )}

      <div className="space-y-2">
        {issues.map((issue) => (
          <div
            key={issue.fingerprint}
            className="bg-white rounded-lg shadow p-4 hover:bg-gray-50 transition-colors"
          >
            <div className="flex items-start gap-3">
              {!isIgnored && (
                <input
                  type="checkbox"
                  checked={selectedFingerprints.has(issue.fingerprint)}
                  onChange={(e) => {
                    e.stopPropagation()
                    toggleSelection(issue.fingerprint)
                  }}
                  onClick={(e) => e.stopPropagation()}
                  className="mt-1 w-4 h-4 rounded border-gray-300 flex-shrink-0"
                />
              )}
              <div
                className="flex-1 cursor-pointer"
                onClick={() => setSelectedIssue(issue)}
              >
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-2 flex-wrap">
                <SeverityBadge severity={issue.severity} />
                <span className="font-semibold text-gray-900">{issue.title}</span>
                {typeBadges[issue.type] && (
                  <span className={`inline-block px-2 py-0.5 text-xs font-medium rounded ${typeBadges[issue.type].cls}`}>
                    {typeBadges[issue.type].label}
                  </span>
                )}
              </div>
              <div className="text-right text-sm text-gray-500 whitespace-nowrap ml-4">
                {issue.occurrences} occ.
                {issue.total_duration_ms != null && ` · ${Math.round(issue.total_duration_ms)}ms`}
              </div>
            </div>

            <p className="text-sm text-gray-500 mt-1 line-clamp-1">{issue.description}</p>

            <div className="mt-1.5 flex items-center gap-3 text-sm">
              {issue.source_file && (
                <span className="text-blue-600 font-mono text-xs">
                  {issue.source_file.replace(/.*\/app\//, 'app/')}:{issue.source_line}
                </span>
              )}
              {issue.latest_at && (
                <span className="text-xs text-gray-400 ml-auto">
                  <TimeAgo timestamp={issue.latest_at} />
                </span>
              )}
            </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {total_pages > 1 && (
        <div className="mt-6 flex items-center justify-between">
          <div className="text-sm text-gray-500">
            Showing {issues.length} of {total_count} issues
          </div>
          <div className="flex gap-1">
            <button
              onClick={() => changePage(page - 1)}
              disabled={page === 1}
              className="px-3 py-1 text-sm rounded bg-white border border-gray-300 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Previous
            </button>
            {Array.from({ length: Math.min(total_pages, 5) }, (_, i) => {
              const pageNum = page <= 3 ? i + 1 : page + i - 2
              if (pageNum > total_pages) return null
              return (
                <button
                  key={pageNum}
                  onClick={() => changePage(pageNum)}
                  className={`px-3 py-1 text-sm rounded ${
                    page === pageNum
                      ? 'bg-blue-600 text-white'
                      : 'bg-white border border-gray-300 hover:bg-gray-50'
                  }`}
                >
                  {pageNum}
                </button>
              )
            })}
            {total_pages > 5 && page < total_pages - 2 && (
              <span className="px-3 py-1 text-sm text-gray-500">...</span>
            )}
            <button
              onClick={() => changePage(page + 1)}
              disabled={page === total_pages}
              className="px-3 py-1 text-sm rounded bg-white border border-gray-300 hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Next
            </button>
          </div>
        </div>
      )}

      <Drawer isOpen={!!selectedIssue} onClose={() => setSelectedIssue(null)} title={selectedIssue?.title || 'Issue'}>
        <IssueDrawer
          issue={selectedIssue}
          isIgnored={isIgnored}
          onIgnore={handleIgnore}
          onUnignore={handleUnignore}
        />
      </Drawer>
    </div>
  )
}
