import React from 'react'
import { api } from '../api'
import { useEditor } from './EditorContext'

export default function OpenInEditor({ file, line }) {
  const { editor } = useEditor()
  const [status, setStatus] = React.useState(null)

  if (!file) return null

  const handleClick = async (e) => {
    e.stopPropagation()
    e.preventDefault()
    try {
      const body = { file, line: line || 1 }
      if (editor) body.editor = editor
      const res = await api.post('/editor/open', body)
      if (res.ok) {
        setStatus('ok')
      } else {
        setStatus('error')
      }
    } catch {
      setStatus('error')
    }
    setTimeout(() => setStatus(null), 2000)
  }

  const label = status === 'ok' ? 'Opened' : status === 'error' ? 'Failed' : 'Open in editor'

  return (
    <button
      onClick={handleClick}
      className={`inline-flex items-center gap-1 px-2 py-0.5 text-xs rounded border transition-colors ${
        status === 'ok'
          ? 'border-green-300 bg-green-50 text-green-700'
          : status === 'error'
          ? 'border-red-300 bg-red-50 text-red-600'
          : 'border-gray-300 bg-white text-gray-600 hover:bg-gray-50 hover:border-gray-400'
      }`}
      title={`${file}${line ? `:${line}` : ''}`}
    >
      {status === 'ok' ? (
        <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
        </svg>
      ) : status === 'error' ? (
        <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      ) : (
        <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
        </svg>
      )}
      {label}
    </button>
  )
}
