<template>
  <div class="container">
    <div class="full-panel">
      <div class="panel">
        <Banner />
        <DataPanel />
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
  import Banner from './components/banner.vue';
  import DataPanel from './components/data-panel.vue';
  // 移除了其他模板组件
</script>

<script lang="ts">
  export default {
    name: 'Workplace',
  };
</script>

<style lang="less" scoped>
  .container {
    background-color: var(--color-fill-2);
    padding: 16px 20px;
    padding-bottom: 0;
  }

  .full-panel {
    flex: 1;
  }

  .panel {
    background-color: var(--color-bg-2);
    border-radius: 4px;
    overflow: auto;
  }

  :deep(.panel-border) {
    margin-bottom: 0;
    border-bottom: 1px solid rgb(var(--gray-2));
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
