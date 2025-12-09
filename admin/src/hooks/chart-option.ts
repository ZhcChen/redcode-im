import { computed } from 'vue';
import { EChartsOption } from 'echarts';
import { useAppStore } from '@/store';

// for code hints
// import { SeriesOption } from 'echarts';
// Because there are so many configuration items, this provides a relatively convenient code hint.
// When using vue, pay attention to the reactive issues. It is necessary to ensure that corresponding functions can be triggered, TypeScript does not report errors, and code writing is convenient.
interface optionsFn {
  (isDark: boolean, theme: ChartTheme): EChartsOption;
}

export interface ChartTheme {
  backgroundColor: string;
  textColorPrimary: string;
  textColorSecondary: string;
  axisLineColor: string;
  axisSplitLineColor: string;
  primaryGradientFrom: string;
  primaryGradientMid: string;
  primaryGradientTo: string;
  areaGradientFrom: string;
  areaGradientTo: string;
}

function createTheme(isDark: boolean): ChartTheme {
  if (isDark) {
    return {
      backgroundColor: '#141414',
      textColorPrimary: '#E5E6EB',
      textColorSecondary: '#9CA3AF',
      axisLineColor: '#4B5563',
      axisSplitLineColor: '#374151',
      primaryGradientFrom: 'rgba(56, 189, 248, 1)', // sky-400
      primaryGradientMid: 'rgba(37, 99, 235, 1)',  // blue-600
      primaryGradientTo: 'rgba(129, 140, 248, 1)', // indigo-400
      areaGradientFrom: 'rgba(37, 99, 235, 0.24)',
      areaGradientTo: 'rgba(37, 99, 235, 0)',
    };
  }

  return {
    backgroundColor: '#FFFFFF',
    textColorPrimary: '#4E5969',
    textColorSecondary: '#86909C',
    axisLineColor: '#E5E8EF',
    axisSplitLineColor: '#E5E8EF',
    primaryGradientFrom: 'rgba(30, 231, 255, 1)',
    primaryGradientMid: 'rgba(36, 154, 255, 1)',
    primaryGradientTo: 'rgba(111, 66, 251, 1)',
    areaGradientFrom: 'rgba(17, 126, 255, 0.16)',
    areaGradientTo: 'rgba(17, 128, 255, 0)',
  };
}

export default function useChartOption(sourceOption: optionsFn) {
  const appStore = useAppStore();
  const isDark = computed(() => {
    return appStore.theme === 'dark';
  });
  // echarts support https://echarts.apache.org/zh/theme-builder.html
  // It's not used here
  // TODO echarts themes
  const chartOption = computed<EChartsOption>(() => {
    const theme = createTheme(isDark.value);
    return sourceOption(isDark.value, theme);
  });
  return {
    chartOption,
  };
}
