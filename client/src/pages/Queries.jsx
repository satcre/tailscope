import React from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api'
import DurationBadge from '../components/DurationBadge'
import TimeAgo from '../components/TimeAgo'
import Pagination from '../components/Pagination'
import Drawer from '../components/Drawer'
import QueryDrawer from '../drawers/QueryDrawer'

export default function Queries() {
  const [searchParams, setSearchParams] = useSearchParams()
  const page = parseInt(searchParams.get('page') || '1')
  const nPlusOneOnly = searchParams.get('n_plus_one') === '1'
  const [data, setData] = React.useState(null)
  const [loading, setLoading] = React.useState(true)
  const [selected, setSelected] = React.useState(null)

  React.useEffect(() => {
    setLoading(true)
    const p = new URLSearchParams({ page })
    if (nPlusOneOnly) p.set('n_plus_one_only', 'true')
    api.get(`/queries?${p}`).then(setData).finally(() => setLoading(false))
  }, [page, nPlusOneOnly])

  const truncate = (s, n = 120) => s && s.length > n ? s.slice(0, n) + '...' : s

  const handleDeleteAll = () => {
    if (!window.confirm('Delete all queries? This cannot be undone.')) return
    api.del('/queries').then(() => {
      setData({ queries: [], page: 1, per_page: 50, has_more: false })
    })
  }

  if (loading && !data) return <div className="text-gray-400">Loading...</div>

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold">{nPlusOneOnly ? 'N+1 Queries' : 'Slow Queries'}</h1>
        <div className="flex gap-2">
          <button
            onClick={() => setSearchParams({ page: '1' })}
            className={`px-3 py-1 text-sm rounded ${!nPlusOneOnly ? 'bg-gray-900 text-white' : 'bg-gray-200 text-gray-700'}`}
          >All</button>
          <button
            onClick={() => setSearchParams({ page: '1', n_plus_one: '1' })}
            className={`px-3 py-1 text-sm rounded ${nPlusOneOnly ? 'bg-gray-900 text-white' : 'bg-gray-200 text-gray-700'}`}
          >N+1 Only</button>
          <button
            onClick={handleDeleteAll}
            className="px-3 py-1 text-sm rounded bg-red-600 text-white hover:bg-red-700"
          >Delete All</button>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">SQL</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase w-24">Duration</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase w-20">N+1</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase w-24">When</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {data?.queries.map((q) => (
              <tr key={q.id} className="hover:bg-gray-50 cursor-pointer" onClick={() => setSelected(q.id)}>
                <td className="px-4 py-2 text-sm font-mono text-gray-700 max-w-md truncate">{truncate(q.sql_text)}</td>
                <td className="px-4 py-2"><DurationBadge ms={q.duration_ms} /></td>
                <td className="px-4 py-2">
                  {q.n_plus_one === 1 && <span className="text-xs bg-red-100 text-red-700 px-2 py-0.5 rounded font-medium">{q.n_plus_one_count}x</span>}
                </td>
                <td className="px-4 py-2 text-xs text-gray-500"><TimeAgo timestamp={q.recorded_at} /></td>
              </tr>
            ))}
            {data?.queries.length === 0 && (
              <tr><td colSpan="4" className="px-4 py-8 text-center text-gray-400">No queries recorded.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {data && <Pagination page={page} hasMore={data.has_more} onPageChange={(p) => {
        const params = new URLSearchParams(searchParams)
        params.set('page', p)
        setSearchParams(params)
      }} />}

      <Drawer isOpen={!!selected} onClose={() => setSelected(null)} title={`Query #${selected}`}>
        {selected && <QueryDrawer queryId={selected} />}
      </Drawer>
    </div>
  )
}
