/// <reference types="vite/client" />

declare module "*.vue" {
  import type { DefineComponent } from "vue";
  const component: DefineComponent<{}, {}, any>;
  export default component;
}

// Toast 类型声明
declare module '@vue/runtime-core' {
  interface ComponentCustomProperties {
    $toast: {
      show(options: { message: string; type?: 'info' | 'success' | 'warning' | 'error'; duration?: number }): void;
      info(message: string, duration?: number): void;
      success(message: string, duration?: number): void;
      warning(message: string, duration?: number): void;
      error(message: string, duration?: number): void;
      close(): void;
    };
  }
}
