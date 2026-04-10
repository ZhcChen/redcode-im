<template>
  <a-spin :loading="loading" style="width: 100%">
    <a-card
      class="general-card"
      :header-style="{ paddingBottom: 0 }"
      :body-style="{
        paddingTop: '20px',
      }"
      :title="$t('workplace.contentData')"
    >
      <template #extra>
        <a-link>{{ $t('workplace.viewMore') }}</a-link>
      </template>
      <Chart height="289px" :option="chartOption" />
    </a-card>
  </a-spin>
</template>

<script lang="ts" setup>
  import { ref, onMounted, onUnmounted } from 'vue';
  import { graphic } from 'echarts';
  import useLoading from '@/hooks/loading';
  import useChartOption from '@/hooks/chart-option';
  import { ToolTipFormatterParams } from '@/types/echarts';
  import { AnyObject } from '@/types/global';
  import { getDataStatistics } from '@/api/dashboard';

  interface ContentDataRecord {
    x: string;
    y: number;
  }

  // 从 API 获取数据
  const queryContentData = async () => {
    try {
      const response = await getDataStatistics();
      const data: ContentDataRecord[] = response.data.daily_messages.map(
        (item) => ({
          x: item.date,
          y: item.count,
        })
      );
      return { data };
    } catch (error) {
      // 如果 API 失败，返回模拟数据
      console.warn('获取数据统计失败，使用模拟数据:', error);
      const data: ContentDataRecord[] = [
        { x: '1月', y: 100 },
        { x: '2月', y: 120 },
        { x: '3月', y: 140 },
        { x: '4月', y: 110 },
        { x: '5月', y: 160 },
        { x: '6月', y: 130 },
        { x: '7月', y: 150 },
        { x: '8月', y: 170 },
        { x: '9月', y: 140 },
        { x: '10月', y: 160 },
        { x: '11月', y: 180 },
        { x: '12月', y: 150 },
      ];
      return { data };
    }
  };

  function graphicFactory(side: AnyObject) {
    return {
      type: 'text',
      bottom: '8',
      ...side,
      style: {
        text: '',
        textAlign: 'center',
        fill: '#4E5969',
        fontSize: 12,
      },
    };
  }
  const { loading, setLoading } = useLoading(true);
  const xAxis = ref<string[]>([]);
  const chartsData = ref<number[]>([]);
  const graphicElements = ref([
    graphicFactory({ left: '2.6%' }),
    graphicFactory({ right: 0 }),
  ]);
  let timer: number | null = null;

  const { chartOption } = useChartOption((isDark, theme) => {
    return {
      backgroundColor: theme.backgroundColor,
      grid: {
        left: '2.6%',
        right: '0',
        top: '10',
        bottom: '30',
      },
      xAxis: {
        type: 'category',
        offset: 2,
        data: xAxis.value,
        boundaryGap: false,
        axisLabel: {
          color: theme.textColorPrimary,
          formatter(value: number, idx: number) {
            if (idx === 0) return '';
            if (idx === xAxis.value.length - 1) return '';
            return `${value}`;
          },
        },
        axisLine: {
          show: false,
        },
        axisTick: {
          show: false,
        },
        splitLine: {
          show: true,
          interval: (idx: number) => {
            if (idx === 0) return false;
            if (idx === xAxis.value.length - 1) return false;
            return true;
          },
          lineStyle: {
            color: theme.axisSplitLineColor,
          },
        },
        axisPointer: {
          show: true,
          lineStyle: {
            color: theme.primaryGradientMid,
            width: 2,
          },
        },
      },
      yAxis: {
        type: 'value',
        axisLine: {
          show: false,
        },
        axisLabel: {
          formatter(value: any, idx: number) {
            if (idx === 0) return value;
            return `${value}k`;
          },
          color: theme.textColorSecondary,
        },
        splitLine: {
          show: true,
          lineStyle: {
            type: 'dashed',
            color: theme.axisSplitLineColor,
          },
        },
      },
      tooltip: {
        trigger: 'axis',
        formatter(params) {
          const [firstElement] = params as ToolTipFormatterParams[];
          return `<div>
            <p class="tooltip-title">${firstElement.axisValueLabel}</p>
            <div class="content-panel"><span>总内容量</span><span class="tooltip-value">${(
              Number(firstElement.value) * 10000
            ).toLocaleString()}</span></div>
          </div>`;
        },
        className: 'echarts-tooltip-diy',
      },
      graphic: {
        elements: graphicElements.value,
      },
      series: [
        {
          data: chartsData.value,
          type: 'line',
          smooth: true,
          // symbol: 'circle',
          symbolSize: 12,
          emphasis: {
            focus: 'series',
            itemStyle: {
              borderWidth: 2,
            },
          },
          lineStyle: {
            width: 3,
            color: new graphic.LinearGradient(0, 0, 1, 0, [
              {
                offset: 0,
                color: theme.primaryGradientFrom,
              },
              {
                offset: 0.5,
                color: theme.primaryGradientMid,
              },
              {
                offset: 1,
                color: theme.primaryGradientTo,
              },
            ]),
          },
          showSymbol: false,
          areaStyle: {
            opacity: 0.8,
            color: new graphic.LinearGradient(0, 0, 0, 1, [
              {
                offset: 0,
                color: theme.areaGradientFrom,
              },
              {
                offset: 1,
                color: theme.areaGradientTo,
              },
            ]),
          },
        },
      ],
    };
  });
  const fetchData = async () => {
    setLoading(true);
    try {
      const { data: chartData } = await queryContentData();
      // 清空现有数据
      xAxis.value = [];
      chartsData.value = [];
      chartData.forEach((el: ContentDataRecord, idx: number) => {
        xAxis.value.push(el.x);
        chartsData.value.push(el.y);
        if (idx === 0) {
          graphicElements.value[0].style.text = el.x;
        }
        if (idx === chartData.length - 1) {
          graphicElements.value[1].style.text = el.x;
        }
      });
    } catch (err) {
      // you can report use errorHandler or other
    } finally {
      setLoading(false);
    }
  };

  onMounted(() => {
    fetchData();
    // 每3秒更新一次
    timer = window.setInterval(fetchData, 3000);
  });

  onUnmounted(() => {
    if (timer) {
      clearInterval(timer);
    }
  });
</script>
