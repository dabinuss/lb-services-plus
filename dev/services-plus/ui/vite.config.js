import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { fileURLToPath } from 'node:url'

// The built index.html is loaded by lb-phone as
// "<resource>/ui/dist/index.html", so production assets must resolve from
// that same path. In dev, Vite serves from "/" as usual.
export default defineConfig(({ command }) => ({
  base: command === 'build' ? '/ui/dist/' : '/',
  build: {
    sourcemap: false,
    rollupOptions: {
      input: {
        main: fileURLToPath(new URL('./index.html', import.meta.url)),
        notifications: fileURLToPath(new URL('./notifications.html', import.meta.url)),
      },
    },
  },
  server: {
    port: 5173,
  },
  plugins: [react()],
}))
