import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    watch: {
      usePolling: true,
    },
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    // Ensure proper asset paths for production
    assetsInlineLimit: 4096,
    // Generate source maps for debugging (optional, can be disabled for smaller builds)
    sourcemap: false,
    // Optimize build output
    rollupOptions: {
      output: {
        // Ensure consistent chunk naming
        chunkFileNames: 'assets/js/[name]-[hash].js',
        entryFileNames: 'assets/js/[name]-[hash].js',
        assetFileNames: 'assets/[ext]/[name]-[hash].[ext]',
      },
    },
  },
  // Base path - empty for root deployment
  base: '/',
})

