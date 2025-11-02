import { DefineComponent, VNode } from 'vue';

declare global {
  namespace JSX {
    interface IntrinsicElements {
      'a-menu': any;
      'a-sub-menu': any;
      'a-menu-item': any;
    }
  }
}

export {};
