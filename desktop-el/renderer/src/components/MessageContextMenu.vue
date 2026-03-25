<script setup lang="ts">
import { computed, onUnmounted, watch } from "vue";
import { clampContextMenuPosition } from "@/utils/chat-context-menu";

type MessageContextMenuAction =
  | "copy"
  | "reply"
  | "forward"
  | "pin"
  | "reaction"
  | "readers"
  | "edit"
  | "resend"
  | "multi-select"
  | "delete";

const props = defineProps<{
  visible: boolean;
  position: {
    x: number;
    y: number;
  };
  canCopy: boolean;
  canReply: boolean;
  canForward: boolean;
  canPin: boolean;
  isPinned: boolean;
  canReaction: boolean;
  canReaders: boolean;
  canEdit: boolean;
  canResend: boolean;
  canMultiSelect: boolean;
  canDelete: boolean;
  deleteLabel: string;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: MessageContextMenuAction): void;
}>();

const items = computed<
  Array<{
    key: MessageContextMenuAction;
    label: string;
    danger?: boolean;
  }>
>(() => {
  const nextItems: Array<{
    key: MessageContextMenuAction;
    label: string;
    danger?: boolean;
  }> = [];

  if (props.canCopy) {
    nextItems.push({ key: "copy", label: "复制" });
  }
  if (props.canReply) {
    nextItems.push({ key: "reply", label: "引用" });
  }
  if (props.canForward) {
    nextItems.push({ key: "forward", label: "转发" });
  }
  if (props.canPin) {
    nextItems.push({
      key: "pin",
      label: props.isPinned ? "取消置顶" : "置顶",
    });
  }
  if (props.canReaction) {
    nextItems.push({ key: "reaction", label: "添加反应" });
  }
  if (props.canReaders) {
    nextItems.push({ key: "readers", label: "已读成员" });
  }
  if (props.canEdit) {
    nextItems.push({ key: "edit", label: "编辑" });
  }
  if (props.canResend) {
    nextItems.push({ key: "resend", label: "重发" });
  }
  if (props.canMultiSelect) {
    nextItems.push({ key: "multi-select", label: "多选" });
  }
  if (props.canDelete) {
    nextItems.push({
      key: "delete",
      label: props.deleteLabel,
      danger: true,
    });
  }

  return nextItems;
});

const menuStyle = computed(() => {
  const position = clampContextMenuPosition(props.position, {
    menuWidth: 188,
    menuHeight: Math.max(56, items.value.length * 42 + 16),
    viewportWidth: window.innerWidth,
    viewportHeight: window.innerHeight,
  });
  return {
    left: `${position.x}px`,
    top: `${position.y}px`,
  };
});

const closeMenu = () => {
  emit("update:visible", false);
};

const handleAction = (action: MessageContextMenuAction) => {
  emit(action);
  closeMenu();
};

const handleDocumentClick = (event: MouseEvent) => {
  const target = event.target as HTMLElement | null;
  if (!props.visible || target?.closest(".context-menu")) {
    return;
  }
  closeMenu();
};

const handleDocumentKeydown = (event: KeyboardEvent) => {
  if (props.visible && event.key === "Escape") {
    closeMenu();
  }
};

watch(
  () => props.visible,
  (visible) => {
    if (visible) {
      window.setTimeout(() => {
        document.addEventListener("click", handleDocumentClick);
        document.addEventListener("keydown", handleDocumentKeydown);
      }, 0);
      return;
    }

    document.removeEventListener("click", handleDocumentClick);
    document.removeEventListener("keydown", handleDocumentKeydown);
  },
);

onUnmounted(() => {
  document.removeEventListener("click", handleDocumentClick);
  document.removeEventListener("keydown", handleDocumentKeydown);
});
</script>

<template>
  <Teleport to="body">
    <div
      v-if="visible && items.length"
      class="context-menu"
      :style="menuStyle"
      @click.stop
      @contextmenu.prevent
    >
      <button
        v-for="item in items"
        :key="item.key"
        type="button"
        class="context-menu__item"
        :class="{ 'context-menu__item--danger': item.danger }"
        @click="handleAction(item.key)"
      >
        {{ item.label }}
      </button>
    </div>
  </Teleport>
</template>

<style scoped>
.context-menu {
  position: fixed;
  z-index: 1200;
  display: grid;
  min-width: 188px;
  padding: 8px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.98);
  box-shadow: 0 20px 40px rgba(15, 23, 42, 0.18);
  backdrop-filter: blur(14px);
}

.context-menu__item {
  height: 38px;
  padding: 0 14px;
  border: 0;
  border-radius: 12px;
  background: transparent;
  color: var(--text-primary);
  text-align: left;
  cursor: pointer;
}

.context-menu__item:hover {
  background: rgba(15, 23, 42, 0.05);
}

.context-menu__item--danger {
  color: #b91c1c;
}

.context-menu__item--danger:hover {
  background: rgba(239, 68, 68, 0.1);
}
</style>
