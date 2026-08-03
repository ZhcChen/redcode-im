import { attachmentCacheService } from '@/services/attachment-cache';
import { avatarCacheService } from '@/services/avatar-cache';
import { emojiCacheService } from '@/services/emoji-cache';
import { MessageSearchStorage } from '@/storage/message-search-storage';
import { MessageStorage } from '@/storage/message-storage';

export type ChatBackground = 'default' | 'mint' | 'gray';

const backgroundKey = 'redcode-h5-chat-background';

export const chatSettingsService = {
  getBackground(): ChatBackground {
    const value = window.localStorage.getItem(backgroundKey);
    return value === 'mint' || value === 'gray' ? value : 'default';
  },

  setBackground(value: ChatBackground) {
    window.localStorage.setItem(backgroundKey, value);
  },

  async clearLocalCache() {
    await Promise.all([
      new MessageStorage().clearAll(),
      new MessageSearchStorage().clearAll(),
      attachmentCacheService.clearAll(),
      avatarCacheService.clearAll(),
      emojiCacheService.clearAll(),
    ]);
  },
};
