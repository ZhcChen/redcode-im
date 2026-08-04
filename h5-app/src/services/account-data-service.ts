import { attachmentCacheService } from '@/services/attachment-cache';
import { avatarCacheService } from '@/services/avatar-cache';
import { emojiCacheService } from '@/services/emoji-cache';
import { clearEncryptedMessageCache } from '@/services/message-service';
import { e2eeSecureStateStorage } from '@/e2ee/secure-state-storage';
import { ChatSummaryStorage } from '@/storage/chat-summary-storage';
import { ContactStorage } from '@/storage/contact-storage';
import { MessageSearchStorage } from '@/storage/message-search-storage';
import { MessageStorage } from '@/storage/message-storage';

export const accountDataService = {
  async clearAll(accountId?: string) {
    clearEncryptedMessageCache(accountId);
    await Promise.all([
      new ChatSummaryStorage().clear(),
      new ContactStorage().clear(),
      new MessageStorage().clearAll(),
      new MessageSearchStorage().clearAll(),
      attachmentCacheService.clearAll(),
      avatarCacheService.clearAll(),
      emojiCacheService.clearAll(),
      accountId ? e2eeSecureStateStorage.delete(accountId) : Promise.resolve(),
    ]);
  },
};
