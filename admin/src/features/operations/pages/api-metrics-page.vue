<template>
  <div class="container">
    <Breadcrumb :items="['menu.operations', 'menu.operations.apiMetrics']" />
    <a-grid :cols="24" :col-gap="16" :row-gap="16">
      <a-grid-item :span="24">
        <a-card class="general-card" :title="$t('menu.operations.apiMetrics')">
          <template #extra>
            <a-space>
              <a-button type="primary" @click="fetchData">
                <template #icon><icon-refresh /></template>
                {{ $t('monitor.studioInfo.btn.fresh') }}
              </a-button>
              <a-tag color="arcoblue">自动刷新 (5s)</a-tag>
            </a-space>
          </template>
          <a-table
            :data="metrics"
            :loading="loading"
            :pagination="pagination"
            :bordered="false"
            @change="handleTableChange"
          >
            <template #columns>
              <a-table-column title="方法" data-index="method">
                <template #cell="{ record }">
                  <a-tag :color="getMethodColor(record.method)">{{
                    record.method
                  }}</a-tag>
                </template>
              </a-table-column>
              <a-table-column title="请求路径" data-index="path" />
              <a-table-column
                title="调用次数"
                data-index="count"
                :sortable="{ sortDirections: ['ascend', 'descend'] }"
              />
              <a-table-column
                title="平均耗时 (ms)"
                data-index="avg_duration"
                :sortable="{ sortDirections: ['ascend', 'descend'] }"
              >
                <template #cell="{ record }">
                  <a-progress
                    :percent="getDurationPercent(record.avg_duration)"
                    :color="getDurationColor(record.avg_duration)"
                    size="small"
                  >
                    <template #text>{{ record.avg_duration }}ms</template>
                  </a-progress>
                </template>
              </a-table-column>
              <a-table-column
                title="最大耗时 (ms)"
                data-index="max_duration"
                :sortable="{ sortDirections: ['ascend', 'descend'] }"
              >
                <template #cell="{ record }">
                  <span
                    :style="{ color: getDurationColor(record.max_duration) }"
                  >
                    {{ record.max_duration }}ms
                  </span>
                </template>
              </a-table-column>
            </template>
          </a-table>
        </a-card>
      </a-grid-item>

      <a-grid-item :span="12">
        <a-card class="general-card" title="平均耗时排行 (Top 10)">
          <div ref="avgChart" style="width: 100%; height: 350px"></div>
        </a-card>
      </a-grid-item>

      <a-grid-item :span="12">
        <a-card class="general-card" title="调用频次占比">
          <div ref="countChart" style="width: 100%; height: 350px"></div>
        </a-card>
      </a-grid-item>
    </a-grid>
  </div>
</template>

<script lang="ts" setup>
  import { ref, onMounted, onUnmounted } from 'vue';
  import {
    getApiPerformanceMetrics,
    ApiPerformanceMetric,
  } from '@/api/dashboard';
  import * as echarts from 'echarts';
  import { PaginationProps } from '@arco-design/web-vue';

  const loading = ref(false);
  const metrics = ref<ApiPerformanceMetric[]>([]);
  const topAvg = ref<ApiPerformanceMetric[]>([]);
  const topCount = ref<ApiPerformanceMetric[]>([]);
  const pagination = ref<PaginationProps>({
    current: 1,
    pageSize: 10,
    total: 0,
    showTotal: true,
  });
  const sortField = ref<string>('');
  const sortOrder = ref<string>('');

  const avgChart = ref<HTMLElement | null>(null);
  const countChart = ref<HTMLElement | null>(null);
  let avgChartInstance: echarts.ECharts | null = null;
  let countChartInstance: echarts.ECharts | null = null;
  let timer: any = null;

  const getMethodColor = (method: string) => {
    const colors: any = {
      GET: 'green',
      POST: 'blue',
      PUT: 'orange',
      DELETE: 'red',
      PATCH: 'magenta',
    };
    return colors[method] || 'gray';
  };

  const getDurationColor = (duration: number) => {
    if (duration > 500) return '#F53F3F';
    if (duration > 200) return '#F7BA1E';
    return '#00B42A';
  };

  const getDurationPercent = (duration: number) => {
    return Math.min(duration / 1000, 1);
  };

  const updateCharts = () => {
    if (!avgChartInstance || !countChartInstance) return;

    // 平均耗时排行 (使用全局 topAvg)
    const topAvgData = [...topAvg.value].reverse();

    avgChartInstance.setOption({
      tooltip: { trigger: 'axis' },
      grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
      xAxis: { type: 'value' },
      yAxis: {
        type: 'category',
        data: topAvgData.map(
          (item) => `${item.method} ${item.path.split('/').pop()}`
        ),
      },
      series: [
        {
          name: '平均耗时 (ms)',
          type: 'bar',
          data: topAvgData.map((item) => item.avg_duration),
          itemStyle: {
            color: (params: any) => getDurationColor(params.data),
          },
        },
      ],
    });

    // 调用频次占比 (使用全局 topCount)
    const topCountData = topCount.value.slice(0, 5).map((item) => ({
      name: `${item.method} ${item.path}`,
      value: item.count,
    }));

    if (topCount.value.length > 5) {
      const otherCount = topCount.value
        .slice(5)
        .reduce((acc, cur) => acc + cur.count, 0);
      topCountData.push({ name: '其他', value: otherCount });
    }

    countChartInstance.setOption({
      tooltip: { trigger: 'item' },
      legend: { bottom: '0', left: 'center' },
      series: [
        {
          name: '调用频次',
          type: 'pie',
          radius: ['40%', '65%'],
          center: ['50%', '45%'],
          avoidLabelOverlap: false,
          itemStyle: {
            borderRadius: 10,
            borderColor: '#fff',
            borderWidth: 2,
          },
          label: { show: false, position: 'center' },
          emphasis: {
            label: { show: true, fontSize: 16, fontWeight: 'bold' },
          },
          labelLine: { show: false },
          data: topCountData,
        },
      ],
    });

    // 强制触发一次 resize 确保布局正确
    avgChartInstance.resize();
    countChartInstance.resize();
  };

  const fetchData = async () => {
    loading.value = true;
    try {
      const { data } = await getApiPerformanceMetrics({
        page: pagination.value.current,
        page_size: pagination.value.pageSize,
        sort_field: sortField.value,
        sort_order: sortOrder.value,
      });
      metrics.value = data.metrics;
      topAvg.value = data.top_avg;
      topCount.value = data.top_count;
      pagination.value.total = data.total;
      updateCharts();
    } catch (err) {
      // Ignore error for now or handle as needed
    } finally {
      loading.value = false;
    }
  };

  const handleTableChange = (data: any, extra: any) => {
    if (extra.type === 'pagination') {
      pagination.value.current = data.current;
    } else if (extra.type === 'sorter') {
      sortField.value = extra.sorter?.field || '';
      sortOrder.value = extra.sorter?.direction || '';
      pagination.value.current = 1; // 排序后回到第一页
    }
    fetchData();
  };

  const initCharts = () => {
    if (avgChart.value) {
      avgChartInstance = echarts.init(avgChart.value);
    }
    if (countChart.value) {
      countChartInstance = echarts.init(countChart.value);
    }
  };

  onMounted(async () => {
    initCharts();
    await fetchData();
    timer = setInterval(fetchData, 5000);

    window.addEventListener('resize', () => {
      avgChartInstance?.resize();
      countChartInstance?.resize();
    });
  });

  onUnmounted(() => {
    if (timer) clearInterval(timer);
    avgChartInstance?.dispose();
    countChartInstance?.dispose();
  });
</script>

<style scoped lang="less">
  .container {
    padding: 0 20px 20px;
  }

  .general-card {
    border: none;
    border-radius: 4px;

    & > .arco-card-header {
      border-bottom: 0;
    }
  }
</style>
