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
    $bg-light-gray 0%,
    color.adjust($bg-light-gray, $lightness: 6%) 50%,
    $bg-light-gray 100%
  );
  background-size: 200% 100%;
  animation: skeleton-loading 1.2s ease-in-out infinite;
  flex-shrink: 0;
}

.message-skeleton-content {
  flex: 1;
}

.message-skeleton-line {
  height: 10px;
  border-radius: 999px;
  margin-bottom: 8px;
  background: linear-gradient(
    90deg,
    $bg-light-gray 0%,
    color.adjust($bg-light-gray, $lightness: 6%) 50%,
    $bg-light-gray 100%
  );
  background-size: 200% 100%;
  animation: skeleton-loading 1.2s ease-in-out infinite;
}

.message-skeleton-line--short {
  width: 40%;
}

.message-skeleton-line--long {
  width: 80%;
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
      #2c2d3a 0%,
      color.adjust(#2c2d3a, $lightness: 8%) 50%,
      #2c2d3a 100%
    );
    background-size: 200% 100%;
  }
}
</style>
