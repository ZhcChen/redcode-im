<template>
  <div class="container">
    <Breadcrumb :items="['menu.dashboard', 'menu.dashboard.monitor']" />
    <div class="layout">
      <div class="layout-content">
        <NodesMonitor />
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
  import NodesMonitor from './components/nodes-monitor.vue';
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
    display: block;

    &-content {
      width: 100%;
    }
  }
</style>

<style lang="less" scoped>
  // responsive
  @media (max-width: @screen-lg) {
    .layout {
      &-content {
        margin-bottom: 16px;
      }
    }
  }
</style>
