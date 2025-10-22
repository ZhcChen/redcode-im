import axios from 'axios';

export interface SystemStats {
  totalUsers: number;
  onlineUsers: number;
  totalRooms: number;
  activeRooms: number;
  totalMessages: number;
  todayMessages: number;
  systemLoad: number;
  memoryUsage: number;
  storageUsage: number;
}

export function getSystemStats() {
  return axios.get<SystemStats>('/api/dashboard/stats');
}

export interface SystemMonitor {
  cpu: number;
  memory: number;
  disk: number;
  network_in: number;
  network_out: number;
  connections: number;
}

export function getSystemMonitor() {
  return axios.get<SystemMonitor>('/api/dashboard/monitor');
}
