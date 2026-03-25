<script setup lang="ts">
import { computed, onUnmounted, watch } from "vue";
import {
  clampContextMenuPosition,
  getChatContextMenuLabels,
} from "@/utils/chat-context-menu";

const props = defineProps<{
  visible: boolean;
  position: {
    x: number;
    y: number;
  };
  isPinned: boolean;
  isMuted: boolean;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: "pin"): void;
  (event: "mute"): void;
  (event: "delete"): void;
}>();

const labels = computed(() =>
  getChatContextMenuLabels({
    isPinned: props.isPinned,
    isMuted: props.isMuted,
  }),
);

const menuStyle = computed(() => {
  const position = clampContextMenuPosition(props.position, {
    menuWidth: 184,
    menuHeight: 150,
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

const handleAction = (action: "pin" | "mute" | "delete") => {
  switch (action) {
    case "pin":
      emit("pin");
      break;
    case "mute":
      emit("mute");
      break;
    case "delete":
      emit("delete");
      break;
  }
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
      v-if="visible"
      class="context-menu"
      :style="menuStyle"
      @click.stop
      @contextmenu.prevent
    >
      <button
        type="button"
        class="context-menu__item"
        @click="handleAction('pin')"
      >
        {{ labels.pinLabel }}
      </button>
      <button
        type="button"
        class="context-menu__item"
        @click="handleAction('mute')"
      >
        {{ labels.muteLabel }}
      </button>
      <div class="context-menu__divider" />
      <button
        type="button"
        class="context-menu__item context-menu__item--danger"
        @click="handleAction('delete')"
      >
        {{ labels.deleteLabel }}
      </button>
    </div>
  </Teleport>
</template>

<style scoped>
.context-menu {
  position: fixed;
  z-index: 1200;
  display: grid;
  min-width: 184px;
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

.context-menu__divider {
  height: 1px;
  margin: 6px 4px;
  background: rgba(15, 23, 42, 0.08);
}
</style>
