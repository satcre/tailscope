import React from 'react'
import { api } from '../api'
import Drawer from '../components/Drawer'
import OpenInEditor from '../components/OpenInEditor'
import SourceViewer from '../components/SourceViewer'
import OpenInDebugger from '../components/OpenInDebugger'

const LS_EXPANDED_KEY = 'tailscope_tests_expanded'

function loadStoredExpanded() {
  try {
    const stored = JSON.parse(localStorage.getItem(LS_EXPANDED_KEY)) || {}
    // Only restore folder expansion, not files — file examples require a slow dry-run fetch
    const folders = {}
    for (const [key, val] of Object.entries(stored)) {
      if (!key.endsWith('.rb')) folders[key] = val
    }
    return folders
  } catch { return {} }
}

const categoryBadge = {
  controller: { label: 'CTRL', cls: 'bg-blue-100 text-blue-800' },
  model: { label: 'MODEL', cls: 'bg-green-100 text-green-800' },
  request: { label: 'REQ', cls: 'bg-cyan-100 text-cyan-800' },
  job: { label: 'JOB', cls: 'bg-indigo-100 text-indigo-800' },
  mailer: { label: 'MAIL', cls: 'bg-pink-100 text-pink-800' },
  system: { label: 'SYS', cls: 'bg-purple-100 text-purple-800' },
  feature: { label: 'FEAT', cls: 'bg-purple-100 text-purple-800' },
  helper: { label: 'HELP', cls: 'bg-gray-100 text-gray-800' },
  view: { label: 'VIEW', cls: 'bg-teal-100 text-teal-800' },
  routing: { label: 'ROUTE', cls: 'bg-orange-100 text-orange-800' },
  service: { label: 'SVC', cls: 'bg-violet-100 text-violet-800' },
  integration: { label: 'INT', cls: 'bg-amber-100 text-amber-800' },
  lib: { label: 'LIB', cls: 'bg-gray-100 text-gray-700' },
  spec: { label: 'SPEC', cls: 'bg-gray-100 text-gray-700' },
}

const statusDot = {
  passed: 'bg-green-500',
  failed: 'bg-red-500',
  pending: 'bg-yellow-400',
}

function PlayButton({ onClick, disabled, title }) {
  return (
    <button
      onClick={(e) => { e.stopPropagation(); onClick() }}
      disabled={disabled}
      title={title}
      className="w-6 h-6 flex items-center justify-center rounded hover:bg-gray-200 disabled:opacity-30 disabled:cursor-not-allowed shrink-0"
    >
      <svg viewBox="0 0 16 16" className="w-3.5 h-3.5 text-green-600" fill="currentColor">
        <path d="M4 2l10 6-10 6V2z" />
      </svg>
    </button>
  )
}

function SpecTree({ node, onRun, running, results, expanded, toggleExpand, fileExamples, onExpandFile, onViewSource }) {
  if (node.type === 'folder') {
    const isOpen = expanded[node.path] !== false
    const fileCount = countFiles(node)
    const folderResults = results?.filter((r) => r.file_path?.replace('./', '').startsWith(node.path + '/')) || []
    const folderFailed = folderResults.some((r) => r.status === 'failed')
    const folderPassed = folderResults.length > 0 && folderResults.every((r) => r.status === 'passed')

    return (
      <div>
        <div
          className={`flex items-center gap-1.5 py-1 px-1 hover:bg-gray-50 rounded cursor-pointer ${folderFailed ? 'bg-red-50' : folderPassed ? 'bg-green-50' : ''}`}
          onClick={() => toggleExpand(node.path, true)}
        >
          <svg className={`w-3.5 h-3.5 text-gray-400 transition-transform ${isOpen ? 'rotate-90' : ''}`} viewBox="0 0 16 16" fill="currentColor">
            <path d="M6 3l5 5-5 5V3z" />
          </svg>
          <svg className="w-4 h-4 text-yellow-500" viewBox="0 0 16 16" fill="currentColor">
            <path d="M1 3.5A1.5 1.5 0 012.5 2h3.172a1.5 1.5 0 011.06.44l.658.658A.5.5 0 007.744 3.25H13.5A1.5 1.5 0 0115 4.75v7.75A1.5 1.5 0 0113.5 14h-11A1.5 1.5 0 011 12.5v-9z" />
          </svg>
          <span className="text-sm font-medium text-gray-700 flex-1">{node.name}</span>
          {folderResults.length > 0 && (
            <span className={`text-xs font-medium ${folderFailed ? 'text-red-600' : 'text-green-600'}`}>
              {folderResults.filter(r => r.status === 'passed').length}/{folderResults.length}
            </span>
          )}
          <span className="text-xs text-gray-400">{fileCount} files</span>
          <PlayButton onClick={() => onRun(node.path + '/')} disabled={running} title={`Run ${node.name}/`} />
        </div>
        {isOpen && (
          <div className="ml-5 border-l border-gray-200 pl-1">
            {node.children.map((child) => (
              <SpecTree key={child.path} node={child} onRun={onRun} running={running} results={results} expanded={expanded} toggleExpand={toggleExpand} fileExamples={fileExamples} onExpandFile={onExpandFile} onViewSource={onViewSource} />
            ))}
          </div>
        )}
      </div>
    )
  }

  // File node
  const badge = categoryBadge[node.category] || categoryBadge.spec
  const fileResults = results?.filter((r) => r.file_path?.replace('./', '') === node.path) || []
  const discovered = fileExamples[node.path] || []
  const hasFailed = fileResults.some((r) => r.status === 'failed')
  const allPassed = fileResults.length > 0 && fileResults.every((r) => r.status === 'passed')
  const isOpen = expanded[node.path] === true

  // Merge: overlay run results onto discovered examples so we always show the full list
  const displayExamples = React.useMemo(() => {
    if (discovered.length === 0 && fileResults.length === 0) return []
    if (discovered.length === 0) return fileResults
    if (fileResults.length === 0) return discovered.map((d) => ({ ...d, status: null }))

    // Build a lookup from run results by line number
    const resultsByLine = {}
    fileResults.forEach((r) => { if (r.line_number) resultsByLine[r.line_number] = r })

    // Map discovered examples, replacing with run result if available
    const merged = discovered.map((d) => {
      const match = resultsByLine[d.line_number]
      return match || { ...d, status: null }
    })

    // Add any run results that weren't in discovered (in case discovery missed some)
    const mergedLines = new Set(merged.map((m) => m.line_number))
    fileResults.forEach((r) => {
      if (r.line_number && !mergedLines.has(r.line_number)) merged.push(r)
    })

    return merged
  }, [discovered, fileResults])

  const handleClick = () => {
    if (isOpen) {
      toggleExpand(node.path, false)
    } else {
      onExpandFile(node.path)
      toggleExpand(node.path, false)
    }
  }

  return (
    <div>
      <div
        className={`flex items-center gap-1.5 py-1 px-1 hover:bg-gray-50 rounded cursor-pointer ${hasFailed ? 'bg-red-50' : allPassed ? 'bg-green-50' : ''}`}
        onClick={handleClick}
      >
        <svg className={`w-3.5 h-3.5 text-gray-400 transition-transform ${isOpen ? 'rotate-90' : ''}`} viewBox="0 0 16 16" fill="currentColor">
          <path d="M6 3l5 5-5 5V3z" />
        </svg>
        {fileResults.length > 0 && (
          <span className={`w-2 h-2 rounded-full shrink-0 ${hasFailed ? 'bg-red-500' : 'bg-green-500'}`} />
        )}
        <span className={`px-1.5 py-0.5 text-[10px] font-bold rounded shrink-0 ${badge.cls}`}>{badge.label}</span>
        <span className="text-sm font-mono text-gray-600 truncate">{node.name}</span>
        {fileResults.length > 0 && (
          <span className={`text-xs font-medium ${hasFailed ? 'text-red-600' : 'text-green-600'}`}>
            {fileResults.filter(r => r.status === 'passed').length}/{fileResults.length}
          </span>
        )}
        {onViewSource && <ViewSourceButton onClick={() => onViewSource(node.path, 1)} />}
        <PlayButton onClick={() => onRun(node.path)} disabled={running} title={`Run ${node.name}`} />
      </div>
      {isOpen && displayExamples.length > 0 && (
        <div className="ml-7 border-l border-gray-200 pl-2 mb-1">
          <ExampleTree items={buildExampleTree(displayExamples)} filePath={node.path} onRun={onRun} running={running} onViewSource={onViewSource} />
        </div>
      )}
      {isOpen && displayExamples.length === 0 && fileExamples[node.path] === undefined && (
        <div className="ml-7 pl-2 py-1 text-xs text-gray-400">Loading examples...</div>
      )}
    </div>
  )
}

// --- Build describe/context/it hierarchy from flat examples ---

function parseIdIndices(id) {
  if (!id) return null
  const match = id.match(/\[([^\]]+)\]$/)
  if (!match) return null
  return match[1].split(':').map(Number)
}

function longestCommonPrefix(strings) {
  if (strings.length === 0) return ''
  if (strings.length === 1) return strings[0]
  let prefix = strings[0]
  for (let i = 1; i < strings.length; i++) {
    while (strings[i] !== prefix && !strings[i].startsWith(prefix + ' ')) {
      const lastSpace = prefix.lastIndexOf(' ')
      prefix = lastSpace > 0 ? prefix.slice(0, lastSpace) : ''
      if (!prefix) return ''
    }
  }
  return prefix
}

function collectGroupDescs(node) {
  const descs = []
  if (node.examples.length > 0 && node.groupDesc) descs.push(node.groupDesc)
  for (const child of Object.values(node.children)) {
    descs.push(...collectGroupDescs(child))
  }
  return descs
}

function trieToTree(node, parentPrefix) {
  const result = []
  const childKeys = Object.keys(node.children).sort((a, b) => Number(a) - Number(b))

  for (const key of childKeys) {
    const child = node.children[key]
    const allDescs = collectGroupDescs(child)
    const prefix = longestCommonPrefix(allDescs)

    let label = prefix
    if (parentPrefix && prefix.startsWith(parentPrefix + ' ')) {
      label = prefix.slice(parentPrefix.length + 1)
    } else if (parentPrefix && prefix === parentPrefix) {
      label = ''
    }

    const subItems = trieToTree(child, prefix)

    if (label) {
      result.push({ type: 'group', label, children: subItems })
    } else {
      result.push(...subItems)
    }
  }

  for (const ex of node.examples) {
    result.push({ type: 'example', ...ex })
  }

  return result
}

function buildExampleTree(examples) {
  if (!examples || examples.length === 0) return []

  // Check if we have id fields to build hierarchy
  const hasIds = examples.some((ex) => ex.id && ex.full_description)
  if (!hasIds) {
    return examples.map((ex) => ({ type: 'example', ...ex }))
  }

  // Build trie from index paths
  const root = { children: {}, examples: [] }

  for (const ex of examples) {
    const indices = parseIdIndices(ex.id)
    if (!indices || indices.length < 2) {
      root.examples.push(ex)
      continue
    }

    const groupIndices = indices.slice(0, -1)
    const groupDesc = ex.full_description && ex.description
      ? ex.full_description.endsWith(ex.description)
        ? ex.full_description.slice(0, -(ex.description.length)).trim()
        : ex.full_description
      : ''

    let node = root
    for (let i = 0; i < groupIndices.length; i++) {
      const key = groupIndices[i]
      if (!node.children[key]) {
        node.children[key] = { children: {}, examples: [], groupDesc: '' }
      }
      node = node.children[key]
    }
    node.examples.push(ex)
    if (groupDesc) node.groupDesc = groupDesc
  }

  return trieToTree(root, '')
}

// --- Recursive tree renderer for examples ---

function ExampleTree({ items, filePath, onRun, running, onViewSource, showActions }) {
  return (
    <div>
      {items.map((item, i) => (
        item.type === 'group'
          ? <ExampleGroup key={i} group={item} filePath={filePath} onRun={onRun} running={running} onViewSource={onViewSource} showActions={showActions} />
          : <ExampleLeaf key={i} example={item} filePath={filePath} onRun={onRun} running={running} onViewSource={onViewSource} showActions={showActions} />
      ))}
    </div>
  )
}

function ExampleGroup({ group, filePath, onRun, running, onViewSource, showActions }) {
  const [open, setOpen] = React.useState(true)

  const allExamples = flattenExamples(group.children)
  const hasResults = allExamples.some((e) => e.status)
  const hasFailed = allExamples.some((e) => e.status === 'failed')
  const allPassed = hasResults && allExamples.every((e) => e.status === 'passed' || e.status === 'pending')

  // Build a target for running all examples in this group
  const firstExample = allExamples[0]
  const fp = filePath || firstExample?.file_path?.replace('./', '')
  const lines = allExamples.map((e) => e.line_number).filter(Boolean)
  const minLine = lines.length > 0 ? Math.min(...lines) : null
  const maxLine = lines.length > 0 ? Math.max(...lines) : null

  return (
    <div>
      <div
        className="flex items-center gap-1 py-px px-0.5 -mx-0.5 cursor-pointer hover:bg-gray-50 rounded group/row"
        onClick={() => setOpen(!open)}
      >
        <svg className={`w-2.5 h-2.5 text-gray-400 transition-transform shrink-0 ${open ? 'rotate-90' : ''}`} viewBox="0 0 16 16" fill="currentColor">
          <path d="M6 3l5 5-5 5V3z" />
        </svg>
        {hasResults && (
          <span className={`w-1.5 h-1.5 rounded-full shrink-0 ${hasFailed ? 'bg-red-500' : allPassed ? 'bg-green-500' : 'bg-gray-300'}`} />
        )}
        <span className="text-xs font-medium text-gray-500">{group.label}</span>
        {fp && minLine && onViewSource && (
          <ViewSourceButton onClick={() => onViewSource(fp, minLine)} />
        )}
        {fp && minLine && (
          <PlayButton onClick={() => onRun(`${fp}:${minLine}`)} disabled={running} title={`Run ${group.label}`} />
        )}
      </div>
      {open && (
        <div className="ml-2.5 border-l border-gray-100 pl-1.5">
          <ExampleTree items={group.children} filePath={filePath} onRun={onRun} running={running} onViewSource={onViewSource} showActions={showActions} />
        </div>
      )}
    </div>
  )
}

function flattenExamples(items) {
  const result = []
  for (const item of items) {
    if (item.type === 'example') result.push(item)
    else if (item.children) result.push(...flattenExamples(item.children))
  }
  return result
}

function ExampleLeaf({ example, filePath, onRun, running, onViewSource, showActions }) {
  const [showError, setShowError] = React.useState(false)
  const dot = statusDot[example.status] || 'bg-gray-300'
  const fp = filePath || example.file_path?.replace('./', '')

  return (
    <div>
      <div className="flex items-center gap-1 py-px px-0.5 -mx-0.5 hover:bg-gray-50 rounded group/row text-xs">
        <span className={`w-1.5 h-1.5 rounded-full shrink-0 ${dot}`} />
        <span
          className={`${example.status === 'failed' ? 'text-red-700 cursor-pointer hover:underline' : example.status === 'pending' ? 'text-yellow-700 italic' : 'text-gray-600'}`}
          onClick={example.exception ? () => setShowError(!showError) : undefined}
        >
          {example.description}
        </span>
        {example.run_time != null && (
          <span className="text-gray-400 font-mono shrink-0">{(example.run_time * 1000).toFixed(1)}ms</span>
        )}
        {fp && onViewSource && example.line_number && (
          <ViewSourceButton onClick={() => onViewSource(fp, example.line_number)} />
        )}
        {showActions && fp && (
          <span className="inline-flex items-center gap-0.5 shrink-0">
            <OpenInEditor file={fp} line={example.line_number} />
          </span>
        )}
        {fp && example.line_number && (
          <PlayButton onClick={() => onRun(`${fp}:${example.line_number}`)} disabled={running} title={`Run :${example.line_number}`} />
        )}
      </div>
      {showError && example.exception && (
        <div className="ml-3 mt-0.5 mb-1 p-2 bg-red-50 border border-red-200 rounded text-xs">
          <div className="font-semibold text-red-800">{example.exception.class}</div>
          <div className="text-red-700 mt-0.5 whitespace-pre-wrap">{example.exception.message}</div>
          {example.exception.backtrace && (
            <pre className="mt-1 text-gray-500 overflow-x-auto text-[10px] max-h-32 overflow-y-auto">
              {example.exception.backtrace.slice(0, 10).join('\n')}
            </pre>
          )}
        </div>
      )}
    </div>
  )
}

function ViewSourceButton({ onClick }) {
  return (
    <button
      onClick={(e) => { e.stopPropagation(); onClick() }}
      className="w-6 h-6 flex items-center justify-center rounded hover:bg-gray-200 shrink-0"
      title="View source"
    >
      <svg className="w-3.5 h-3.5 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 16.5" />
      </svg>
    </button>
  )
}


function countFiles(node) {
  if (node.type === 'file') return 1
  return (node.children || []).reduce((sum, child) => sum + countFiles(child), 0)
}

function NotAvailable() {
  return (
    <div className="max-w-lg mx-auto mt-16">
      <div className="bg-white rounded-lg shadow p-8 text-center">
        <h2 className="text-xl font-bold text-gray-800 mb-2">RSpec Not Detected</h2>
        <p className="text-gray-500 mb-6">Install RSpec in your application to use the test runner.</p>
        <div className="text-left bg-gray-50 rounded p-4 font-mono text-sm space-y-2">
          <div className="text-gray-500"># Add to your Gemfile (test group)</div>
          <div>gem "rspec-rails"</div>
          <div className="mt-3 text-gray-500"># Then run:</div>
          <div>bundle install</div>
          <div>rails generate rspec:install</div>
        </div>
      </div>
    </div>
  )
}

// --- Coverage drawer ---

function CoverageBar({ percentage }) {
  const color = percentage >= 80 ? 'bg-green-500' : percentage >= 50 ? 'bg-yellow-500' : 'bg-red-500'
  return (
    <div className="w-24 h-2 bg-gray-200 rounded-full overflow-hidden shrink-0">
      <div className={`h-full ${color} rounded-full`} style={{ width: `${Math.min(percentage, 100)}%` }} />
    </div>
  )
}

function CoverageDrawer({ data, loading }) {
  const [expandedFile, setExpandedFile] = React.useState(null)

  if (loading) return <div className="text-sm text-gray-400">Loading coverage data...</div>
  if (!data?.available) return (
    <div className="text-center py-12">
      <div className="text-gray-500 text-sm mb-2">No coverage data found.</div>
      <div className="text-gray-400 text-xs">Run your tests with SimpleCov enabled to generate coverage data.</div>
    </div>
  )

  const { summary, files } = data

  return (
    <div className="flex flex-col h-full">
      {/* Summary */}
      <div className="flex items-center gap-4 mb-4 pb-4 border-b border-gray-200">
        <div className="text-3xl font-bold" style={{ color: summary.percentage >= 80 ? '#16a34a' : summary.percentage >= 50 ? '#ca8a04' : '#dc2626' }}>
          {summary.percentage}%
        </div>
        <div className="text-sm text-gray-500">
          <div>{summary.covered_lines.toLocaleString()} / {summary.total_lines.toLocaleString()} lines covered</div>
          <div>{files.length} files</div>
        </div>
        <div className="flex-1" />
        <CoverageBar percentage={summary.percentage} />
      </div>

      {/* File list */}
      <div className="flex-1 overflow-y-auto space-y-0.5">
        {files.map((file) => (
          <CoverageFileRow
            key={file.path}
            file={file}
            isOpen={expandedFile === file.path}
            onToggle={() => setExpandedFile(expandedFile === file.path ? null : file.path)}
          />
        ))}
      </div>
    </div>
  )
}

function CoverageFileRow({ file, isOpen, onToggle }) {
  const pctColor = file.percentage >= 80 ? 'text-green-700' : file.percentage >= 50 ? 'text-yellow-700' : 'text-red-700'

  return (
    <div>
      <div
        className="flex items-center gap-2 py-1.5 px-2 hover:bg-gray-50 rounded cursor-pointer text-sm"
        onClick={onToggle}
      >
        <svg className={`w-3 h-3 text-gray-400 transition-transform shrink-0 ${isOpen ? 'rotate-90' : ''}`} viewBox="0 0 16 16" fill="currentColor">
          <path d="M6 3l5 5-5 5V3z" />
        </svg>
        <span className="font-mono text-gray-600 truncate flex-1">{file.path}</span>
        <span className="text-xs text-gray-400 shrink-0">{file.covered}/{file.total}</span>
        <CoverageBar percentage={file.percentage} />
        <span className={`text-xs font-medium w-12 text-right shrink-0 ${pctColor}`}>{file.percentage}%</span>
      </div>
      {isOpen && (
        <div className="ml-4 mr-2 mb-2 mt-1">
          <SourceViewer file={file.path} line={1} full coverage={file.lines} />
        </div>
      )}
    </div>
  )
}

// --- Drawer content: results + console ---

function ResultsDrawer({ runStatus, isRunning, onCancel, onViewSource }) {
  const [tab, setTab] = React.useState('results')
  const consoleRef = React.useRef(null)

  // Auto-scroll console to bottom
  React.useEffect(() => {
    if (tab === 'console' && consoleRef.current) {
      consoleRef.current.scrollTop = consoleRef.current.scrollHeight
    }
  }, [tab, runStatus?.console_output])

  if (!runStatus) return null

  const examples = runStatus.examples || []
  const summary = runStatus.summary

  // Group examples by file
  const byFile = {}
  examples.forEach((ex) => {
    const key = ex.file_path || 'unknown'
    if (!byFile[key]) byFile[key] = []
    byFile[key].push(ex)
  })
  const fileKeys = Object.keys(byFile).sort()

  return (
    <div className="flex flex-col h-full">
      {/* Status bar */}
      <div className="flex items-center gap-3 mb-3">
        {isRunning ? (
          <>
            <span className="flex items-center gap-2 text-sm text-blue-600 font-medium">
              <svg className="w-4 h-4 animate-spin" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="8" cy="8" r="6" strokeDasharray="30" strokeDashoffset="10" strokeLinecap="round" />
              </svg>
              Running...
            </span>
            <button onClick={onCancel} className="px-2 py-0.5 text-xs rounded bg-red-600 text-white hover:bg-red-700">Cancel</button>
          </>
        ) : summary ? (
          <div className="flex items-center gap-3 text-sm">
            <span className="font-semibold text-gray-700">{summary.total} examples</span>
            {summary.passed > 0 && <span className="text-green-700 font-medium">{summary.passed} passed</span>}
            {summary.failed > 0 && <span className="text-red-700 font-medium">{summary.failed} failed</span>}
            {summary.pending > 0 && <span className="text-yellow-700 font-medium">{summary.pending} pending</span>}
            {summary.duration_s != null && <span className="text-gray-400">{summary.duration_s}s</span>}
          </div>
        ) : runStatus.status === 'error' ? (
          <span className="text-sm text-red-600 font-medium">Error</span>
        ) : null}
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-3 border-b border-gray-200">
        <button
          onClick={() => setTab('results')}
          className={`px-3 py-1.5 text-sm font-medium border-b-2 -mb-px ${tab === 'results' ? 'border-gray-900 text-gray-900' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
        >Results {examples.length > 0 && `(${examples.length})`}</button>
        <button
          onClick={() => setTab('console')}
          className={`px-3 py-1.5 text-sm font-medium border-b-2 -mb-px ${tab === 'console' ? 'border-gray-900 text-gray-900' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
        >Console</button>
      </div>

      {/* Tab content */}
      {tab === 'results' && (
        <div className="flex-1 overflow-y-auto space-y-3">
          {runStatus.status === 'error' && runStatus.error_output && (
            <pre className="p-3 bg-gray-900 text-gray-100 rounded text-xs font-mono whitespace-pre-wrap overflow-x-auto">
              <AnsiText text={runStatus.error_output} />
            </pre>
          )}
          {fileKeys.map((filePath) => (
            <FileResultGroup key={filePath} filePath={filePath} examples={byFile[filePath]} onViewSource={onViewSource} />
          ))}
          {examples.length === 0 && !isRunning && runStatus.status !== 'error' && (
            <div className="text-gray-400 text-sm text-center py-8">No results yet.</div>
          )}
        </div>
      )}

      {tab === 'console' && (
        <pre
          ref={consoleRef}
          className="flex-1 overflow-y-auto overflow-x-auto bg-gray-900 text-gray-100 p-3 rounded text-xs font-mono whitespace-pre-wrap"
        >
          {runStatus.console_output ? <AnsiText text={runStatus.console_output} /> : (isRunning ? 'Waiting for output...' : 'No output.')}
        </pre>
      )}
    </div>
  )
}

function FileResultGroup({ filePath, examples, onViewSource }) {
  const [showSource, setShowSource] = React.useState(false)
  const fileFailed = examples.some((e) => e.status === 'failed')
  const displayPath = filePath.replace('./', '')

  return (
    <div>
      <div className={`flex items-center gap-2 py-1 px-2 rounded text-xs font-mono ${fileFailed ? 'bg-red-50 text-red-700' : 'bg-green-50 text-green-700'}`}>
        <span className={`w-2 h-2 rounded-full shrink-0 ${fileFailed ? 'bg-red-500' : 'bg-green-500'}`} />
        <span className="flex-1 break-all">{displayPath}</span>
        <button
          onClick={() => setShowSource(!showSource)}
          className={`shrink-0 ${showSource ? 'text-blue-600' : 'text-gray-400 hover:text-gray-600'}`}
          title="View source"
        >
          <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
        </button>
        <OpenInEditor file={displayPath} line={1} />
      </div>
      {showSource && (
        <div className="mt-1 mb-2">
          <SourceViewer file={displayPath} line={1} full />
        </div>
      )}
      <div className="ml-2 mt-0.5">
        <ExampleTree items={buildExampleTree(examples)} filePath={displayPath} onRun={() => {}} running={false} onViewSource={onViewSource} showActions />
      </div>
    </div>
  )
}

// --- ANSI to styled spans ---

const ANSI_COLORS = {
  '30': '#4b5563', '31': '#ef4444', '32': '#22c55e', '33': '#eab308',
  '34': '#3b82f6', '35': '#a855f7', '36': '#06b6d4', '37': '#d1d5db',
  '90': '#6b7280', '91': '#f87171', '92': '#4ade80', '93': '#facc15',
  '94': '#60a5fa', '95': '#c084fc', '96': '#22d3ee', '97': '#f3f4f6',
}

function AnsiText({ text }) {
  if (!text) return null
  // Split on ANSI escape sequences
  const parts = text.split(/(\x1b\[[0-9;]*m)/g)
  const spans = []
  let style = {}

  for (let i = 0; i < parts.length; i++) {
    const part = parts[i]
    const match = part.match(/^\x1b\[([0-9;]*)m$/)
    if (match) {
      const codes = match[1].split(';')
      for (const code of codes) {
        if (code === '0' || code === '') {
          style = {}
        } else if (code === '1') {
          style = { ...style, fontWeight: 'bold' }
        } else if (code === '4') {
          style = { ...style, textDecoration: 'underline' }
        } else if (ANSI_COLORS[code]) {
          style = { ...style, color: ANSI_COLORS[code] }
        }
      }
    } else if (part) {
      spans.push(<span key={i} style={Object.keys(style).length > 0 ? style : undefined}>{part}</span>)
    }
  }

  return <>{spans}</>
}

// --- Main page ---

export default function Tests() {
  const [specs, setSpecs] = React.useState(null)
  const [loading, setLoading] = React.useState(true)
  const [runStatus, setRunStatus] = React.useState(null)
  const [drawerOpen, setDrawerOpen] = React.useState(false)
  const [expanded, setExpanded] = React.useState(loadStoredExpanded)
  const [fileExamples, setFileExamples] = React.useState({})
  const [sourceDrawer, setSourceDrawer] = React.useState({ open: false, file: null, line: null })
  const [coverageData, setCoverageData] = React.useState(null)
  const [coverageOpen, setCoverageOpen] = React.useState(false)
  const [coverageLoading, setCoverageLoading] = React.useState(false)
  const pollingRef = React.useRef(null)

  React.useEffect(() => {
    api.get('/tests/specs').then(setSpecs).finally(() => setLoading(false))
  }, [])

  // Persist expanded state to localStorage
  React.useEffect(() => {
    localStorage.setItem(LS_EXPANDED_KEY, JSON.stringify(expanded))
  }, [expanded])

  // Don't auto-fetch examples on mount — they load lazily when the user expands a file

  // Poll when running
  React.useEffect(() => {
    if (runStatus?.status !== 'running') {
      if (pollingRef.current) clearInterval(pollingRef.current)
      return
    }

    pollingRef.current = setInterval(() => {
      api.get('/tests/status').then((data) => {
        if (data.run) {
          setRunStatus(data.run)
          if (data.run.status !== 'running') {
            clearInterval(pollingRef.current)
          }
        }
      })
    }, 1000)

    return () => clearInterval(pollingRef.current)
  }, [runStatus?.status])

  // When a run finishes, refresh coverage data and fetch examples
  React.useEffect(() => {
    if (!runStatus?.examples || runStatus.status === 'running') return
    // Refresh coverage data (stored in SQLite immediately after test run)
    api.get('/tests/coverage').then(setCoverageData).catch(() => {})
    const files = new Set()
    runStatus.examples.forEach((ex) => {
      const fp = ex.file_path?.replace('./', '')
      if (fp) files.add(fp)
    })
    files.forEach((fp) => {
      if (!fileExamples[fp]) {
        api.get(`/tests/examples?target=${encodeURIComponent(fp)}`).then((data) => {
          setFileExamples((prev) => ({ ...prev, [fp]: data.examples || [] }))
        }).catch(() => {
          setFileExamples((prev) => ({ ...prev, [fp]: [] }))
        })
      }
      setExpanded((prev) => ({ ...prev, [fp]: true }))
    })
  }, [runStatus?.status, runStatus?.examples])

  const handleRun = (target) => {
    api.post('/tests/run', { target }).then((data) => {
      if (!data.error) {
        setRunStatus({ ...data, status: 'running', target: target || 'all', examples: null, summary: null, console_output: null })
        setDrawerOpen(true)
      }
    })
  }

  const handleCancel = () => {
    api.post('/tests/cancel')
  }

  const handleViewSource = (file, line) => {
    setSourceDrawer({ open: true, file, line: line || 1 })
  }

  const handleCoverage = () => {
    setCoverageLoading(true)
    setCoverageOpen(true)
    api.get('/tests/coverage').then((data) => {
      setCoverageData(data)
    }).catch(() => {
      setCoverageData({ available: false })
    }).finally(() => setCoverageLoading(false))
  }

  const handleExpandFile = (path) => {
    if (fileExamples[path]) return // already fetched
    api.get(`/tests/examples?target=${encodeURIComponent(path)}`).then((data) => {
      setFileExamples((prev) => ({ ...prev, [path]: data.examples || [] }))
    }).catch(() => {
      setFileExamples((prev) => ({ ...prev, [path]: [] }))
    })
  }

  const toggleExpand = (path, defaultOpen) => {
    setExpanded((prev) => {
      const current = prev[path] !== undefined ? prev[path] : (defaultOpen ?? false)
      return { ...prev, [path]: !current }
    })
  }

  if (loading) return <div className="text-gray-400">Loading...</div>
  if (specs && !specs.available) return <NotAvailable />

  const isRunning = runStatus?.status === 'running'
  const results = runStatus?.examples || []

  const drawerTitle = isRunning
    ? `Running ${runStatus?.target === 'all' ? 'all specs' : runStatus?.target}...`
    : runStatus?.summary
      ? `${runStatus.summary.failed > 0 ? 'Failed' : 'Passed'} — ${runStatus.summary.total} examples`
      : 'Test Results'

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-baseline gap-3">
          <h1 className="text-2xl font-bold">Tests</h1>
          {specs?.tree && (
            <span className="text-sm text-gray-500">
              {countFiles({ type: 'folder', children: specs.tree })} spec files
            </span>
          )}
          {runStatus?.summary && !isRunning && (
            <span className="flex items-center gap-2 text-sm">
              <span className="text-gray-500">{runStatus.summary.total}</span>
              {runStatus.summary.passed > 0 && <span className="text-green-600 font-medium">{runStatus.summary.passed} passed</span>}
              {runStatus.summary.failed > 0 && <span className="text-red-600 font-medium">{runStatus.summary.failed} failed</span>}
              {runStatus.summary.pending > 0 && <span className="text-yellow-600 font-medium">{runStatus.summary.pending} pending</span>}
            </span>
          )}
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => setExpanded({})}
            className="px-3 py-1 text-sm rounded bg-gray-200 text-gray-700 hover:bg-gray-300"
          >Collapse All</button>
          {isRunning && (
            <span className="flex items-center gap-2 text-sm text-blue-600">
              <svg className="w-4 h-4 animate-spin" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="8" cy="8" r="6" strokeDasharray="30" strokeDashoffset="10" strokeLinecap="round" />
              </svg>
              Running...
            </span>
          )}
          {runStatus && !isRunning && (
            <button
              onClick={() => setDrawerOpen(true)}
              className="px-3 py-1 text-sm rounded bg-gray-200 text-gray-700 hover:bg-gray-300"
            >Last Results</button>
          )}
          <button
            onClick={handleCoverage}
            disabled={isRunning}
            className="px-4 py-1.5 text-sm rounded bg-indigo-600 text-white hover:bg-indigo-700 font-medium flex items-center gap-2 disabled:opacity-50"
          >
            <svg viewBox="0 0 16 16" className="w-3.5 h-3.5" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="2" y="2" width="12" height="12" rx="2" />
              <path d="M5 10V8M8 10V5M11 10V7" strokeLinecap="round" />
            </svg>
            Coverage
          </button>
          <button
            onClick={() => handleRun(null)}
            disabled={isRunning}
            className="px-4 py-1.5 text-sm rounded bg-green-600 text-white hover:bg-green-700 font-medium flex items-center gap-2 disabled:opacity-50"
          >
            <svg viewBox="0 0 16 16" className="w-3.5 h-3.5" fill="currentColor">
              <path d="M4 2l10 6-10 6V2z" />
            </svg>
            Run All
          </button>
        </div>
      </div>

      {/* Spec tree */}
      <div className="bg-white rounded-lg shadow p-4">
        {specs?.tree?.map((node) => (
          <SpecTree
            key={node.path}
            node={node}
            onRun={handleRun}
            running={isRunning}
            results={results}
            expanded={expanded}
            toggleExpand={toggleExpand}
            fileExamples={fileExamples}
            onExpandFile={handleExpandFile}
            onViewSource={handleViewSource}
          />
        ))}
        {(!specs?.tree || specs.tree.length === 0) && (
          <div className="text-center text-gray-400 py-8">No spec files found in spec/ directory.</div>
        )}
      </div>

      {/* Results drawer */}
      <Drawer isOpen={drawerOpen} onClose={() => setDrawerOpen(false)} title={drawerTitle}>
        <ResultsDrawer runStatus={runStatus} isRunning={isRunning} onCancel={handleCancel} onViewSource={handleViewSource} />
      </Drawer>

      {/* Source viewer drawer */}
      <Drawer isOpen={sourceDrawer.open} onClose={() => setSourceDrawer({ open: false, file: null, line: null })} title={sourceDrawer.file || 'Source'}>
        {sourceDrawer.file && (
          <div className="flex flex-col h-full">
            <div className="flex items-center gap-2 mb-3">
              <OpenInEditor file={sourceDrawer.file} line={sourceDrawer.line} />
              <OpenInDebugger file={sourceDrawer.file} line={sourceDrawer.line} />
            </div>
            <div className="flex-1 overflow-y-auto">
              <SourceViewer file={sourceDrawer.file} line={sourceDrawer.line} full />
            </div>
          </div>
        )}
      </Drawer>

      {/* Coverage drawer */}
      <Drawer isOpen={coverageOpen} onClose={() => setCoverageOpen(false)} title="Code Coverage" wide>
        <CoverageDrawer data={coverageData} loading={coverageLoading} />
      </Drawer>
    </div>
  )
}
