import React from 'react'
import { Link, useLocation } from 'react-router-dom'
import { EditorPicker } from './EditorContext'

export default function Layout({ children }) {
  const location = useLocation()

  const navLinks = [
    { to: '/', label: 'Issues', match: (p) => p === '/' },
    { to: '/queries', label: 'Queries', match: (p) => p.startsWith('/queries') },
    { to: '/requests', label: 'Requests', match: (p) => p.startsWith('/requests') },
    { to: '/errors', label: 'Errors', match: (p) => p.startsWith('/errors') },
    { to: '/debugger', label: 'Debugger', match: (p) => p.startsWith('/debugger'), accent: true },
  ]

  return (
    <div className="bg-gray-50 min-h-screen">
      <nav className="bg-gray-900 text-white">
        <div className="max-w-7xl mx-auto px-4 py-3 flex items-center gap-8">
          <Link to="/" className="text-lg font-bold tracking-tight">Tailscope</Link>
          <div className="flex gap-4 text-sm flex-1">
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
          </div>
          <EditorPicker />
        </div>
      </nav>
      <main className={`mx-auto px-4 py-6 ${location.pathname.startsWith('/debugger') ? 'max-w-full' : 'max-w-7xl'}`}>
        {children}
      </main>
    </div>
  )
}
