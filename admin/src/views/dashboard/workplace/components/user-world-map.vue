<template>
  <a-card class="user-world-map-card" :title="title">
    <template #extra>
      <a-badge :count="totalUsers" :max-count="999" show-zero>
        <a-tag color="blue">总用户数</a-tag>
      </a-badge>
    </template>

    <div ref="mapContainer" class="map-container"></div>

    <div class="map-legend">
      <div class="legend-item">
        <span class="legend-dot" style="background: #91caff"></span>
        <span>1-10 用户</span>
      </div>
      <div class="legend-item">
        <span class="legend-dot" style="background: #1677ff"></span>
        <span>11-50 用户</span>
      </div>
      <div class="legend-item">
        <span class="legend-dot" style="background: #0958d9"></span>
        <span>51-100 用户</span>
      </div>
      <div class="legend-item">
        <span class="legend-dot" style="background: #003a8c"></span>
        <span>100+ 用户</span>
      </div>
    </div>
  </a-card>
</template>

<script setup lang="ts">
  import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue';
  import * as echarts from 'echarts';
  import { Message } from '@arco-design/web-vue';
  import axios from 'axios';

  defineOptions({
    name: 'UserWorldMap',
  });

  const props = withDefaults(
    defineProps<{
      title?: string;
    }>(),
    {
      title: '全球用户分布',
    }
  );

  const mapContainer = ref<HTMLElement>();
  const totalUsers = ref(0);
  let chartInstance: echarts.ECharts | null = null;
  const loading = ref(false);
  let mapDataLoaded = false;

  interface UserLocation {
    latitude: number;
    longitude: number;
    country?: string;
    region?: string;
    city?: string;
    user_count: number;
    users: Array<{
      user_id: string;
      username: string;
      nickname?: string;
    }>;
  }

  const locationData = ref<UserLocation[]>([]);

  // 根据用户数获取点的大小
  function getPointSize(count: number): number {
    if (count >= 100) return 20;
    if (count >= 51) return 16;
    if (count >= 11) return 12;
    return 8;
  }

  // 根据用户数获取点的颜色
  function getPointColor(count: number): string {
    if (count >= 100) return '#003a8c';
    if (count >= 51) return '#0958d9';
    if (count >= 11) return '#1677ff';
    return '#91caff';
  }

  // 处理窗口大小变化
  function handleResize() {
    if (chartInstance) {
      chartInstance.resize();
    }
  }

  // 加载世界地图GeoJSON数据
  async function loadWorldMap() {
    if (mapDataLoaded) return true;

    try {
      const response = await fetch(
        'https://geo.datav.aliyun.com/areas_v3/bound/world.json'
      );
      const geoJson = await response.json();
      echarts.registerMap('world', geoJson);
      mapDataLoaded = true;
      return true;
    } catch (error) {
      console.error('加载世界地图数据失败:', error);
      Message.error('加载地图数据失败');
      return false;
    }
  }

  // 渲染地图
  async function renderMap() {
    if (!mapContainer.value || locationData.value.length === 0) return;

    // 先加载地图数据
    const loaded = await loadWorldMap();
    if (!loaded) return;

    // 初始化图表
    if (!chartInstance) {
      chartInstance = echarts.init(mapContainer.value);
    }

    // 准备数据
    const scatterData = locationData.value.map((item) => ({
      name: item.city || item.region || item.country || '未知',
      value: [item.longitude, item.latitude, item.user_count],
      itemStyle: {
        color: getPointColor(item.user_count),
        opacity: 0.8,
      },
      symbolSize: getPointSize(item.user_count),
      tooltip: {
        trigger: 'item',
        formatter: (params: any) => {
          const data = locationData.value[params.dataIndex];
          return `
          <div style="padding: 8px;">
            <div style="font-weight: bold; margin-bottom: 8px;">${
              data.city || '未知城市'
            }</div>
            <div><strong>国家:</strong> ${data.country || '未知'}</div>
            <div><strong>地区:</strong> ${data.region || '未知'}</div>
            <div><strong>用户数:</strong> ${data.user_count}</div>
            <div style="margin-top: 8px; font-size: 12px; color: #666;">
              点击查看详情
            </div>
          </div>
        `;
        },
      },
      emphasis: {
        itemStyle: {
          opacity: 1,
          shadowBlur: 10,
          shadowColor: getPointColor(item.user_count),
        },
      },
    }));

    // 配置选项
    const option: echarts.EChartsOption = {
      backgroundColor: 'transparent',
      tooltip: {
        trigger: 'item',
      },
      geo: {
        map: 'world',
        roam: true,
        itemStyle: {
          areaColor: '#f3f4f6',
          borderColor: '#d1d5db',
        },
        emphasis: {
          itemStyle: {
            areaColor: '#e5e7eb',
          },
        },
        zoom: 1.2,
      },
      series: [
        {
          name: '用户分布',
          type: 'scatter',
          coordinateSystem: 'geo',
          data: scatterData,
          label: {
            show: false,
            formatter: (params: any) => params.data.name,
            position: 'top',
            fontSize: 10,
          },
          encode: {
            tooltip: 2,
          },
        },
      ],
      // 添加动画效果
      animationDurationUpdate: 1000,
      animationEasing: 'cubicOut',
    };

    // 设置配置
    chartInstance.setOption(option);

    // 添加点击事件
    chartInstance.on('click', (params: any) => {
      if (params.data && params.dataIndex !== undefined) {
        const locationInfo = locationData.value[params.dataIndex];
        console.log('点击位置:', locationInfo);
        // 未来可以添加显示用户详情的逻辑
      }
    });

    // 响应式
    window.addEventListener('resize', handleResize);
  }

  // 清理资源
  function cleanup() {
    if (chartInstance) {
      chartInstance.dispose();
      chartInstance = null;
    }
    window.removeEventListener('resize', handleResize);
  }

  // 获取用户地理位置分布数据
  async function fetchUserDistribution() {
    loading.value = true;
    try {
      const response = await axios.get(
        '/api/admin/users/geolocation/distribution'
      );
      if (response.data && Array.isArray(response.data)) {
        locationData.value = response.data;
        totalUsers.value = locationData.value.reduce(
          (sum, item) => sum + item.user_count,
          0
        );
        await renderMap();
      }
    } catch (error: any) {
      Message.error(
        `获取用户分布数据失败: ${
          error.response?.data?.message || error.message
        }`
      );
    } finally {
      loading.value = false;
    }
  }

  onMounted(async () => {
    await nextTick();
    await fetchUserDistribution();
  });

  onUnmounted(() => {
    cleanup();
  });

  // 监听数据变化
  watch(locationData, async () => {
    if (locationData.value.length > 0) {
      await renderMap();
    }
  });
</script>

<style scoped>
  .user-world-map-card {
    margin-bottom: 16px;
  }

  .map-container {
    width: 100%;
    height: 500px;
    min-height: 400px;
  }

  .map-legend {
    display: flex;
    flex-wrap: wrap;
    gap: 24px;
    margin-top: 16px;
    padding: 12px;
    background-color: #fafafa;
    border-radius: 6px;
  }

  .legend-item {
    display: flex;
    gap: 8px;
    align-items: center;
    color: #666;
    font-size: 14px;
  }

  .legend-dot {
    display: inline-block;
    width: 12px;
    height: 12px;
    border-radius: 50%;
  }
</style>
