import http from '@/services/http';

const cleanupAllAppData = () => {
  return http.post('/admin/data/cleanup/all', {});
};

export default cleanupAllAppData;
