import { mergeConfig } from 'vite';
import baseConfig from './vite.config.base';
import configCompressPlugin from './plugin/compress';
import configVisualizerPlugin from './plugin/visualizer';
import configArcoResolverPlugin from './plugin/arcoResolver';

export default mergeConfig(
  {
    mode: 'production',
    plugins: [
      configCompressPlugin('gzip'),
      configVisualizerPlugin(),
      configArcoResolverPlugin(),
    ],
    build: {
      rollupOptions: {
        onwarn(warning, warn) {
          if (warning.code === 'EVAL') {
            return;
          }
          warn(warning);
        },
        output: {
          manualChunks: {
            arco: ['@arco-design/web-vue'],
            chart: ['echarts', 'vue-echarts'],
            vue: ['vue', 'vue-router', 'pinia', '@vueuse/core', 'vue-i18n'],
          },
        },
      },
      chunkSizeWarningLimit: 2000,
      // 抑制 CSS 嵌套语法警告(不影响功能,只是压缩器的限制)
      cssMinify: 'esbuild',
    },
    // esbuild 配置
    esbuild: {
      logOverride: {
        'css-syntax-error': 'silent',
        'invalid-@nest': 'silent',
      },
    },
  },
  baseConfig
);
