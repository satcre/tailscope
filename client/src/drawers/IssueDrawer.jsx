import React from 'react'
import SeverityBadge from '../components/SeverityBadge'
import SuggestedFix from '../components/SuggestedFix'
import SqlBlock from '../components/SqlBlock'
import SourceViewer from '../components/SourceViewer'
import OpenInEditor from '../components/OpenInEditor'
import OpenInDebugger from '../components/OpenInDebugger'
import TimeAgo from '../components/TimeAgo'

const typeBadges = {
  n_plus_one: { label: 'N+1', cls: 'bg-purple-100 text-purple-800' },
  slow_query: { label: 'Query', cls: 'bg-blue-100 text-blue-800' },
  slow_request: { label: 'Request', cls: 'bg-green-100 text-green-800' },
  code_smell: { label: 'Code Smell', cls: 'bg-orange-100 text-orange-800' },
}

export default function IssueDrawer({ issue, isIgnored, onIgnore, onUnignore }) {
  if (!issue) return null

  const badge = typeBadges[issue.type]

  return (
    <div className="space-y-5">
      {/* Header */}
      <div>
        <div className="flex items-center gap-2 flex-wrap mb-2">
          <SeverityBadge severity={issue.severity} />
          {badge && (
            <span className={`inline-block px-2 py-0.5 text-xs font-medium rounded ${badge.cls}`}>
              {badge.label}
            </span>
          )}
        </div>
        <h2 className="text-lg font-semibold text-gray-900">{issue.title}</h2>
      </div>

      {/* Metadata */}
      <div className="grid grid-cols-2 gap-3 text-sm">
        <div>
          <span className="text-gray-500">Occurrences</span>
          <div className="font-medium text-gray-900">{issue.occurrences}</div>
        </div>
        {issue.total_duration_ms != null && (
          <div>
            <span className="text-gray-500">Total Duration</span>
            <div className="font-medium text-gray-900">{Math.round(issue.total_duration_ms)}ms</div>
          </div>
        )}
        {issue.metadata?.controller && (
          <div>
            <span className="text-gray-500">Controller</span>
            <div className="font-mono font-medium text-gray-900 text-sm">{issue.metadata.controller}</div>
          </div>
        )}
        {issue.latest_at && (
          <div>
            <span className="text-gray-500">Last Seen</span>
            <div className="font-medium text-gray-900"><TimeAgo timestamp={issue.latest_at} /></div>
          </div>
        )}
      </div>

      {/* Description */}
      <div>
        <p className="text-sm text-gray-600">{issue.description}</p>
      </div>

      {/* Source location + actions */}
      {issue.source_file && (
        <div className="flex items-center gap-3 flex-wrap">
          <span className="text-blue-600 font-mono text-sm">
            {issue.source_file.replace(/.*\/app\//, 'app/')}:{issue.source_line}
          </span>
          <span className="inline-flex items-center gap-1 ml-auto">
            <OpenInEditor file={issue.source_file} line={issue.source_line} />
            <OpenInDebugger file={issue.source_file} line={issue.source_line} />
          </span>
        </div>
      )}

      {/* SQL block */}
      {issue.metadata?.sql_text && (
        <div>
          <div className="text-xs font-semibold text-gray-500 uppercase mb-1.5">SQL</div>
          <SqlBlock sql={issue.metadata.sql_text} />
        </div>
      )}

      {/* Backtrace */}
      {issue.metadata?.backtrace?.length > 0 && (
        <div>
          <div className="text-xs font-semibold text-gray-500 uppercase mb-1.5">Backtrace</div>
          <pre className="bg-gray-100 p-3 rounded text-xs text-gray-600 overflow-x-auto">
            <code>{issue.metadata.backtrace.slice(0, 5).join('\n')}</code>
          </pre>
        </div>
      )}

      {/* Source viewer */}
      {issue.source_file && (
        <div>
          <div className="text-xs font-semibold text-gray-500 uppercase mb-1.5">Source</div>
          <SourceViewer file={issue.source_file} line={issue.source_line} />
        </div>
      )}

      {/* Suggested fix */}
      {issue.suggested_fix && (
        <div className="bg-emerald-50 border border-emerald-200 rounded p-3">
          <div className="text-xs font-semibold text-emerald-700 uppercase mb-1.5">How to fix</div>
          <SuggestedFix text={issue.suggested_fix} />
        </div>
      )}

      {/* Ignore / Unignore */}
      <div className="pt-2 border-t border-gray-200">
        {isIgnored ? (
          <button
            onClick={() => onUnignore(issue.fingerprint)}
            className="px-3 py-1.5 text-sm rounded bg-gray-200 text-gray-600 hover:bg-gray-300"
          >
            Unignore
          </button>
        ) : (
          <button
            onClick={() => onIgnore(issue.fingerprint)}
            className="px-3 py-1.5 text-sm rounded bg-gray-100 text-gray-400 hover:bg-gray-200 hover:text-gray-600"
          >
            Ignore
          </button>
        )}
      </div>
    </div>
  )
}
