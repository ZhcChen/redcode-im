import { defineStore } from 'pinia';

export type AppTab = 'chat' | 'contacts' | 'settings';

export const useAppShellStore = defineStore('appShell', {
  state: () => ({
    activeTab: 'chat' as AppTab,
    unreadMessages: 2,
    pendingFriends: 1,
  }),
  actions: {
    switchTab(tab: AppTab) {
      this.activeTab = tab;
    },
  },
});
