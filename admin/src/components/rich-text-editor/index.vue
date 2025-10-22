<template>
  <div class="rich-text-editor">
    <Toolbar
      class="rich-text-editor__toolbar"
      :editor="editorRef"
      :default-config="toolbarConfig"
      :mode="mode"
    />
    <Editor
      v-model="valueHtml"
      class="rich-text-editor__content"
      :default-config="editorConfig"
      :mode="mode"
      @on-created="handleCreated"
    />
  </div>
</template>

<script lang="ts" setup>
  import '@wangeditor/editor/dist/css/style.css';
  import { shallowRef, ref, watch, onBeforeUnmount, computed } from 'vue';
  import { Editor, Toolbar } from '@wangeditor/editor-for-vue';
  import type { IEditorConfig, IToolbarConfig } from '@wangeditor/editor';

  interface Props {
    modelValue: string;
    mode?: 'default' | 'simple';
    placeholder?: string;
    readOnly?: boolean;
  }

  const props = withDefaults(defineProps<Props>(), {
    modelValue: '',
    mode: 'default',
    placeholder: '请输入内容...',
    readOnly: false,
  });

  const emit = defineEmits<{
    (e: 'update:modelValue', value: string): void;
  }>();

  const editorRef = shallowRef();
  const valueHtml = ref(props.modelValue);

  const toolbarConfig = computed<Partial<IToolbarConfig>>(() => ({
    excludeKeys: ['group-video', 'insertVideo', 'insertTable'],
  }));

  const editorConfig = computed<Partial<IEditorConfig>>(() => ({
    placeholder: props.placeholder,
    readOnly: props.readOnly,
  }));

  const handleCreated = (editor: any) => {
    editorRef.value = editor;
  };

  watch(
    () => props.modelValue,
    (val) => {
      if (val !== valueHtml.value) {
        valueHtml.value = val ?? '';
      }
    },
  );

  watch(
    valueHtml,
    (val) => {
      emit('update:modelValue', val);
    },
  );

  onBeforeUnmount(() => {
    const editor = editorRef.value;
    if (editor != null) {
      editor.destroy();
    }
  });
</script>

<style scoped>
  .rich-text-editor {
    border: 1px solid var(--color-border-2, #e5e6eb);
    border-radius: 8px;
    overflow: hidden;
    display: flex;
    flex-direction: column;
  }

  .rich-text-editor__toolbar {
    border-bottom: 1px solid var(--color-border-2, #e5e6eb);
  }

  .rich-text-editor__content {
    min-height: 320px;
  }
</style>
