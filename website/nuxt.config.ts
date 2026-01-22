// https://nuxt.com/docs/reference/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  devServer: {
    port: 8015
  },
  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || 'http://localhost:8010'
    }
  },
  app: {
    head: {
      link: [
        { rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' },
        { rel: 'icon', type: 'image/png', sizes: '64x64', href: '/logo-64.png' },
        { rel: 'icon', type: 'image/png', sizes: '192x192', href: '/logo-192.png' },
        { rel: 'apple-touch-icon', sizes: '180x180', href: '/logo-192.png' }
      ]
    }
  },
  modules: ['@nuxtjs/tailwindcss']
})
