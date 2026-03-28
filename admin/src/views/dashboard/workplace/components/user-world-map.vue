<template>
  <StatisticCard :title="t('workplace.map.title')">
    <template #extra>
      <a-badge :count="totalUsers" :max-count="999" show-zero>
        <a-tag color="blue">{{ t('workplace.map.totalUsersTag') }}</a-tag>
      </a-badge>
    </template>

    <div ref="mapContainer" class="map-container"></div>

    <div class="map-legend">
      <div class="legend-item">
        <span class="legend-dot" style="background: #91caff"></span>
        <span>{{ t('workplace.map.legend.1') }}</span>
      </div>
      <div class="legend-item">
        <span class="legend-dot" style="background: #1677ff"></span>
        <span>{{ t('workplace.map.legend.2') }}</span>
      </div>
      <div class="legend-item">
        <span class="legend-dot" style="background: #0958d9"></span>
        <span>{{ t('workplace.map.legend.3') }}</span>
      </div>
      <div class="legend-item">
        <span class="legend-dot" style="background: #003a8c"></span>
        <span>{{ t('workplace.map.legend.4') }}</span>
      </div>
    </div>
  </StatisticCard>
</template>

<script setup lang="ts">
  import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue';
  import { useI18n } from 'vue-i18n';
  import * as echarts from 'echarts';
  import { Message } from '@arco-design/web-vue';
  import axios from 'axios';
  import StatisticCard from '@/components/statistic-card/index.vue';

  defineOptions({
    name: 'UserWorldMap',
  });

  const mapContainer = ref<HTMLElement>();
  const totalUsers = ref(0);
  const { t } = useI18n();
  let chartInstance: echarts.ECharts | null = null;
  const loading = ref(false);
  let mapDataLoaded = false;
  let currentMapName = 'world';

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

  function getPointSize(count: number): number {
    if (count >= 100) return 20;
    if (count >= 51) return 16;
    if (count >= 11) return 12;
    return 8;
  }

  function getPointColor(count: number): string {
    if (count >= 100) return '#003a8c';
    if (count >= 51) return '#0958d9';
    if (count >= 11) return '#1677ff';
    return '#91caff';
  }

  function handleResize() {
    if (chartInstance) {
      chartInstance.resize();
    }
  }

  async function loadWorldMap() {
    if (mapDataLoaded) return true;

    try {
      const mapSources = [
        'https://geo.datav.aliyun.com/areas_v3/bound/100000_full.json',
        'https://raw.githubusercontent.com/holtzy/D3-graph-gallery/master/DATA/world.geojson',
        'https://raw.githubusercontent.com/python-visualization/folium/master/examples/data/world-countries.json',
      ];

      let geoJson = null;
      let mapName = 'world';
      let loadedSource = '';

      const loadPromises = mapSources.map(async (source) => {
        const response = await fetch(source);
        if (response.ok) {
          return { data: await response.json(), source };
        }
        throw new Error(`Failed to load ${source}`);
      });

      const results = await Promise.allSettled(loadPromises);
      const successResult = results.find(
        (
          result,
        ): result is {
          status: 'fulfilled';
          value: { data: any; source: string };
        } => result.status === 'fulfilled',
      );

      if (successResult) {
        geoJson = successResult.value.data;
        loadedSource = successResult.value.source;
      } else {
        throw new Error('All map data sources are unavailable');
      }

      if (loadedSource.includes('100000_full.json')) {
        mapName = 'china';
      }

      echarts.registerMap(mapName, geoJson);
      currentMapName = mapName;
      mapDataLoaded = true;
      return true;
    } catch (error) {
      console.error('Failed to load world map data:', error);
      Message.error(t('workplace.map.error.loadMap'));
      return false;
    }
  }

  async function renderMap() {
    if (!mapContainer.value) return;

    const loaded = await loadWorldMap();
    if (!loaded) return;

    if (!chartInstance) {
      chartInstance = echarts.init(mapContainer.value);
    }

    const scatterData =
      locationData.value.length > 0
        ? locationData.value.map((item) => ({
            name:
              item.city ||
              item.region ||
              item.country ||
              t('workplace.map.unknownLocation'),
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
              data.city || t('workplace.map.unknownCity')
            }</div>
            <div><strong>${t('workplace.map.tooltip.country')}:</strong> ${
              data.country || t('workplace.map.unknownLocation')
            }</div>
            <div><strong>${t('workplace.map.tooltip.region')}:</strong> ${
              data.region || t('workplace.map.unknownLocation')
            }</div>
            <div><strong>${t('workplace.map.tooltip.users')}:</strong> ${
              data.user_count
            }</div>
            <div style="margin-top: 8px; font-size: 12px; color: #666;">
              ${t('workplace.map.tooltip.clickHint')}
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

    const option: echarts.EChartsOption = {
      backgroundColor: 'transparent',
      tooltip: {
        trigger: 'item',
      },
      geo: {
        map: currentMapName,
        roam: true,
        top: 20,
        itemStyle: {
          areaColor: '#f3f4f6',
          borderColor: '#d1d5db',
        },
        emphasis: {
          itemStyle: {
            areaColor: '#e5e7eb',
          },
        },
        zoom: currentMapName === 'china' ? 1.0 : 0.8,
      },
      series: [
        {
          name: t('workplace.map.seriesName'),
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
      animationDurationUpdate: 1000,
      animationEasing: 'cubicOut',
    };

    chartInstance.setOption(option);

    if (locationData.value.length > 0) {
      chartInstance.on('click', (params: any) => {
        if (params.data && params.dataIndex !== undefined) {
          console.log(
            'clicked location:',
            locationData.value[params.dataIndex],
          );
        }
      });
    }

    window.addEventListener('resize', handleResize);
  }

  function cleanup() {
    if (chartInstance) {
      chartInstance.dispose();
      chartInstance = null;
    }
    window.removeEventListener('resize', handleResize);
  }

  async function fetchUserDistribution() {
    loading.value = true;
    try {
      const response = await axios.get(
        '/api/admin/users/geolocation/distribution',
      );
      if (response.data && Array.isArray(response.data)) {
        locationData.value = response.data;
        totalUsers.value = locationData.value.reduce(
          (sum, item) => sum + item.user_count,
          0,
        );
      } else {
        locationData.value = [];
        totalUsers.value = 0;
      }
      await renderMap();
    } catch (error: any) {
      Message.error(t('workplace.map.error.fetch'));
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

  watch(locationData, async () => {
    await renderMap();
  });
</script>

<style scoped>
  .map-container {
    width: 100%;
    height: 650px;
    min-height: 500px;
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
