import React from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api'
import DurationBadge from '../components/DurationBadge'
import TimeAgo from '../components/TimeAgo'
import Pagination from '../components/Pagination'
import Drawer from '../components/Drawer'
import JobDrawer from '../drawers/JobDrawer'

const statusStyle = (s) =>
  s === 'performed' ? 'bg-green-100 text-green-800'
  : s === 'enqueued' ? 'bg-blue-100 text-blue-800'
  : 'bg-red-100 text-red-800'

export default function Jobs() {
  const [searchParams, setSearchParams] = useSearchParams()
  const page = parseInt(searchParams.get('page') || '1')
  const [data, setData] = React.useState(null)
  const [loading, setLoading] = React.useState(true)
  const [selected, setSelected] = React.useState(null)

  const loadData = React.useCallback(() => {
    api.get(`/jobs?page=${page}`).then(setData).finally(() => setLoading(false))
  }, [page])

  React.useEffect(() => {
    setLoading(true)
    loadData()
    const interval = setInterval(loadData, 3000)
    return () => clearInterval(interval)
  }, [loadData])

  const handleDeleteAll = () => {
    if (!window.confirm('Delete all jobs? This cannot be undone.')) return
    api.del('/jobs').then(() => {
      setData({ jobs: [], total: 0, page: 1, per_page: 50, has_more: false })
    })
  }

  if (loading && !data) return <div className="text-gray-400">Loading...</div>

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-baseline gap-3">
          <h1 className="text-2xl font-bold">Jobs</h1>
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
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Job Class</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase w-24">Queue</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase w-24">Status</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase w-24">Duration</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase w-24">When</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {data?.jobs.map((j) => (
              <tr key={j.id} className="hover:bg-gray-50 cursor-pointer" onClick={() => setSelected(j.id)}>
                <td className="px-4 py-2 text-sm font-mono text-gray-700">{j.job_class}</td>
                <td className="px-4 py-2">
                  <span className="px-2 py-0.5 text-xs rounded bg-indigo-100 text-indigo-800 font-medium">{j.queue_name || 'default'}</span>
                </td>
                <td className="px-4 py-2">
                  <span className={`px-2 py-0.5 text-xs rounded font-medium ${statusStyle(j.status)}`}>{j.status}</span>
                </td>
                <td className="px-4 py-2">{j.duration_ms != null ? <DurationBadge ms={j.duration_ms} /> : '—'}</td>
                <td className="px-4 py-2 text-xs text-gray-500"><TimeAgo timestamp={j.recorded_at} /></td>
              </tr>
            ))}
            {data?.jobs.length === 0 && (
              <tr><td colSpan="5" className="px-4 py-8 text-center text-gray-400">No jobs recorded.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {data && <Pagination page={page} hasMore={data.has_more} onPageChange={(p) => setSearchParams({ page: p })} />}

      <Drawer isOpen={!!selected} onClose={() => setSelected(null)} title={`Job #${selected}`}>
        {selected && <JobDrawer jobId={selected} />}
      </Drawer>
    </div>
  )
}
