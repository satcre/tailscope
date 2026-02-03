import React from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { EditorPicker } from './EditorContext'
import OpenInEditor from './OpenInEditor'
import { api } from '../api'

function DebuggerIndicator() {
  const [data, setData] = React.useState(null)
  const [open, setOpen] = React.useState(false)
  const ref = React.useRef(null)
  const navigate = useNavigate()

  const load = React.useCallback(() => {
    api.get('/debugger').then(setData).catch(() => {})
  }, [])

  React.useEffect(() => {
    load()
    const interval = setInterval(load, 5000)
    const onBreakpointChange = () => load()
    window.addEventListener('tailscope:breakpoints-changed', onBreakpointChange)
    return () => {
      clearInterval(interval)
      window.removeEventListener('tailscope:breakpoints-changed', onBreakpointChange)
    }
  }, [load])

  React.useEffect(() => {
    if (!open) return
    const handleClick = (e) => {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false)
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [open])

  if (!data) return null

  const breakpoints = data.breakpoints || []
  const activeSessions = data.active_sessions || []
  const hasActive = activeSessions.length > 0
  const hasBreakpoints = breakpoints.length > 0

  if (!hasBreakpoints && !hasActive) return null

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-1.5 px-2 py-1 rounded hover:bg-gray-800 transition-colors"
        title={hasActive ? `${activeSessions.length} active session(s)` : `${breakpoints.length} breakpoint(s)`}
      >
        <span className={`w-2 h-2 rounded-full ${hasActive ? 'bg-yellow-400 animate-pulse' : 'bg-red-500'}`} />
        <span className="text-xs text-gray-300">
          {hasActive ? `${activeSessions.length} paused` : `${breakpoints.length} bp`}
        </span>
      </button>

      {open && (
        <div className="absolute right-0 top-full mt-2 w-80 bg-white rounded-lg shadow-xl border z-50 text-gray-900 overflow-hidden">
          {hasActive && (
            <div className="border-b">
              <div className="px-3 py-2 bg-yellow-50 text-xs font-semibold text-yellow-800 uppercase">
                Active Sessions ({activeSessions.length})
              </div>
              <div className="max-h-40 overflow-y-auto">
                {activeSessions.map((s) => (
                  <div key={s.id} className="px-3 py-2 flex items-center gap-2 hover:bg-gray-50 text-sm border-b last:border-0">
                    <span className="w-2 h-2 rounded-full bg-yellow-500 shrink-0 animate-pulse" />
                    <button
                      onClick={() => { navigate(`/debugger?file=${encodeURIComponent(s.file)}`); setOpen(false) }}
                      className="font-mono text-xs text-blue-600 hover:underline truncate flex-1 text-left"
                    >
                      {s.file.replace(/.*\/app\//, 'app/')}:{s.line}
                    </button>
                    <span className="text-xs text-gray-400 shrink-0">in {s.method_name}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div>
            <div className="px-3 py-2 bg-gray-50 text-xs font-semibold text-gray-500 uppercase">
              Breakpoints ({breakpoints.length})
            </div>
            <div className="max-h-60 overflow-y-auto">
              {breakpoints.length === 0 ? (
                <div className="px-3 py-2 text-xs text-gray-400">No breakpoints set.</div>
              ) : (
                breakpoints.map((bp) => (
                  <div key={bp.id} className="px-3 py-2 flex items-center gap-2 hover:bg-gray-50 border-b last:border-0">
                    <span className="text-red-500 text-xs shrink-0">●</span>
                    <button
                      onClick={() => { navigate(`/debugger?file=${encodeURIComponent(bp.file)}`); setOpen(false) }}
                      className="font-mono text-xs text-left hover:underline truncate flex-1"
                    >
                      {bp.file.replace(/.*\/app\//, 'app/')}:{bp.line}
                      {bp.condition && <span className="text-gray-400 font-sans ml-1">if {bp.condition}</span>}
                    </button>
                    <OpenInEditor file={bp.file} line={bp.line} />
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default function Layout({ children }) {
  const location = useLocation()

  const navLinks = [
    { to: '/', label: 'Issues', match: (p) => p === '/' },
    { to: '/queries', label: 'Queries', match: (p) => p.startsWith('/queries') },
    { to: '/requests', label: 'Requests', match: (p) => p.startsWith('/requests') },
    { to: '/jobs', label: 'Jobs', match: (p) => p.startsWith('/jobs') },
    { to: '/errors', label: 'Errors', match: (p) => p.startsWith('/errors') },
    { to: '/tests', label: 'Tests', match: (p) => p.startsWith('/tests') },
    { to: '/debugger', label: 'Debugger', match: (p) => p.startsWith('/debugger'), accent: true },
  ]

  return (
    <div className="bg-gray-50 min-h-screen">
      <nav className="bg-gray-900 text-white">
        <div className="max-w-7xl mx-auto px-4 py-3 flex items-center gap-8">
          <Link to="/" className="flex items-center gap-1.5">
            <svg viewBox="0 0 440 120" fill="none" xmlns="http://www.w3.org/2000/svg" className="h-16" style={{ width: 'auto' }}>
              <circle cx="50" cy="60" r="28" stroke="currentColor" strokeWidth="5"/>
              <circle cx="50" cy="60" r="16" stroke="currentColor" strokeWidth="3"/>
              <circle cx="50" cy="60" r="5" fill="#EF4444"/>
              <line x1="50" y1="28" x2="50" y2="40" stroke="currentColor" strokeWidth="3" strokeLinecap="round"/>
              <line x1="50" y1="80" x2="50" y2="92" stroke="currentColor" strokeWidth="3" strokeLinecap="round"/>
              <line x1="18" y1="60" x2="30" y2="60" stroke="currentColor" strokeWidth="3" strokeLinecap="round"/>
              <line x1="70" y1="60" x2="82" y2="60" stroke="currentColor" strokeWidth="3" strokeLinecap="round"/>
              <text x="84" y="72" fontFamily="system-ui, -apple-system, sans-serif" fontSize="48" fontWeight="800" fill="currentColor" letterSpacing="-1">tail<tspan fill="#EF4444">scope</tspan></text>
              <path d="M78 60 Q88 54 98 60 Q108 66 118 60 Q128 54 138 60 Q148 66 158 60 Q168 54 178 60 Q188 66 198 60" stroke="#EF4444" strokeWidth="4" fill="none" strokeLinecap="round"/>
            </svg>
          </Link>
          <div className="flex gap-4 text-sm flex-1 items-center">
            {navLinks.map(({ to, label, match, accent }) => {
              const active = match(location.pathname)
              const base = accent ? 'text-yellow-400' : 'text-gray-400'
              const activeClass = accent ? 'text-yellow-300 font-medium' : 'text-white font-medium'
              return (
                <Link key={to} to={to} className={`hover:text-gray-200 ${active ? activeClass : base}`}>
                  {label}
                </Link>
              )
            })}
            <DebuggerIndicator />
          </div>
          <EditorPicker />
        </div>
      </nav>
      <div className="bg-red-600 text-white text-center text-xs py-1.5 px-4 font-medium">
        Early stage. Tailscope is under active development and has not been battle-tested in production. APIs, configuration, and internal behavior may change. Use in development environments only.
      </div>
      <main className={`mx-auto px-4 py-6 ${location.pathname.startsWith('/debugger') ? 'max-w-full' : 'max-w-7xl'}`}>
        {children}
      </main>
    </div>
  )
}
