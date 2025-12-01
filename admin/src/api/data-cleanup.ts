import axios from 'axios';

const cleanupAllAppData = () => {
  return axios.post('/admin/data/cleanup/all', {});
};

export default cleanupAllAppData;
