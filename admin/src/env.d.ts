/// <reference types="vite/client" />

declare module '*.vue' {
  import { DefineComponent } from 'vue';
  // eslint-disable-next-line @typescript-eslint/no-explicit-any, @typescript-eslint/ban-types
  const component: DefineComponent<{}, {}, any>;
  export default component;
}
interface ImportMetaEnv {
  readonly VITE_API_BASE_URL: string;
}

// 构建时注入的特性开关
// eslint-disable-next-line no-underscore-dangle
declare const __VITE_ENABLE_DATA_CLEANUP__: string;
// eslint-disable-next-line no-underscore-dangle
declare const __VITE_ENABLE_DEV_MOCKS__: string;
