<template>
  <a-card class="general-card" :title="$t('monitor.title.studioPreview')">
    <template #extra>
      <icon-more />
    </template>
    <div class="studio-wrapper">
      <img :src="monitorPreviewImage" alt="" class="studio-preview" />
      <div class="studio-bar">
        <div v-if="userInfo">
          <a-space :size="12">
            <a-avatar :size="24">
              <img :src="userInfo.avatar" />
            </a-avatar>
            <a-typography-text>
              {{ userInfo.name }} {{ $t('monitor.studioPreview.studio') }}
            </a-typography-text>
          </a-space>
        </div>
        <a-typography-text type="secondary">
          36,000 {{ $t('monitor.studioPreview.watching') }}
        </a-typography-text>
      </div>
    </div>
  </a-card>
</template>

<script lang="ts" setup>
  import { useUserStore } from '@/store';
  import monitorPreviewImage from '@/assets/images/dashboard-monitor-preview.svg?url';

  const userInfo = useUserStore();
</script>

<style scoped lang="less">
  .studio {
    &-preview {
      display: block;
      width: 100%;
      max-width: 600px;
      margin: 0 auto;
    }

    &-bar {
      display: flex;
      justify-content: space-between;
      margin-top: 16px;
    }
  }
</style>
