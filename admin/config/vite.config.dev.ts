import { mergeConfig } from 'vite';
import eslint from 'vite-plugin-eslint';
import baseConfig from './vite.config.base';

export default mergeConfig(
  {
    mode: 'development',
    server: {
      open: true,
      port: 8011,
      fs: {
        strict: true,
      },
    },
    define: {
      __VITE_ENABLE_DATA_CLEANUP__: JSON.stringify(
        process.env.VITE_ENABLE_DATA_CLEANUP || 'true'
      ),
    },
    plugins: [
      eslint({
        cache: false,
        include: ['src/**/*.ts', 'src/**/*.tsx', 'src/**/*.vue'],
        exclude: ['node_modules'],
      }),
    ],
  },
  baseConfig
);
