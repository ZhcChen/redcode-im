<template>
  <StatisticCard title="对象存储统计">
    <template #extra>
      <a-tag color="green">存储</a-tag>
    </template>

    <div class="stats-grid">
      <div class="stat-item">
        <div class="stat-icon">
          <icon-cloud />
        </div>
        <div class="stat-content">
          <div class="stat-value">{{
            formatNumber(storageStats?.totalFiles || 0)
          }}</div>
          <div class="stat-label">文件总数</div>
        </div>
      </div>

      <div class="stat-item">
        <div class="stat-icon">
          <icon-storage />
        </div>
        <div class="stat-content">
          <div class="stat-value">{{
            formatSize(storageStats?.totalSize || 0)
          }}</div>
          <div class="stat-label">存储总大小</div>
        </div>
      </div>

      <div class="stat-item">
        <div class="stat-icon">
          <icon-upload />
        </div>
        <div class="stat-content">
          <div class="stat-value">{{
            formatNumber(storageStats?.todayUploads || 0)
          }}</div>
          <div class="stat-label">今日上传</div>
        </div>
      </div>
    </div>
  </StatisticCard>
</template>

<script setup lang="ts">
  import { ref, onMounted, onUnmounted } from 'vue';
  import StatisticCard from '@/components/statistic-card/index.vue';

  defineOptions({
    name: 'StorageStats',
  });

  interface StorageStats {
    totalFiles: number;
    totalSize: number;
    todayUploads: number;
  }

  const storageStats = ref<StorageStats>();
  let timer: number | null = null;

  const formatNumber = (num: number): string => {
    if (num >= 10000) {
      return `${(num / 10000).toFixed(1)}w`;
    }
    return num.toString();
  };

  const formatSize = (bytes: number): string => {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    let size = bytes;
    let unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex += 1;
    }

    return `${size.toFixed(1)} ${units[unitIndex]}`;
  };

  const fetchStorageStats = async () => {
    try {
      // TODO: 调用实际的API
      // const { data } = await getStorageStats();
      // storageStats.value = data;

      // 模拟数据
      storageStats.value = {
        totalFiles: 15234,
        totalSize: 1024 * 1024 * 1024 * 2.5, // 2.5GB
        todayUploads: 89,
      };
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('获取存储统计失败:', error);
    }
  };

  onMounted(() => {
    fetchStorageStats();
    // 每30秒更新一次
    timer = window.setInterval(fetchStorageStats, 30000);
  });

  onUnmounted(() => {
    if (timer) {
      clearInterval(timer);
    }
  });
</script>

<style scoped>
  .stats-grid {
    display: flex;
    flex-direction: column;
    gap: 16px;
  }

  .stat-item {
    display: flex;
    gap: 12px;
    align-items: center;
    padding: 12px;
    background-color: var(--color-fill-1);
    border-radius: 6px;
    transition: all 0.3s ease;
  }

  .stat-item:hover {
    background-color: var(--color-fill-2);
    transform: translateX(4px);
  }

  .stat-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 40px;
    height: 40px;
    color: var(--color-primary);
    font-size: 20px;
    background-color: var(--color-primary-light-1);
    border-radius: 8px;
  }

  .stat-content {
    flex: 1;
  }

  .stat-value {
    margin-bottom: 4px;
    color: var(--color-text-1);
    font-weight: 600;
    font-size: 18px;
  }

  .stat-label {
    color: var(--color-text-3);
    font-size: 12px;
  }
</style>
