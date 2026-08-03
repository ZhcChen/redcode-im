import { defineStore } from 'pinia';

export type AppTab = 'chat' | 'contacts' | 'discover' | 'mine';

export const useAppShellStore = defineStore('appShell', {
  state: () => ({
    activeTab: 'chat' as AppTab,
    unreadMessages: 0,
    pendingFriends: 0,
  }),
  actions: {
    switchTab(tab: AppTab) {
      this.activeTab = tab;
    },
    setPendingFriends(count: number) {
      this.pendingFriends = Math.max(0, count);
    },
  },
});
