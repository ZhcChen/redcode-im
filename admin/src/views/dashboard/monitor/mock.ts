import Mock from 'mockjs';

import setupMock, {
  successResponseWrap,
  // failResponseWrap,
} from '@/utils/setup-mock';

setupMock({
  setup() {
    Mock.mock(new RegExp('/api/chat/list'), () => {
      const data = Mock.mock({
        'data|4-6': [
          {
            'id|+1': 1,
            'username': 'user7352772',
            'content': 'Starting soon. Excited!',
            'time': '13:09:12',
            'isCollect|2': true,
          },
        ],
      });
      return successResponseWrap(data.data);
    });
  },
});
