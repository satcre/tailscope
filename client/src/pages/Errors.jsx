import React from 'react'
import { useSearchParams } from 'react-router-dom'
import { api } from '../api'
import TimeAgo from '../components/TimeAgo'
import Pagination from '../components/Pagination'
import Drawer from '../components/Drawer'
import ErrorDrawer from '../drawers/ErrorDrawer'
import OpenInEditor from '../components/OpenInEditor'
import OpenInDebugger from '../components/OpenInDebugger'

export default function Errors() {
  const [searchParams, setSearchParams] = useSearchParams()
  const page = parseInt(searchParams.get('page') || '1')
  const [data, setData] = React.useState(null)
  const [loading, setLoading] = React.useState(true)
  const [selected, setSelected] = React.useState(null)

  React.useEffect(() => {
    setLoading(true)
    api.get(`/errors?page=${page}`).then(setData).finally(() => setLoading(false))
  }, [page])

  const handleDeleteAll = () => {
    if (!window.confirm('Delete all errors? This cannot be undone.')) return
    api.del('/errors').then(() => {
      setData({ errors: [], page: 1, per_page: 50, has_more: false })
    })
  }

  if (loading && !data) return <div className="text-gray-400">Loading...</div>

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-baseline gap-3">
          <h1 className="text-2xl font-bold">Errors</h1>
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
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Exception</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Message</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Source</th>
              <th className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase w-24">When</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {data?.errors.map((e) => (
              <tr key={e.id} className="hover:bg-gray-50 cursor-pointer" onClick={() => setSelected(e.id)}>
                <td className="px-4 py-2 text-sm font-semibold text-red-800">{e.exception_class}</td>
                <td className="px-4 py-2 text-sm text-gray-600 truncate max-w-sm">{e.message}</td>
                <td className="px-4 py-2 text-sm font-mono text-gray-500 truncate">
                  {e.source_file ? (
                    <span className="inline-flex items-center gap-1">
                      {e.source_file.replace(/.*\/app\//, 'app/')}:{e.source_line}
                      <OpenInEditor file={e.source_file} line={e.source_line} />
                      <OpenInDebugger file={e.source_file} line={e.source_line} />
                    </span>
                  ) : '—'}
                </td>
                <td className="px-4 py-2 text-xs text-gray-500"><TimeAgo timestamp={e.recorded_at} /></td>
              </tr>
            ))}
            {data?.errors.length === 0 && (
              <tr><td colSpan="4" className="px-4 py-8 text-center text-gray-400">No errors recorded.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {data && <Pagination page={page} hasMore={data.has_more} onPageChange={(p) => setSearchParams({ page: p })} />}

      <Drawer isOpen={!!selected} onClose={() => setSelected(null)} title={`Error #${selected}`}>
        {selected && <ErrorDrawer errorId={selected} />}
      </Drawer>
    </div>
  )
}
