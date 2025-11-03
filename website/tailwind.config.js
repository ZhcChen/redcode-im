import forms from '@tailwindcss/forms'
import containerQueries from '@tailwindcss/container-queries'

export default {
  content: [
    './components/**/*.{js,vue,ts}',
    './layouts/**/*.vue',
    './pages/**/*.vue',
    './plugins/**/*.{js,ts}',
    './app/**/*.vue',
    './app.vue',
    './error.vue'
  ],
  theme: {
    extend: {},
  },
  plugins: [
    forms,
    containerQueries
  ],
}

