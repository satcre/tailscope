import React from 'react'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { EditorProvider } from './components/EditorContext'
import Layout from './components/Layout'
import Issues from './pages/Issues'
import Queries from './pages/Queries'
import Requests from './pages/Requests'
import Errors from './pages/Errors'
import Jobs from './pages/Jobs'
import Tests from './pages/Tests'
import Debugger from './pages/Debugger'


export default function App() {
  return (
    <EditorProvider>
    <BrowserRouter basename="/tailscope">
      <Layout>
        <Routes>
          <Route path="/" element={<Issues />} />
          <Route path="/queries" element={<Queries />} />
          <Route path="/requests" element={<Requests />} />
          <Route path="/jobs" element={<Jobs />} />
          <Route path="/errors" element={<Errors />} />
          <Route path="/tests" element={<Tests />} />
          <Route path="/debugger" element={<Debugger />} />
        </Routes>
      </Layout>
    </BrowserRouter>
    </EditorProvider>
  )
}
