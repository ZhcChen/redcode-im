<template>
  <div class="message-list-skeleton">
    <div
      v-for="index in rows"
      :key="index"
      class="message-skeleton-row"
    >
      <div class="message-skeleton-avatar" />
      <div class="message-skeleton-content">
        <div class="message-skeleton-line message-skeleton-line--short" />
        <div class="message-skeleton-line message-skeleton-line--long" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
interface Props {
  rows?: number
}

withDefaults(defineProps<Props>(), {
  rows: 8
})
</script>

<style lang="scss" scoped>
@use 'sass:color';

.message-list-skeleton {
  padding: 16px 20px;
}

.message-skeleton-row {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  margin-bottom: 16px;
}

.message-skeleton-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: linear-gradient(
    90deg,
    #e5e7eb 0%,
    #d1d5db 50%,
    #e5e7eb 100%
  );
  background-size: 200% 100%;
  animation: skeleton-loading 2s ease-in-out infinite;
  flex-shrink: 0;
}

.message-skeleton-content {
  flex: 1;
}

.message-skeleton-line {
  height: 16px;
  border-radius: 999px;
  margin-bottom: 8px;
  background: linear-gradient(
    90deg,
    #e5e7eb 0%,
    #d1d5db 50%,
    #e5e7eb 100%
  );
  background-size: 200% 100%;
  animation: skeleton-loading 2s ease-in-out infinite;
}

.message-skeleton-line--short {
  width: 60px;
  height: 12px;
}

.message-skeleton-line--long {
  width: 65%;
}

@keyframes skeleton-loading {
  0% {
    background-position: 200% 0;
  }
  100% {
    background-position: -200% 0;
  }
}

@media (prefers-color-scheme: dark) {
  .message-skeleton-avatar,
  .message-skeleton-line {
    background: linear-gradient(
      90deg,
      #3f4451 0%,
      #4b5261 50%,
      #3f4451 100%
    );
    background-size: 200% 100%;
  }
}
</style>
