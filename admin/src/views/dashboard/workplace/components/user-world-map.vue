<template>
  <a-card class="user-world-map-card" title="全球用户分布">
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

  const mapContainer = ref<HTMLElement>();
  const totalUsers = ref(0);
  let chartInstance: echarts.ECharts | null = null;
  const loading = ref(false);
  let mapDataLoaded = false;
  let currentMapName = 'world'; // 添加当前地图名称变量

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
      // 尝试多个数据源
      const mapSources = [
        'https://geo.datav.aliyun.com/areas_v3/bound/100000_full.json', // 中国地图
        'https://raw.githubusercontent.com/holtzy/D3-graph-gallery/master/DATA/world.geojson', // 备用世界地图
        'https://raw.githubusercontent.com/python-visualization/folium/master/examples/data/world-countries.json', // 另一个备用源
      ];

      let geoJson = null;
      let mapName = 'world';
      let loadedSource = '';

      // 使用 Promise.any 尝试多个数据源
      const loadPromises = mapSources.map(async (source) => {
        const response = await fetch(source);
        if (response.ok) {
          return { data: await response.json(), source };
        }
        throw new Error(`Failed to load ${source}`);
      });

      // 使用 Promise.allSettled 找到第一个成功的结果
      const results = await Promise.allSettled(loadPromises);
      const successResult = results.find(
        (
          result
        ): result is {
          status: 'fulfilled';
          value: { data: any; source: string };
        } => result.status === 'fulfilled'
      );

      if (successResult) {
        geoJson = successResult.value.data;
        loadedSource = successResult.value.source;
      } else {
        throw new Error('所有地图数据源都无法访问');
      }

      // 如果是中国地图数据，需要调整名称
      if (loadedSource.includes('100000_full.json')) {
        mapName = 'china';
      }

      echarts.registerMap(mapName, geoJson);
      currentMapName = mapName; // 设置当前地图名称
      mapDataLoaded = true;
      return true;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error('加载世界地图数据失败:', error);
      Message.error('加载地图数据失败，请检查网络连接');
      return false;
    }
  }

  // 渲染地图
  async function renderMap() {
    if (!mapContainer.value) return;

    // 先加载地图数据
    const loaded = await loadWorldMap();
    if (!loaded) return;

    // 初始化图表
    if (!chartInstance) {
      chartInstance = echarts.init(mapContainer.value);
    }

    // 准备数据 - 如果没有数据则使用空数组
    const scatterData =
      locationData.value.length > 0
        ? locationData.value.map((item) => ({
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
          }))
        : [];

    // 配置选项
    const option: echarts.EChartsOption = {
      backgroundColor: 'transparent',
      tooltip: {
        trigger: 'item',
      },
      geo: {
        map: currentMapName,
        roam: true,
        top: 20, // 距离容器顶部20像素的距离
        itemStyle: {
          areaColor: '#f3f4f6',
          borderColor: '#d1d5db',
        },
        emphasis: {
          itemStyle: {
            areaColor: '#e5e7eb',
          },
        },
        zoom: currentMapName === 'china' ? 1.5 : 1.2, // 中国地图缩放比例调整
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

    // 添加点击事件 - 只有有数据时才添加
    if (locationData.value.length > 0) {
      chartInstance.on('click', (params: any) => {
        if (params.data && params.dataIndex !== undefined) {
          const locationInfo = locationData.value[params.dataIndex];
          // eslint-disable-next-line no-console
          console.log('点击位置:', locationInfo);
          // 未来可以添加显示用户详情的逻辑
        }
      });
    }

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
      } else {
        // 如果没有数据，设置为空数组
        locationData.value = [];
        totalUsers.value = 0;
      }
      // 无论是否有数据都要渲染地图
      await renderMap();
    } catch (error: any) {
      Message.error(
        `获取用户分布数据失败: ${
          error.response?.data?.message || error.message
        }`
      );
      // 即使请求失败也要显示空地图
      locationData.value = [];
      totalUsers.value = 0;
      await renderMap();
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
    // 无论数据是否为空都要重新渲染地图
    await renderMap();
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
