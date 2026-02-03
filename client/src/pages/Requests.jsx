import React from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api'
import DurationBadge from '../components/DurationBadge'
import TimeAgo from '../components/TimeAgo'
import Pagination from '../components/Pagination'
import Drawer from '../components/Drawer'
import RequestDrawer from '../drawers/RequestDrawer'

export default function Requests() {
  const [searchParams, setSearchParams] = useSearchParams()
  const page = parseInt(searchParams.get('page') || '1')
  const [data, setData] = React.useState(null)
  const [loading, setLoading] = React.useState(true)
  const [selected, setSelected] = React.useState(null)

  const loadData = React.useCallback(() => {
    api.get(`/requests?page=${page}`).then(setData).finally(() => setLoading(false))
  }, [page])

  React.useEffect(() => {
    setLoading(true)
    loadData()
    const interval = setInterval(loadData, 3000)
    return () => clearInterval(interval)
  }, [loadData])

  const handleDeleteAll = () => {
    if (!window.confirm('Delete all requests? This cannot be undone.')) return
    api.del('/requests').then(() => {
      setData({ requests: [], total: 0, page: 1, per_page: 50, has_more: false })
    })
  }

  if (loading && !data) return <div className="text-gray-400">Loading...</div>

  const statusColor = (s) =>
    s < 300 ? 'bg-green-100 text-green-800'
    : s < 400 ? 'bg-blue-100 text-blue-800'
    : s < 500 ? 'bg-yellow-100 text-yellow-800'
    : 'bg-red-100 text-red-800'

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-baseline gap-3">
          <h1 className="text-2xl font-bold">Requests</h1>
          {data?.total != null && (
            <span className="text-sm text-gray-500">{data.total.toLocaleString()} total</span>
          )}
        </div>
        <button
          onClick={handleDeleteAll}
          className="px-3 py-1 text-sm rounded bg-red-600 text-white hover:bg-red-700"
        >Delete All</button>
      </div>

      <div className="bg-white rounded-lg shadow overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Method</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Path</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase w-20">Status</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase w-24">Duration</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Controller</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase w-24">When</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {data?.requests.map((r) => (
              <tr key={r.id} className="hover:bg-gray-50 cursor-pointer" onClick={() => setSelected(r.id)}>
                <td className="px-4 py-2">
                  <span className="px-2 py-0.5 text-xs font-bold rounded bg-gray-800 text-white">{r.method}</span>
                </td>
                <td className="px-4 py-2 text-sm font-mono text-gray-700 truncate max-w-xs">{r.path}</td>
                <td className="px-4 py-2">
                  <span className={`px-2 py-0.5 text-xs rounded font-medium ${statusColor(r.status)}`}>{r.status}</span>
                </td>
                <td className="px-4 py-2"><DurationBadge ms={r.duration_ms} /></td>
                <td className="px-4 py-2 text-sm font-mono text-gray-600">{r.controller ? `${r.controller}#${r.action}` : '—'}</td>
                <td className="px-4 py-2 text-xs text-gray-500"><TimeAgo timestamp={r.recorded_at} /></td>
              </tr>
            ))}
            {data?.requests.length === 0 && (
              <tr><td colSpan="6" className="px-4 py-8 text-center text-gray-400">No requests recorded.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {data && <Pagination page={page} hasMore={data.has_more} onPageChange={(p) => setSearchParams({ page: p })} />}

      <Drawer isOpen={!!selected} onClose={() => setSelected(null)} title={`Request #${selected}`}>
        {selected && <RequestDrawer requestId={selected} />}
      </Drawer>
    </div>
  )
}
