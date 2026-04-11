import { resolve } from 'path';
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import vueJsx from '@vitejs/plugin-vue-jsx';
import svgLoader from 'vite-svg-loader';
import configArcoStyleImportPlugin from './plugin/arcoStyleImport';

export default defineConfig({
  plugins: [
    vue(),
    vueJsx(),
    svgLoader({ svgoConfig: {} }),
    configArcoStyleImportPlugin(),
  ],
  resolve: {
    alias: [
      {
        find: '@',
        replacement: resolve(__dirname, '../src'),
      },
      {
        find: 'assets',
        replacement: resolve(__dirname, '../src/assets'),
      },
      {
        find: 'vue-i18n',
        replacement: 'vue-i18n/dist/vue-i18n.cjs.js', // Resolve the i18n warning issue
      },
      {
        find: /^vue$/,
        replacement: resolve(__dirname, '../src/shims/vue-with-default'),
      },
    ],
    extensions: ['.ts', '.js'],
  },
  define: {
    'process.env': {},
    '__VUE_OPTIONS_API__': JSON.stringify(true),
    '__VUE_PROD_DEVTOOLS__': JSON.stringify(false),
    '__VUE_PROD_HYDRATION_MISMATCH_DETAILS__': JSON.stringify(false),
    '__VITE_ENABLE_DATA_CLEANUP__': JSON.stringify(
      process.env.VITE_ENABLE_DATA_CLEANUP || 'false'
    ),
    '__VITE_ENABLE_DEV_MOCKS__': JSON.stringify(
      process.env.VITE_ENABLE_DEV_MOCKS || 'false'
    ),
  },
  css: {
    preprocessorOptions: {
      less: {
        modifyVars: {
          hack: `true; @import (reference) "${resolve(
            'src/assets/style/breakpoint.less'
          )}";`,
        },
        javascriptEnabled: true,
      },
    },
  },
});
