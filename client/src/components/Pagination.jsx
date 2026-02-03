import React from 'react'

export default function Pagination({ page, hasMore, onPageChange }) {
  if (page <= 1 && !hasMore) return null

  return (
    <div className="mt-4 flex justify-between items-center">
      {page > 1 ? (
        <button onClick={() => onPageChange(page - 1)} className="text-sm text-blue-600 hover:underline">
          &larr; Previous
        </button>
      ) : <span />}
      <span className="text-sm text-gray-400">Page {page}</span>
      {hasMore ? (
        <button onClick={() => onPageChange(page + 1)} className="text-sm text-blue-600 hover:underline">
          Next &rarr;
        </button>
      ) : <span />}
    </div>
  )
}
