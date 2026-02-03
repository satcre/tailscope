import React from 'react'
import { api } from '../api'
import { useEditor } from './EditorContext'

export default function OpenInEditor({ file, line }) {
  const { editor } = useEditor()
  const [status, setStatus] = React.useState(null)

  if (!file) return null
  if (file.includes('/gems/') || file.includes('/ruby/lib/')) return null

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

  return (
    <button
      onClick={handleClick}
      className={`inline-flex items-center px-1.5 py-0.5 rounded border text-xs transition-colors shrink-0 ${
        status === 'ok'
          ? 'border-green-300 bg-green-50 text-green-700'
          : status === 'error'
          ? 'border-red-300 bg-red-50 text-red-600'
          : 'border-gray-300 bg-white text-gray-500 hover:bg-gray-50 hover:border-gray-400'
      }`}
      title={`Open ${file}${line ? `:${line}` : ''} in editor`}
    >
      {status === 'ok' ? (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
        </svg>
      ) : status === 'error' ? (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
        </svg>
      ) : (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M17.25 6.75L22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3l-4.5 16.5" />
        </svg>
      )}
    </button>
  )
}
