import React from 'react'
import SeverityBadge from '../components/SeverityBadge'
import SuggestedFix from '../components/SuggestedFix'
import TimeAgo from '../components/TimeAgo'

export default function CodeAnalysisDrawer({ filePath, issues, analyzedAt, onReanalyze, isAnalyzing }) {
  const filename = filePath?.split('/').pop() || ''

  const grouped = React.useMemo(() => {
    const groups = { critical: [], warning: [], info: [] }
    issues.forEach(issue => {
      if (groups[issue.severity]) groups[issue.severity].push(issue)
    })
    return groups
  }, [issues])

  const totalCount = issues.length
  const counts = {
    critical: grouped.critical.length,
    warning: grouped.warning.length,
    info: grouped.info.length
  }

  return (
    <div className="space-y-5">
      {/* Header */}
      <div>
        <h2 className="text-lg font-semibold text-gray-900 mb-2">
          Code Analysis — {filename}
        </h2>
        <div className="flex items-center gap-3 text-sm text-gray-500">
          <span>Analyzed <TimeAgo timestamp={analyzedAt} /></span>
          <span>•</span>
          <span>{totalCount} {totalCount === 1 ? 'issue' : 'issues'} found</span>
          {counts.critical > 0 && (
            <>
              <span>•</span>
              <span className="text-red-600 font-medium">{counts.critical} critical</span>
            </>
          )}
        </div>
      </div>

      {/* Re-analyze button */}
      <div className="flex items-center gap-2 pb-3 border-b">
        <button
          onClick={onReanalyze}
          disabled={isAnalyzing}
          className="px-3 py-1.5 text-sm rounded bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50"
        >
          {isAnalyzing ? 'Analyzing...' : 'Re-analyze'}
        </button>
        <span className="text-xs text-gray-400">Clear cache and run fresh analysis</span>
      </div>

      {/* No issues state */}
      {totalCount === 0 && (
        <div className="bg-green-50 border border-green-200 rounded p-4 text-center">
          <div className="text-green-700 font-medium mb-1">No issues found!</div>
          <div className="text-sm text-green-600">This file looks good.</div>
        </div>
      )}

      {/* Issues grouped by severity */}
      {['critical', 'warning', 'info'].map(severity => {
        const items = grouped[severity]
        if (items.length === 0) return null

        return (
          <div key={severity} className="space-y-3">
            <h3 className="text-sm font-semibold text-gray-700 uppercase">
              {severity} ({items.length})
            </h3>
            <div className="space-y-4">
              {items.map((issue, idx) => (
                <div key={idx} className="border border-gray-200 rounded p-4 space-y-2">
                  <div className="flex items-start gap-2">
                    <SeverityBadge severity={issue.severity} />
                    <div className="flex-1">
                      <div className="font-medium text-gray-900">{issue.title}</div>
                      {issue.source_line && (
                        <div className="text-xs text-gray-500 font-mono mt-0.5">
                          Line {issue.source_line}
                        </div>
                      )}
                    </div>
                  </div>
                  <div className="text-sm text-gray-600">{issue.description}</div>
                  {issue.suggested_fix && (
                    <div className="bg-emerald-50 border border-emerald-200 rounded p-3 mt-2">
                      <div className="text-xs font-semibold text-emerald-700 uppercase mb-1.5">
                        How to fix
                      </div>
                      <SuggestedFix text={issue.suggested_fix} />
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )
      })}
    </div>
  )
}
