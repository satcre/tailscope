import React from 'react'
import { api } from '../api'

const EDITORS = [
  { id: 'vscode', label: 'VS Code' },
  { id: 'sublime', label: 'Sublime Text' },
  { id: 'rubymine', label: 'RubyMine' },
  { id: 'nvim_terminal', label: 'Neovim (Terminal)' },
  { id: 'nvim_iterm', label: 'Neovim (iTerm)' },
]

const LS_KEY = 'tailscope_editor'

const EditorContext = React.createContext({ editor: null, setEditor: () => {} })

export function EditorProvider({ children }) {
  const [editor, setEditorState] = React.useState(() => localStorage.getItem(LS_KEY) || null)

  const setEditor = React.useCallback((val) => {
    setEditorState(val)
    if (val) localStorage.setItem(LS_KEY, val)
    else localStorage.removeItem(LS_KEY)
  }, [])

  return (
    <EditorContext.Provider value={{ editor, setEditor }}>
      {children}
    </EditorContext.Provider>
  )
}

export function useEditor() {
  return React.useContext(EditorContext)
}

export function EditorPicker() {
  const { editor, setEditor } = useEditor()
  const [open, setOpen] = React.useState(false)
  const [checking, setChecking] = React.useState(null)
  const [error, setError] = React.useState(null)
  const ref = React.useRef(null)

  React.useEffect(() => {
    if (!open) return
    const close = (e) => { if (ref.current && !ref.current.contains(e.target)) setOpen(false) }
    document.addEventListener('mousedown', close)
    return () => document.removeEventListener('mousedown', close)
  }, [open])

  const handleSelect = async (editorId) => {
    setChecking(editorId)
    setError(null)
    try {
      await api.post('/editor/check', { editor: editorId })
      setEditor(editorId)
      setOpen(false)
    } catch (err) {
      setError(err.message || `${editorId} is not installed`)
    } finally {
      setChecking(null)
    }
  }

  const current = EDITORS.find((e) => e.id === editor)

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => { setOpen(!open); setError(null) }}
        className="flex items-center gap-1 text-xs text-gray-400 hover:text-gray-200 px-2 py-1 rounded border border-gray-700 hover:border-gray-500"
      >
        <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
        </svg>
        {current ? current.label : 'Editor'}
        <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      {open && (
        <div className="absolute right-0 top-full mt-1 bg-white rounded shadow-lg border py-1 z-50 min-w-[200px]">
          {error && (
            <div className="px-3 py-2 text-xs text-red-600 bg-red-50 border-b">
              {error}
            </div>
          )}
          <div className="px-3 py-1.5 text-xs text-gray-400 uppercase font-semibold">GUI Editors</div>
          {EDITORS.filter((e) => !e.id.startsWith('nvim')).map((e) => (
            <button
              key={e.id}
              onClick={() => handleSelect(e.id)}
              disabled={checking !== null}
              className={`w-full text-left px-3 py-1.5 text-sm hover:bg-gray-100 ${editor === e.id ? 'text-blue-600 font-medium' : 'text-gray-700'} ${checking === e.id ? 'opacity-50' : ''}`}
            >
              {checking === e.id ? (
                <span className="text-gray-400">Checking...</span>
              ) : (
                <>
                  {e.label}
                  {editor === e.id && <span className="ml-1">✓</span>}
                </>
              )}
            </button>
          ))}
          <div className="border-t my-1" />
          <div className="px-3 py-1.5 text-xs text-gray-400 uppercase font-semibold">Terminal Editors</div>
          {EDITORS.filter((e) => e.id.startsWith('nvim')).map((e) => (
            <button
              key={e.id}
              onClick={() => handleSelect(e.id)}
              disabled={checking !== null}
              className={`w-full text-left px-3 py-1.5 text-sm hover:bg-gray-100 ${editor === e.id ? 'text-blue-600 font-medium' : 'text-gray-700'} ${checking === e.id ? 'opacity-50' : ''}`}
            >
              {checking === e.id ? (
                <span className="text-gray-400">Checking...</span>
              ) : (
                <>
                  {e.label}
                  {editor === e.id && <span className="ml-1">✓</span>}
                </>
              )}
            </button>
          ))}
          {editor && (
            <>
              <div className="border-t my-1" />
              <button
                onClick={() => { setEditor(null); setOpen(false); setError(null) }}
                className="w-full text-left px-3 py-1.5 text-sm text-gray-400 hover:bg-gray-100"
              >
                Auto-detect
              </button>
            </>
          )}
        </div>
      )}
    </div>
  )
}

export { EDITORS }
