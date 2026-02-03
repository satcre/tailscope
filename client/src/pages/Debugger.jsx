import React from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api'
import { useHighlightedLines, HighlightedCode } from '../components/HighlightedLine'
import Drawer from '../components/Drawer'
import DebuggerSessionDrawer from '../drawers/DebuggerSessionDrawer'
import OpenInEditor from '../components/OpenInEditor'
import OpenInDebugger from '../components/OpenInDebugger'

function FileTree({ onSelectFile, currentFile, breakpoints }) {
  const [tree, setTree] = React.useState({})
  const [expanded, setExpanded] = React.useState({})
  const [rootPath, setRootPath] = React.useState(null)

  const loadDir = React.useCallback(async (path) => {
    const p = path ? `?path=${encodeURIComponent(path)}` : ''
    const data = await api.get(`/debugger/browse${p}`)
    if (data.is_directory) {
      setTree((prev) => ({ ...prev, [data.path]: data }))
      if (!rootPath) setRootPath(data.path)
    }
    return data
  }, [rootPath])

  React.useEffect(() => { loadDir('') }, [loadDir])

  const toggle = async (path) => {
    if (expanded[path]) {
      setExpanded((prev) => ({ ...prev, [path]: false }))
    } else {
      if (!tree[path]) await loadDir(path)
      setExpanded((prev) => ({ ...prev, [path]: true }))
    }
  }

  const bpFiles = React.useMemo(() => {
    const s = new Set()
    breakpoints.forEach((bp) => s.add(bp.file))
    return s
  }, [breakpoints])

  const renderDir = (dirPath, depth = 0) => {
    const data = tree[dirPath]
    if (!data) return null
    return (
      <>
        {data.directories.map((d) => {
          const fullPath = `${dirPath}/${d}`
          const isOpen = expanded[fullPath]
          return (
            <React.Fragment key={fullPath}>
              <button
                onClick={() => toggle(fullPath)}
                className="w-full text-left px-2 py-1 text-sm hover:bg-gray-100 flex items-center gap-1 rounded"
                style={{ paddingLeft: `${depth * 16 + 8}px` }}
              >
                <span className="text-gray-400 text-xs w-4">{isOpen ? '▾' : '▸'}</span>
                <span className="text-yellow-600">📁</span>
                <span className="truncate">{d}</span>
              </button>
              {isOpen && renderDir(fullPath, depth + 1)}
            </React.Fragment>
          )
        })}
        {data.files.map((f) => {
          const fullPath = `${dirPath}/${f}`
          const isActive = currentFile === fullPath
          const hasBp = bpFiles.has(fullPath)
          return (
            <button
              key={fullPath}
              onClick={() => onSelectFile(fullPath)}
              className={`w-full text-left px-2 py-1 text-sm flex items-center gap-1 rounded truncate ${isActive ? 'bg-blue-100 text-blue-800 font-medium' : 'hover:bg-gray-100'}`}
              style={{ paddingLeft: `${depth * 16 + 8}px` }}
            >
              <span className="w-4" />
              {hasBp ? <span className="text-red-500 text-xs">●</span> : <span className="text-gray-400">📄</span>}
              <span className="truncate">{f}</span>
            </button>
          )
        })}
      </>
    )
  }

  if (!rootPath) return <div className="text-gray-400 text-sm p-3">Loading...</div>

  return (
    <div className="overflow-y-auto overflow-x-hidden">
      {renderDir(rootPath)}
    </div>
  )
}

function CodeViewer({ filePath, breakpointLines, onToggleBreakpoint, activeSessions }) {
  const [fileData, setFileData] = React.useState(null)
  const [loading, setLoading] = React.useState(false)
  const [conditionLine, setConditionLine] = React.useState(null)
  const [conditionText, setConditionText] = React.useState('')
  const lineRefs = React.useRef({})

  React.useEffect(() => {
    if (!filePath) return
    setLoading(true)
    api.get(`/debugger/browse?path=${encodeURIComponent(filePath)}`)
      .then(setFileData)
      .catch(() => setFileData(null))
      .finally(() => setLoading(false))
  }, [filePath])

  const highlightedLines = useHighlightedLines(fileData?.lines, filePath)

  const sessionOnLine = React.useMemo(() => {
    const map = {}
    activeSessions.forEach((s) => {
      if (s.file === filePath) map[s.line] = s
    })
    return map
  }, [activeSessions, filePath])

  const bpSet = React.useMemo(() => new Set(breakpointLines), [breakpointLines])

  const handleLineClick = (lineNum, e) => {
    if (e.shiftKey) {
      setConditionLine(lineNum)
      setConditionText('')
    } else {
      onToggleBreakpoint(filePath, lineNum, bpSet.has(lineNum))
    }
  }

  const submitCondition = (e) => {
    e.preventDefault()
    onToggleBreakpoint(filePath, conditionLine, false, conditionText || undefined)
    setConditionLine(null)
    setConditionText('')
  }

  if (!filePath) {
    return (
      <div className="flex items-center justify-center h-full text-gray-400 text-sm">
        Select a file from the tree to view code and set breakpoints.
      </div>
    )
  }

  if (loading) return <div className="text-gray-400 text-sm p-4">Loading file...</div>
  if (!fileData || fileData.is_directory) return <div className="text-red-400 text-sm p-4">Could not load file</div>

  const shortPath = fileData.path.replace(/.*\/(app\/)/, '$1')

  return (
    <div className="flex flex-col h-full">
      <div className="text-xs text-gray-500 px-3 py-2 border-b bg-gray-50 font-mono shrink-0 flex items-center gap-1">
        <span className="truncate flex-1">{shortPath}</span>
        <span className="inline-flex items-center gap-1 shrink-0">
          <OpenInEditor file={fileData.path} line={1} />
        </span>
      </div>
      <div className="overflow-auto flex-1 bg-gray-900">
        <table className="text-sm font-mono w-full">
          <tbody>
            {fileData.lines.map((content, i) => {
              const lineNum = i + 1
              const hasBp = bpSet.has(lineNum)
              const hasSession = sessionOnLine[lineNum]
              return (
                <React.Fragment key={lineNum}>
                  <tr
                    ref={(el) => { lineRefs.current[lineNum] = el }}
                    className={hasSession ? 'bg-yellow-900/40' : hasBp ? 'bg-red-900/20' : ''}
                  >
                    <td
                      onClick={(e) => handleLineClick(lineNum, e)}
                      className="px-1 py-0.5 text-right select-none w-16 border-r border-gray-700 cursor-pointer hover:bg-gray-700 group relative"
                      title={hasBp ? 'Click to remove breakpoint' : 'Click to add breakpoint · Shift+click for condition'}
                    >
                      <span className="inline-flex items-center gap-1 justify-end w-full">
                        {hasBp && <span className="text-red-500 text-xs">●</span>}
                        <span className="text-gray-500">{lineNum}</span>
                      </span>
                    </td>
                    <td className="px-3 py-0.5 text-gray-300 whitespace-pre"><HighlightedCode html={highlightedLines[i] || content} /></td>
                  </tr>
                  {conditionLine === lineNum && (
                    <tr>
                      <td colSpan="2" className="px-3 py-2 bg-gray-800">
                        <form onSubmit={submitCondition} className="flex gap-2 items-center">
                          <span className="text-xs text-gray-400">Condition for line {lineNum}:</span>
                          <input
                            autoFocus
                            value={conditionText}
                            onChange={(e) => setConditionText(e.target.value)}
                            placeholder="e.g. user.admin?"
                            className="flex-1 bg-gray-700 border border-gray-600 rounded px-2 py-1 text-xs text-gray-200 font-mono"
                            onKeyDown={(e) => { if (e.key === 'Escape') setConditionLine(null) }}
                          />
                          <button type="submit" className="px-2 py-1 bg-red-600 text-white rounded text-xs hover:bg-red-700">Set</button>
                          <button type="button" onClick={() => setConditionLine(null)} className="px-2 py-1 text-gray-400 text-xs hover:text-gray-200">Cancel</button>
                        </form>
                      </td>
                    </tr>
                  )}
                </React.Fragment>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}

const LS_TABS_KEY = 'tailscope_debugger_tabs'
const LS_ACTIVE_KEY = 'tailscope_debugger_active'

function loadStoredTabs() {
  try { return JSON.parse(localStorage.getItem(LS_TABS_KEY)) || [] } catch { return [] }
}
function loadStoredActive() {
  return localStorage.getItem(LS_ACTIVE_KEY) || null
}

export default function Debugger() {
  const [searchParams, setSearchParams] = useSearchParams()
  const [data, setData] = React.useState(null)
  const [loading, setLoading] = React.useState(true)
  const [openTabs, setOpenTabs] = React.useState(loadStoredTabs)
  const [activeTab, setActiveTab] = React.useState(loadStoredActive)
  const [fileBpLines, setFileBpLines] = React.useState([])
  const [treeCollapsed, setTreeCollapsed] = React.useState(false)
  const [sidebarCollapsed, setSidebarCollapsed] = React.useState(false)
  const [selectedSession, setSelectedSession] = React.useState(null)
  const didHandleParams = React.useRef(false)

  React.useEffect(() => {
    localStorage.setItem(LS_TABS_KEY, JSON.stringify(openTabs))
  }, [openTabs])

  React.useEffect(() => {
    if (activeTab) localStorage.setItem(LS_ACTIVE_KEY, activeTab)
    else localStorage.removeItem(LS_ACTIVE_KEY)
  }, [activeTab])

  const loadData = React.useCallback(() => {
    api.get('/debugger').then(setData).catch(() => setData(null)).finally(() => setLoading(false))
  }, [])

  React.useEffect(() => {
    loadData()
    const interval = setInterval(() => {
      api.get('/debugger/poll').then((d) => {
        if (d.active_sessions?.length > 0) loadData()
      }).catch(() => {})
    }, 1500)
    return () => clearInterval(interval)
  }, [loadData])

  const loadFileBpLines = React.useCallback((filePath) => {
    if (!filePath) return
    api.get(`/debugger/browse?path=${encodeURIComponent(filePath)}`)
      .then((d) => { if (!d.is_directory) setFileBpLines(d.breakpoint_lines || []) })
      .catch(() => {})
  }, [])

  // Restore bp lines for active tab on mount
  React.useEffect(() => {
    if (activeTab) loadFileBpLines(activeTab)
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  const selectFile = React.useCallback((filePath) => {
    setOpenTabs((prev) => prev.includes(filePath) ? prev : [...prev, filePath])
    setActiveTab(filePath)
    loadFileBpLines(filePath)
  }, [loadFileBpLines])

  // Handle ?file=...&line=... params (from "Open in debugger" buttons)
  React.useEffect(() => {
    if (didHandleParams.current) return
    const fileParam = searchParams.get('file')
    if (fileParam) {
      didHandleParams.current = true
      selectFile(fileParam)
      // Clear the params so they don't re-trigger on navigation
      setSearchParams({}, { replace: true })
    }
  }, [searchParams, selectFile, setSearchParams])

  const closeTab = React.useCallback((filePath, e) => {
    e?.stopPropagation()
    setOpenTabs((prev) => {
      const next = prev.filter((t) => t !== filePath)
      if (activeTab === filePath) {
        const idx = prev.indexOf(filePath)
        const newActive = next[Math.min(idx, next.length - 1)] || null
        setActiveTab(newActive)
        if (newActive) loadFileBpLines(newActive)
      }
      return next
    })
  }, [activeTab, loadFileBpLines])

  const switchTab = React.useCallback((filePath) => {
    setActiveTab(filePath)
    loadFileBpLines(filePath)
  }, [loadFileBpLines])

  const notifyBreakpointChange = () => {
    window.dispatchEvent(new CustomEvent('tailscope:breakpoints-changed'))
  }

  const toggleBreakpoint = async (file, line, isRemove, condition) => {
    if (isRemove) {
      const bp = data?.breakpoints.find((b) => b.file === file && b.line === line)
      if (bp) await api.del(`/debugger/breakpoints/${bp.id}`)
    } else {
      await api.post('/debugger/breakpoints', { file, line, condition })
    }
    loadData()
    loadFileBpLines(file)
    notifyBreakpointChange()
  }

  const removeBreakpoint = async (id) => {
    await api.del(`/debugger/breakpoints/${id}`)
    loadData()
    if (activeTab) loadFileBpLines(activeTab)
    notifyBreakpointChange()
  }

  const goToBreakpoint = (bp) => {
    selectFile(bp.file)
  }

  if (loading) return <div className="text-gray-400">Loading...</div>
  if (!data) return <div className="text-red-400">Debugger not available. Is it enabled in configuration?</div>

  return (
    <div className="flex flex-col" style={{ height: 'calc(100vh - 80px)' }}>
      <div className="flex items-center justify-between mb-4 shrink-0">
        <h1 className="text-2xl font-bold">Debugger</h1>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setTreeCollapsed(!treeCollapsed)}
            className="text-sm text-gray-500 hover:text-gray-700 px-2 py-1 rounded border border-gray-300 hover:border-gray-400"
          >{treeCollapsed ? 'Show Files' : 'Hide Files'}</button>
          <button
            onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
            className="text-sm text-gray-500 hover:text-gray-700 px-2 py-1 rounded border border-gray-300 hover:border-gray-400"
          >{sidebarCollapsed ? 'Show Panel' : 'Hide Panel'}</button>
        </div>
      </div>

      {data.active_sessions.length > 0 && (
        <div className="bg-yellow-50 border border-yellow-300 rounded-lg p-3 mb-4 shrink-0">
          <div className="font-semibold text-yellow-800 text-sm mb-1">Active Sessions (thread paused)</div>
          {data.active_sessions.map((s) => (
            <div key={s.id} className="flex items-center gap-3 py-1">
              <span className="font-mono text-sm">{s.file.replace(/.*\/(app\/)/, '$1')}:{s.line}</span>
              <span className="text-gray-500 text-sm">in {s.method_name}</span>
              <span className="inline-flex items-center gap-1 ml-auto">
                <OpenInEditor file={s.file} line={s.line} />
                <button onClick={() => selectFile(s.file)} className="text-xs text-yellow-700 hover:underline">View File</button>
                <button onClick={() => setSelectedSession(s.id)} className="px-2 py-1 text-xs bg-yellow-600 text-white rounded hover:bg-yellow-700">Debug</button>
              </span>
            </div>
          ))}
        </div>
      )}

      <div className="flex gap-4 flex-1 min-h-0">
        {/* File Tree — collapsible */}
        {!treeCollapsed && (
          <div className="bg-white rounded-lg shadow flex flex-col shrink-0" style={{ width: '240px' }}>
            <div className="text-xs font-semibold text-gray-500 uppercase px-3 py-2 border-b">Files</div>
            <div className="flex-1 overflow-y-auto">
              <FileTree onSelectFile={selectFile} currentFile={activeTab} breakpoints={data.breakpoints} />
            </div>
          </div>
        )}

        {/* Code Viewer with Tabs */}
        <div className="flex-1 bg-white rounded-lg shadow overflow-hidden flex flex-col min-w-0">
          {openTabs.length > 0 && (
            <div className="flex bg-gray-100 border-b overflow-x-auto shrink-0">
              {openTabs.map((tab) => {
                const name = tab.split('/').pop()
                const isActive = tab === activeTab
                return (
                  <button
                    key={tab}
                    onClick={() => switchTab(tab)}
                    className={`flex items-center gap-1 px-3 py-1.5 text-xs border-r border-gray-200 shrink-0 max-w-[180px] ${isActive ? 'bg-white text-gray-900 font-medium' : 'text-gray-500 hover:bg-gray-50'}`}
                    title={tab}
                  >
                    <span className="truncate">{name}</span>
                    <span
                      onClick={(e) => closeTab(tab, e)}
                      className="ml-1 text-gray-400 hover:text-red-500 hover:bg-gray-200 rounded px-0.5"
                    >✕</span>
                  </button>
                )
              })}
            </div>
          )}
          <CodeViewer
            filePath={activeTab}
            breakpointLines={fileBpLines}
            onToggleBreakpoint={toggleBreakpoint}
            activeSessions={data.active_sessions}
          />
        </div>

        {/* Right Sidebar — collapsible */}
        {!sidebarCollapsed && (
          <div className="bg-white rounded-lg shadow flex flex-col shrink-0 overflow-y-auto" style={{ width: '280px' }}>
            <div className="p-3 border-b">
              <div className="text-xs font-semibold text-gray-500 uppercase mb-2">Breakpoints</div>
              {data.breakpoints.length === 0 ? (
                <p className="text-xs text-gray-400">Click a line number in the code viewer to set a breakpoint.</p>
              ) : (
                <div className="space-y-1">
                  {data.breakpoints.map((bp) => (
                    <div key={bp.id} className="flex items-start gap-1 text-xs group">
                      <button onClick={() => goToBreakpoint(bp)} className="text-left font-mono text-red-700 hover:underline truncate flex-1">
                        <span className="text-red-500">●</span> {bp.file.replace(/.*\/(app\/)/, '$1')}:{bp.line}
                        {bp.condition && <div className="text-gray-500 font-sans ml-3">if {bp.condition}</div>}
                      </button>
                      <span className="inline-flex items-center gap-1 shrink-0">
                        <OpenInEditor file={bp.file} line={bp.line} />
                        <button onClick={() => removeBreakpoint(bp.id)} className="text-gray-400 hover:text-red-500 opacity-0 group-hover:opacity-100">✕</button>
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            <div className="p-3">
              <div className="text-xs font-semibold text-gray-500 uppercase mb-2">Recent Sessions</div>
              {data.recent_sessions.length === 0 ? (
                <p className="text-xs text-gray-400">No sessions yet.</p>
              ) : (
                <div className="space-y-1">
                  {data.recent_sessions.map((s) => (
                    <div key={s.id} className="flex items-center gap-2 text-xs py-1">
                      <span className={`w-2 h-2 rounded-full shrink-0 ${s.status === 'paused' ? 'bg-yellow-500' : 'bg-gray-300'}`} />
                      <span className="font-mono truncate flex-1">{s.file.replace(/.*\/(app\/)/, '$1')}:{s.line}</span>
                      <span className="inline-flex items-center gap-1 shrink-0">
                        <OpenInEditor file={s.file} line={s.line} />
                        <button onClick={() => setSelectedSession(s.id)} className="text-blue-600 hover:underline">
                          {s.status === 'paused' ? 'Debug' : 'View'}
                        </button>
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      <Drawer isOpen={!!selectedSession} onClose={() => setSelectedSession(null)} title={`Debug Session`} wide>
        {selectedSession && <DebuggerSessionDrawer sessionId={selectedSession} onSessionUpdate={loadData} />}
      </Drawer>
    </div>
  )
}
