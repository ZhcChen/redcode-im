import type {
  defineProps as DefineProps,
  defineEmits as DefineEmits,
  defineExpose as DefineExpose,
  withDefaults as WithDefaults
} from 'vue';

declare global {
  const defineProps: DefineProps;
  const defineEmits: DefineEmits;
  const defineExpose: DefineExpose;
  const withDefaults: WithDefaults;
}

export {};
