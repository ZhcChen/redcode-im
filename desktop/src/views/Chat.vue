<template>
  <div class="chat-page">
    <div class="chat-header">
      <div class="header-left" :style="{ width: chatListWidth + 'px' }">
        <Popover placement="bottom" :offset="8" :content-offset-x="30" :content-offset-y="15" :arrow-offset-x="-30">
          <template #trigger>
            <img 
              src="@/assets/image/icon-menu.svg" 
              alt="菜单" 
              class="menu-icon"
            />
          </template>
          <template #content>
            <div class="menu-popup">
              <div class="popover-item" @click="handleCreateGroup">
                <img 
                  src="@/assets/image/icon-message.svg"
                  alt="创建群组"
                  class="popover-icon"
                />
                <span class="popover-label">创建群组</span>
              </div>
            </div>
          </template>
        </Popover>
        <SearchInput
          v-model="searchText"
          placeholder="搜索聊天..."
          @search="handleSearch"
          @focus="handleSearchFocus"
        />
        
      </div>
      <div class="chat-header-right" v-if="selectedChat">
        <Avatar :src="selectedChat.avatar" :text="selectedChat.name" :size="42" />
        <div class="chat-info">
          <h2 class="chat-title">{{ selectedChat.name }}</h2>
          <div v-if="selectedChat.groupType === 1" class="chat-member-count">
            人数 {{ selectedChat.memberCount || 0 }}
          </div>
        </div>
        <!-- 群设置按钮 -->
        <div v-if="selectedChat.groupType === 1" class="group-settings-btn" @click="showGroupSettings = true">
          <img src="@/assets/image/icon-menu.svg" alt="群设置" class="settings-icon" />
        </div>
      </div>
      <h2 v-else></h2>
    </div>
    
    <div class="chat-content">
      <div class="chat-list" :style="{ width: chatListWidth + 'px' }">
        <!-- 只有在初始加载且没有缓存数据时才显示loading -->
        <div v-if="loading && chatList.length === 0" class="loading-container">
          <div class="loading-text">加载聊天列表中...</div>
        </div>
        <div v-else-if="!loading && chatList.length === 0" class="empty-container">
          <div class="empty-text">暂无聊天</div>
          <div v-if="route.query.contactId" class="debug-info">
            <div class="debug-text">正在处理联系人聊天请求...</div>
            <div class="debug-details">联系人: {{ route.query.contactName }} (ID: {{ route.query.contactId }})</div>
          </div>
        </div>
        <div v-else class="chat-item" v-for="chat in chatList" :key="chat.id" @click="selectChat(chat)" :class="{ 'is-top': chat.isTop, 'selected': selectedChat && selectedChat.id === chat.id }">
          <Avatar :src="chat.avatar" :text="chat.name" :size="48" />
          <div class="chat-info">
            <div class="chat-name-time">
              <div class="chat-name">
                {{ chat.name }}
                <span v-if="chat.isTop" class="top-indicator">📌</span>
                <span class="chat-type">
                  {{ chat.groupType === 1 ? '[群聊]' : chat.groupType === 2 ? '[收藏夹]' : '[单聊]' }}
                </span>
              </div>
              <div class="chat-time">{{ chat.time }}</div>
            </div>
            <div class="chat-message-badge">
              <div class="chat-message">{{ chat.lastMessage }}</div>
              <div v-if="chat.unreadCount > 0" class="chat-badge">{{ chat.unreadCount }}</div>
            </div>
          </div>
        </div>
      </div>
      
      <div class="resize-handle" 
           @mousedown="startResize"
           @dblclick="resetWidth">
        <div class="resize-line"></div>
      </div>
      
      <div class="chat-window" v-if="selectedChat">
        <div class="chat-messages" ref="chatMessagesRef">
          <div v-if="messages.length === 0" class="empty-container">
            <div class="empty-text">暂无消息，开始聊天吧</div>
          </div>
          <div v-else class="message" v-for="message in messages" :key="message.id" :data-message-id="message.id" :class="{ 'own-message': message.isSelf, 'message-failed': message.status === 3, 'system-message': message.messageType === MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG }">
            <!-- 系统消息特殊显示 -->
            <div v-if="message.messageType === MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG" class="system-message-content">
              <div class="system-message-text">{{ getTextContent(message) }}</div>
              <div class="system-message-time">{{ formatMessageTime(message.createTime || message.time) }}</div>
            </div>

            <!-- 普通用户消息 -->
            <template v-else>
            <Avatar v-if="!message.isSelf" :src="message.senderAvatar" :text="message.senderName" :size="40" />
            <div v-if="!message.isSelf" class="message-wrapper">
              <div class="message-sender-name">{{ message.senderName }}</div>
              <div class="message-content">
                <!-- 文本消息 -->
                <template v-if="!message.contentType || message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE">
                  {{ getTextContent(message) }}
                </template>

                <!-- 图片消息 -->
                <template v-else-if="message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE">
                  <div class="media-message image-message">
                    <img
                      v-if="parseImageSrc(message)"
                      :src="parseImageSrc(message)"
                      :alt="getImageAlt(message)"
                      class="message-image"
                      :class="{ uploading: isMessageUploading(message) }"
                      @click="handleImagePreview(parseImageSrc(message), message)"
                      @load="scrollToBottomAfterImageLoad"
                      @error="handleImageError"
                      loading="lazy"
                    />
                    <div v-else class="image-loading-placeholder">
                      <div class="loading-text">图片加载中...</div>
                    </div>
                  </div>
                </template>

                <!-- 视频消息 -->
                <template v-else-if="message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE">
                  <div class="media-message video-message">
                    <div class="video-container" @click="handleVideoPlay(message)">
                      <!-- 如果有视频缩略图则显示，否则显示默认视频图标 -->
                      <div v-if="parseVideoScreenShotSrc(message)" class="video-thumbnail-wrapper">
                        <img
                          :src="parseVideoScreenShotSrc(message)"
                          :alt="(typeof message.content === 'object' && message.content.name) || '视频'"
                          class="video-thumbnail"
                          @load="scrollToBottomAfterImageLoad"
                          @error="handleVideoThumbnailError"
                          loading="lazy"
                        />
                      </div>
                      <!-- 默认视频显示 -->
                      <div v-else class="video-placeholder">
                        <div class="video-icon">🎬</div>
                        <div class="video-info">
                          <div class="video-filename">{{ (typeof message.content === 'object' && message.content.name) || '视频文件' }}</div>
                          <div class="video-size" v-if="typeof message.content === 'object' && message.content.size">
                            {{ formatFileSize(message.content.size) }}
                          </div>
                        </div>
                      </div>
                      <div class="video-play-overlay">
                        <div class="play-icon">▶</div>
                      </div>
                    </div>
                  </div>
                </template>

                <!-- 其他类型消息 -->
              <template v-else>
                <span>{{ getTextContent(message) }}</span>
                <span v-if="message.isEdited" class="message-edited-flag">（已编辑）</span>
              </template>

                <div class="message-time-other">
                  {{ formatMessageTime(message.createTime || message.time) }}
                </div>
              </div>
            </div>
            <div v-else class="message-content">
              <!-- 文本消息 -->
              <template v-if="!message.contentType || message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE">
                {{ getTextContent(message) }}
              </template>

              <!-- 图片消息 -->
              <template v-else-if="message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE">
                <div class="media-message image-message">
                    <img
                      v-if="parseImageSrc(message)"
                      :src="parseImageSrc(message)"
                      :alt="getImageAlt(message)"
                      class="message-image"
                      :class="{ uploading: isMessageUploading(message) }"
                      @click="handleImagePreview(parseImageSrc(message), message)"
                      @load="scrollToBottomAfterImageLoad"
                      @error="handleImageError"
                      loading="lazy"
                    />
                    <div v-else class="image-loading-placeholder">
                      <div class="loading-text">图片加载中...</div>
                    </div>
                </div>
              </template>

              <!-- 视频消息 -->
              <template v-else-if="message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE">
                <div class="media-message video-message">
                  <div class="video-container" @click="handleVideoPlay(message)">
                    <!-- 如果有视频缩略图则显示，否则显示默认视频图标 -->
                    <div v-if="parseVideoScreenShotSrc(message)" class="video-thumbnail-wrapper">
                      <img
                        :src="parseVideoScreenShotSrc(message)"
                        :alt="(typeof message.content === 'object' && message.content.name) || '视频'"
                        class="video-thumbnail"
                        @load="scrollToBottomAfterImageLoad"
                        @error="handleVideoThumbnailError"
                        loading="lazy"
                      />
                    </div>
                    <!-- 默认视频显示 -->
                    <div v-else class="video-placeholder">
                      <div class="video-icon">🎬</div>
                      <div class="video-info">
                        <div class="video-filename">{{ (typeof message.content === 'object' && message.content.name) || '视频文件' }}</div>
                        <div class="video-size" v-if="typeof message.content === 'object' && message.content.size">
                          {{ formatFileSize(message.content.size) }}
                        </div>
                      </div>
                    </div>
                    <div class="video-play-overlay">
                      <div class="play-icon">▶</div>
                    </div>
                  </div>
                </div>
              </template>

              <!-- 其他类型消息 -->
              <template v-else>
                <span>{{ getTextContent(message) }}</span>
                <span v-if="message.isEdited" class="message-edited-flag">（已编辑）</span>
              </template>

              <div class="message-time">
                {{ formatMessageTime(message.createTime || message.time) }}
              </div>
            </div>
            <div v-if="message.status === 3" class="message-status failed">
              发送失败
              <button v-if="message.isSelf" @click="resendMessage(message)" class="resend-btn">重发</button>
            </div>
            <!-- 加载动画放在消息框外面左下角 -->
            <div v-if="message.status === 1" class="message-loading-indicator">
              <div class="loading-spinner"></div>
            </div>
            </template>
          </div>
        </div>
        <div class="chat-input">
          <div class="input-container">
            <div class="input-left-actions">
              <img
                src="@/assets/image/icon-emoji.svg"
                alt="表情"
                class="action-icon emoji-icon"
                @click="handleEmojiClick"
              />
              <img
                src="@/assets/image/icon-upload.svg"
                alt="上传"
                class="action-icon upload-icon"
                @click="handleUploadClick"
              />
              <img
                src="@/assets/image/icon-voice.svg"
                alt="语音"
                class="action-icon voice-icon"
                @click="handleVoiceClick"
              />
            </div>
            <textarea
              v-model="newMessage"
              @keydown="handleInputKeydown"
              placeholder="输入消息..."
              rows="1"
              ref="messageInput"
            ></textarea>
            <div class="input-right-actions">
              <img
                src="@/assets/image/icon-send.svg"
                alt="发送"
                class="action-icon send-icon"
                @click="sendMessage"
              />
            </div>
            <!-- 表情选择器 -->
            <EmojiPicker
              :show="showEmojiPicker"
              @select="handleEmojiSelect"
              @close="handleEmojiClose"
            />
          </div>
        </div>
      </div>
      
      <div class="empty-chat" v-else>
        <p>选择一个聊天开始对话</p>
      </div>
    </div>

    <!-- 群名输入对话框 -->
    <Dialog
      v-model="showGroupNameDialog"
      title="创建群聊"
      @confirm="handleConfirmGroupName"
      @cancel="handleCancelGroupName"
      :confirm-text="isCreatingGroup ? '加载中...' : '下一步'"
      :confirm-disabled="isCreatingGroup || !newGroupName.trim()"
    >
      <div class="group-name-content">
        <DialogInput
          v-model="newGroupName"
          placeholder="请输入群聊名称..."
          :disabled="isCreatingGroup"
          maxlength="20"
          @keyup.enter="handleConfirmGroupName"
        />

        <!-- 错误提示 -->
        <div v-if="groupNameError" class="group-name-error">
          {{ groupNameError }}
        </div>
      </div>
    </Dialog>

    <!-- 修改群名对话框 -->
    <Dialog
      v-model="showEditGroupNameDialog"
      title="修改群名称"
      @confirm="handleConfirmEditGroupName"
      @cancel="handleCancelEditGroupName"
      :confirm-text="isUpdatingGroupName ? '保存中...' : '保存'"
      :confirm-disabled="isUpdatingGroupName || !editingGroupName.trim() || editingGroupName === selectedChat?.name"
    >
      <div class="group-name-content">
        <DialogInput
          v-model="editingGroupName"
          placeholder="请输入新的群名称..."
          :disabled="isUpdatingGroupName"
          maxlength="20"
          @keyup.enter="handleConfirmEditGroupName"
        />

        <!-- 错误提示 -->
        <div v-if="groupNameError" class="group-name-error">
          {{ groupNameError }}
        </div>
      </div>
    </Dialog>

    <!-- 修改群公告对话框 -->
    <Dialog
      v-model="showEditGroupNoticeDialog"
      title="修改群公告"
      @confirm="handleConfirmEditGroupNotice"
      @cancel="handleCancelEditGroupNotice"
      :confirm-text="isUpdatingGroupNotice ? '保存中...' : '保存'"
      :confirm-disabled="isUpdatingGroupNotice || !editingGroupNotice.trim()"
    >
      <div class="group-name-content">
        <DialogInput
          v-model="editingGroupNotice"
          placeholder="请输入群公告..."
          :disabled="isUpdatingGroupNotice"
          maxlength="100"
          @keyup.enter="handleConfirmEditGroupNotice"
        />

        <!-- 错误提示 -->
        <div v-if="groupNameError" class="group-name-error">
          {{ groupNameError }}
        </div>
      </div>
    </Dialog>

    <!-- 添加群成员对话框 (创建新群时) -->
    <AddGroupMemberDialog
      v-model:visible="showAddMemberDialog"
      :contacts="contacts"
      @confirm="handleConfirmAddMembers"
      @close="handleCancelAddMembers"
    />

    <!-- 添加成员到现有群聊对话框 -->
    <AddGroupMemberDialog
      v-model:visible="showAddExistingGroupMemberDialog"
      :contacts="availableContactsForGroup"
      @confirm="handleConfirmAddExistingGroupMembers"
      @close="showAddExistingGroupMemberDialog = false"
    />

    <!-- 删除群成员对话框 -->
    <RemoveGroupMemberDialog
      v-model:visible="showRemoveMemberDialog"
      :members="groupMembers"
      @confirm="handleConfirmRemoveMembers"
      @close="showRemoveMemberDialog = false"
    />

    <!-- 举报群聊对话框 -->
    <ReportDialog
      v-model:visible="showReportDialog"
      @confirm="handleConfirmReport"
      @close="showReportDialog = false"
    />

    <!-- 媒体预览组件 -->
    <MediaPreview
      :visible="showMediaPreview"
      :media-src="previewMediaSrc"
      :media-type="previewMediaType"
      :media-name="previewMediaName"
      :media-size="previewMediaSize"
      @close="closeMediaPreview"
    />

    <!-- 群设置抽屉 -->
    <GroupSettingsDrawer
      :visible="showGroupSettings"
      :group-info="selectedChat"
      :group-members="groupMembers"
      @close="showGroupSettings = false"
      @edit-group-name="handleEditGroupName"
      @edit-group-avatar="handleEditGroupAvatar"
      @edit-group-notice="handleEditGroupNotice"
      @toggle-mute="handleToggleMute"
      @toggle-top="handleToggleTop"
      @add-member="handleAddMember"
      @remove-member="handleRemoveMember"
      @clear-history="handleClearHistory"
      @report-group="handleReportGroup"
      @leave-group="handleLeaveGroup"
    />

    <!-- 语音录制弹窗 -->
    <Dialog
      :visible="showVoiceRecorder"
      title="语音消息"
      @close="closeVoiceRecorder"
    >
      <VoiceMessage
        :show-recorder="true"
        @voice-send="handleVoiceSend"
        @voice-cancel="closeVoiceRecorder"
      />
    </Dialog>

  <!-- 搜索对话框 -->
  <SearchDialog
    :visible="showSearchDialog"
    :current-room-id="selectedChat?.groupId"
    :available-rooms="availableRoomsForSearch"
    :available-senders="availableSendersForSearch"
    @close="showSearchDialog = false"
    @result-click="handleSearchResultClick"
  />
</div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useStore } from 'vuex'
import Avatar from '../components/Avatar.vue'
import SearchInput from '../components/SearchInput.vue'
import Popover from '../components/Popover.vue'
import SearchDialog from '../components/SearchDialog.vue'
import { messageSearchService } from '../services/messageSearchService'
import EmojiPicker from '../components/EmojiPicker.vue'
import AddGroupMemberDialog from '../components/AddGroupMemberDialog.vue'
import RemoveGroupMemberDialog from '../components/RemoveGroupMemberDialog.vue'
import ReportDialog from '../components/ReportDialog.vue'
import Dialog from '../components/Dialog.vue'
import DialogInput from '../components/DialogInput.vue'
import MediaPreview from '../components/MediaPreview.vue'
import GroupSettingsDrawer from '../components/GroupSettingsDrawer.vue'
import VoiceMessage from '../components/VoiceMessage.vue'
import { api, MessageApi } from '../api'
import type { DirectUploadSignatureInfo, MessagePartPayloadInput } from '../api/message'
import { GroupApi } from '../api/group'
import { FriendApi } from '../api/friend'
import { FileApi } from '../api/file'
import type { Message as DomainMessage, Chat, RoomMember, MessagePart, MessageAttachment } from '@/types/models'
import { ChatType, MessageStatus, MessageType, MessagePartType } from '@/types/models'
import { toast } from '../utils/toast'
import { webSocketManager } from '../utils/websocket'
import { eventManager } from '../utils/eventManager'
import { fileConfig } from '../api/config'
import { loadCache, saveCache, CACHE_KEYS } from '../utils/cache'
import { rustHttp } from '../api/rust-http'
import type { HttpRequestParams } from '../api/rust-http'
import { base64ToUint8Array } from '../utils/binary'

// 消息常量定义 - 与bear-chat-uniapp保持一致
const MESSAGE_CONSTANTS = {
  // WebSocket业务类型
  BUSINESS_CODE: {
    ping: "WSHeartBeat",
    chatting: "Chatting",
    launchGroup: "LaunchGroup",
    deleteGroup: 'DeleteGroup',
    AI: "AI"
  },
  // 消息类型
  MSG_TYPE: {
    SYSTEM_MSG: 0, // 系统消息
    USER_MSG: 1,   // 用户消息
  },
  // 内容类型
  CONTENT_TYPE: {
    TEXT_CONTENT_TYPE: 1,      // 文本
    IMG_CONTENT_TYPE: 2,       // 图片
    VIDEO_CONTENT_TYPE: 3,     // 视频
    AUDIO_CONTENT_TYPE: 4,     // 语音
    FILE_CONTENT_TYPE: 5,      // 文件
    OTHER_CONTENT_TYPE: 6,     // 其他
    RED_BAG_CONTENT_TYPE: 7,   // 红包
    FRIEND_INFO_CONTENT_TYPE: 8, // 名片
    LOCATION_CONTENT_TYPE: 9,  // 位置
    CHAT_RECORD_CONTENT_TYPE: 10, // 聊天记录
    IMG_TEXT_COM_CONTENT_TYPE: 11, // 图文组合
    VIDEO_TEXT_COM_CONTENT_TYPE: 12, // 视频图文组合
    TRANSFER_CONTENT_TYPE: 13, // 转账
  },
  // 平台类型
  PLATFORM: {
    WEB: 1,
    IOS: 2,
    ANDROID: 3,
    WECHAT: 4
  }
}

const messageStatusToUiStatus: Record<MessageStatus, number> = {
  [MessageStatus.SENDING]: 1,
  [MessageStatus.SENT]: 2,
  [MessageStatus.DELIVERED]: 2,
  [MessageStatus.READ]: 2,
  [MessageStatus.FAILED]: 3
}

const blobUrlRegistry = new Set<string>();

const registerBlobUrl = (url: string | null) => {
  if (typeof url === 'string' && url.startsWith('blob:')) {
    blobUrlRegistry.add(url);
  }
};

const releaseBlobUrl = (url: string | null) => {
  if (typeof url === 'string' && url.startsWith('blob:') && blobUrlRegistry.has(url)) {
    try {
      URL.revokeObjectURL(url);
    } catch (error) {
      console.warn('释放本地URL失败:', error);
    }
    blobUrlRegistry.delete(url);
  }
};

const attachmentUrlCache = new Map<string, { localPath: string; expiresAt: number; downloadUrl?: string | null }>();
const pendingAttachmentDownloads = new Map<string, Promise<{ localPath: string; downloadUrl: string | null } | null>>();
const ATTACHMENT_CACHE_TTL_MS = 10 * 60 * 1000; // 10 分钟
const ATTACHMENT_DOWNLOAD_EXPIRES_SECONDS = 600;

const messageTypeToContentType: Record<MessageType, number> = {
  [MessageType.TEXT]: MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE,
  [MessageType.IMAGE]: MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE,
  [MessageType.VOICE]: MESSAGE_CONSTANTS.CONTENT_TYPE.AUDIO_CONTENT_TYPE,
  [MessageType.VIDEO]: MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE,
  [MessageType.FILE]: MESSAGE_CONSTANTS.CONTENT_TYPE.FILE_CONTENT_TYPE,
  [MessageType.SYSTEM]: MESSAGE_CONSTANTS.CONTENT_TYPE.OTHER_CONTENT_TYPE,
  [MessageType.MIXED]: MESSAGE_CONSTANTS.CONTENT_TYPE.OTHER_CONTENT_TYPE
}

type AttachmentMeta = {
  partType: MessagePartPayloadInput['type'];
  width?: number | null;
  height?: number | null;
  durationMs?: number | null;
  mime: string;
  summary: string;
};

const MESSAGES_CACHE_LIMIT = 200;

const sanitizeAttachmentForCache = (attachment: MessageAttachment | null | undefined): MessageAttachment | null => {
  if (!attachment) {
    return null
  }
  return {
    ...attachment,
    localPath: null,
    downloadUrl: null,
    uploadProgress: null,
  }
}

const sanitizeMessageForCache = (message: Message): Message => {
  const sanitizedParts = message.parts?.map((part) => ({
    ...part,
    attachment: sanitizeAttachmentForCache(part.attachment ?? undefined),
  }))

  let sanitizedContent: Message['content'] = message.content
  if (typeof message.content === 'object' && message.content) {
    sanitizedContent = {
      ...message.content,
      localUrl: null,
      downloadUrl: null,
      uploadProgress: null,
      isUploading: false,
    }
  }

  return {
    ...message,
    content: sanitizedContent,
    parts: sanitizedParts,
  }
}

const restoreMessageFromCache = (cached: Message): Message => {
  const restoredParts = cached.parts?.map((part) => ({
    ...part,
    attachment: part.attachment
      ? {
          ...part.attachment,
          localPath: null,
          downloadUrl: null,
          uploadProgress: null,
        }
      : part.attachment ?? null,
  }))

  let restoredContent: Message['content'] = cached.content
  if (typeof cached.content === 'object' && cached.content) {
    restoredContent = {
      ...cached.content,
      localUrl: null,
      downloadUrl: null,
      uploadProgress: null,
      isUploading: false,
    }
  }

  return {
    ...cached,
    content: restoredContent,
    parts: restoredParts,
  }
}

const persistMessagesCache = async (groupId: string, messageList: Message[]) => {
  if (!groupId) return
  const sliced = messageList.slice(-MESSAGES_CACHE_LIMIT).map((msg) => sanitizeMessageForCache(msg))
  await saveCache(CACHE_KEYS.messages(groupId), sliced)
}

let messageCachePersistTimer: ReturnType<typeof setTimeout> | null = null

const scheduleMessagesCachePersist = (groupId: string | null | undefined, messageList: Message[]) => {
  if (!groupId) {
    return
  }
  if (messageCachePersistTimer) {
    clearTimeout(messageCachePersistTimer)
  }
  messageCachePersistTimer = setTimeout(() => {
    persistMessagesCache(groupId, messageList).catch((error) => {
      console.warn('[cache] 持久化消息缓存失败:', error)
    })
  }, 400)
}

const partTypeEnumMap: Record<MessagePartPayloadInput['type'], MessagePartType> = {
  text: MessagePartType.TEXT,
  image: MessagePartType.IMAGE,
  video: MessagePartType.VIDEO,
  audio: MessagePartType.AUDIO,
  file: MessagePartType.FILE
};

const partTypeContentMap: Record<Exclude<MessagePartPayloadInput['type'], 'text'>, number> = {
  image: MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE,
  video: MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE,
  audio: MESSAGE_CONSTANTS.CONTENT_TYPE.AUDIO_CONTENT_TYPE,
  file: MESSAGE_CONSTANTS.CONTENT_TYPE.FILE_CONTENT_TYPE
};

const buildAttachmentSummary = (type: MessagePartPayloadInput['type'], name: string): string => {
  const safeName = name || '';
  switch (type) {
    case 'image':
      return `[图片] ${safeName}`.trim();
    case 'video':
      return `[视频] ${safeName}`.trim();
    case 'audio':
      return `[语音] ${safeName}`.trim();
    case 'file':
      return `[文件] ${safeName}`.trim();
    case 'text':
    default:
      return safeName || '';
  }
};

const getImageDimensions = (file: File): Promise<{ width: number; height: number }> => {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      resolve({ width: img.naturalWidth, height: img.naturalHeight });
      URL.revokeObjectURL(url);
    };
    img.onerror = (error) => {
      URL.revokeObjectURL(url);
      reject(error);
    };
    img.src = url;
  });
};

const getVideoMetadata = (file: File): Promise<{ width: number; height: number; durationMs: number }> => {
  return new Promise((resolve, reject) => {
    const video = document.createElement('video');
    video.preload = 'metadata';
    video.muted = true;
    const url = URL.createObjectURL(file);
    video.onloadedmetadata = () => {
      const width = video.videoWidth;
      const height = video.videoHeight;
      const durationMs = Number.isFinite(video.duration) ? Math.round(video.duration * 1000) : 0;
      URL.revokeObjectURL(url);
      resolve({ width, height, durationMs });
    };
    video.onerror = (error) => {
      URL.revokeObjectURL(url);
      reject(error);
    };
    video.src = url;
  });
};

const getAudioDuration = (file: File): Promise<number> => {
  return new Promise((resolve, reject) => {
    const audio = document.createElement('audio');
    audio.preload = 'metadata';
    const url = URL.createObjectURL(file);
    audio.onloadedmetadata = () => {
      const durationMs = Number.isFinite(audio.duration) ? Math.round(audio.duration * 1000) : 0;
      URL.revokeObjectURL(url);
      resolve(durationMs);
    };
    audio.onerror = (error) => {
      URL.revokeObjectURL(url);
      reject(error);
    };
    audio.src = url;
  });
};

const determineAttachmentMeta = async (file: File): Promise<AttachmentMeta> => {
  const mime = file.type?.toLowerCase() || 'application/octet-stream';

  if (mime.startsWith('image/')) {
    try {
      const { width, height } = await getImageDimensions(file);
      return {
        partType: 'image',
        width,
        height,
        mime,
        summary: buildAttachmentSummary('image', file.name)
      };
    } catch (error) {
      console.warn('获取图片尺寸失败:', error);
      return {
        partType: 'image',
        mime,
        summary: buildAttachmentSummary('image', file.name)
      };
    }
  }

  if (mime.startsWith('video/')) {
    try {
      const { width, height, durationMs } = await getVideoMetadata(file);
      return {
        partType: 'video',
        width,
        height,
        durationMs,
        mime,
        summary: buildAttachmentSummary('video', file.name)
      };
    } catch (error) {
      console.warn('获取视频元数据失败:', error);
      return {
        partType: 'video',
        mime,
        summary: buildAttachmentSummary('video', file.name)
      };
    }
  }

  if (mime.startsWith('audio/')) {
    try {
      const durationMs = await getAudioDuration(file);
      return {
        partType: 'audio',
        durationMs,
        mime,
        summary: buildAttachmentSummary('audio', file.name)
      };
    } catch (error) {
      console.warn('获取音频时长失败:', error);
      return {
        partType: 'audio',
        mime,
        summary: buildAttachmentSummary('audio', file.name)
      };
    }
  }

  return {
    partType: 'file',
    mime,
    summary: buildAttachmentSummary('file', file.name)
  };
};

const updateAttachmentProgress = (messageId: string, attachmentKey: string, progress: number | null) => {
  const index = messages.value.findIndex((msg) => msg.id === messageId);
  if (index === -1) {
    return;
  }

  const message = messages.value[index];
  if (!Array.isArray(message.parts) || message.parts.length === 0) {
    return;
  }

  let changed = false;

  const updatedParts = message.parts.map((part) => {
    if (part.attachment?.key !== attachmentKey) {
      return part;
    }
    if (part.attachment.uploadProgress === progress) {
      return part;
    }
    changed = true;
    return {
      ...part,
      attachment: {
        ...part.attachment,
        uploadProgress: progress,
      }
    };
  });

  if (!changed) {
    return;
  }

  let updatedContent = message.content;
  if (typeof message.content === 'object' && message.content) {
    updatedContent = {
      ...message.content,
      uploadProgress: progress,
      isUploading: progress !== null && progress < 1,
    };
  }

  messages.value[index] = {
    ...message,
    parts: updatedParts,
    content: updatedContent,
  };
};

const buildAttachmentPartPayload = (
  meta: AttachmentMeta,
  key: string,
  file: File,
): MessagePartPayloadInput => {
  if (meta.partType === 'text') {
    return {
      type: 'text',
      text: file.name,
    };
  }

  return {
    type: meta.partType,
    key,
    name: file.name,
    mime: meta.mime,
    size: file.size,
    width: meta.width ?? undefined,
    height: meta.height ?? undefined,
    durationMs: meta.durationMs ?? undefined,
  };
};

const buildPlaceholderPart = (
  meta: AttachmentMeta,
  key: string,
  file: File,
  localUrl: string,
): MessagePart => ({
  position: 0,
  type: partTypeEnumMap[meta.partType],
  attachment: {
    key,
    name: file.name,
    mime: meta.mime,
    size: file.size,
    width: meta.width ?? null,
    height: meta.height ?? null,
    durationMs: meta.durationMs ?? null,
    thumbnailKey: null,
    localPath: localUrl,
    uploadProgress: 0,
  },
});

const forbiddenDirectUploadHeaders = new Set([
  'host',
  'content-length',
  'accept-encoding',
  'user-agent',
  'referer',
  'origin',
  'connection',
]);

const buildDirectUploadHeaders = (signatureHeaders: Record<string, string> | undefined, file: File) => {
  const normalizedHeaders: Record<string, string> = {};
  let hasContentTypeHeader = false;

  if (signatureHeaders && typeof signatureHeaders === 'object') {
    Object.entries(signatureHeaders).forEach(([rawKey, rawValue]) => {
      const headerKey = typeof rawKey === 'string' ? rawKey.trim() : '';
      if (!headerKey) return;
      const lowerKey = headerKey.toLowerCase();
      if (forbiddenDirectUploadHeaders.has(lowerKey)) {
        return;
      }
      if (lowerKey === 'content-type') {
        hasContentTypeHeader = true;
      }
      if (typeof rawValue !== 'string') {
        return;
      }
      normalizedHeaders[headerKey] = rawValue;
    });
  }

  if (!hasContentTypeHeader && file.type) {
    normalizedHeaders['Content-Type'] = file.type;
  }

  return normalizedHeaders;
};

const uploadWithSignature = async (
  signature: DirectUploadSignatureInfo,
  file: File,
  onProgress?: (progress: number) => void,
) => {
  const headers = buildDirectUploadHeaders(signature.headers, file);
  const method = (signature.method || 'PUT').toUpperCase() as HttpRequestParams['method'];
  if (!headers['Content-Length']) {
    headers['Content-Length'] = String(file.size);
  }
  const fileBuffer = new Uint8Array(await file.arrayBuffer());

  const response = await rustHttp.requestRaw({
    path: signature.url,
    method,
    headers,
    binaryBody: fileBuffer,
    injectToken: false,
    forceStreaming: true
  });

  if (!response.success) {
    const extra = response.message ? `，响应：${response.message.slice(0, 200)}` : '';
    throw new Error(`上传失败，状态码 ${response.code}${extra}`);
  }

  if (onProgress) {
    onProgress(1);
  }
};

const downloadAttachmentToLocalUrl = async (downloadUrl: string, mime?: string | null): Promise<{ localPath: string; fromBlob: boolean }> => {
  try {
    const response = await rustHttp.requestRaw<{ base64?: string; headers?: Record<string, string> }>({
      path: downloadUrl,
      method: 'GET',
      responseType: 'binary',
      injectToken: false
    });

    if (!response.success || !response.data || !response.data.base64) {
      throw new Error(`下载失败，状态码 ${response.code}`);
    }

    const bytes = base64ToUint8Array(response.data.base64);
    const contentType = mime || response.data.headers?.['content-type'] || undefined;
    const blob = new Blob([bytes], { type: contentType });
    const objectUrl = URL.createObjectURL(blob);
    return { localPath: objectUrl, fromBlob: true };
  } catch (error) {
    console.error('下载附件失败，回退至签名URL:', error);
    return { localPath: downloadUrl, fromBlob: false };
  }
};

const setAttachmentLocalPath = (messageId: string, attachmentKey: string, localPath: string | null, extra: { downloadUrl?: string | null } = {}) => {
  const index = messages.value.findIndex((msg) => msg.id === messageId);
  if (index === -1) {
    return;
  }

  const message = messages.value[index];
  if (!Array.isArray(message.parts)) {
    return;
  }

  let changed = false;

  const updatedParts = message.parts.map((part) => {
    if (!part.attachment || part.attachment.key !== attachmentKey) {
      return part;
    }

    const previousPath = part.attachment.localPath || null;
    if (previousPath && previousPath !== localPath) {
      releaseBlobUrl(previousPath);
    }

    if (part.attachment.localPath === localPath && part.attachment.downloadUrl === (extra.downloadUrl ?? part.attachment.downloadUrl)) {
      return part;
    }

    changed = true;
    return {
      ...part,
      attachment: {
        ...part.attachment,
        localPath,
        downloadUrl: extra.downloadUrl ?? part.attachment.downloadUrl ?? null,
      },
    };
  });

  if (!changed) {
    return;
  }

  let updatedContent = message.content;
  if (typeof message.content === 'object' && message.content) {
    updatedContent = {
      ...message.content,
      localUrl: localPath ?? message.content.localUrl ?? null,
      downloadUrl: extra.downloadUrl ?? message.content.downloadUrl ?? null,
      isUploading: false,
      uploadProgress: 1,
    };
  }

  messages.value[index] = {
    ...message,
    parts: updatedParts,
    content: updatedContent,
    status: message.status === 1 ? 2 : message.status,
  };
};

const ensureAttachmentLocalPath = async (message: Message, part: MessagePart) => {
  const attachment = part.attachment;
  if (!attachment || attachment.localPath) {
    return;
  }

  const { key } = attachment;
  if (!key) {
    return;
  }

  const cached = attachmentUrlCache.get(key);
  if (cached && cached.expiresAt > Date.now()) {
    if (cached.localPath && cached.localPath.startsWith('blob:')) {
      registerBlobUrl(cached.localPath);
    }
    setAttachmentLocalPath(message.id, key, cached.localPath, { downloadUrl: cached.downloadUrl ?? cached.localPath });
    return;
  }

  const roomId = message.roomId || selectedChat.value?.groupId;
  if (!roomId) {
    return;
  }

  let pending = pendingAttachmentDownloads.get(key);
  if (!pending) {
    pending = (async () => {
      try {
        const response = await MessageApi.getAttachmentDownloadUrl({
          groupId: roomId,
          key,
          expiresInSeconds: ATTACHMENT_DOWNLOAD_EXPIRES_SECONDS,
        });

        const payload = response.data;
        if (!response.success || !payload || !payload.downloadUrl) {
          throw new Error(payload?.message || response.message || '获取附件下载链接失败');
        }

        const { localPath, fromBlob } = await downloadAttachmentToLocalUrl(payload.downloadUrl, attachment.mime ?? null);
        if (fromBlob) {
          registerBlobUrl(localPath);
        }
        attachmentUrlCache.set(key, {
          localPath,
          expiresAt: Date.now() + ATTACHMENT_CACHE_TTL_MS,
          downloadUrl: payload.downloadUrl,
        });
        return { localPath, downloadUrl: payload.downloadUrl };
      } catch (error: any) {
        console.error('获取附件本地缓存失败:', error);
        toast.error(error?.message || '图片加载失败');
        return null;
      }
    })();
    pendingAttachmentDownloads.set(key, pending);
  }

  const result = await pending;
  pendingAttachmentDownloads.delete(key);

  if (result) {
    attachmentUrlCache.set(key, {
      localPath: result.localPath,
      expiresAt: Date.now() + ATTACHMENT_CACHE_TTL_MS,
      downloadUrl: result.downloadUrl,
    });
    setAttachmentLocalPath(message.id, key, result.localPath, { downloadUrl: result.downloadUrl });
  }
};

const isMessageUploading = (message: Message): boolean => {
  if (message.status === 1) {
    return true;
  }
  if (typeof message.content === 'object' && message.content) {
    if (message.content.isUploading) {
      return true;
    }
    if (typeof message.content.uploadProgress === 'number' && message.content.uploadProgress < 1) {
      return true;
    }
  }
  if (Array.isArray(message.parts)) {
    return message.parts.some((part) => {
      const progress = part.attachment?.uploadProgress;
      return typeof progress === 'number' && progress < 1;
    });
  }
  return false;
};

const getImageAlt = (message: Message): string => {
  if (typeof message.content === 'object' && message.content) {
    return message.content.name || '图片';
  }
  const text = getTextContent(message);
  return text && text !== '[图片]' ? text : '图片';
};


interface ChatItem {
  id: string
  roomId: string
  name: string
  avatar?: string | null
  lastMessage: string
  time: string
  groupId: string
  memberCount?: number
  unreadCount: number
  isTop: boolean
  isHidden?: boolean
  groupType: number // 0=单聊, 1=群聊
  lastMessageId?: string | null
  chatStatus?: number
  groupNotice?: string | null
  showNoticeFlag?: boolean
  userAvatar?: string | null
  friendName?: string | null
}

interface Message {
  id: string
  content: string | {
    url?: string;
    text?: string;
    name?: string;
    size?: number;
    type?: string;
    localUrl?: string;  // 新增：本地URL字段
    isUploading?: boolean;  // 新增：上传中标记
    fullPath?: string;
    fileName?: string;
    fileSaveTarget?: string;
    key?: string | null;
    thumbnailKey?: string | null;
    mime?: string | null;
    uploadProgress?: number | null;
    downloadUrl?: string | null;
  }
  isSelf: boolean
  time: string
  senderId: string
  senderName: string
  senderAvatar?: string
  messageType: number
  status: number
  createTime?: string  // 原始创建时间
  timestamp?: number   // 时间戳
  contentType?: number // 内容类型：1=文本，2=图片，3=视频等
  isEdited?: boolean
  parts?: MessagePart[]
  roomId?: string
}

const route = useRoute()
const router = useRouter()
const store = useStore()
const selectedChat = ref<ChatItem | null>(null)
const newMessage = ref('')
const searchText = ref('')
const isResizing = ref(false)
const startX = ref(0)
const startWidth = ref(0)

// 搜索功能状态
const showSearchDialog = ref(false)
const availableRoomsForSearch = ref<Array<{ id: string; name: string }>>([])
const availableSendersForSearch = ref<Array<{ id: string; name: string }>>([])

// 表情选择器状态
const showEmojiPicker = ref(false)

// 媒体预览状态
const showMediaPreview = ref(false)
const previewMediaSrc = ref('')
const previewMediaType = ref<'image' | 'video'>('image')
const previewMediaName = ref('')
const previewMediaSize = ref(0)

// 群组创建相关状态
const showGroupNameDialog = ref(false)
const showAddMemberDialog = ref(false)
const newGroupName = ref('')
const isCreatingGroup = ref(false)
const groupNameError = ref('')
const contacts = ref<any[]>([])
const pendingGroupData = ref<any>(null)

// 群设置抽屉状态
const showGroupSettings = ref(false)

// 群成员数据
const groupMembers = ref<RoomMember[]>([])

// 可添加到群的联系人列表(排除已在群里的成员)
const availableContactsForGroup = computed(() => {
  if (!selectedChat.value || selectedChat.value.groupType !== 1) {
    return contacts.value
  }

  // 获取已在群里的成员 ID 列表
  const existingMemberIds = new Set(groupMembers.value.map(member => member.userId))

  // 过滤掉已在群里的联系人
  return contacts.value.filter(contact => !existingMemberIds.has(contact.id))
})

// 群名修改相关状态
const showEditGroupNameDialog = ref(false)
const editingGroupName = ref('')
const isUpdatingGroupName = ref(false)

// 群公告修改相关状态
const showEditGroupNoticeDialog = ref(false)
const editingGroupNotice = ref('')
const isUpdatingGroupNotice = ref(false)

// 语音相关状态
const showVoiceRecorder = ref(false)

// 聊天消息容器引用
const chatMessagesRef = ref<HTMLElement | null>(null)
const messageInput = ref<HTMLTextAreaElement | null>(null)

// 数据状态管理 - 使用store中的数据
const chatList = computed(() => store.getters.chatList)
const messages = ref<Message[]>([])
const loading = computed(() => store.getters.chatListLoading)
const messagesLoading = ref(false)
const currentUserId = computed(() => store.getters.currentUser.id)

watch(
  () => [selectedChat.value?.groupId, messages.value] as [string | undefined | null, Message[]],
  ([groupId, messageList]) => {
    if (!groupId) {
      return
    }
    scheduleMessagesCachePersist(groupId, messageList)
  },
  { deep: true }
)

// 添加本地初始化状态，避免重复加载
const isInitialized = ref(false)

// 新增：跟踪最近发送的消息，用于避免重复
const recentSentMessages = ref<Set<string>>(new Set())

// 最小和最大宽度限制
const minWidth = 300
const maxWidthVw = 70

// 使用 store 中的宽度状态
const chatListWidth = computed({
  get: () => store.getters.sidebarWidth,
  set: (value: number) => store.dispatch('setSidebarWidth', value)
})

// API调用函数 - 优化为使用store持久化
const loadChatList = async (forceRefresh = false) => {
  try {
    console.log('🔄 开始加载聊天列表...', { forceRefresh, isInitialized: isInitialized.value })

    // 如果已经初始化过且不强制刷新，直接返回
    if (isInitialized.value && !forceRefresh) {
      console.log('✅ 聊天列表已初始化，跳过重复加载')
      return
    }

    // 如果不强制刷新且store中有数据，优先从store加载
    if (!forceRefresh && chatList.value.length > 0) {
      console.log('✅ 从store中加载聊天列表:', chatList.value.length, '个聊天')
      isInitialized.value = true
      return
    }

    // 调用store的loadChatList action，传入比对逻辑参数
    await store.dispatch('loadChatList', {
      forceRefresh,
      compareWithStore: true // 启用与store的数据比对
    })

    const roomIds = chatList.value
      .map(chat => chat.groupId)
      .filter((groupId): groupId is string => typeof groupId === 'string' && groupId.length > 0)

    webSocketManager.ensureRoomsSubscribed(roomIds, false)

    isInitialized.value = true
    console.log('✅ 聊天列表加载完成')
  } catch (error: any) {
    console.error('❌ 加载聊天列表失败:', error)
    // 静默处理错误，不显示toast
  }
}

// 发送群公告修改的系统消息（与bear-chat-uniapp保持一致）
const sendGroupNoticeUpdateSystemMessage = async (groupId: string, groupNotice: string) => {
  try {
    const user = store.getters.currentUser
    const timestamp = Date.now()

    console.log('🔄 发送群公告修改系统消息...', { groupId, groupNotice })

    // 构造系统消息对象，参考bear-chat-uniapp的格式
    const systemMessage = {
      id: `${timestamp}`,
      chatGroupId: groupId,
      userId: parseInt(user?.id || currentUserId.value) || 0,
      meFlag: true,
      userName: user?.username || user?.nickname || '用户',
      userAvatar: user?.avatar || '/static/image/default/default-user/default-user.png',
      messageType: MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG,
      contentType: MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE,
      content: {
        text: groupNotice.length > 0 ? '群主发布了新的公告' : '群主作废了群公告', // 根据bear-chat-uniapp的解析规则
        sysMsgType: 'updateGroupNotice', // 系统消息类型
        param: {
          groupId: groupId,
          groupNotice: groupNotice,
          showNoticeFlag: 1
        }
      },
      createTime: getTimeStr(timestamp),
      timestamp: timestamp,
      platFrom: MESSAGE_CONSTANTS.PLATFORM.WEB,
      showTimeFlag: true
    }

    console.log('📤 准备发送的群公告修改系统消息:', systemMessage)

    // 通过WebSocket发送系统消息
    await new Promise((resolve, reject) => {
      webSocketManager.sendMessage(systemMessage, MESSAGE_CONSTANTS.BUSINESS_CODE.chatting, (success: boolean) => {
        if (success) {
          console.log('✅ 群公告修改系统消息发送成功')
          resolve(true)
        } else {
          console.error('❌ 群公告修改系统消息发送失败')
          reject(new Error('系统消息发送失败'))
        }
      })
    })

  } catch (error: any) {
    console.error('❌ 发送群公告修改系统消息失败:', error)
    // 静默处理错误，不影响用户体验
  }
}

// 发送群头像修改的系统消息（与bear-chat-uniapp保持一致）
const sendGroupAvatarUpdateSystemMessage = async (groupId: string, avatarUrl: string) => {
  try {
    const user = store.getters.currentUser
    const timestamp = Date.now()

    console.log('🔄 发送群头像修改系统消息...', { groupId, avatarUrl })

    // 构造系统消息对象，参考bear-chat-uniapp的格式
    const systemMessage = {
      id: `${timestamp}`,
      chatGroupId: groupId,
      userId: parseInt(user?.id || currentUserId.value) || 0,
      meFlag: true,
      userName: user?.username || user?.nickname || '用户',
      userAvatar: user?.avatar || '/static/image/default/default-user/default-user.png',
      messageType: MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG,
      contentType: MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE,
      content: {
        text: `${user?.username || user?.nickname || '用户'}修改群头像`,
        sysMsgType: 'updateGroupAvatar', // 系统消息类型
        param: {
          groupId: groupId,
          groupAvatar: avatarUrl
        }
      },
      createTime: getTimeStr(timestamp),
      timestamp: timestamp,
      platFrom: MESSAGE_CONSTANTS.PLATFORM.WEB,
      showTimeFlag: true
    }

    console.log('📤 准备发送的群头像修改系统消息:', systemMessage)

    // 通过WebSocket发送系统消息
    await new Promise((resolve, reject) => {
      webSocketManager.sendMessage(systemMessage, MESSAGE_CONSTANTS.BUSINESS_CODE.chatting, (success: boolean) => {
        if (success) {
          console.log('✅ 群头像修改系统消息发送成功')
          resolve(true)
        } else {
          console.error('❌ 群头像修改系统消息发送失败')
          reject(new Error('系统消息发送失败'))
        }
      })
    })

  } catch (error: any) {
    console.error('❌ 发送群头像修改系统消息失败:', error)
    // 静默处理错误，不影响用户体验
  }
}

// 加载群组详细信息和成员列表（与bear-chat-uniapp保持一致）
const loadGroupDetailInfo = async (groupId: string) => {
  try {
    console.log('🔄 开始加载群组详细信息:', groupId)

    // 1. 获取群组基本信息
    const groupInfoResponse = await GroupApi.getChatGroupInfo({
      chatGroupId: groupId
    })

    if (groupInfoResponse.success && groupInfoResponse.data) {
      const groupInfo: Chat = groupInfoResponse.data
      const description =
        (groupInfo.extra && typeof groupInfo.extra.description === 'string'
          ? groupInfo.extra.description
          : '') || ''

      console.log('✅ 群组信息获取成功:', {
        id: groupInfo.id,
        name: groupInfo.name,
        description
      })

      if (selectedChat.value) {
        selectedChat.value = {
          ...selectedChat.value,
          roomId: groupInfo.roomId,
          name: groupInfo.name,
          avatar: groupInfo.avatar || selectedChat.value.avatar,
          groupType: groupInfo.type === ChatType.GROUP ? 1 : 0,
          memberCount: groupInfo.memberCount ?? selectedChat.value.memberCount,
          groupNotice: description,
          showNoticeFlag: description.trim().length > 0
        }

        console.log('📋 更新后的selectedChat数据:', {
          name: selectedChat.value.name,
          groupNotice: selectedChat.value.groupNotice,
          showNoticeFlag: selectedChat.value.showNoticeFlag
        })
      }
    }

    // 2. 获取群成员列表
    const membersResponse = await GroupApi.getChatGroupMembers({
      chatGroupId: groupId
    })

    if (membersResponse.success && membersResponse.data) {
      console.log('✅ 群成员列表获取成功:', membersResponse.data)

      // 保存群成员数据
      groupMembers.value = membersResponse.data

      // 更新成员数量
      if (selectedChat.value && membersResponse.data.length) {
        selectedChat.value.memberCount = membersResponse.data.length
      }
    }

  } catch (error: any) {
    console.error('❌ 加载群组详细信息失败:', error)
    // 静默处理错误，不影响聊天功能
  }
}

const loadMessages = async (groupId: string) => {
  let usedCache = false
  try {
    if (!groupId) {
      messages.value = []
      return
    }

    const cached = await loadCache<Message[]>(CACHE_KEYS.messages(groupId))
    if (cached?.data && Array.isArray(cached.data) && cached.data.length > 0) {
      messages.value = cached.data.map((item) => restoreMessageFromCache(item))
      usedCache = true
      console.log('💾 使用缓存的消息列表，数量:', cached.data.length)
    }

    if (!usedCache) {
      messagesLoading.value = true
    }

    console.log('🔄 开始加载群聊消息:', groupId)
    const response = await MessageApi.getMessageListByChatGroupId({
      groupId,
      limit: 50,
      currentUserId: currentUserId.value
    })
    
    if (response.success && response.data) {
      const messageList = Array.isArray(response.data) ? (response.data as DomainMessage[]) : []

      const convertedMessages = messageList.map((msg) => mapDomainMessageToUi(msg))
      
      // 按时间排序：最早的消息在上面，最新的在下面
      // 使用 createTime 或 timestamp 进行排序
      const sortedMessages = convertedMessages.sort((a, b) => {
        // 优先使用 timestamp，如果没有则使用 createTime
        const timeA = a.timestamp || new Date(a.createTime).getTime()
        const timeB = b.timestamp || new Date(b.createTime).getTime()
        return timeA - timeB // 升序排列
      })
      
      messages.value = sortedMessages
      await persistMessagesCache(groupId, sortedMessages)
      
      console.log('✅ 消息加载成功:', messages.value.length, '条消息')
      console.log('📋 消息详情（按时间排序）:', messages.value.map(msg => ({
        id: msg.id,
        content: msg.content,
        isSelf: msg.isSelf,
        senderName: msg.senderName,
        time: msg.time,
        createTime: msg.createTime
      })))

      // 初始化消息搜索索引
      if (messages.value.length > 0 && selectedChat.value) {
        messageSearchService.initializeSearchIndex(messages.value, selectedChat.value.name).catch(error => {
          console.warn('⚠️ 搜索索引初始化失败:', error)
        })
      }
    } else {
      console.warn('❌ 消息加载失败:', response.message)
      messages.value = []
    }
  } catch (error: any) {
    console.error('❌ 消息加载异常:', error)
    messages.value = []
    toast.error('加载消息失败: ' + (error.message || '网络错误'))
  } finally {
    messagesLoading.value = false
  }
}

const resolveAttachmentUrl = (key?: string | null): string => {
  if (!key) return ''
  const trimmed = key.trim()
  if (!trimmed) return ''
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed
  }
  const normalized = trimmed.startsWith('/') ? trimmed.slice(1) : trimmed
  return `${fileConfig.showFile}${normalized}`
}

// 图片和视频URL构建工具函数
const parseImageSrc = (message: Message): string => {
  if (Array.isArray(message.parts)) {
    const imagePart = message.parts.find((part) => part.type === MessagePartType.IMAGE)
    if (imagePart?.attachment) {
      const attachment = imagePart.attachment

      if (attachment.localPath) {
        return attachment.localPath
      }

      if (attachment.key) {
        void ensureAttachmentLocalPath(message, imagePart)
        if (attachment.downloadUrl) {
          return attachment.downloadUrl
        }
        return ''
      }

      const fromThumb = resolveAttachmentUrl(attachment.thumbnailKey)
      if (fromThumb) {
        return fromThumb
      }

      const fromUrl = attachment.downloadUrl
      if (fromUrl) {
        return fromUrl
      }
    }
  }

  if (typeof message.content === 'object' && message.content) {
    const content = message.content as any
    if (content.localUrl) {
      return content.localUrl
    }
    if (content.key) {
      const attachmentPart: MessagePart | undefined = message.parts?.find((part) => part.type === MessagePartType.IMAGE)
      if (attachmentPart) {
        void ensureAttachmentLocalPath(message, attachmentPart)
      }
      if (content.downloadUrl) {
        return content.downloadUrl
      }
      return ''
    }
    if (content.downloadUrl) {
      return content.downloadUrl
    }
    if (content.url) {
      return content.url
    }
    if (content.fullPath && !content.key) {
      const target = content.fileSaveTarget || 'local'
      return target === 'local'
        ? `${fileConfig.showFile}${content.fullPath}`
        : content.fullPath
    }
  }

  return ''
}

const parseVideoScreenShotSrc = (message: Message): string => {
  if (Array.isArray(message.parts)) {
    const videoPart = message.parts.find((part) => part.type === MessagePartType.VIDEO)
    if (videoPart?.attachment?.localPath) {
      return videoPart.attachment.localPath
    }
    if (videoPart?.attachment?.thumbnailKey) {
      const url = resolveAttachmentUrl(videoPart.attachment.thumbnailKey)
      if (url) {
        return url
      }
    }
  }

  if (typeof message.content === 'object' && message.content) {
    const content = message.content as any

    console.log('🎬 parseVideoScreenShotSrc - 解析视频缩略图:', {
      messageId: message.id,
      status: message.status,
      content: content
    })

    // 只处理专门的缩略图字段，不使用视频文件本身
    if (content.screenShot) {
      const target = content.fileSaveTarget || 'local'
      const thumbnailUrl = target === 'local'
        ? `${fileConfig.getFileByPath}${content.screenShot}`
        : content.screenShot
      console.log('✅ 使用视频专用缩略图:', thumbnailUrl)
      return thumbnailUrl
    }

    // 对于没有缩略图的视频，返回空字符串，让模板显示默认占位符
    console.log('ℹ️ 视频消息无专用缩略图，将显示默认占位符')
    return ''
  }

  return ''
}

// 视频URL解析函数 - 专门处理视频文件
const parseVideoSrc = (message: Message): string => {
  if (Array.isArray(message.parts)) {
    const videoPart = message.parts.find((part) => part.type === MessagePartType.VIDEO)
    if (videoPart?.attachment?.localPath) {
      return videoPart.attachment.localPath
    }
    if (videoPart?.attachment?.key) {
      const url = resolveAttachmentUrl(videoPart.attachment.key)
      if (url) {
        return url
      }
    }
  }

  if (typeof message.content === 'object' && message.content) {
    const content = message.content as any

    console.log('🎬 parseVideoSrc - 解析视频URL:', {
      messageId: message.id,
      status: message.status,
      content: content
    })

    // 1. 消息发送成功或历史消息，优先使用服务器地址
    if (message.status === 2 || !message.status) {
      // 优先使用现有的完整 URL
      if (content.url && content.url.trim() !== '' && (content.url.startsWith('http://') || content.url.startsWith('https://'))) {
        console.log('✅ 视频使用完整 URL:', content.url)
        return content.url
      }

      // 使用 fullPath 构建 URL
      if (content.fullPath) {
        const target = content.fileSaveTarget || 'local'
        const serverUrl = target === 'local'
          ? `${fileConfig.showFile}${content.fullPath}`
          : content.fullPath
        console.log('✅ 视频使用 fullPath 构建URL:', serverUrl)
        return serverUrl
      }

      // 处理历史消息：url为空但有fileName的情况
      if (content.fileName && (!content.url || content.url.trim() === '')) {
        const target = content.fileSaveTarget || 'local'
        if (target === 'local') {
          const constructedUrl = `${fileConfig.showFile}chattingFiles/${content.fileName}`
          console.log('✅ 视频历史消息使用 fileName 构建URL:', constructedUrl)
          return constructedUrl
        }
      }
    }

    // 2. 发送中或失败时，使用本地预览
    if (message.status === 1 || message.status === 3) {
      if (content.localUrl) {
        console.log('🔄 视频发送中/失败，使用本地预览:', content.localUrl)
        return content.localUrl
      }

      if (content.url && (content.url.startsWith('blob:') || content.url.startsWith('data:'))) {
        console.log('🔄 视频发送中/失败，使用blob URL:', content.url)
        return content.url
      }
    }

    console.warn('❌ 无法构建视频URL')
    return ''
  }

  return ''
}

// 获取文本内容
const getTextContent = (message: Message): string => {
  if (Array.isArray(message.parts) && message.parts.length > 0) {
    const textPart = message.parts.find((part) => part.type === MessagePartType.TEXT && part.text && part.text.trim() !== '')
    if (textPart?.text) {
      return textPart.text
    }

    const firstPart = message.parts[0]
    switch (firstPart.type) {
      case MessagePartType.IMAGE:
        return '[图片]'
      case MessagePartType.VIDEO:
        return '[视频]'
      case MessagePartType.AUDIO:
        return '[语音]'
      case MessagePartType.FILE:
        return '[文件]'
      default:
        break
    }
  }

  if (typeof message.content === 'string') {
    return message.content
  }

  if (typeof message.content === 'object' && message.content) {
    // 如果是对象，尝试获取text字段
    if ((message.content as any).text) {
      return (message.content as any).text
    }

    // 如果没有text字段，返回JSON字符串（用于调试）
    return JSON.stringify(message.content)
  }

  return ''
}

// 工具函数
const formatTime = (timeStr: string) => {
  if (!timeStr) return ''
  
  const now = new Date()
  const time = new Date(timeStr)
  
  if (isNaN(time.getTime())) return timeStr
  
  const diffMs = now.getTime() - time.getTime()
  const diffMinutes = Math.floor(diffMs / (1000 * 60))
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60))
  const diffDays = Math.floor(diffHours / 24)
  
  if (diffMinutes < 1) {
    return '刚刚'
  } else if (diffMinutes < 60) {
    return `${diffMinutes}分钟前`
  } else if (diffHours < 24) {
    return time.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
  } else if (diffDays === 1) {
    return '昨天'
  } else if (diffDays < 7) {
    return `${diffDays}天前`
  } else {
    return time.toLocaleDateString('zh-CN', { month: 'short', day: 'numeric' })
  }
}

const cloneMessageParts = (parts?: MessagePart[]): MessagePart[] | undefined => {
  if (!Array.isArray(parts)) {
    return undefined
  }
  return parts.map((part) => {
    let attachmentCopy = part.attachment ? { ...part.attachment } : part.attachment ?? null
    if (attachmentCopy && attachmentCopy.key) {
      const cached = attachmentUrlCache.get(attachmentCopy.key)
      if (cached && cached.expiresAt > Date.now()) {
        if (!attachmentCopy.localPath && cached.localPath) {
          attachmentCopy.localPath = cached.localPath
          if (cached.localPath.startsWith('blob:')) {
            registerBlobUrl(cached.localPath)
          }
        }
        if (!attachmentCopy.downloadUrl && cached.downloadUrl) {
          attachmentCopy.downloadUrl = cached.downloadUrl
        }
      }
    }
    return {
      ...part,
      attachment: attachmentCopy,
    }
  })
}

const buildMessageContentFromParts = (
  parts: MessagePart[] | undefined,
  incomingContent: Message['content'],
  existingContent?: Message['content'],
): Message['content'] => {
  const cloneContent = (value: Message['content']) => (
    value && typeof value === 'object' ? { ...value } : value
  )

  const primaryAttachmentPart = parts?.find((part) =>
    part.type !== MessagePartType.TEXT && part.attachment,
  )

  if (primaryAttachmentPart?.attachment) {
    const attachment = primaryAttachmentPart.attachment
    const base = (
      (existingContent && typeof existingContent === 'object' ? { ...existingContent } : null)
      ?? (incomingContent && typeof incomingContent === 'object' ? { ...incomingContent } : null)
      ?? {}
    ) as Record<string, any>

    const uploadProgress = base.uploadProgress ?? attachment.uploadProgress ?? null

    return {
      ...base,
      name: base.name ?? attachment.name ?? (typeof incomingContent === 'string' ? incomingContent : null),
      size: base.size ?? attachment.size ?? null,
      type: base.type ?? primaryAttachmentPart.type,
      localUrl: base.localUrl ?? attachment.localPath ?? null,
      key: base.key ?? attachment.key ?? null,
      thumbnailKey: base.thumbnailKey ?? attachment.thumbnailKey ?? null,
      mime: base.mime ?? attachment.mime ?? null,
      downloadUrl: base.downloadUrl ?? attachment.downloadUrl ?? null,
      uploadProgress,
      isUploading: typeof uploadProgress === 'number' ? uploadProgress < 1 : Boolean(base.isUploading),
    }
  }

  const textPart = parts?.find((part) => part.type === MessagePartType.TEXT && part.text)
  if (textPart?.text) {
    return textPart.text
  }

  if (incomingContent !== undefined) {
    return cloneContent(incomingContent)
  }

  if (existingContent !== undefined) {
    return cloneContent(existingContent)
  }

  return ''
}

const resolveContentTypeFromParts = (parts: MessagePart[] | undefined, fallback: number): number => {
  if (!parts || parts.length === 0) {
    return fallback
  }

  const typePriority: Array<{ type: MessagePartType; contentType: number }> = [
    { type: MessagePartType.IMAGE, contentType: MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE },
    { type: MessagePartType.VIDEO, contentType: MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE },
    { type: MessagePartType.AUDIO, contentType: MESSAGE_CONSTANTS.CONTENT_TYPE.AUDIO_CONTENT_TYPE },
    { type: MessagePartType.FILE, contentType: MESSAGE_CONSTANTS.CONTENT_TYPE.FILE_CONTENT_TYPE },
  ]

  for (const { type, contentType } of typePriority) {
    if (parts.some((part) => part.type === type)) {
      return contentType
    }
  }

  return fallback
}

const mapDomainMessageToUi = (msg: DomainMessage): Message => {
  const timestamp = msg.timestamp instanceof Date ? msg.timestamp : new Date(msg.timestamp)
  const messageType = msg.type === MessageType.SYSTEM
    ? MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG
    : MESSAGE_CONSTANTS.MSG_TYPE.USER_MSG
  const parts = cloneMessageParts(msg.parts)
  const normalizedContent = buildMessageContentFromParts(parts, msg.content as any)
  const baseContentType = messageTypeToContentType[msg.type] || MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE
  const resolvedContentType = resolveContentTypeFromParts(parts, baseContentType)

  return {
    id: msg.id,
    content: normalizedContent,
    isSelf: msg.isSelf,
    time: formatTime(timestamp.toISOString()),
    senderId: msg.senderId,
    senderName: msg.senderName,
    senderAvatar: msg.senderAvatar || '',
    messageType,
    contentType: resolvedContentType,
    status: messageStatusToUiStatus[msg.status] || 2,
    createTime: timestamp.toISOString(),
    timestamp: timestamp.getTime(),
    isEdited: !!(msg.extra && (msg.extra as Record<string, unknown>).edited),
    parts,
    roomId: msg.roomId,
  }
}

const mergeMessagePreservingLocalData = (existing: Message, incoming: Message): Message => {
  const incomingParts = cloneMessageParts(incoming.parts)
  const existingParts = cloneMessageParts(existing.parts)

  const allParts = (incomingParts && incomingParts.length > 0 ? incomingParts : existingParts) ?? []

  const identifyPart = (part: MessagePart) => {
    if (part.attachment?.key) {
      return `key:${part.attachment.key}`
    }
    return `type:${part.type}|pos:${part.position ?? 0}`
  }

  const mergedParts = allParts.length > 0
    ? allParts.map((part) => {
        if (!part.attachment) {
          return part
        }

        const identity = identifyPart(part)
        const incomingAttachment = incomingParts?.find((p) => identifyPart(p) === identity)?.attachment
        const existingAttachment = existingParts?.find((p) => identifyPart(p) === identity)?.attachment

        const localPath = existingAttachment?.localPath
          ?? incomingAttachment?.localPath
          ?? part.attachment.localPath
          ?? null

        const downloadUrl = existingAttachment?.downloadUrl
          ?? incomingAttachment?.downloadUrl
          ?? part.attachment.downloadUrl
          ?? null

        const uploadProgress = incomingAttachment?.uploadProgress
          ?? existingAttachment?.uploadProgress
          ?? part.attachment.uploadProgress
          ?? null

        return {
          ...part,
          attachment: {
            ...part.attachment,
            localPath,
            downloadUrl,
            uploadProgress,
          },
        }
      })
    : undefined

  const mergedContent = buildMessageContentFromParts(
    mergedParts,
    incoming.content,
    existing.content,
  )

  const fallbackContentType = existing.contentType
    ?? incoming.contentType
    ?? MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE

  const mergedContentType = resolveContentTypeFromParts(
    mergedParts,
    fallbackContentType,
  )

  return {
    ...existing,
    ...incoming,
    content: mergedContent,
    contentType: mergedContentType,
    parts: mergedParts,
    roomId: incoming.roomId ?? existing.roomId,
  }
}

// 时间戳转化为日期字符串 - 与bear-chat-uniapp保持一致
const getTimeStr = (timestamp: number, type?: string) => {
  let _data = timestamp
  // 如果是13位正常，如果是10位则需要转化为毫秒
  if (String(timestamp).length === 13) {
    _data = timestamp
  } else {
    _data = timestamp * 1000
  }
  
  const time = new Date(_data)
  const Y = time.getFullYear()
  const Mon = time.getMonth() + 1 < 10 ? '0' + (time.getMonth() + 1) : time.getMonth() + 1
  const Day = time.getDate() < 10 ? '0' + time.getDate() : time.getDate()
  const H = time.getHours() < 10 ? '0' + time.getHours() : time.getHours()
  const Min = time.getMinutes() < 10 ? '0' + time.getMinutes() : time.getMinutes()
  const S = time.getSeconds() < 10 ? '0' + time.getSeconds() : time.getSeconds()
  
  // 自定义选择想要返回的类型
  if (type === "Y") {
    return `${Y}-${Mon}-${Day}`
  } else if (type === "H") {
    return `${H}:${Min}:${S}`
  } else if (type === "M") {
    return `${H}:${Min}`
  } else {
    return `${Y}-${Mon}-${Day} ${H}:${Min}:${S}`
  }
}

// 格式化消息时间显示
const formatMessageTime = (timeStr: string) => {
  if (!timeStr) return ''

  const messageTime = new Date(timeStr)
  const now = new Date()

  if (isNaN(messageTime.getTime())) return timeStr

  // 判断是否为今天
  const isToday = messageTime.toDateString() === now.toDateString()
  // 判断是否为今年
  const isThisYear = messageTime.getFullYear() === now.getFullYear()

  if (isToday) {
    // 今天只显示时间 HH:MM
    return messageTime.toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    })
  } else if (isThisYear) {
    // 今年但不是今天显示月日时间 MM-DD HH:MM
    const month = String(messageTime.getMonth() + 1).padStart(2, '0')
    const day = String(messageTime.getDate()).padStart(2, '0')
    const hour = String(messageTime.getHours()).padStart(2, '0')
    const minute = String(messageTime.getMinutes()).padStart(2, '0')

    return `${month}-${day} ${hour}:${minute}`
  } else {
    // 不是今年显示完整时间 YYYY-MM-DD HH:MM
    const year = messageTime.getFullYear()
    const month = String(messageTime.getMonth() + 1).padStart(2, '0')
    const day = String(messageTime.getDate()).padStart(2, '0')
    const hour = String(messageTime.getHours()).padStart(2, '0')
    const minute = String(messageTime.getMinutes()).padStart(2, '0')

    return `${year}-${month}-${day} ${hour}:${minute}`
  }
}

// 滚动到底部函数
const scrollToBottom = (force = false) => {
  if (chatMessagesRef.value) {
    const scroll = () => {
      if (chatMessagesRef.value) {
        chatMessagesRef.value.scrollTop = chatMessagesRef.value.scrollHeight
      }
    }

    // 立即滚动一次
    scroll()

    // 延迟滚动，等待DOM更新
    setTimeout(scroll, 50)

    // 如果强制滚动或有图片消息，额外延迟确保图片加载完成
    if (force || messages.value.some(msg =>
      msg.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE ||
      msg.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE
    )) {
      setTimeout(scroll, 200)
      setTimeout(scroll, 500) // 给图片更多加载时间
    }
  }
}

// 专门用于图片加载完成后的滚动
const scrollToBottomAfterImageLoad = () => {
  scrollToBottom(true)
}

// 监听消息变化，自动滚动到底部
watch(messages, () => {
  scrollToBottom()
}, { flush: 'post' }) // flush: 'post' 确保DOM更新后执行

const selectChat = async (chat: ChatItem) => {
  selectedChat.value = chat
  store.commit('SET_CURRENT_CHAT_GROUP_ID', chat.groupId)
  webSocketManager.joinRoom(chat.groupId)

  // 如果是群聊，获取群组详细信息和成员列表
  if (chat.groupType === 1) {
    await loadGroupDetailInfo(chat.groupId)
  }

  // 先立即更新本地UI，避免等待API响应
  if (chat.unreadCount > 0) {
    // 立即更新store中的聊天数据
    const updatedChat = { ...chat, unreadCount: 0 }
    store.dispatch('updateChatItem', updatedChat)

    // 异步调用API更新服务器状态
    markChatAsRead(chat).catch(error => {
      console.error('标记已读失败，回滚本地状态:', error)
      // 如果API调用失败，回滚本地状态
      store.dispatch('updateChatItem', chat)
    })
  }

  await loadMessages(chat.groupId)

  // 选择聊天后滚动到底部
  scrollToBottom()
}

// 标记聊天为已读状态
const markChatAsRead = async (chat: ChatItem) => {
  try {
    const currentUser = store.getters.currentUser
    console.log('🔄 标记聊天为已读:', {
      chatName: chat.name,
      chatId: chat.id,
      groupId: chat.groupId,
      currentUnreadCount: chat.unreadCount,
      userId: currentUser?.id,
      currentTime: getTimeStr(Date.now())
    })
    
    if (!currentUser?.id) {
      console.warn('❌ 用户信息缺失，无法标记已读')
      return
    }
    
    if (!chat.groupId) {
      console.warn('❌ 群组ID为空，无法标记已读:', {
        chat: chat,
        chatId: chat.id,
        groupId: chat.groupId
      })
      toast.error('群组ID为空，无法标记已读')
      return
    }
    
    if (!chat.lastMessageId) {
      console.warn('⚠️ 未找到最新消息 ID，跳过远端标记已读')
      return
    }

    console.log('📤 发送标记已读请求:', {
      groupId: chat.groupId,
      lastMessageId: chat.lastMessageId
    })

    const response = await MessageApi.markMessagesAsRead({
      groupId: chat.groupId,
      messageIds: [chat.lastMessageId]
    })

    if (response.success) {
      const updatedChat = { ...chat, unreadCount: 0 }
      store.dispatch('updateChatItem', updatedChat)
      console.log('✅ 聊天已标记为已读:', chat.name)
    } else {
      console.warn('❌ 标记聊天已读失败:', response.message)
      toast.error('标记已读失败: ' + (response.message || '未知错误'))
    }
  } catch (error: any) {
    console.error('❌ 标记聊天已读异常:', error)
    toast.error('标记已读失败: ' + (error.message || '网络错误'))
  }
}

// 处理输入框键盘事件
const handleInputKeydown = (event: KeyboardEvent) => {
  if (event.key === 'Enter') {
    if (event.shiftKey) {
      // Shift + Enter 换行，不阻止默认行为
      return
    } else {
      // 单独 Enter 发送消息
      event.preventDefault()
      sendMessage()
    }
  }
}

// 自动调整textarea高度
const adjustTextareaHeight = () => {
  if (messageInput.value) {
    // 重置高度以获取正确的 scrollHeight
    messageInput.value.style.height = 'auto'
    // 设置新高度，限制在20px到100px之间
    const newHeight = Math.max(20, Math.min(messageInput.value.scrollHeight, 100))
    messageInput.value.style.height = newHeight + 'px'
  }
}

// 监听消息输入变化，自动调整高度
watch(newMessage, () => {
  setTimeout(adjustTextareaHeight, 0)
})

const sendMessage = async () => {
  if (!newMessage.value.trim() || !selectedChat.value) {
    return
  }

  const content = newMessage.value.trim()
  const groupId = selectedChat.value.groupId
  const timestamp = Date.now()
  const tempId = `${timestamp}`
  const user = store.getters.currentUser

  const tempMessage: Message = {
    id: tempId,
    content,
    isSelf: true,
    time: formatTime(getTimeStr(timestamp)),
    senderId: currentUserId.value || '',
    senderName: user?.nickname || user?.username || '我',
    senderAvatar: user?.avatar,
    messageType: MESSAGE_CONSTANTS.MSG_TYPE.USER_MSG,
    status: 1,
    createTime: getTimeStr(timestamp),
    timestamp
  }

  console.log('📤 [sendMessage] 添加临时消息:', { tempId, content })
  messages.value.push(tempMessage)
  newMessage.value = ''
  scrollToBottom()

  try {
    const apiMessage = await webSocketManager.sendMessage({
      roomId: groupId,
      content,
    }, MESSAGE_CONSTANTS.BUSINESS_CODE.chatting)

    if (apiMessage) {
      const uiMessage = mapDomainMessageToUi(apiMessage)
      console.log('📥 [sendMessage] API 返回:', { 
        realId: apiMessage.id, 
        tempId, 
        recentSentMessages: Array.from(recentSentMessages.value),
        messagesCount: messages.value.length,
        messageIds: messages.value.map(m => m.id)
      })
      
      // 先检查是否已经存在真实消息（可能 WebSocket 先到达）
      const existingRealMessageIndex = messages.value.findIndex(msg => msg.id === apiMessage.id)
      if (existingRealMessageIndex !== -1) {
        console.log('✅ [sendMessage] 真实消息已存在，更新状态:', existingRealMessageIndex)
        // 如果真实消息已存在，更新状态即可，不需要重复添加
        messages.value[existingRealMessageIndex] = {
          ...messages.value[existingRealMessageIndex],
          status: 2
        }
        // 添加到 recentSentMessages 用于去重
        recentSentMessages.value.add(apiMessage.id)
        setTimeout(() => {
          recentSentMessages.value.delete(apiMessage.id)
        }, 10000)
        return // 消息已存在，直接返回
      }
      
      // 查找临时消息并替换
      // 注意：临时消息可能已经被 WebSocket 替换为真实消息 ID，所以需要同时检查 tempId 和真实消息 ID
      let messageIndex = messages.value.findIndex(msg => msg.id === tempId)
      console.log('🔍 [sendMessage] 查找临时消息:', { tempId, found: messageIndex !== -1 })
      
      // 如果找不到 tempId，可能是已经被 WebSocket 替换了，检查真实消息 ID
      if (messageIndex === -1) {
        messageIndex = messages.value.findIndex(msg => msg.id === apiMessage.id)
        console.log('🔍 [sendMessage] 临时消息不存在，查找真实消息ID:', { realId: apiMessage.id, found: messageIndex !== -1 })
      }
      
      if (messageIndex !== -1) {
        console.log('✅ [sendMessage] 找到消息，替换为真实消息:', messageIndex)
        // 找到消息，更新为真实消息（确保状态为2，移除转圈圈）
        messages.value[messageIndex] = {
          ...uiMessage,
          status: 2
        }
        // 立即添加到 recentSentMessages，防止 WebSocket 消息重复添加
        recentSentMessages.value.add(apiMessage.id)
        setTimeout(() => {
          recentSentMessages.value.delete(apiMessage.id)
        }, 10000)
        console.log('✅ [sendMessage] 消息已替换，添加到 recentSentMessages:', apiMessage.id)
        return // 消息已更新，直接返回，避免后续重复处理
      } else {
        console.log('⚠️ [sendMessage] 消息不存在，检查 recentSentMessages:', { 
          hasInRecent: recentSentMessages.value.has(apiMessage.id),
          recentSentMessages: Array.from(recentSentMessages.value)
        })
        // 如果消息不存在，检查是否应该添加
        // 只有在 recentSentMessages 中没有时才添加（避免 WebSocket 消息已添加的情况）
        if (!recentSentMessages.value.has(apiMessage.id)) {
          console.log('➕ [sendMessage] 添加新消息到列表')
          messages.value.push({
            ...uiMessage,
            status: 2
          })
        } else {
          console.log('⏭️ [sendMessage] recentSentMessages 中已有，跳过添加')
        }
        // 添加到 recentSentMessages 用于去重
        recentSentMessages.value.add(apiMessage.id)
        setTimeout(() => {
          recentSentMessages.value.delete(apiMessage.id)
        }, 10000)
      }
    }
  } catch (error: any) {
    const messageIndex = messages.value.findIndex(msg => msg.id === tempId)
    if (messageIndex !== -1) {
      messages.value[messageIndex].status = 3
    }
    console.error('❌ 消息发送失败:', error)
    toast.error('消息发送失败: ' + (error.message || '网络错误'))
  }
}

// 重发消息功能
const resendMessage = async (message: Message) => {
  if (!selectedChat.value) {
    return
  }

  console.log('🔄 重发消息:', message.content)

  const messageIndex = messages.value.findIndex(msg => msg.id === message.id)
  if (messageIndex !== -1) {
    messages.value[messageIndex].status = 1
  }

  if (Array.isArray(message.parts) && message.parts.length > 0) {
    toast.error('文件消息暂不支持重发，请重新选择文件发送')
    if (messageIndex !== -1) {
      messages.value[messageIndex].status = 3
    }
    return
  }

  const messageContent = typeof message.content === 'string'
    ? message.content
    : (message.content as any)?.text || getTextContent(message)

  if (!messageContent) {
    toast.error('无法获取消息内容，重发失败')
    if (messageIndex !== -1) {
      messages.value[messageIndex].status = 3
    }
    return
  }

  try {
    const apiMessage = await webSocketManager.sendMessage({
      roomId: selectedChat.value.groupId,
      content: messageContent,
    }, MESSAGE_CONSTANTS.BUSINESS_CODE.chatting)

    if (apiMessage) {
      const uiMessage = mapDomainMessageToUi(apiMessage)
      if (messageIndex !== -1) {
        messages.value[messageIndex] = {
          ...uiMessage,
          status: 2
        }
      }

      recentSentMessages.value.add(apiMessage.id)
      setTimeout(() => {
        recentSentMessages.value.delete(apiMessage.id)
      }, 10000)
    }
  } catch (error: any) {
    if (messageIndex !== -1) {
      messages.value[messageIndex].status = 3
    }
    console.error('❌ 消息重发失败:', error)
    toast.error('消息重发失败: ' + (error.message || '网络错误'))
  }
}

const handleSearch = (value: string) => {
  console.log('搜索聊天:', value)
  if (value.trim()) {
    showSearchDialog.value = true
  }
}

const handleSearchFocus = () => {
  // 准备搜索数据
  prepareSearchData()
}

const handleSearchResultClick = (result: any) => {
  // 点击搜索结果时，切换到对应的聊天
  if (result.roomId && result.roomId !== selectedChat.value?.groupId) {
    const chat = chatList.value.find(c => c.groupId === result.roomId)
    if (chat) {
      selectChat(chat)
    }
  }

  // 滚动到对应的消息
  setTimeout(() => {
    const messageElement = document.querySelector(`[data-message-id="${result.id}"]`)
    if (messageElement) {
      messageElement.scrollIntoView({ behavior: 'smooth', block: 'center' })
      // 高亮显示
      messageElement.classList.add('search-highlighted')
      setTimeout(() => {
        messageElement.classList.remove('search-highlighted')
      }, 2000)
    }
  }, 100)
}

const prepareSearchData = () => {
  // 准备可用的房间列表
  availableRoomsForSearch.value = chatList.value.map(chat => ({
    id: chat.groupId,
    name: chat.name
  }))

  // 准备可用的发送者列表（从当前消息中提取）
  const senders = new Set<string>()
  const senderMap = new Map<string, string>()

  messages.value.forEach(msg => {
    if (!senders.has(msg.senderId)) {
      senders.add(msg.senderId)
      senderMap.set(msg.senderId, msg.senderName || msg.senderUsername)
    }
  })

  availableSendersForSearch.value = Array.from(senders).map(senderId => ({
    id: senderId,
    name: senderMap.get(senderId) || senderId
  }))
}

// 处理表情点击
const handleEmojiClick = () => {
  console.log('点击表情按钮')
  showEmojiPicker.value = !showEmojiPicker.value
}

// 处理表情选择
const handleEmojiSelect = (emoji: string) => {
  console.log('选择表情:', emoji)

  // 将表情插入到当前光标位置
  if (messageInput.value) {
    const textarea = messageInput.value
    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const before = newMessage.value.substring(0, start)
    const after = newMessage.value.substring(end)

    newMessage.value = before + emoji + after

    // 恢复光标位置
    setTimeout(() => {
      if (textarea) {
        const newPosition = start + emoji.length
        textarea.setSelectionRange(newPosition, newPosition)
        textarea.focus()
      }
    }, 0)
  } else {
    // 如果没有输入框引用，直接添加到末尾
    newMessage.value += emoji
  }

  // 自动调整输入框高度
  setTimeout(adjustTextareaHeight, 0)
}

// 处理表情选择器关闭
const handleEmojiClose = () => {
  showEmojiPicker.value = false
}

// 点击外部关闭表情选择器
const handleClickOutside = (event: Event) => {
  if (showEmojiPicker.value) {
    const target = event.target as Element
    // 检查点击是否在表情选择器或表情按钮内
    const emojiPicker = document.querySelector('.emoji-picker')
    const emojiIcon = document.querySelector('.emoji-icon')

    if (emojiPicker && !emojiPicker.contains(target) &&
        emojiIcon && !emojiIcon.contains(target)) {
      showEmojiPicker.value = false
    }
  }
}

// 处理图片预览
const handleImagePreview = (imageUrl: string, message?: Message) => {
  console.log('预览图片:', imageUrl)
  if (imageUrl) {
    previewMediaSrc.value = imageUrl
    previewMediaType.value = 'image'

    // 如果有消息对象，提取媒体信息
    if (message && typeof message.content === 'object' && message.content) {
      previewMediaName.value = message.content.name || '图片'
      previewMediaSize.value = message.content.size || 0
    } else {
      previewMediaName.value = '图片'
      previewMediaSize.value = 0
    }

    showMediaPreview.value = true
  } else {
    toast.error('图片地址无效')
  }
}

// 关闭媒体预览
const closeMediaPreview = () => {
  showMediaPreview.value = false
  previewMediaSrc.value = ''
  previewMediaName.value = ''
  previewMediaSize.value = 0
}

// 处理图片加载错误
const handleImageError = (event: Event) => {
  const img = event.target as HTMLImageElement
  console.error('图片加载失败:', img.src)
}

// 处理视频缩略图加载错误
const handleVideoThumbnailError = (event: Event) => {
  const img = event.target as HTMLImageElement
  console.error('视频缩略图加载失败:', img.src)
  // 隐藏缩略图，显示默认视频图标
  const thumbnailWrapper = img.closest('.video-thumbnail-wrapper') as HTMLElement
  if (thumbnailWrapper) {
    thumbnailWrapper.style.display = 'none'
    const placeholder = thumbnailWrapper.parentElement?.querySelector('.video-placeholder') as HTMLElement
    if (placeholder) {
      placeholder.style.display = 'flex'
    }
  }
}

// 格式化文件大小
const formatFileSize = (bytes: number): string => {
  if (bytes === 0) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

// 处理视频播放
const handleVideoPlay = (message: Message) => {
  const videoSrc = parseVideoSrc(message)
  console.log('播放视频:', videoSrc)
  if (videoSrc) {
    // 设置媒体信息并显示预览
    previewMediaSrc.value = videoSrc
    previewMediaType.value = 'video'
    if (typeof message.content === 'object' && message.content) {
      previewMediaName.value = message.content.name || '视频文件'
      previewMediaSize.value = message.content.size || 0
    }
    showMediaPreview.value = true
  } else {
    toast.error('视频地址无效')
  }
}

// 处理上传点击
const handleUploadClick = () => {
  console.log('点击上传按钮')
  // 创建文件输入元素
  const input = document.createElement('input')
  input.type = 'file'
  input.accept = 'image/*,video/*'
  input.multiple = true
  input.onchange = handleFileUpload
  input.click()
}

// 处理文件上传
const handleFileUpload = async (event: Event) => {
  const target = event.target as HTMLInputElement
  const files = target.files

  if (!files || files.length === 0) {
    return
  }

  for (let i = 0; i < files.length; i++) {
    const file = files[i]
    await uploadAndSendFile(file)
  }
}

// 图片预缓存管理
const imagePreloadCache = ref<Map<string, HTMLImageElement>>(new Map())

// 预加载图片并缓存
const preloadImage = (url: string): Promise<void> => {
  return new Promise((resolve, reject) => {
    if (imagePreloadCache.value.has(url)) {
      resolve() // 已缓存，直接返回
      return
    }

    const img = new Image()
    img.onload = () => {
      imagePreloadCache.value.set(url, img)
      console.log('✅ 图片预加载完成:', url)
      resolve()
    }
    img.onerror = () => {
      console.warn('❌ 图片预加载失败:', url)
      reject(new Error('图片预加载失败'))
    }
    img.src = url
  })
}

// 上传并发送文件
const uploadAndSendFile = async (file: File) => {
  if (!selectedChat.value) {
    toast.error('请先选择聊天对象')
    return
  }

  let tempId: string | null = null
  let attachmentKey = ''
  let localUrl: string | null = null

  try {
    const meta = await determineAttachmentMeta(file)

    if (meta.partType === 'text') {
      toast.error('当前文件类型暂不支持发送')
      return
    }

    const sizeLimitMap: Record<Exclude<MessagePartPayloadInput['type'], 'text'>, number> = {
      image: 5 * 1024 * 1024,
      video: 50 * 1024 * 1024,
      audio: 50 * 1024 * 1024,
      file: 100 * 1024 * 1024,
    }
    const limit = sizeLimitMap[meta.partType] ?? 50 * 1024 * 1024
    if (file.size > limit) {
      toast.error(`文件大小不能超过${meta.partType === 'image' ? '5MB' : meta.partType === 'video' ? '50MB' : '100MB'}`)
      return
    }

    const signatureResponse = await MessageApi.requestAttachmentSignature({
      groupId: selectedChat.value.groupId,
      partType: meta.partType,
      fileName: file.name,
      contentType: meta.mime,
    })

    if (!signatureResponse.success || !signatureResponse.data) {
      throw new Error(signatureResponse.message || '获取上传签名失败')
    }

    attachmentKey = signatureResponse.data.key
    localUrl = URL.createObjectURL(file)
    registerBlobUrl(localUrl)
    const timestamp = Date.now()
    tempId = `upload_${timestamp}_${Math.random().toString(36).slice(2, 8)}`
    const user = store.getters.currentUser
    const placeholderPart = buildPlaceholderPart(meta, attachmentKey, file, localUrl)
    const contentTypeCode = partTypeContentMap[meta.partType as keyof typeof partTypeContentMap] ?? MESSAGE_CONSTANTS.CONTENT_TYPE.FILE_CONTENT_TYPE

    const placeholderContent = {
      name: file.name,
      size: file.size,
      type: meta.partType,
      localUrl,
      isUploading: true,
      uploadProgress: 0,
      key: attachmentKey,
      thumbnailKey: placeholderPart.attachment?.thumbnailKey ?? null,
      mime: meta.mime,
    };

    const tempMessage: Message = {
      id: tempId,
      content: placeholderContent,
      isSelf: true,
      time: formatTime(getTimeStr(timestamp)),
      senderId: currentUserId.value || '',
      senderName: user?.nickname || user?.username || '我',
      senderAvatar: user?.avatar,
      messageType: MESSAGE_CONSTANTS.MSG_TYPE.USER_MSG,
      contentType: contentTypeCode,
      status: 1,
      createTime: getTimeStr(timestamp),
      timestamp,
      parts: [placeholderPart],
      roomId: selectedChat.value.groupId,
    }

    messages.value.push(tempMessage)
    scrollToBottom()

    await uploadWithSignature(signatureResponse.data.signature, file, (progress) => {
      if (tempId) {
        updateAttachmentProgress(tempId, attachmentKey, progress)
      }
    })

    if (tempId) {
      updateAttachmentProgress(tempId, attachmentKey, null)
    }

    const apiMessage = await webSocketManager.sendMessage({
      roomId: selectedChat.value.groupId,
      content: meta.summary,
      parts: [buildAttachmentPartPayload(meta, attachmentKey, file)],
    }, MESSAGE_CONSTANTS.BUSINESS_CODE.chatting)

    if (apiMessage) {
      const uiMessage = mapDomainMessageToUi(apiMessage)
      if (tempId) {
        const messageIndex = messages.value.findIndex((msg) => msg.id === tempId)
        if (messageIndex !== -1) {
          const localMessage = messages.value[messageIndex]
          const mergedMessage = mergeMessagePreservingLocalData(localMessage, {
            ...uiMessage,
            status: 2,
            roomId: uiMessage.roomId ?? selectedChat.value.groupId,
          })

          if (typeof mergedMessage.content === 'object' && mergedMessage.content) {
            mergedMessage.content.isUploading = false
            mergedMessage.content.uploadProgress = 1
          }

          messages.value[messageIndex] = mergedMessage
        } else {
          messages.value.push({
            ...uiMessage,
            status: 2,
            roomId: uiMessage.roomId ?? selectedChat.value.groupId,
          })
        }
      } else {
        messages.value.push({
          ...uiMessage,
          status: 2,
          roomId: uiMessage.roomId ?? selectedChat.value.groupId,
        })
      }

      recentSentMessages.value.add(apiMessage.id)
      setTimeout(() => {
        recentSentMessages.value.delete(apiMessage.id)
      }, 10000)
    }

    scrollToBottom()
  } catch (error: any) {
    console.error('文件上传或发送失败:', error)
    if (tempId) {
      const messageIndex = messages.value.findIndex((msg) => msg.id === tempId)
      if (messageIndex !== -1) {
        messages.value[messageIndex].status = 3
        updateAttachmentProgress(tempId, attachmentKey, null)
      }
    }
    toast.error('文件发送失败: ' + (error.message || '网络错误'))
  }
}

const handleCreateGroup = async () => {
  console.log('🔄 用户点击创建群组...')

  // 重置状态
  newGroupName.value = ''
  groupNameError.value = ''

  // 显示群名输入对话框
  showGroupNameDialog.value = true
}

// 处理群头像修改
const handleEditGroupAvatar = () => {
  if (!selectedChat.value) return

  console.log('🔄 打开群头像修改功能')

  // 创建文件输入元素用于选择头像
  const input = document.createElement('input')
  input.type = 'file'
  input.accept = 'image/*'
  input.onchange = async (event) => {
    const target = event.target as HTMLInputElement
    const file = target.files?.[0]

    if (file) {
      await updateGroupAvatar(file)
    }
  }
  input.click()
}

// 更新群头像
const updateGroupAvatar = async (file: File) => {
  if (!selectedChat.value) return

  try {
    console.log('🔄 开始上传群头像:', file.name)

    // 先上传文件
    const { FileApi } = await import('../api/file')
    const uploadResult = await FileApi.uploadFile({
      file,
      category: 'avatar',
      isPublic: true,
      description: '群头像'
    })

    if (uploadResult.code === 200 && uploadResult.data) {
      const avatarUrl = FileApi.buildImageUrl(uploadResult.data)

      if (!avatarUrl) {
        throw new Error('头像URL构建失败')
      }

      console.log('✅ 头像上传成功，开始更新群信息:', avatarUrl)

      // 调用更新群信息API
      const response = await GroupApi.updateGroupInfo({
        groupId: selectedChat.value.groupId,
        groupAvatar: avatarUrl  // 修正：使用 groupAvatar
      })

      if (response.success) {
        console.log('✅ 群头像修改成功')
        toast.success('群头像修改成功')

        // 更新本地数据
        if (selectedChat.value) {
          selectedChat.value.avatar = avatarUrl

          // 更新store中的聊天列表
          const updatedChat = { ...selectedChat.value, avatar: avatarUrl }
          store.dispatch('updateChatItem', updatedChat)
        }

        // 发送群头像修改的系统消息（与bear-chat-uniapp保持一致）
        await sendGroupAvatarUpdateSystemMessage(selectedChat.value.groupId, avatarUrl)
      } else {
        console.warn('❌ 群头像修改失败:', response.message)
        toast.error('群头像修改失败: ' + (response.message || '未知错误'))
      }
    } else {
      throw new Error(uploadResult.message || '头像上传失败')
    }
  } catch (error: any) {
    console.error('❌ 群头像修改异常:', error)
    toast.error('群头像修改失败: ' + (error.message || '网络错误'))
  }
}

// 处理群公告修改
const handleEditGroupNotice = () => {
  if (!selectedChat.value) return

  console.log('🔄 打开群公告修改弹窗')

  // 设置当前群公告作为默认值（如果有的话）
  editingGroupNotice.value = selectedChat.value.groupNotice || ''
  groupNameError.value = ''

  // 关闭群设置抽屉，打开群公告修改弹窗
  showGroupSettings.value = false
  showEditGroupNoticeDialog.value = true
}

// 确认修改群公告
const handleConfirmEditGroupNotice = async () => {
  const newGroupNotice = editingGroupNotice.value.trim()

  // 验证群公告
  if (!newGroupNotice) {
    groupNameError.value = '群公告不能为空'
    return
  }

  if (newGroupNotice.length > 100) {
    groupNameError.value = '群公告不能超过100个字符'
    return
  }

  isUpdatingGroupNotice.value = true
  groupNameError.value = ''

  try {
    console.log('🔄 开始修改群公告:', {
      groupId: selectedChat.value?.groupId,
      newNotice: newGroupNotice
    })

    const response = await GroupApi.updateGroupInfo({
      groupId: selectedChat.value?.groupId || '',
      groupNotice: newGroupNotice,  // 群公告内容
      showNoticeFlag: 1            // 显示群公告标志（与bear-chat-uniapp保持一致）
    })

    if (response.success) {
      console.log('✅ 群公告修改成功')
      toast.success('群公告修改成功')

      // 更新本地数据
      if (selectedChat.value) {
        selectedChat.value.groupNotice = newGroupNotice
        selectedChat.value.showNoticeFlag = 1

        console.log('✅ 群公告本地数据已更新:', {
          groupNotice: selectedChat.value.groupNotice,
          showNoticeFlag: selectedChat.value.showNoticeFlag
        })
      }

      // 发送群公告修改的系统消息（与bear-chat-uniapp保持一致）
      await sendGroupNoticeUpdateSystemMessage(selectedChat.value?.groupId || '', newGroupNotice)

      // 重新加载群详情以确保数据同步
      if (selectedChat.value?.groupId) {
        await loadGroupDetailInfo(selectedChat.value.groupId)
      }

      // 关闭弹窗
      showEditGroupNoticeDialog.value = false
    } else {
      groupNameError.value = response.message || '修改失败'
      console.warn('❌ 群公告修改失败:', response.message)
    }
  } catch (error: any) {
    console.error('❌ 群公告修改异常:', error)
    groupNameError.value = error.message || '网络错误，请稍后重试'
  } finally {
    isUpdatingGroupNotice.value = false
  }
}

// 取消修改群公告
const handleCancelEditGroupNotice = () => {
  showEditGroupNoticeDialog.value = false
  editingGroupNotice.value = ''
  groupNameError.value = ''
  isUpdatingGroupNotice.value = false
}

// 处理消息免打扰切换
const handleToggleMute = async (value: boolean) => {
  if (!selectedChat.value) return

  const oldValue = selectedChat.value.chatStatus

  try {
    console.log('🔄 切换消息免打扰:', value)

    // 调用API更新通知设置
    const response = await MessageApi.updateNotificationSettings({
      roomId: selectedChat.value.id,
      notificationSettings: value ? 2 : 0, // 2 = 完全静音, 0 = 全部通知
    })

    if (response.success) {
      // 更新本地状态
      selectedChat.value.chatStatus = value ? 2 : 0
      toast.success(value ? '已开启消息免打扰' : '已关闭消息免打扰')
    } else {
      throw new Error(response.message || '设置失败')
    }
  } catch (error: any) {
    console.error('❌ 免打扰设置异常:', error)
    toast.error('设置失败: ' + (error.message || '网络错误'))

    // 回滚本地状态
    if (selectedChat.value) {
      selectedChat.value.chatStatus = oldValue
    }
  }
}

// 处理置顶聊天切换
const handleToggleTop = async (value: boolean) => {
  if (!selectedChat.value) return

  try {
    console.log('🔄 切换置顶聊天:', value)
    toast.warning('当前版本暂未提供聊天置顶功能，敬请期待后续更新')
    selectedChat.value.isTop = !value
  } catch (error: any) {
    console.error('❌ 置顶设置异常:', error)
    toast.error('设置失败: ' + (error.message || '网络错误'))

    // 回滚本地状态
    if (selectedChat.value) {
      selectedChat.value.isTop = !value
    }
  }
}

// 处理群名修改
const handleEditGroupName = () => {
  if (!selectedChat.value) return

  console.log('🔄 打开群名修改弹窗')

  // 设置当前群名作为默认值
  editingGroupName.value = selectedChat.value.name || ''
  groupNameError.value = ''

  // 关闭群设置抽屉，打开群名修改弹窗
  showGroupSettings.value = false
  showEditGroupNameDialog.value = true
}

// 确认修改群名
const handleConfirmEditGroupName = async () => {
  const newGroupName = editingGroupName.value.trim()

  // 验证群名
  if (!newGroupName) {
    groupNameError.value = '群名不能为空'
    return
  }

  if (newGroupName.length > 20) {
    groupNameError.value = '群名不能超过20个字符'
    return
  }

  if (newGroupName === selectedChat.value?.name) {
    groupNameError.value = '群名没有变化'
    return
  }

  isUpdatingGroupName.value = true
  groupNameError.value = ''

  try {
    console.log('🔄 开始修改群名称:', {
      groupId: selectedChat.value?.groupId,
      oldName: selectedChat.value?.name,
      newName: newGroupName
    })

    const response = await GroupApi.updateGroupInfo({
      groupId: selectedChat.value?.groupId || '',
      groupName: newGroupName  // 修正：使用 groupName 而不是 name
    })

    if (response.success) {
      console.log('✅ 群名修改成功')
      toast.success('群名修改成功')

      // 更新本地数据
      if (selectedChat.value) {
        selectedChat.value.name = newGroupName

        // 更新store中的聊天列表
        const updatedChat = { ...selectedChat.value, name: newGroupName }
        store.dispatch('updateChatItem', updatedChat)
      }

      // 关闭弹窗
      showEditGroupNameDialog.value = false
    } else {
      groupNameError.value = response.message || '修改失败'
      console.warn('❌ 群名修改失败:', response.message)
    }
  } catch (error: any) {
    console.error('❌ 群名修改异常:', error)
    groupNameError.value = error.message || '网络错误，请稍后重试'
  } finally {
    isUpdatingGroupName.value = false
  }
}

// 取消修改群名
const handleCancelEditGroupName = () => {
  showEditGroupNameDialog.value = false
  editingGroupName.value = ''
  groupNameError.value = ''
  isUpdatingGroupName.value = false
}

// 确认创建群组 - 输入群名后
const handleConfirmGroupName = async () => {
  const groupName = newGroupName.value.trim()

  // 验证群名
  if (!groupName) {
    groupNameError.value = '群名不能为空'
    return
  }

  if (groupName.length > 20) {
    groupNameError.value = '群名不能超过20个字符'
    return
  }

  // 开始加载联系人
  isCreatingGroup.value = true
  groupNameError.value = ''

  try {
    console.log('🔄 加载联系人列表用于群组创建...')

    // 获取好友列表
    const response = await FriendApi.getMyFriendList({
      page: 1,
      size: 1000
    })

    if (response.success && response.data) {
      // 新的API响应格式：{ myFriendsIndexList: string[], myFriendList: FriendGroup[] }
      const friendListResponse = response.data
      const allContacts: any[] = []

      // 遍历所有分组的好友
      if (friendListResponse.myFriendList && Array.isArray(friendListResponse.myFriendList)) {
        friendListResponse.myFriendList.forEach((group: any) => {
          if (group.friends && Array.isArray(group.friends)) {
            group.friends.forEach((friend: any) => {
              allContacts.push({
                id: friend.friendId || friend.id,
                nickname: friend.nickname || friend.friendName || friend.userName || friend.realName || '未知用户',
                avatar: friend.avatar || friend.headImg || '',
                username: friend.username || friend.userName || friend.chatNumber
              })
            })
          }
        })
      }

      contacts.value = allContacts

      // 保存群组数据供后续使用
      pendingGroupData.value = {
        name: groupName,
        description: `由${store.getters.currentUser.userName || '用户'}创建的群聊`,
        avatar: null // 暂时不支持群头像，设为null
      }

      // 关闭群名对话框，打开成员选择对话框
      showGroupNameDialog.value = false
      showAddMemberDialog.value = true

      console.log('✅ 联系人列表加载成功:', contacts.value.length, '个联系人')
    } else {
      groupNameError.value = '获取联系人列表失败: ' + (response.message || '未知错误')
      console.warn('❌ 联系人列表获取失败:', response.message)
    }
  } catch (error: any) {
    console.error('❌ 获取联系人列表异常:', error)
    groupNameError.value = '获取联系人列表失败: ' + (error.message || '网络错误')
  } finally {
    isCreatingGroup.value = false
  }
}

// 取消创建群组 - 群名输入阶段
const handleCancelGroupName = () => {
  showGroupNameDialog.value = false
  newGroupName.value = ''
  groupNameError.value = ''
  isCreatingGroup.value = false
}

// 确认添加成员并创建群组
const handleConfirmAddMembers = async (selectedMemberIds: string[]) => {
  if (!pendingGroupData.value) {
    toast.error('群组信息丢失，请重新创建')
    return
  }

  console.log('🔄 创建群组并添加成员:', {
    groupName: pendingGroupData.value.name,
    memberCount: selectedMemberIds.length,
    memberIds: selectedMemberIds
  })

  try {
    isCreatingGroup.value = true

    // 调用创建群组API - 使用与bear-chat-uniapp一致的参数结构
    const currentUser = store.getters.currentUser
    const membersWithCreator = [...selectedMemberIds, currentUser.id] // 成员列表必须包含创建者

    console.log('🔄 准备创建群组，参数构建:', {
      groupName: pendingGroupData.value.name,
      selectedMembers: selectedMemberIds,
      currentUser: currentUser.id,
      finalMembers: membersWithCreator
    })

    const response = await GroupApi.launchChatGroup({
      name: pendingGroupData.value.name,
      memberIds: membersWithCreator,
      description: pendingGroupData.value.description || undefined
    })

    if (response.success && response.data) {
      console.log('✅ 群组创建成功:', response.data)
      toast.success('群组创建成功')

      // 关闭对话框
      showAddMemberDialog.value = false

      // 提取返回的群组信息
      const groupId = response.data.roomId
      const groupName = pendingGroupData.value.name
      console.log('📋 新群组信息:', { groupId, groupName })

      // 重新加载聊天列表以显示新创建的群组
      await loadChatList(true) // 强制刷新获取最新数据

      // 使用返回的groupId和groupName查找新创建的群组
      let newGroup: ChatItem | undefined

      // 尝试多次查找新创建的群组（因为可能需要时间同步）
      for (let attempt = 0; attempt < 3; attempt++) {
        console.log(`🔍 第${attempt + 1}次尝试查找新创建的群组:`, { groupId, groupName })

        // 优先使用 groupId 查找，其次使用 groupName
        newGroup = chatList.value.find(chat =>
          chat.groupId === groupId ||
          chat.id === groupId ||
          chat.name === groupName ||
          chat.name.includes(groupName)
        )

        if (newGroup) {
          console.log('✅ 找到新创建的群组:', newGroup)
          await selectChat(newGroup)

          // 发送群组创建的系统消息
          await sendGroupCreationSystemMessage(groupId, groupName)
          break
        } else {
          console.log(`⏳ 第${attempt + 1}次未找到群组，当前聊天列表:`, chatList.value.map(c => ({
            id: c.id,
            groupId: c.groupId,
            name: c.name
          })))

          if (attempt < 2) { // 只在前两次尝试时等待
            await new Promise(resolve => setTimeout(resolve, 1000))
            await loadChatList(true) // 重新加载
          }
        }
      }

      // 如果最终没找到群组，提供备用方案
      if (!newGroup) {
        console.warn('⚠️ 多次尝试后仍未找到新创建的群组')
        console.warn('📊 查找条件:', {
          targetGroupId: groupId,
          targetGroupName: groupName,
          currentChatList: chatList.value.length
        })
        toast.warning('群组创建成功，但无法自动打开，请手动选择群组')
      }
    } else {
      console.warn('❌ 群组创建失败:', response.message)
      toast.error('群组创建失败: ' + (response.message || '未知错误'))
    }
  } catch (error: any) {
    console.error('❌ 群组创建异常:', error)
    toast.error('群组创建失败: ' + (error.message || '网络错误'))
  } finally {
    isCreatingGroup.value = false
    // 清理临时数据
    pendingGroupData.value = null
  }
}

// 取消添加成员
const handleCancelAddMembers = () => {
  showAddMemberDialog.value = false
  pendingGroupData.value = null
  isCreatingGroup.value = false
}

// 发送群组创建的系统消息（与bear-chat-uniapp保持一致）
// NOTE: 此功能已废弃 - 系统消息应由服务器自动生成并通过 WebSocket 推送
// 群聊创建流程：
// 1. 调用 HTTP API 创建群聊 (RoomApi.createRoom)
// 2. 服务器创建群聊并生成系统消息
// 3. 服务器通过 WebSocket 推送消息给所有成员
// 4. 客户端接收 'message' 事件并显示
const sendGroupCreationSystemMessage = async (groupId: string, groupName: string) => {
  // 功能已废弃，保留函数以避免调用处报错
  console.warn('⚠️ sendGroupCreationSystemMessage 已废弃：系统消息应由服务器生成');
  return;

  /* 原实现已注释
  try {
    const user = store.getters.currentUser
    const timestamp = Date.now()

    console.log('🔄 发送群组创建系统消息...', { groupId, groupName, user: user.username })

    // 构造系统消息对象，参考bear-chat-uniapp的格式
    const systemMessage = {
      id: `${timestamp}`, // 使用时间戳作为ID
      chatGroupId: groupId,
      userId: parseInt(user?.id || currentUserId.value) || 0,
      meFlag: true, // 标记为自己发送的消息
      userName: user?.username || user?.nickname || '用户',
      userAvatar: user?.avatar || '/static/image/default/default-user/default-user.png',
      messageType: MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG, // 系统消息类型
      contentType: MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE, // 文本内容
      content: {
        text: `${user?.username || user?.nickname || '用户'}发起了群聊` // 与bear-chat-uniapp一致的消息内容
      },
      createTime: getTimeStr(timestamp),
      timestamp: timestamp,
      platFrom: MESSAGE_CONSTANTS.PLATFORM.WEB,
      showTimeFlag: true
    }

    console.log('📤 准备发送的群组创建系统消息:', systemMessage)

    // 立即在本地显示系统消息
    const localSystemMessage: Message = {
      id: `${timestamp}`,
      content: `${user?.username || user?.nickname || '用户'}发起了群聊`,
      isSelf: true,
      time: formatTime(getTimeStr(timestamp)),
      senderId: user?.id || '',
      senderName: user?.username || user?.nickname || '用户',
      senderAvatar: user?.avatar || '',
      messageType: MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG,
      contentType: MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE,
      status: 1, // 发送中
      createTime: getTimeStr(timestamp),
      timestamp: timestamp
    }

    // 添加到消息列表
    messages.value.push(localSystemMessage)
    scrollToBottom()

    // 通过WebSocket发送系统消息
    await new Promise((resolve, reject) => {
      webSocketManager.sendMessage(systemMessage, MESSAGE_CONSTANTS.BUSINESS_CODE.launchGroup, (success: boolean) => {
        if (success) {
          console.log('✅ 群组创建系统消息发送成功')

          // 更新本地消息状态为成功
          const messageIndex = messages.value.findIndex(msg => msg.id === localSystemMessage.id)
          if (messageIndex !== -1) {
            messages.value[messageIndex].status = 2 // 发送成功
          }

          resolve(true)
        } else {
          console.error('❌ 群组创建系统消息发送失败')

          // 更新本地消息状态为失败
          const messageIndex = messages.value.findIndex(msg => msg.id === localSystemMessage.id)
          if (messageIndex !== -1) {
            messages.value[messageIndex].status = 3 // 发送失败
          }

          reject(new Error('系统消息发送失败'))
        }
      })
    })

  } catch (error: any) {
    console.error('❌ 发送群组创建系统消息失败:', error)
    // 静默处理错误，不影响用户体验
  }
  */
}

// 拖拽调整宽度相关函数
const getMaxWidth = () => {
  return window.innerWidth * (maxWidthVw / 100)
}

const startResize = (e: MouseEvent) => {
  isResizing.value = true
  startX.value = e.clientX
  startWidth.value = chatListWidth.value
  
  document.addEventListener('mousemove', handleResize)
  document.addEventListener('mouseup', stopResize)
  document.body.style.cursor = 'col-resize'
  document.body.style.userSelect = 'none'
}

const handleResize = (e: MouseEvent) => {
  if (!isResizing.value) return
  
  const deltaX = e.clientX - startX.value
  const newWidth = startWidth.value + deltaX
  const maxWidth = getMaxWidth()
  
  chatListWidth.value = Math.max(minWidth, Math.min(newWidth, maxWidth))
}

const stopResize = () => {
  isResizing.value = false
  document.removeEventListener('mousemove', handleResize)
  document.removeEventListener('mouseup', stopResize)
  document.body.style.cursor = ''
  document.body.style.userSelect = ''
}

const resetWidth = () => {
  chatListWidth.value = 300
}

// 监听窗口大小变化，确保宽度不超过限制
const handleWindowResize = () => {
  const maxWidth = getMaxWidth()
  if (chatListWidth.value > maxWidth) {
    chatListWidth.value = maxWidth
  }
}

// 根据路由参数创建或选择聊天会话
const handleRouteParams = async () => {
  const { contactId, contactName } = route.query
  
  if (contactId) {
    console.log('从联系人页面发起聊天:', { contactId, contactName })
    
    // 先加载现有的聊天列表
    await loadChatList()
    
    // 首先尝试在现有聊天中查找
    let existingChat = chatList.value.find(chat => {
      // 更精确的匹配逻辑：名称完全匹配或包含联系人名称
      return chat.name === contactName ||
             chat.name.includes(contactName as string) ||
             chat.groupId === contactId
    })
    
    if (existingChat) {
      // 找到现有聊天，直接选中
      selectChat(existingChat)
      console.log('✅ 选中已存在的聊天会话:', existingChat.name)
      return
    }
    
    // 没找到现有聊天，尝试创建新的单聊
    try {
      console.log('🔄 创建新的单聊...')
      // 创建单聊 - 使用与bear-chat-uniapp相同的参数格式
      const response = await GroupApi.createSingleChat({
        friendId: contactId as string
      })
      
      if (response.success) {
        const createdRoomId = response.data?.roomId || ''
        console.log('✅ 单聊创建成功，响应数据:', response.data)
        
        // 重新加载聊天列表以获取新创建的单聊
        await loadChatList()
        
        // 多次尝试查找新创建的聊天，使用更宽松的匹配条件
        let attempts = 0
        const maxAttempts = 3
        
        const findAndSelectChat = async () => {
          attempts++
          console.log(`🔍 第${attempts}次尝试查找新聊天...`)
          
          const newChat = chatList.value.find(chat => {
            const matchesName = contactName && (
              chat.name === contactName ||
              chat.name.includes(contactName as string) ||
              (contactName as string).includes(chat.name)
            )
            const matchesId = createdRoomId && chat.id === createdRoomId
            const matchesGroupId = createdRoomId && chat.groupId === createdRoomId

            return matchesName || matchesId || matchesGroupId
          })
          
          if (newChat) {
            selectChat(newChat)
            console.log('✅ 选中新创建的聊天会话:', newChat.name)
            return true
          }
          
          if (attempts < maxAttempts) {
            console.log(`⏳ 未找到聊天，${500 * attempts}ms后重试...`)
            setTimeout(async () => {
              // 重新加载列表再试
              await loadChatList()
              await findAndSelectChat()
            }, 500 * attempts)
          } else {
            console.warn('❌ 经过多次尝试仍未找到新创建的聊天')
            // 如果实在找不到，至少显示一个提示
            toast.error('聊天创建成功，但无法自动打开，请手动选择')
          }
          
          return false
        }
        
        await findAndSelectChat()
        
      } else {
        console.warn('❌ 单聊创建失败:', response.message)
        toast.error('创建聊天失败: ' + (response.message || '未知错误'))
      }
    } catch (error: any) {
      console.error('❌ 单聊创建异常:', error)
      toast.error('创建聊天失败: ' + (error.message || '网络错误'))
    }
    
    // 处理完路由参数后清除，避免刷新页面时重复处理
    router.replace({ path: '/home/chat' })
  }
}

// 比较消息内容是否匹配（用于识别重复消息）
const isContentMatch = (content1: any, content2: any): boolean => {
  console.log('🔍 比较消息内容:', { content1, content2 })

  // 如果都是字符串，直接比较
  if (typeof content1 === 'string' && typeof content2 === 'string') {
    const match = content1 === content2
    console.log('📝 字符串比较结果:', match)
    return match
  }

  // 如果都是对象，比较关键字段
  if (typeof content1 === 'object' && typeof content2 === 'object') {
    // 对于图片/视频消息，比较文件名或URL
    if (content1.name && content2.name) {
      const match = content1.name === content2.name
      console.log('📷 文件名比较结果:', match, { name1: content1.name, name2: content2.name })
      return match
    }
    if (content1.url && content2.url) {
      const match = content1.url === content2.url
      console.log('🔗 URL比较结果:', match, { url1: content1.url, url2: content2.url })
      return match
    }
    if (content1.fullPath && content2.fullPath) {
      const match = content1.fullPath === content2.fullPath
      console.log('📁 fullPath比较结果:', match, { fullPath1: content1.fullPath, fullPath2: content2.fullPath })
      return match
    }
    if (content1.fileName && content2.fileName) {
      const match = content1.fileName === content2.fileName
      console.log('📄 fileName比较结果:', match, { fileName1: content1.fileName, fileName2: content2.fileName })
      return match
    }
    // 对于文本消息，比较text字段
    if (content1.text && content2.text) {
      const match = content1.text === content2.text
      console.log('💬 text字段比较结果:', match)
      return match
    }
    // 如果一个有text，另一个是字符串
    if (content1.text && typeof content2 === 'string') {
      const match = content1.text === content2
      console.log('💬 text vs string比较结果:', match)
      return match
    }
    if (content2.text && typeof content1 === 'string') {
      const match = content2.text === content1
      console.log('💬 string vs text比较结果:', match)
      return match
    }
  }

  // 如果一个是对象，一个是字符串
  if (typeof content1 === 'object' && typeof content2 === 'string') {
    const match = content1.text === content2
    console.log('🔄 对象 vs 字符串比较结果:', match)
    return match
  }
  if (typeof content2 === 'object' && typeof content1 === 'string') {
    const match = content2.text === content1
    console.log('🔄 字符串 vs 对象比较结果:', match)
    return match
  }

  // 默认不匹配
  console.log('❌ 无法匹配，返回false')
  return false
}

// WebSocket消息监听
const handleWebSocketMessage = (event: CustomEvent) => {
  const detail = event.detail as { message?: DomainMessage; raw?: any }
  if (!detail?.message) {
    console.warn('⚠️ WebSocket 消息缺少 message 字段，忽略:', detail)
    return
  }

  const messageData = detail.message
  const uiMessage = mapDomainMessageToUi(messageData)
  const messageGroupId = messageData.roomId
  const isCurrentRoom = !!selectedChat.value && selectedChat.value.groupId === messageGroupId

  console.log('📨 [WebSocket] 收到消息:', { 
    id: uiMessage.id, 
    isSelf: messageData.isSelf, 
    isCurrentRoom,
    content: typeof messageData.content === 'string' ? messageData.content.substring(0, 20) : 'object',
    recentSentMessages: Array.from(recentSentMessages.value),
    messagesCount: messages.value.length,
    messageIds: messages.value.map(m => m.id)
  })

  if (isCurrentRoom) {
    const existingMessageIndex = messages.value.findIndex(msg => msg.id === uiMessage.id)
    console.log('🔍 [WebSocket] 检查消息是否存在:', { id: uiMessage.id, found: existingMessageIndex !== -1 })

    if (existingMessageIndex !== -1) {
      // 如果消息已存在，检查是否需要更新
      if (messageData.isSelf) {
        console.log('✅ [WebSocket] 消息已存在（自己发送），合并更新:', existingMessageIndex)
        // 如果是自己发送的消息，无论状态如何都应该合并（避免重复）
        const mergedMessage = mergeMessagePreservingLocalData(
          messages.value[existingMessageIndex],
          {
            ...uiMessage,
            status: messages.value[existingMessageIndex].status === 1 ? 2 : messages.value[existingMessageIndex].status,
          },
        )

        if (typeof mergedMessage.content === 'object' && mergedMessage.content) {
          mergedMessage.content.isUploading = false
          mergedMessage.content.uploadProgress = 1
        }

        messages.value[existingMessageIndex] = mergedMessage
        // 确保添加到 recentSentMessages，防止后续重复处理
        recentSentMessages.value.add(uiMessage.id)
        setTimeout(() => {
          recentSentMessages.value.delete(uiMessage.id)
        }, 10000)
        console.log('✅ [WebSocket] 消息已更新，添加到 recentSentMessages:', uiMessage.id)
        // 消息已存在且已更新，直接返回，避免重复添加
        return
      } else {
        console.log('⏭️ [WebSocket] 消息已存在（他人发送），跳过')
        // 如果是他人发送的消息且已存在，说明可能是重复推送，直接返回
        return
      }
    } else {
      let matchedLocalMessageId: string | null = null
      if (messageData.isSelf) {
        // 如果 recentSentMessages 中已经有真实消息 ID，说明 API 已经返回了
        // 即使消息不存在（可能是时序问题），也应该直接返回，避免重复添加
        if (recentSentMessages.value.has(uiMessage.id)) {
          console.log('⚠️ [WebSocket] recentSentMessages 中已有真实消息ID，再次检查消息是否存在')
          // 再次检查消息是否存在（可能是时序问题导致第一次检查时不存在）
          const existingIndex = messages.value.findIndex(msg => msg.id === uiMessage.id)
          if (existingIndex !== -1) {
            console.log('✅ [WebSocket] 消息存在，更新状态:', existingIndex)
            // 消息存在，更新状态
            messages.value[existingIndex] = {
              ...messages.value[existingIndex],
              ...uiMessage,
              status: 2
            }
          } else {
            console.log('⚠️ [WebSocket] 消息不存在但 recentSentMessages 中有，可能是时序问题，跳过')
          }
          // 无论消息是否存在，都直接返回，避免重复添加
          return
        } else {
          console.log('🔍 [WebSocket] 尝试匹配临时消息')
          const resendMatchId = Array.from(recentSentMessages.value).find((sentId: string) =>
            sentId.startsWith('resend_') && messageData.content
          )
          if (resendMatchId) {
            console.log('✅ [WebSocket] 匹配到重发消息ID:', resendMatchId)
            recentSentMessages.value.delete(resendMatchId)
            return
          }
          for (const sentId of Array.from(recentSentMessages.value)) {
            const localMessage = messages.value.find(msg => msg.id === sentId)
            if (localMessage && isContentMatch(localMessage.content, uiMessage.content)) {
              matchedLocalMessageId = sentId as string
              console.log('✅ [WebSocket] 匹配到临时消息:', matchedLocalMessageId)
              break
            }
          }
        }
      }

      if (matchedLocalMessageId) {
        // matchedLocalMessageId 应该是临时消息 ID，需要替换为真实消息
        // 如果匹配到的就是真实消息 ID，说明逻辑有问题，应该已经在上面处理了
        // 这里只处理临时消息的情况
        const localMessageIndex = messages.value.findIndex(msg => msg.id === matchedLocalMessageId)
        if (localMessageIndex !== -1) {
          console.log('✅ [WebSocket] 替换临时消息为真实消息:', { tempId: matchedLocalMessageId, realId: uiMessage.id, index: localMessageIndex })
          const mergedMessage = mergeMessagePreservingLocalData(
            {
              ...messages.value[localMessageIndex],
              id: matchedLocalMessageId,
            },
            {
              ...uiMessage,
              status: 2,
            },
          )

          if (typeof mergedMessage.content === 'object' && mergedMessage.content) {
            mergedMessage.content.isUploading = false
            mergedMessage.content.uploadProgress = 1
          }

          mergedMessage.id = uiMessage.id
          messages.value[localMessageIndex] = mergedMessage
          recentSentMessages.value.delete(matchedLocalMessageId)
          // 将真实消息 ID 添加到 recentSentMessages，防止 API 返回时重复添加
          recentSentMessages.value.add(uiMessage.id)
          setTimeout(() => {
            recentSentMessages.value.delete(uiMessage.id)
          }, 10000)
          console.log('✅ [WebSocket] 临时消息已替换，添加到 recentSentMessages:', uiMessage.id)
        }
      } else {
        // 如果没有匹配到临时消息，检查是否应该添加
        // 对于自己发送的消息，如果已经在 recentSentMessages 中，说明 API 已返回，不应该重复添加
        if (messageData.isSelf && recentSentMessages.value.has(uiMessage.id)) {
          console.log('⏭️ [WebSocket] recentSentMessages 中已有，跳过添加')
          // 消息已经在 recentSentMessages 中，说明 API 已返回，不应该重复添加
          return
        }
        
        console.log('➕ [WebSocket] 添加新消息到列表')
        messages.value.push(uiMessage)
        // 如果是自己发送的消息，应该添加到 recentSentMessages，防止 API 返回时重复添加
        if (messageData.isSelf) {
          recentSentMessages.value.add(uiMessage.id)
          setTimeout(() => {
            recentSentMessages.value.delete(uiMessage.id)
          }, 10000)
        }

        // 索引新消息
        if (selectedChat.value) {
          messageSearchService.indexMessageAsync(uiMessage, selectedChat.value.name).catch(error => {
            console.warn('⚠️ 消息索引失败:', error)
          })
        }

        scrollToBottom()
      }
    }
  }

  const existingChat = store.getters.getChatByGroupId(messageGroupId)
  if (existingChat) {
    const shouldIncreaseUnread = !isCurrentRoom && !messageData.isSelf
    const unreadCount = shouldIncreaseUnread ? (existingChat.unreadCount || 0) + 1 : (isCurrentRoom ? 0 : (existingChat.unreadCount || 0))

    const updatedChat = {
      ...existingChat,
      lastMessage: getTextContent(uiMessage),
      time: uiMessage.time,
      lastMessageId: messageData.id,
      unreadCount
    }

    store.dispatch('updateChatItem', updatedChat)
    store.dispatch('setChatUnreadCount', { groupId: messageGroupId, unreadCount })

    if (isCurrentRoom && selectedChat.value) {
      selectedChat.value.unreadCount = 0
      selectedChat.value.lastMessage = updatedChat.lastMessage
      selectedChat.value.time = updatedChat.time
      selectedChat.value.lastMessageId = updatedChat.lastMessageId ?? null
    }

  }
}

const handleWebSocketMessageUpdate = (event: CustomEvent) => {
  const detail = event.detail as { message?: DomainMessage; action?: string } | undefined
  if (!detail?.message) {
    console.warn('⚠️ WebSocket 消息更新缺少 message 字段，忽略:', detail)
    return
  }

  const message = detail.message
  const uiMessage = mapDomainMessageToUi(message)
  const isCurrentRoom = !!selectedChat.value && selectedChat.value.groupId === message.roomId

  if (isCurrentRoom) {
    const existingIndex = messages.value.findIndex((msg) => msg.id === uiMessage.id)

    if (message.isDeleted) {
      if (existingIndex !== -1) {
        messages.value.splice(existingIndex, 1)
      }
    } else if (existingIndex !== -1) {
      const mergedMessage = mergeMessagePreservingLocalData(
        messages.value[existingIndex],
        uiMessage,
      )
      mergedMessage.isEdited = true
      messages.value.splice(existingIndex, 1, mergedMessage)
    }
  }

  const chatItem = store.getters.getChatByGroupId(message.roomId)
  if (chatItem && chatItem.lastMessageId === message.id) {
    const updatedChat = {
      ...chatItem,
      lastMessage: message.isDeleted ? '[消息已删除]' : getTextContent(uiMessage),
      time: uiMessage.time
    }
    store.dispatch('updateChatItem', updatedChat)
  }
}

const handleWebSocketMessageRead = (event: CustomEvent) => {
  const detail = event.detail as { room_id?: string; roomId?: string; message_ids?: string[]; message_id?: string; messageId?: string } | undefined
  if (!detail) return

  const roomId = detail.room_id || detail.roomId
  if (!roomId || !selectedChat.value || roomId !== selectedChat.value.groupId) {
    return
  }

  const ids: string[] = []
  if (Array.isArray(detail.message_ids)) {
    ids.push(...detail.message_ids)
  }
  if (detail.message_id) ids.push(detail.message_id)
  if (detail.messageId) ids.push(detail.messageId)

  if (!ids.length) return

  ids.forEach((id) => {
    const index = messages.value.findIndex((msg) => msg.id === id)
    if (index !== -1) {
      messages.value[index].status = messageStatusToUiStatus[MessageStatus.READ]
    }
  })

  store.dispatch('setChatUnreadCount', { groupId: roomId, unreadCount: 0 })
  if (selectedChat.value) {
    selectedChat.value.unreadCount = 0
  }
}

const handleWebSocketPinUpdate = (event: CustomEvent) => {
  const detail = event.detail as { room_id?: string; roomId?: string; is_pinned?: boolean; isPinned?: boolean; message?: DomainMessage } | undefined
  if (!detail) return

  const roomId = detail.room_id || detail.roomId
  if (!roomId || !selectedChat.value || roomId !== selectedChat.value.groupId) {
    return
  }

  if (detail.message) {
    const uiMessage = mapDomainMessageToUi(detail.message)
    const existingIndex = messages.value.findIndex((msg) => msg.id === uiMessage.id)
    if (existingIndex !== -1) {
      messages.value.splice(existingIndex, 1, {
        ...messages.value[existingIndex],
        ...uiMessage
      })
    }
  }

  const isPinned = detail.is_pinned ?? detail.isPinned ?? false
  selectedChat.value.isTop = isPinned

  const chatItem = store.getters.getChatByGroupId(roomId)
  if (chatItem) {
    const updatedChat = {
      ...chatItem,
      isTop: isPinned
    }
    store.dispatch('updateChatItem', updatedChat)
  }
}

const handleWebSocketGroupMessage = (event: CustomEvent) => {
  const groupData = event.detail
  console.log('收到WebSocket群组消息:', groupData)

  // 重新加载聊天列表，使用后台同步方式避免闪烁
  store.dispatch('loadChatList', { forceRefresh: true, compareWithStore: true })
}

onMounted(async () => {
  // 使用事件管理器添加监听器
  eventManager.addWindowListener('resize', handleWindowResize)
  eventManager.addWindowListener('websocket-chat-message', handleWebSocketMessage as EventListener)
  eventManager.addWindowListener('websocket-launch-group', handleWebSocketGroupMessage as EventListener)
  eventManager.addWindowListener('websocket-room-created', handleWebSocketGroupMessage as EventListener)
  eventManager.addWindowListener('websocket-delete-group', handleWebSocketGroupMessage as EventListener)
  eventManager.addWindowListener('websocket-message-update', handleWebSocketMessageUpdate as EventListener)
  eventManager.addWindowListener('websocket-message-read', handleWebSocketMessageRead as EventListener)
  eventManager.addWindowListener('websocket-pin-update', handleWebSocketPinUpdate as EventListener)

  // 添加点击外部关闭表情选择器的监听器
  document.addEventListener('click', handleClickOutside)

  // 先处理路由参数，如果有联系人参数，会在处理过程中加载聊天列表
  const hasRouteParams = route.query.contactId
  if (hasRouteParams) {
    await handleRouteParams()
  } else {
    // 没有路由参数时优先从store加载，然后后台刷新
    await loadChatList(false) // 从store加载

    // 只有在初始化成功后才启动后台刷新，避免重复请求
    if (isInitialized.value) {
      // 后台异步刷新数据，避免界面闪烁
      setTimeout(async () => {
        try {
          await loadChatList(true) // 强制刷新API数据
        } catch (error: any) {
          console.warn('⚠️ 后台刷新聊天列表数据失败:', error)
          // 即使失败也不影响用户体验，用户可以看到store中的数据
        }
      }, 500) // 500ms 后开始后台刷新
    }
  }
})

onUnmounted(async () => {
  // 重置初始化状态
  isInitialized.value = false

  // 如果有选中的聊天，更新已读时间
  if (selectedChat.value) {
    await updateReadTimeOnLeave(selectedChat.value)
  }

  // 清理所有临时本地URL，避免内存泄漏
  Array.from(blobUrlRegistry).forEach((url) => releaseBlobUrl(url))

  // 清理图片预缓存
  imagePreloadCache.value.clear()

  // 手动清理监听器（事件管理器会自动清理，但为了保险起见）
  window.removeEventListener('resize', handleWindowResize)
  document.removeEventListener('mousemove', handleResize)
  document.removeEventListener('mouseup', stopResize)

  // 移除点击外部关闭表情选择器的监听器
  document.removeEventListener('click', handleClickOutside)

  // 移除WebSocket事件监听
  window.removeEventListener('websocket-chat-message', handleWebSocketMessage as EventListener)
  window.removeEventListener('websocket-launch-group', handleWebSocketGroupMessage as EventListener)
  window.removeEventListener('websocket-room-created', handleWebSocketGroupMessage as EventListener)
  window.removeEventListener('websocket-delete-group', handleWebSocketGroupMessage as EventListener)
  window.removeEventListener('websocket-message-update', handleWebSocketMessageUpdate as EventListener)
  window.removeEventListener('websocket-message-read', handleWebSocketMessageRead as EventListener)
  window.removeEventListener('websocket-pin-update', handleWebSocketPinUpdate as EventListener)
})

// 离开聊天时更新已读时间
const updateReadTimeOnLeave = async (chat: ChatItem) => {
  try {
    const currentUser = store.getters.currentUser
    const currentTime = getTimeStr(Date.now())
    
    console.log('🔄 离开聊天，更新已读时间:', chat.name)
    
    if (!chat.groupId) {
      console.warn('❌ 群组ID为空，无法更新已读时间:', chat.name)
      return
    }
    
    console.log('ℹ️ 当前版本离开聊天不再调用旧的群用户接口，稍后将接入新的阅读状态接口')
  } catch (error: any) {
    console.error('❌ 已读时间更新异常:', error)
  }
}

// 群组管理功能
// 添加成员到现有群聊
const showAddExistingGroupMemberDialog = ref(false)
const isAddingMembers = ref(false)

// 删除群成员
const showRemoveMemberDialog = ref(false)
const isRemovingMembers = ref(false)

// 举报群聊
const showReportDialog = ref(false)
const isReportingGroup = ref(false)

const handleAddMember = () => {
  if (!selectedChat.value || selectedChat.value.groupType !== 1) {
    toast.error('请先选择一个群聊')
    return
  }
  console.log('打开添加成员对话框', { groupId: selectedChat.value.id, groupName: selectedChat.value.name })
  showAddExistingGroupMemberDialog.value = true
}

// 确认向现有群聊添加成员
const handleConfirmAddExistingGroupMembers = async (selectedMemberIds: string[]) => {
  if (!selectedChat.value || selectedChat.value.groupType !== 1) {
    toast.error('请先选择一个群聊')
    return
  }

  if (selectedMemberIds.length === 0) {
    toast.warning('请至少选择一位成员')
    return
  }

  console.log('🔄 添加成员到群聊:', {
    groupId: selectedChat.value.id,
    groupName: selectedChat.value.name,
    memberCount: selectedMemberIds.length,
    memberIds: selectedMemberIds
  })

  try {
    isAddingMembers.value = true

    // 调用添加成员 API
    const response = await MessageApi.addGroupMembers({
      roomId: selectedChat.value.id,
      userIds: selectedMemberIds
    })

    if (response.success) {
      console.log('✅ 成员添加成功')
      toast.success(`成功添加 ${selectedMemberIds.length} 位成员`)

      // 刷新群成员列表
      await loadGroupMembers(selectedChat.value.id)

      // 关闭对话框
      showAddExistingGroupMemberDialog.value = false
    } else {
      throw new Error(response.message || '添加成员失败')
    }
  } catch (error: any) {
    console.error('❌ 添加成员失败:', error)
    toast.error('添加成员失败: ' + (error.message || '网络错误'))
  } finally {
    isAddingMembers.value = false
  }
}

const handleRemoveMember = () => {
  if (!selectedChat.value || selectedChat.value.groupType !== 1) {
    toast.error('请先选择一个群聊')
    return
  }
  console.log('打开删除成员对话框', { groupId: selectedChat.value.id, groupName: selectedChat.value.name })
  showRemoveMemberDialog.value = true
}

// 确认删除群成员
const handleConfirmRemoveMembers = async (selectedMemberIds: string[]) => {
  if (!selectedChat.value || selectedChat.value.groupType !== 1) {
    toast.error('请先选择一个群聊')
    return
  }

  if (selectedMemberIds.length === 0) {
    toast.warning('请至少选择一位成员')
    return
  }

  console.log('🔄 从群聊中删除成员:', {
    groupId: selectedChat.value.id,
    groupName: selectedChat.value.name,
    memberCount: selectedMemberIds.length,
    memberIds: selectedMemberIds
  })

  try {
    isRemovingMembers.value = true

    // 批量删除成员
    const results = await Promise.allSettled(
      selectedMemberIds.map(userId =>
        MessageApi.removeGroupMember({
          roomId: selectedChat.value!.id,
          userId
        })
      )
    )

    // 统计成功和失败数量
    const successCount = results.filter(r => r.status === 'fulfilled' && r.value.success).length
    const failedCount = results.length - successCount

    if (successCount > 0) {
      console.log(`✅ 成功删除 ${successCount} 位成员`)
      toast.success(`成功删除 ${successCount} 位成员${failedCount > 0 ? `，${failedCount} 位失败` : ''}`)

      // 刷新群成员列表
      if (selectedChat.value) {
        await loadGroupDetailInfo(selectedChat.value.groupId)
      }

      // 关闭对话框
      showRemoveMemberDialog.value = false
    } else {
      throw new Error('所有成员删除失败')
    }
  } catch (error: any) {
    console.error('❌ 删除成员失败:', error)
    toast.error('删除成员失败: ' + (error.message || '网络错误'))
  } finally {
    isRemovingMembers.value = false
  }
}

const handleClearHistory = async () => {
  if (!selectedChat.value) return

  try {
    const confirmed = confirm('确定要清除该群聊的所有聊天记录吗？此操作不可撤销。')
    if (!confirmed) return

    console.log('清除聊天记录:', selectedChat.value.id)
    const response = await MessageApi.clearGroupHistory({
      roomId: selectedChat.value.id,
    })

    if (response.success) {
      toast.success('聊天记录已清除')
      // 清空本地消息列表
      messageList.value = []
      // 重新加载消息
      if (selectedChat.value) {
        await loadMessageList(selectedChat.value.groupId)
      }
    } else {
      throw new Error(response.message || '清除失败')
    }
  } catch (error: any) {
    console.error('清除聊天记录失败:', error)
    toast.error('清除失败: ' + (error.message || '网络错误'))
  }
}

const handleReportGroup = () => {
  if (!selectedChat.value || selectedChat.value.groupType !== 1) {
    toast.error('请先选择一个群聊')
    return
  }
  console.log('打开举报群聊对话框', { groupId: selectedChat.value.id, groupName: selectedChat.value.name })
  showReportDialog.value = true
}

// 确认举报群聊
const handleConfirmReport = async (reason: string) => {
  if (!selectedChat.value || selectedChat.value.groupType !== 1) {
    toast.error('请先选择一个群聊')
    return
  }

  if (!reason || !reason.trim()) {
    toast.error('请输入举报原因')
    return
  }

  console.log('🔄 举报群聊:', {
    groupId: selectedChat.value.id,
    groupName: selectedChat.value.name,
    reason
  })

  try {
    isReportingGroup.value = true

    // 调用举报 API
    const response = await MessageApi.reportGroup({
      roomId: selectedChat.value.id,
      reason: reason.trim()
    })

    if (response.success) {
      console.log('✅ 举报成功')
      toast.success('举报已提交，感谢您的反馈')

      // 关闭对话框
      showReportDialog.value = false
    } else {
      throw new Error(response.message || '举报失败')
    }
  } catch (error: any) {
    console.error('❌ 举报失败:', error)
    toast.error('举报失败: ' + (error.message || '网络错误'))
  } finally {
    isReportingGroup.value = false
  }
}

const handleLeaveGroup = async () => {
  if (!selectedChat.value) return

  try {
    const confirmed = confirm('确定要退出该群聊吗？')
    if (!confirmed) return

    console.log('退出群聊:', selectedChat.value.id)
    const response = await MessageApi.leaveGroup({
      roomId: selectedChat.value.id,
    })

    if (response.success) {
      toast.success('已退出群聊')
      // 从聊天列表中移除
      const index = chatList.value.findIndex(chat => chat.id === selectedChat.value?.id)
      if (index > -1) {
        chatList.value.splice(index, 1)
      }
      // 清空选中状态
      selectedChat.value = null
      messageList.value = []
      // 关闭群设置
      showGroupSettings.value = false
    } else {
      throw new Error(response.message || '退出失败')
    }
  } catch (error: any) {
    console.error('退出群聊失败:', error)
    toast.error('退出失败: ' + (error.message || '网络错误'))
  }
}

// 语音功能
const handleVoiceClick = () => {
  console.log('打开语音录制')
  showVoiceRecorder.value = true
}

const closeVoiceRecorder = () => {
  console.log('关闭语音录制')
  showVoiceRecorder.value = false
}

const handleVoiceSend = async (recording: any) => {
  if (!selectedChat.value) return

  try {
    console.log('发送语音消息:', recording)

    // 1. 获取语音上传签名
    const signatureResponse = await MessageApi.generateMessageAttachmentSignature({
      roomId: selectedChat.value.id,
      partType: 4, // AUDIO_CONTENT_TYPE
      filename: `voice_${recording.id}.webm`,
      contentType: 'audio/webm',
      fileSize: recording.blob.size,
    })

    if (!signatureResponse.success || !signatureResponse.data) {
      throw new Error(signatureResponse.message || '获取上传签名失败')
    }

    // 2. 直接上传到COS
    const { key, signature } = signatureResponse.data
    const headers = new Headers(signature.headers || {})
    headers.set('Content-Type', 'audio/webm')
    if (!headers.has('Content-Length')) {
      headers.set('Content-Length', String(recording.blob.size))
    }

    const voiceBuffer = new Uint8Array(await recording.blob.arrayBuffer())
    const uploadResponse = await rustHttp.requestRaw({
      path: signature.url,
      method: (signature.method || 'PUT').toUpperCase() as HttpRequestParams['method'],
      headers,
      binaryBody: voiceBuffer,
      injectToken: false,
      forceStreaming: true
    })

    if (!uploadResponse.success) {
      throw new Error(uploadResponse.message || '文件上传失败')
    }

    // 3. 创建语音消息
    const messageResponse = await MessageApi.sendMessage({
      groupId: selectedChat.value.id,
      content: '', // 语音消息通常不包含文字内容
      parts: [{
        partType: 4, // AUDIO_CONTENT_TYPE
        objectKey: key,
        originalName: `voice_${recording.id}.webm`,
        mimeType: 'audio/webm',
        duration: Math.round(recording.duration),
      }],
    })

    if (messageResponse.success && messageResponse.data) {
      toast.success('语音消息发送成功')
      // 关闭录音弹窗
      closeVoiceRecorder()
    } else {
      throw new Error(messageResponse.message || '发送消息失败')
    }
  } catch (error: any) {
    console.error('发送语音消息失败:', error)
    toast.error('发送失败: ' + (error.message || '网络错误'))
  }
}
</script>

<style lang="scss" scoped>
// Variables are now globally imported via vite.config.ts

.chat-page {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.chat-header {
  padding: 16px 20px 16px 0; // 上 右 下 左，左侧设为0
  display: flex;
  align-items: center;
  height: 76px;
  box-sizing: border-box;
  flex-shrink: 0;
  
  .header-left {
    min-width: 300px;
    max-width: 70vw;
    display: flex;
    align-items: center;
    gap: 16px;
    margin-right: 20px;
    padding-left: 20px; // 恢复左侧内边距
    padding-right: 20px;
    box-sizing: border-box;
    
    .menu-icon {
      width: 24px;
      height: 24px;
      flex-shrink: 0;
      cursor: pointer;
      transition: opacity 0.2s;
      
      &:hover {
        opacity: 0.7;
      }
    }
    
    // 搜索组件占据剩余空间
    :deep(.search-input) {
      flex: 1;
    }
  }
  
  h2 {
    margin: 0;
    color: #262626;
    flex: 1;
  }
  
  .chat-header-right {
    display: flex;
    align-items: center;
    gap: 12px;
    flex: 1;
    height: 100%;
    overflow: hidden;

    .chat-info {
      display: flex;
      flex-direction: column;
      justify-content: center;
      gap: 2px;
      flex: 1; /* 让chat-info占用剩余空间，但为按钮留出位置 */

      .chat-title {
        margin: 0;
        font-size: 14px;
        font-weight: bold;
        color: #2C2D3A;
        line-height: 1.2;
      }

      .chat-member-count {
        font-size: 12px;
        color: $settings-label-color; /* 使用全局变量 #686A8A */
        line-height: 1;
      }
    }

    // 兼容旧的直接 chat-title 结构
    .chat-title {
      margin: 0;
      font-size: 14px;
      font-weight: bold;
      color: #2C2D3A;
    }

    .group-settings-btn {
      width: 24px;
      height: 24px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: opacity 0.2s;

      &:hover {
        opacity: 0.7;
      }

      .settings-icon {
        width: 24px;
        height: 24px;
      }
    }
  }
}

.chat-content {
  flex: 1;
  display: flex;
  overflow: hidden;
}

.chat-list {
  min-width: 300px;
  max-width: 70vw;
  overflow-y: auto;
  flex-shrink: 0;
}

.resize-handle {
  width: 2px;
  background-color: transparent;
  cursor: col-resize;
  position: relative;
  flex-shrink: 0;
  
  &:hover {
    background-color: rgba($primary-color, 0.1);
    
    .resize-line {
      background-color: $primary-color;
    }
  }
  
  &:active {
    background-color: rgba($primary-color, 0.15);
    
    .resize-line {
      background-color: $primary-dark;
    }
  }
}

.resize-line {
  width: 1px;
  height: 100%;
  background-color: #f0f0f0;
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
  transition: background-color 0.2s;
}

.chat-item {
  display: flex;
  align-items: center;
  height: 72px;
  padding: 0 16px;
  cursor: pointer;
  transition: background-color 0.2s;
  border-bottom: 1px solid #f0f0f0;
  
  &:hover {
    background-color: #f5f5f5;
  }
  
  &.is-top {
    background-color: #f4f5f6;
  }

  &.selected {
    background-color: #F5F5F5;
  }

    .chat-info {
      flex: 1;
      margin-left: 12px;
      min-width: 0;
      display: flex;
      flex-direction: column;
      justify-content: center;
      
      .chat-name-time {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 4px;
        
        .chat-name {
          font-weight: 500;
          font-size: 16px;
          color: $chat-name-color;
          line-height: 1.2;
          white-space: nowrap;
          overflow: hidden;
          text-overflow: ellipsis;
          flex: 1;
          margin-right: 8px;
        }
        
        .chat-time {
          font-size: 12px;
          color: $chat-message-color;
          white-space: nowrap;
          flex-shrink: 0;
        }
      }
      
      .chat-message {
        font-size: 14px;
        color: $chat-message-color;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        line-height: 1.2;
      }
    }
}

.chat-window {
  flex: 1;
  display: flex;
  flex-direction: column;
  background-color: $bg-chat;
}


.chat-messages {
  flex: 1;
  padding: 24px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
}

.message {
  display: flex;
  align-items: flex-end; /* 改为底部对齐，让圈圈和消息气泡底部对齐 */
  gap: 8px;
  position: relative; /* 添加相对定位以支持绝对定位的加载动画 */
  margin-bottom: 8px; /* 添加消息间距 */

  &.own-message {
    flex-direction: row-reverse;

    .message-content {
      background-color: $primary-color;
      color: white;
      padding: 12px 16px;
      border-radius: 16px 16px 0 16px; /* 右下角0px，其余16px */
      white-space: pre-wrap; /* 保留换行符和空格 */
      font-size: 16px;
      overflow: hidden; /* 防止内容溢出 */

      // 媒体消息特殊处理 - 自己的消息
      .media-message {
        margin: -4px; /* 抵消padding，让媒体内容贴边 */
        border-radius: 8px;
        overflow: hidden;

        .message-image {
          max-width: 200px;
          max-height: 200px;
          width: auto;
          height: auto;
          border-radius: 8px;
        }

        .video-container {
          max-width: 280px; /* 确保不超出气泡 */
          border-radius: 8px;
        }

        .video-placeholder {
          max-width: 280px; /* 确保不超出气泡 */
          border-radius: 8px;
        }

        .video-thumbnail {
          max-width: 200px;
          max-height: 200px;
          border-radius: 8px;
        }
      }

      .message-time {
        font-size: 12px;
        color: $message-time-color;
        margin-top: 8px;
        text-align: right;
        line-height: 1;
      }

      .message-edited-flag {
        margin-left: 6px;
        font-size: 12px;
        color: $message-time-color;
      }
    }
  }

  .message-wrapper {
    display: flex;
    flex-direction: column;
    max-width: 60%;

    .message-sender-name {
      font-size: 12px;
      line-height: 16px;
      color: $message-sender-name-color;
      margin-bottom: 8px;
    }
  }

  .message-content {
    background-color: #ffffff;
    padding: 12px 16px;
    border-radius: 0 16px 16px 16px; /* 左上角0px，其余16px */
    max-width: 60%;
    word-wrap: break-word;
    white-space: pre-wrap; /* 保留换行符和空格 */
    font-size: 16px;
    color: $text-primary;
    overflow: hidden; /* 防止内容溢出 */

    // 媒体消息特殊处理 - 他人消息
    .media-message {
      margin: -4px; /* 抵消padding，让媒体内容贴边 */
      border-radius: 8px;
      overflow: hidden;

      .message-image {
        max-width: 200px;
        max-height: 200px;
        width: auto;
        height: auto;
        border-radius: 8px;
      }

      .video-container {
        max-width: 280px; /* 确保不超出气泡 */
        border-radius: 8px;
      }

      .video-placeholder {
        max-width: 280px; /* 确保不超出气泡 */
        border-radius: 8px;
      }

      .video-thumbnail {
        max-width: 200px;
        max-height: 200px;
        border-radius: 8px;
      }
    }

    .message-time-other {
      font-size: 12px;
      color: $message-time-other-color;
      margin-top: 8px;
      text-align: left;
      line-height: 1;
      white-space: nowrap; /* 防止时间换行 */
    }

    .message-edited-flag {
      margin-left: 6px;
      font-size: 12px;
      color: $message-time-other-color;
    }
  }
}

.chat-input {
  padding: 16px 24px 40px 24px;
  
  .input-container {
    display: flex;
    align-items: flex-end; /* 恢复flex-end，这样多行时图标靠底部 */
    min-height: 54px;
    width: 100%;
    background: white;
    border-radius: 12px;
    box-shadow: 0px 0px 10px 0px #0000000D;
    padding: 15px 20px;
    box-sizing: border-box;
    position: relative; /* 为表情选择器提供定位基础 */
    gap: 16px;

    input, textarea {
      flex: 1;
      border: none;
      outline: none;
      font-size: 14px;
      color: #262626;
      background: transparent;
      resize: none;
      line-height: 20px;
      min-height: 20px;
      max-height: 100px;
      overflow-y: auto;
      word-wrap: break-word;
      white-space: pre-wrap;

      &::placeholder {
        color: #8c8c8c;
      }
    }

    .input-left-actions {
      display: flex;
      align-items: center;
      gap: 16px;
      margin-bottom: 2px; /* 稍微上移，与textarea文本行对齐 */
    }

    .input-right-actions {
      display: flex;
      align-items: center;
      margin-bottom: 2px; /* 稍微上移，与textarea文本行对齐 */
    }

    .action-icon {
      width: 24px;
      height: 24px;
      cursor: pointer;
      flex-shrink: 0;
      transition: opacity 0.2s;

      &:hover {
        opacity: 0.7;
      }

      &:active {
        opacity: 0.5;
      }
    }

    .emoji-icon {
      // 表情图标特殊样式
    }

    .upload-icon {
      // 上传图标特殊样式
    }

    .voice-icon {
      // 语音图标特殊样式
      &:hover {
        transform: scale(1.05);
      }
    }

    .send-icon {
      // 发送图标特殊样式
    }
  }
}

.empty-chat {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #8c8c8c;
}

.loading-container, .empty-container {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 40px 20px;
  color: #8c8c8c;
  font-size: 14px;
}

.loading-text, .empty-text {
  text-align: center;
}

.debug-info {
  margin-top: 16px;
  padding: 12px;
  background-color: #f0f8ff;
  border-radius: 8px;
  border: 1px solid #e1f5fe;
  
  .debug-text {
    font-size: 14px;
    color: #1976d2;
    margin-bottom: 8px;
  }
  
  .debug-details {
    font-size: 12px;
    color: #666;
    font-family: monospace;
  }
}

.message-failed {
  opacity: 0.6;
}


.menu-popup {
  .popover-item {
    display: flex;
    align-items: center;
    padding: 12px 16px;
    cursor: pointer;
    transition: background-color 0.2s ease;
    
    &:hover {
      background-color: #f5f5f5;
    }
    
    .popover-icon {
      width: 24px;
      height: 24px;
      margin-right: 8px;
      flex-shrink: 0;
    }
    
    .popover-label {
      font-size: 14px;
      color: #707991;
      white-space: nowrap;
    }
  }
}



// 新增样式：聊天列表增强
.chat-message-badge {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-top: 4px;
}

.chat-badge {
  background: #ff4757;
  color: white;
  border-radius: 10px;
  padding: 2px 6px;
  font-size: 12px;
  font-weight: bold;
  min-width: 18px;
  text-align: center;
  line-height: 14px;
}

.top-indicator {
  font-size: 12px;
  margin-left: 4px;
  color: #ffa502;
}

.chat-type {
  font-size: 10px;
  color: #999;
  margin-left: 4px;
  background: #f0f0f0;
  padding: 1px 4px;
  border-radius: 3px;
}

// 重发按钮样式
.resend-btn {
  background: #1890ff;
  color: white;
  border: none;
  padding: 2px 6px;
  margin-left: 8px;
  border-radius: 3px;
  font-size: 10px;
  cursor: pointer;
  transition: background-color 0.2s;
  
  &:hover {
    background: #40a9ff;
  }
  
  &:active {
    background: #096dd9;
  }
}

// 消息加载指示器容器 - 使用正常文档流，底部对齐
.message-loading-indicator {
  display: inline-flex;
  align-items: flex-end; // 改为底部对齐
  margin-left: 8px;
  margin-right: 8px;
}

// 移除message-content的相对定位
.message-content {
  // position: relative; 已移除
}

// 对于他人消息，message-content-row使用flex布局
.message:not(.own-message) .message-wrapper {
  display: flex;
  flex-direction: column;
  max-width: 60%;
}

// 对于自己的消息，也使用flex布局
.message.own-message {
  .message-content {
    display: inline-block;
  }
}

// 加载动画样式
.loading-spinner {
  width: 12px;
  height: 12px;
  border: 2px solid #f3f3f3;
  border-top: 2px solid #999999; // 改为灰色
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

// 发送状态样式调整
.message-status {
  display: flex;
  align-items: center;
  justify-content: flex-start;
  margin-top: 4px;
  font-size: 12px;
  
  &.sending {
    color: #1890ff;
  }
  
  &.failed {
    color: #ff4d4f;
  }
}

/* 滚动条美化样式 */
::-webkit-scrollbar {
  width: 4px;
  height: 4px;
}

::-webkit-scrollbar-track {
  background: transparent;
}

::-webkit-scrollbar-thumb {
  background-color: #CCCCCC;
  border-radius: 2px;
}

::-webkit-scrollbar-thumb:hover {
  background-color: #BBBBBB;
}

/* 针对Firefox的滚动条样式 */
* {
  scrollbar-width: thin;
  scrollbar-color: #CCCCCC transparent;
}

// 系统消息特殊样式
.system-message {
  display: flex;
  justify-content: center;
  margin: 16px 0;

  .system-message-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    max-width: 80%;

    .system-message-text {
      background-color: rgba(0, 0, 0, 0.05);
      color: #666;
      padding: 8px 16px;
      border-radius: 16px;
      font-size: 14px;
      text-align: center;
      line-height: 1.4;
    }

    .system-message-time {
      font-size: 12px;
      color: #999;
      margin-top: 4px;
      text-align: center;
    }
  }
}

// 媒体消息样式
.media-message {
  margin: 4px 0;

  .media-name {
    font-size: 12px;
    color: #666;
    margin-top: 4px;
    opacity: 0.8;
  }
}

.message-image {
  max-width: 200px;
  max-height: 200px;
  border-radius: 8px;
  cursor: pointer;
  transition: opacity 0.2s;
  display: block;

  &:hover {
    opacity: 0.8;
  }
}

// 图片加载占位符
.image-loading-placeholder {
  width: 200px;
  height: 120px;
  background: #f5f5f5;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px dashed #ddd;

  .loading-text {
    color: #999;
    font-size: 14px;
  }
}

// 上传中的图片特殊样式
.message.own-message .message-content .media-message .message-image {
  // 如果是自己发送且正在上传，添加上传指示器
  position: relative;
}

// 上传中的图片遮罩（可选）
.message-image.uploading {
  opacity: 0.8;
  position: relative;

  &::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.1);
    border-radius: 8px;
    pointer-events: none;
  }
}

.message-video {
  max-width: 300px;
  max-height: 200px;
  border-radius: 8px;
  display: block;
}

// 视频相关样式
.video-container {
  position: relative;
  display: inline-block;
  cursor: pointer;
  border-radius: 8px;
  overflow: hidden;

  &:hover .video-play-overlay {
    opacity: 0.9;
  }
}

.video-thumbnail {
  max-width: 200px;
  max-height: 200px;
  border-radius: 8px;
  display: block;
  transition: opacity 0.2s;
}

.video-play-overlay {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 60px;
  height: 60px;
  background-color: rgba(0, 0, 0, 0.6);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0.8;
  transition: opacity 0.2s;

  .play-icon {
    color: white;
    font-size: 24px;
    margin-left: 3px; // 视觉上让播放图标居中
  }
}

// 视频占位符样式
.video-placeholder {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  background-color: #f3f4f6;
  border-radius: 8px;
  min-width: 200px;
  max-width: 300px;

  .video-icon {
    font-size: 32px;
    margin-right: 12px;
  }

  .video-info {
    flex: 1;

    .video-filename {
      font-size: 14px;
      font-weight: 500;
      color: #374151;
      margin-bottom: 4px;
      word-break: break-all;
    }

    .video-size {
      font-size: 12px;
      color: #6b7280;
    }
  }
}

.video-thumbnail-wrapper {
  display: block;
}

// 针对自己发送的消息，媒体内容需要特殊处理
.own-message {
  .media-message {
    .media-name {
      color: rgba(255, 255, 255, 0.8);
    }
  }

  .video-placeholder {
    background-color: rgba(255, 255, 255, 0.1);

    .video-info .video-filename {
      color: rgba(255, 255, 255, 0.9);
    }

    .video-info .video-size {
      color: rgba(255, 255, 255, 0.7);
    }
  }
}

// 群名输入对话框样式
.group-name-content {
  padding: 16px 8px;

  :deep(.dialog-input) {
    width: 100%;
    border-radius: 22px;
    padding: 0 20px;
    font-size: 14px;

    &::placeholder {
      font-size: 14px;
    }
  }

  .group-name-error {
    margin-top: 12px;
    padding: 8px 12px;
    background-color: #fef2f2;
    border: 1px solid #fecaca;
    border-radius: 8px;
    color: #dc2626;
    font-size: 14px;
  }
}

// 搜索高亮样式
.search-highlighted {
  background-color: #fef3c7 !important;
  border-radius: 6px;
  box-shadow: 0 0 0 2px #f59e0b;
  animation: highlight-fade 2s ease-in-out;
}

@keyframes highlight-fade {
  0% {
    background-color: #f59e0b;
    transform: scale(1.02);
  }
  100% {
    background-color: #fef3c7;
    transform: scale(1);
  }
}
</style>
