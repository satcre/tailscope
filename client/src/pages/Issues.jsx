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
  const [data, setData] = React.useState(null)
  const [loading, setLoading] = React.useState(true)
  const [selectedIssue, setSelectedIssue] = React.useState(null)

  const loadData = React.useCallback(() => {
    setLoading(true)
    const p = new URLSearchParams()
    if (tab === 'ignored') p.set('tab', 'ignored')
    if (filter) p.set('severity', filter)
    api.get(`/issues?${p}`).then(setData).finally(() => setLoading(false))
  }, [tab, filter])

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

  const isIgnored = tab === 'ignored'

  if (loading && !data) return <div className="text-gray-400">Loading...</div>
  if (!data) return <div className="text-red-400">Failed to load issues</div>

  const { issues, counts, ignored_count } = data

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Issues</h1>

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

      <div className="flex gap-2 mb-6 flex-wrap">
        <button
          onClick={() => setSearchParams({})}
          className={`px-3 py-1 text-sm rounded ${!filter && !isIgnored ? 'bg-gray-900 text-white' : 'bg-gray-200 text-gray-700'}`}
        >
          All ({issues.length})
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

      {issues.length === 0 && (
        <div className="bg-white rounded-lg shadow p-8 text-center text-gray-400">
          {isIgnored ? 'No ignored issues. Issues you ignore will appear here.' : 'No issues detected. Browse your app to generate traffic.'}
        </div>
      )}

      <div className="space-y-2">
        {issues.map((issue) => (
          <div
            key={issue.fingerprint}
            onClick={() => setSelectedIssue(issue)}
            className="bg-white rounded-lg shadow p-4 cursor-pointer hover:bg-gray-50 transition-colors"
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
        ))}
      </div>

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
