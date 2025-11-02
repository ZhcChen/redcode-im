declare module 'vue' {
  export const ref: typeof import('@vue/reactivity')['ref'];
  export const reactive: typeof import('@vue/reactivity')['reactive'];
  export const computed: typeof import('@vue/reactivity')['computed'];
  export const watch: typeof import('@vue/runtime-dom')['watch'];
  export const watchEffect: typeof import('@vue/runtime-dom')['watchEffect'];
  export const nextTick: typeof import('@vue/runtime-dom')['nextTick'];
  export const onMounted: typeof import('@vue/runtime-dom')['onMounted'];
  export const onUnmounted: typeof import('@vue/runtime-dom')['onUnmounted'];
  export const createApp: typeof import('@vue/runtime-dom')['createApp'];
  export const Teleport: typeof import('@vue/runtime-dom')['Teleport'];
  export const Transition: typeof import('@vue/runtime-dom')['Transition'];
  export type DefineComponent = typeof import('@vue/runtime-dom')['defineComponent'];
  export * from '@vue/runtime-dom';
  export * from '@vue/reactivity';
}
