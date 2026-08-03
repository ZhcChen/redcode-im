import { attachmentCacheService } from '@/services/attachment-cache';
import { avatarCacheService } from '@/services/avatar-cache';
import { emojiCacheService } from '@/services/emoji-cache';
import { ChatSummaryStorage } from '@/storage/chat-summary-storage';
import { ContactStorage } from '@/storage/contact-storage';
import { MessageSearchStorage } from '@/storage/message-search-storage';
import { MessageStorage } from '@/storage/message-storage';

export const accountDataService = {
  async clearAll() {
    await Promise.all([
      new ChatSummaryStorage().clear(),
      new ContactStorage().clear(),
      new MessageStorage().clearAll(),
      new MessageSearchStorage().clearAll(),
      attachmentCacheService.clearAll(),
      avatarCacheService.clearAll(),
      emojiCacheService.clearAll(),
    ]);
  },
};
