import Mock from 'mockjs';

import './user';
import './message-box';

import '@/features/dashboard/workplace/mock';
/** simple */
import '@/features/dashboard/monitor/mock';

Mock.setup({
  timeout: '600-1000',
});
