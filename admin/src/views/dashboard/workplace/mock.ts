import Mock from 'mockjs';
import qs from 'query-string';
import dayjs from 'dayjs';
import { GetParams } from '@/types/global';
import setupMock, { successResponseWrap } from '@/utils/setup-mock';

const textList = [
  {
    key: 1,
    clickNumber: '346.3w+',
    title: 'Policy watch: fiscal support needs precision...',
    increases: 35,
  },
  {
    key: 2,
    clickNumber: '324.2w+',
    title: 'Double 12 cooled off as shoppers tired of the hype...',
    increases: 22,
  },
  {
    key: 3,
    clickNumber: '318.9w+',
    title: 'A tribute to community workers on the front line...',
    increases: 9,
  },
  {
    key: 4,
    clickNumber: '257.9w+',
    title: 'Academic or vocational school? Families face the choice...',
    increases: 17,
  },
  {
    key: 5,
    clickNumber: '124.2w+',
    title: 'Quick take: an unexpected twist from a familiar face...',
    increases: 37,
  },
];
const imageList = [
  {
    key: 1,
    clickNumber: '15.3w+',
    title: 'Yang Tao succeeds Lu Kang in regional affairs...',
    increases: 15,
  },
  {
    key: 2,
    clickNumber: '12.2w+',
    title: 'Photo set: tornado damage across multiple states...',
    increases: 26,
  },
  {
    key: 3,
    clickNumber: '18.9w+',
    title: 'A caregiver keeps supporting autistic children...',
    increases: 9,
  },
  {
    key: 4,
    clickNumber: '7.9w+',
    title: 'Family hospitalized after unsafe overnight heating...',
    increases: 0,
  },
  {
    key: 5,
    clickNumber: '5.2w+',
    title: 'Police investigate an alleged threat complaint...',
    increases: 4,
  },
];
const videoList = [
  {
    key: 1,
    clickNumber: '367.6w+',
    title: 'Nanjing at 10 a.m. today',
    increases: 5,
  },
  {
    key: 2,
    clickNumber: '352.2w+',
    title: 'Repeated provocations continue to hurt the economy...',
    increases: 17,
  },
  {
    key: 3,
    clickNumber: '348.9w+',
    title: 'South Korean entertainer tests positive for COVID-19',
    increases: 30,
  },
  {
    key: 4,
    clickNumber: '346.3w+',
    title: 'A public statement on the Beijing Winter Olympics',
    increases: 12,
  },
  {
    key: 5,
    clickNumber: '271.2w+',
    title: 'A post-95 service member awarded first-class merit',
    increases: 2,
  },
];
setupMock({
  setup() {
    Mock.mock(new RegExp('/api/content-data'), () => {
      const presetData = [58, 81, 53, 90, 64, 88, 49, 79];
      const getLineData = () => {
        const count = 8;
        return new Array(count).fill(0).map((el, idx) => ({
          x: dayjs()
            .day(idx - 2)
            .format('YYYY-MM-DD'),
          y: presetData[idx],
        }));
      };
      return successResponseWrap([...getLineData()]);
    });
    Mock.mock(new RegExp('/api/popular/list'), (params: GetParams) => {
      const { type = 'text' } = qs.parseUrl(params.url).query;
      if (type === 'image') {
        return successResponseWrap([...videoList]);
      }
      if (type === 'video') {
        return successResponseWrap([...imageList]);
      }
      return successResponseWrap([...textList]);
    });
  },
});
