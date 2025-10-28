import Mock from 'mockjs';
import setupMock, { successResponseWrap } from '@/utils/setup-mock';

const haveReadIds: number[] = [];
const getMessageList = () => {
  return [];
};

setupMock({
  setup: () => {
    Mock.mock(new RegExp('/api/message/list'), () => {
      return successResponseWrap(getMessageList());
    });

    Mock.mock(new RegExp('/api/message/read'), (params: { body: string }) => {
      const { ids } = JSON.parse(params.body);
      haveReadIds.push(...(ids || []));
      return successResponseWrap(true);
    });
  },
});
