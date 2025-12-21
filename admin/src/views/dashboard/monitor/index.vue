<template>
  <div class="container">
    <Breadcrumb :items="['menu.dashboard', 'menu.dashboard.monitor']" />
    <div class="layout">
      <div class="layout-content">
        <a-space :size="16" direction="vertical" fill>
          <NodesMonitor />
          <ResourceMonitor />
        </a-space>
      </div>
      <div class="layout-right-side">
        <a-space :size="16" direction="vertical" fill>
          <SystemLoad />
          <NetworkStatus />
        </a-space>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
  import NodesMonitor from './components/nodes-monitor.vue';
  import ResourceMonitor from './components/resource-monitor.vue';
  import SystemLoad from './components/system-load.vue';
  import NetworkStatus from './components/network-status.vue';
</script>

<script lang="ts">
  export default {
    name: 'Monitor',
  };
</script>

<style scoped lang="less">
  .container {
    padding: 0 20px 20px;
  }

  .layout {
    display: flex;

    &-content {
      flex: 1;
      padding-right: 16px;
    }

    &-right-side {
      flex-basis: 360px;
    }
  }
</style>

<style lang="less" scoped>
  // responsive
  @media (max-width: @screen-lg) {
    .layout {
      flex-wrap: wrap;

      &-content {
        flex: none;
        flex-basis: 100%;
        order: -1;
        margin-bottom: 16px;
        padding: 0;
      }

      &-right-side {
        flex-basis: 100%;
      }
    }
  }
</style>
