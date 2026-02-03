import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: path.resolve(__dirname, '../public/tailscope'),
    emptyOutDir: true,
    rollupOptions: {
      output: {
        entryFileNames: 'app.js',
        assetFileNames: (assetInfo) => {
          if (assetInfo.name?.endsWith('.css')) return 'app.css'
          return assetInfo.name
        }
      }
    }
  },
  base: '/tailscope/',
  server: {
    proxy: {
      '/tailscope/api': 'http://localhost:3000'
    }
  }
})
