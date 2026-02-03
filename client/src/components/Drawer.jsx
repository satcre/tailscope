import React from 'react'

export default function Drawer({ isOpen, onClose, title, children, wide }) {
  React.useEffect(() => {
    if (!isOpen) return
    const handleEsc = (e) => { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', handleEsc)
    document.body.style.overflow = 'hidden'
    return () => {
      document.removeEventListener('keydown', handleEsc)
      document.body.style.overflow = ''
    }
  }, [isOpen, onClose])

  if (!isOpen) return null

  return (
    <>
      <div className="fixed inset-0 bg-black/50 z-40 transition-opacity" onClick={onClose} />
      <div className={`fixed inset-y-0 right-0 w-full bg-white shadow-xl z-50 overflow-y-auto transform transition-transform ${wide ? 'sm:w-3/4 lg:w-2/3' : 'sm:w-2/3 lg:w-1/2'}`}>
        <div className="sticky top-0 bg-white border-b px-6 py-4 flex items-center justify-between z-10">
          <h2 className="text-lg font-bold text-gray-900">{title}</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-2xl leading-none">&times;</button>
        </div>
        <div className="p-6 overflow-x-hidden min-w-0">{children}</div>
      </div>
    </>
  )
}
