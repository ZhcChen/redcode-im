<template>
  <StatisticCard title="表情包统计">
    <template #extra>
      <a-tag color="orange">表情</a-tag>
    </template>

    <div class="stats-grid">
      <div class="stat-item">
        <div class="stat-icon emoji-icon"> 😊 </div>
        <div class="stat-content">
          <div class="stat-value">{{
            formatNumber(emojiStats?.totalEmojis || 0)
          }}</div>
          <div class="stat-label">表情包总数</div>
        </div>
      </div>

      <div class="stat-item">
        <div class="stat-icon emoji-icon"> 🔥 </div>
        <div class="stat-content">
          <div class="stat-value">{{
            formatNumber(emojiStats?.todayUsage || 0)
          }}</div>
          <div class="stat-label">今日使用</div>
        </div>
      </div>

      <div class="stat-item">
        <div class="stat-icon emoji-icon"> ⭐ </div>
        <div class="stat-content">
          <div class="stat-value">{{
            formatNumber(emojiStats?.popularCount || 0)
          }}</div>
          <div class="stat-label">热门表情</div>
        </div>
      </div>
    </div>
  </StatisticCard>
</template>

<script setup lang="ts">
  import { ref, onMounted, onUnmounted } from 'vue';
  import StatisticCard from '@/components/statistic-card/index.vue';

  defineOptions({
    name: 'EmojiStats',
  });

  interface EmojiStats {
    totalEmojis: number;
    todayUsage: number;
    popularCount: number;
  }

  const emojiStats = ref<EmojiStats>();
  let timer: number | null = null;

  const formatNumber = (num: number): string => {
    if (num >= 10000) {
      return `${(num / 10000).toFixed(1)}w`;
    }
    return num.toString();
  };

  const fetchEmojiStats = async () => {
    try {
      // TODO: 调用实际的API
      // const { data } = await getEmojiStats();
      // emojiStats.value = data;

      // 模拟数据
      emojiStats.value = {
        totalEmojis: 568,
        todayUsage: 2341,
        popularCount: 28,
      };
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('获取表情包统计失败:', error);
    }
  };

  onMounted(() => {
    fetchEmojiStats();
    // 每30秒更新一次
    timer = window.setInterval(fetchEmojiStats, 30000);
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

  .emoji-icon {
    color: var(--color-warning);
    font-size: 24px;
    background-color: var(--color-warning-light-1);
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
