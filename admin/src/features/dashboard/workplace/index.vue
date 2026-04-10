<template>
  <div class="container">
    <div class="full-panel">
      <Banner />
      <DataPanel />
      <div class="map-and-stats">
        <UserWorldMap class="map-section" />
        <div class="stats-section">
          <StorageStats />
          <EmojiStats />
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
  import Banner from './components/banner.vue';
  import DataPanel from './components/data-panel.vue';
  import UserWorldMap from './components/user-world-map.vue';
  import StorageStats from './components/storage-stats.vue';
  import EmojiStats from './components/emoji-stats.vue';
</script>

<script lang="ts">
  export default {
    name: 'Workplace',
  };
</script>

<style lang="less" scoped>
  .container {
    padding: 16px 20px;
    padding-bottom: 0;
    background-color: var(--color-fill-2);
  }

  .full-panel {
    flex: 1;
  }

  .map-and-stats {
    display: flex;
    gap: 16px;
    margin-top: 16px;

    .map-section {
      flex: 2;
      min-width: 0;
    }

    .stats-section {
      display: flex;
      flex: 1;
      flex-direction: column;
      gap: 16px;
      min-width: 0;
    }
  }
</style>

<style lang="less" scoped>
  // responsive
  .mobile {
    .container {
      display: block;
    }
  }
</style>
