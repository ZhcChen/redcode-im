<template>
  <StatisticCard title="工作台">
    <div class="banner-content">
      <div class="welcome-section">
        <div class="welcome-info">
          <a-typography-title :heading="5" style="margin-top: 0">
            {{ $t('workplace.welcome') }} {{ userInfo.name }}
          </a-typography-title>
          <p class="welcome-desc">
            {{ currentTime }}，今天又是充满希望的一天！
          </p>
        </div>
        <div class="user-avatar">
          <a-avatar :size="64" style="background-color: #165dff">
            <template #icon>
              <icon-user />
            </template>
          </a-avatar>
        </div>
      </div>

      <div class="quick-actions">
        <div class="action-item">
          <div class="action-icon">
            <icon-message />
          </div>
          <div class="action-content">
            <div class="action-title">快速消息</div>
            <div class="action-desc">发送即时消息</div>
          </div>
        </div>

        <div class="action-item">
          <div class="action-icon">
            <icon-team />
          </div>
          <div class="action-content">
            <div class="action-title">团队协作</div>
            <div class="action-desc">创建群组聊天</div>
          </div>
        </div>

        <div class="action-item">
          <div class="action-icon">
            <icon-file />
          </div>
          <div class="action-content">
            <div class="action-title">文件管理</div>
            <div class="action-desc">上传下载文件</div>
          </div>
        </div>
      </div>
    </div>
  </StatisticCard>
</template>

<script lang="ts" setup>
  import { computed, ref, onMounted, onUnmounted } from 'vue';
  import { useUserStore } from '@/store';
  import StatisticCard from '@/components/statistic-card/index.vue';

  const userStore = useUserStore();
  const userInfo = computed(() => {
    return {
      name: userStore.name,
    };
  });

  const currentTime = ref('');
  let timer: number | null = null;

  const updateGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 6) {
      currentTime.value = '夜深了';
    } else if (hour < 12) {
      currentTime.value = '早上好';
    } else if (hour < 14) {
      currentTime.value = '中午好';
    } else if (hour < 18) {
      currentTime.value = '下午好';
    } else {
      currentTime.value = '晚上好';
    }
  };

  onMounted(() => {
    updateGreeting();
    // 每分钟更新一次问候语
    timer = window.setInterval(updateGreeting, 60000);
  });

  onUnmounted(() => {
    if (timer) {
      clearInterval(timer);
    }
  });
</script>

<style scoped lang="less">
  .banner-content {
    padding: 16px 0;
  }

  .welcome-section {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 24px;
  }

  .welcome-info {
    flex: 1;
  }

  .welcome-desc {
    margin: 8px 0 0;
    color: var(--color-text-3);
    font-size: 14px;
  }

  .user-avatar {
    margin-left: 24px;
  }

  .quick-actions {
    display: flex;
    gap: 16px;
  }

  .action-item {
    display: flex;
    flex: 1;
    gap: 12px;
    align-items: center;
    padding: 16px;
    background-color: var(--color-fill-1);
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.3s ease;
  }

  .action-item:hover {
    background-color: var(--color-fill-2);
    box-shadow: 0 4px 12px rgb(0 0 0 / 10%);
    transform: translateY(-2px);
  }

  .action-icon {
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

  .action-content {
    flex: 1;
  }

  .action-title {
    margin-bottom: 4px;
    color: var(--color-text-1);
    font-weight: 600;
    font-size: 14px;
  }

  .action-desc {
    color: var(--color-text-3);
    font-size: 12px;
  }
</style>
