import React from 'react'
import hljs from 'highlight.js/lib/core'
import ruby from 'highlight.js/lib/languages/ruby'
import javascript from 'highlight.js/lib/languages/javascript'
import xml from 'highlight.js/lib/languages/xml'
import css from 'highlight.js/lib/languages/css'
import sql from 'highlight.js/lib/languages/sql'
import yaml from 'highlight.js/lib/languages/yaml'
import json from 'highlight.js/lib/languages/json'
import erb from 'highlight.js/lib/languages/erb'
import markdown from 'highlight.js/lib/languages/markdown'
import 'highlight.js/styles/github-dark.css'

hljs.registerLanguage('ruby', ruby)
hljs.registerLanguage('javascript', javascript)
hljs.registerLanguage('html', xml)
hljs.registerLanguage('xml', xml)
hljs.registerLanguage('css', css)
hljs.registerLanguage('sql', sql)
hljs.registerLanguage('yaml', yaml)
hljs.registerLanguage('json', json)
hljs.registerLanguage('erb', erb)
hljs.registerLanguage('markdown', markdown)

const EXT_MAP = {
  rb: 'ruby', rake: 'ruby', gemspec: 'ruby', ru: 'ruby',
  js: 'javascript', jsx: 'javascript', mjs: 'javascript',
  ts: 'javascript', tsx: 'javascript',
  html: 'html', htm: 'html',
  erb: 'erb',
  css: 'css', scss: 'css',
  sql: 'sql',
  yml: 'yaml', yaml: 'yaml',
  json: 'json',
  md: 'markdown',
  xml: 'xml',
}

function getLang(filePath) {
  if (!filePath) return null
  const ext = filePath.split('.').pop()?.toLowerCase()
  return EXT_MAP[ext] || null
}

const highlightCache = {}

export function useHighlightedLines(lines, filePath) {
  const [highlighted, setHighlighted] = React.useState([])

  React.useEffect(() => {
    if (!lines || lines.length === 0) { setHighlighted([]); return }

    const lang = getLang(filePath)
    const code = Array.isArray(lines)
      ? (typeof lines[0] === 'string' ? lines.join('\n') : lines.map((l) => l.content).join('\n'))
      : ''
    if (!code) { setHighlighted(lines.map(() => '')); return }

    const cacheKey = `${filePath}:${lines.length}`
    if (highlightCache[cacheKey]) {
      setHighlighted(highlightCache[cacheKey])
      return
    }

    // Defer highlighting so plain text renders first
    const id = requestAnimationFrame(() => {
      try {
        const result = lang
          ? hljs.highlight(code, { language: lang, ignoreIllegals: true })
          : hljs.highlightAuto(code)
        const result_lines = result.value.split('\n')
        highlightCache[cacheKey] = result_lines
        setHighlighted(result_lines)
      } catch {
        setHighlighted(lines.map((l) => typeof l === 'string' ? l : l.content))
      }
    })

    return () => cancelAnimationFrame(id)
  }, [lines, filePath])

  return highlighted
}

export function HighlightedCode({ html }) {
  return <span dangerouslySetInnerHTML={{ __html: html }} />
}
