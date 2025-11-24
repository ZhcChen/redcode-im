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
        <Avatar
          :src="selectedChat.avatarLocalPath"
          :text="selectedChat.name"
          :size="42"
          :background-color="selectedChat.groupType === 2 ? 'var(--primary-color)' : undefined"
        />
        <div class="chat-info">
          <h2 class="chat-title">{{ selectedChat.name }}</h2>
          <div v-if="selectedChat.groupType === 1" class="chat-member-count">
            人数 {{ selectedChat.memberCount || 0 }}
          </div>
        </div>
        <!-- 群设置按钮 -->
        <div v-if="selectedChat.groupType === 1" class="group-settings-btn" @click="handleShowGroupSettings">
          <img src="@/assets/image/icon-menu.svg" alt="群设置" class="settings-icon" />
        </div>
        <!-- 单聊设置按钮 -->
        <div v-if="selectedChat.groupType === 0" class="group-settings-btn" @click="handleShowGroupSettings">
          <img src="@/assets/image/icon-menu.svg" alt="聊天设置" class="settings-icon" />
        </div>
      </div>
      <h2 v-else></h2>
    </div>
    
    <div class="chat-content">
      <ScrollContainer
        class="chat-list"
        :style="{ width: chatListWidth + 'px' }"
      >
        <!-- 只有在初始加载且没有缓存数据时才显示loading -->
        <div v-if="loading && chatList.length === 0" class="loading-container">
          <div class="loading-text">加载聊天列表中...</div>
        </div>
        <div v-else-if="!loading && chatList.length === 0" class="empty-container">
          <div class="empty-text">暂无聊天</div>
          <div v-if="routeQuery.contactId" class="debug-info">
            <div class="debug-text">正在处理联系人聊天请求...</div>
            <div class="debug-details">联系人: {{ routeQuery.contactName }} (ID: {{ routeQuery.contactId }})</div>
          </div>
        </div>
        <div
          v-else
          class="chat-item"
          v-for="chat in chatList"
          :key="chat.id"
          @click="selectChat(chat)"
          @contextmenu.prevent="handleChatContextMenu(chat, $event)"
          :class="{
            'is-top': chat.isTop,
            selected: selectedChat && selectedChat.id === chat.id
          }"
        >
          <div class="avatar-container">
            <Avatar
              :src="chat.avatarLocalPath"
              :text="chat.name"
              :size="48"
              :background-color="chat.groupType === 2 ? 'var(--primary-color)' : undefined"
            />
            <!-- 免打扰状态的小红点 -->
            <div v-if="chat.chatStatus === 1 && chat.unreadCount > 0" class="mute-dot"></div>
          </div>
          <div class="chat-info">
            <div class="chat-name-time">
              <div class="chat-name">
                {{ chat.name }}
                <span v-if="chat.isTop" class="top-indicator">📌</span>
              </div>
              <div class="chat-time">{{ chat.time }}</div>
            </div>
            <div class="chat-message-badge">
              <div class="chat-message">{{ chat.lastMessage }}</div>
              <!-- 非免打扰状态显示未读角标 -->
              <div
                v-if="chat.unreadCount > 0 && chat.chatStatus !== 1"
                :class="['chat-badge', { 'is-single-digit': chat.unreadCount < 10 }]"
              >
                {{ chat.unreadCount }}
              </div>
            </div>
          </div>
        </div>
      </ScrollContainer>

      <div class="resize-handle" 
           @mousedown="startResize"
           @dblclick="resetWidth">
        <div class="resize-line"></div>
      </div>
      
      <div class="chat-window" v-if="selectedChat">
        <ScrollContainer
          class="chat-messages"
          :class="{ 'multi-select-active': multiSelectMode, 'drag-selecting': isDragSelectingClass }"
          ref="chatMessagesRef"
          @mousedown.left="handleMouseDownOnMessages"
          @mousemove="handleMouseMoveOnMessages"
          @mouseup="handleMouseUpOnMessages"
        >
          <div v-if="messages.length === 0" class="empty-container">
            <div class="empty-text">暂无消息，开始聊天吧</div>
          </div>
          <div
            v-else
            class="message"
            v-for="message in messages"
            :key="message.id"
            :data-message-id="message.id"
            :class="{
              'own-message': message.isSelf,
              'message-failed': message.status === 5,
              'system-message': message.messageType === MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG,
              'selected-message': isMessageSelected(message)
            }"
            @contextmenu.prevent="handleMessageContextMenu(message, $event)"
            @click="toggleMessageSelection(message)"
            @mouseenter="handleMessageHover(message)"
          >
            <!-- 系统消息特殊显示 -->
            <div v-if="message.messageType === MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG" class="system-message-content">
              <div class="system-message-text">{{ getTextContent(message) }}</div>
              <div class="system-message-time">{{ formatMessageTime(message.createTime || message.time) }}</div>
            </div>

            <!-- 普通用户消息 -->
            <template v-else>
            <!-- 多选指示器 - 其他用户消息 -->
            <div
              v-if="multiSelectMode && !message.isSelf"
              class="select-indicator other"
              :class="{ active: isMessageSelected(message) }"
              @click.stop="handleIndicatorClick(message)"
            >
              ✓
            </div>
            <Avatar v-if="!message.isSelf" :src="message.senderAvatarLocalPath" :text="message.senderName" :size="40" />
            <div v-if="!message.isSelf" class="message-wrapper">
              <div class="message-sender-name">{{ message.senderName }}</div>
              <div class="message-content">
                <!-- 引用消息预览 -->
                <template v-if="message.quotedMessage">
                  <div class="quoted-block" @click.stop="scrollToQuoted(message.quotedMessage)">
                    <div class="quoted-header">
                      <Avatar
                        :src="getQuotedAvatar(message.quotedMessage)
                          || getSenderAvatarById(message.quotedMessage.senderId)
                          || undefined"
                        :text="getQuotedInitial(message.quotedMessage)"
                        :size="24"
                      />
                      <div class="quoted-sender">{{ getQuotedSenderName(message.quotedMessage) }}</div>
                    </div>
                    <div class="quoted-text">{{ getQuotedText(message.quotedMessage) }}</div>
                  </div>
                </template>

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

                <!-- 文件消息 -->
                <template v-else-if="message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.FILE_CONTENT_TYPE">
                  <div class="file-message" @click="handleFileDownload(message)">
                    <div class="file-icon-wrapper">
                      <div class="file-icon" :class="getFileIconClass(message)">
                        <!-- 压缩包图标 -->
                        <svg v-if="getFileIconType(message) === 'archive'" width="32" height="32" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M4 6h16v2H4V6zm0 4h16v10H4V10zm2 2v6h12v-6H6z" fill="currentColor"/>
                          <path d="M6 8h12v2H6V8z" fill="currentColor" opacity="0.5"/>
                        </svg>
                        <!-- 文本文件图标 -->
                        <svg v-else-if="getFileIconType(message) === 'text'" width="32" height="32" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M5 4v3h5.5v12h3V7H19V4H5zm-1-2h16a1 1 0 011 1v19a1 1 0 01-1 1H4a1 1 0 01-1-1V3a1 1 0 011-1z" fill="currentColor"/>
                          <path d="M7 9h10v1.5H7V9zm0 3h10v1.5H7V12zm0 3h7v1.5H7V15z" fill="currentColor" opacity="0.3"/>
                        </svg>
                        <!-- 其他文件图标（问号） -->
                        <svg v-else width="32" height="32" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" fill="none"/>
                          <path d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3M12 17h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
                        </svg>
                      </div>
                      <!-- 下载进度圆圈 -->
                      <div v-if="isFileDownloading(message) || isMessageUploading(message)" class="file-progress-circle">
                        <svg class="progress-svg" width="48" height="48">
                          <circle
                            class="progress-background"
                            cx="24"
                            cy="24"
                            r="20"
                            fill="none"
                            stroke="rgba(0,0,0,0.1)"
                            stroke-width="3"
                          />
                          <circle
                            class="progress-bar"
                            cx="24"
                            cy="24"
                            r="20"
                            fill="none"
                            :stroke="message.isSelf ? '#fff' : '#007AFF'"
                            stroke-width="3"
                            stroke-linecap="round"
                            :stroke-dasharray="2 * Math.PI * 20"
                            :stroke-dashoffset="2 * Math.PI * 20 * (1 - getFileProgress(message))"
                            transform="rotate(-90 24 24)"
                          />
                        </svg>
                        <div class="progress-text">{{ Math.round(getFileProgress(message) * 100) }}%</div>
                      </div>
                      <!-- 下载图标 -->
                      <div v-else-if="shouldShowDownloadIcon(message)" class="file-download-icon">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                          <path d="M12 15.577l-3.539-3.538 1.414-1.414L11 12.586V3h2v9.586l1.125-1.125 1.414 1.414L12 15.577zm-7 4.423h14v2H5v-2z" fill="currentColor"/>
                        </svg>
                      </div>
                    </div>
                    <div class="file-info">
                      <div class="file-name">{{ getFileName(message) }}</div>
                      <div class="file-size" v-if="getFileSize(message)">{{ formatFileSize(getFileSize(message)) }}</div>
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
            <!-- 多选指示器 - 自己的消息 -->
            <div
              v-if="multiSelectMode && message.isSelf"
              class="select-indicator self"
              :class="{ active: isMessageSelected(message) }"
              @click.stop="handleIndicatorClick(message)"
            >
              ✓
            </div>
            <div v-if="message.isSelf" class="message-content">
              <template v-if="message.quotedMessage">
                <div class="quoted-block" @click.stop="scrollToQuoted(message.quotedMessage)">
                  <div class="quoted-header">
                    <Avatar
                      :src="getQuotedAvatar(message.quotedMessage)
                        || getSenderAvatarById(message.quotedMessage.senderId)
                        || undefined"
                      :text="getQuotedInitial(message.quotedMessage)"
                      :size="24"
                    />
                    <div class="quoted-sender">{{ getQuotedSenderName(message.quotedMessage) }}</div>
                  </div>
                  <div class="quoted-text">{{ getQuotedText(message.quotedMessage) }}</div>
                </div>
              </template>

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

              <!-- 文件消息 -->
              <template v-else-if="message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.FILE_CONTENT_TYPE">
                <div class="file-message" @click="handleFileDownload(message)">
                  <div class="file-icon-wrapper">
                    <div class="file-icon" :class="getFileIconClass(message)">
                      <!-- 压缩包图标 -->
                      <svg v-if="getFileIconType(message) === 'archive'" width="32" height="32" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M4 6h16v2H4V6zm0 4h16v10H4V10zm2 2v6h12v-6H6z" fill="currentColor"/>
                        <path d="M6 8h12v2H6V8z" fill="currentColor" opacity="0.5"/>
                      </svg>
                      <!-- 文本文件图标 -->
                      <svg v-else-if="getFileIconType(message) === 'text'" width="32" height="32" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M5 4v3h5.5v12h3V7H19V4H5zm-1-2h16a1 1 0 011 1v19a1 1 0 01-1 1H4a1 1 0 01-1-1V3a1 1 0 011-1z" fill="currentColor"/>
                        <path d="M7 9h10v1.5H7V9zm0 3h10v1.5H7V12zm0 3h7v1.5H7V15z" fill="currentColor" opacity="0.3"/>
                      </svg>
                      <!-- 其他文件图标（问号） -->
                      <svg v-else width="32" height="32" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" fill="none"/>
                        <path d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3M12 17h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
                      </svg>
                    </div>
                    <!-- 下载进度圆圈 -->
                    <div v-if="isFileDownloading(message) || isMessageUploading(message)" class="file-progress-circle">
                      <svg class="progress-svg" width="48" height="48">
                        <circle
                          class="progress-background"
                          cx="24"
                          cy="24"
                          r="20"
                          fill="none"
                          stroke="rgba(0,0,0,0.1)"
                          stroke-width="3"
                        />
                        <circle
                          class="progress-bar"
                          cx="24"
                          cy="24"
                          r="20"
                          fill="none"
                          :stroke="message.isSelf ? '#fff' : '#007AFF'"
                          stroke-width="3"
                          stroke-linecap="round"
                          :stroke-dasharray="2 * Math.PI * 20"
                          :stroke-dashoffset="2 * Math.PI * 20 * (1 - getFileProgress(message))"
                          transform="rotate(-90 24 24)"
                        />
                      </svg>
                      <div class="progress-text">{{ Math.round(getFileProgress(message) * 100) }}%</div>
                    </div>
                    <!-- 下载图标 -->
                    <div v-else-if="shouldShowDownloadIcon(message)" class="file-download-icon">
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <path d="M12 15.577l-3.539-3.538 1.414-1.414L11 12.586V3h2v9.586l1.125-1.125 1.414 1.414L12 15.577zm-7 4.423h14v2H5v-2z" fill="currentColor"/>
                      </svg>
                    </div>
                  </div>
                  <div class="file-info">
                    <div class="file-name">{{ getFileName(message) }}</div>
                    <div class="file-size" v-if="getFileSize(message)">{{ formatFileSize(getFileSize(message)) }}</div>
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
                <svg v-if="message.isSelf && message.status === 2" class="message-status-icon sent" width="16" height="16" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path fill-rule="evenodd" clip-rule="evenodd" d="M9.03789 4.04543C9.21991 4.20434 9.23865 4.48071 9.07974 4.66273L4.49641 9.91273C4.41333 10.0079 4.29317 10.0625 4.16684 10.0625C4.04051 10.0625 3.92034 10.0079 3.83726 9.91273L2.00393 7.81273C1.84502 7.63071 1.86376 7.35434 2.04578 7.19543C2.2278 7.03652 2.50417 7.05526 2.66308 7.23728L4.16684 8.95977L8.42059 4.08728C8.5795 3.90526 8.85587 3.88652 9.03789 4.04543Z" fill="currentColor"/>
                </svg>
                <svg v-if="message.isSelf && message.status === 4" class="message-status-icon read" width="16" height="16" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path fill-rule="evenodd" clip-rule="evenodd" d="M9.03789 4.04543C9.21991 4.20434 9.23865 4.48071 9.07974 4.66273L4.49641 9.91273C4.41333 10.0079 4.29317 10.0625 4.16684 10.0625C4.04051 10.0625 3.92034 10.0079 3.83726 9.91273L2.00393 7.81273C1.84502 7.63071 1.86376 7.35434 2.04578 7.19543C2.2278 7.03652 2.50417 7.05526 2.66308 7.23728L4.16684 8.95977L8.42059 4.08728C8.5795 3.90526 8.85587 3.88652 9.03789 4.04543Z" fill="currentColor"/>
                  <path fill-rule="evenodd" clip-rule="evenodd" d="M11.9687 4.09469C12.1436 4.26133 12.1504 4.53825 11.9838 4.71322L6.98361 9.96322C6.89524 10.056 6.77064 10.1054 6.6427 10.0983C6.51476 10.0913 6.39635 10.0285 6.31872 9.92654L6.06887 9.59841C5.92249 9.40618 5.95966 9.13167 6.1519 8.98529C6.31705 8.85954 6.54291 8.86925 6.69609 8.99637L11.3501 4.10976C11.5168 3.9348 11.7937 3.92805 11.9687 4.09469Z" fill="currentColor"/>
                </svg>
              </div>
            </div>
            <div v-if="message.status === 5" class="message-status failed">
              发送失败
              <button v-if="message.isSelf" @click="resendMessage(message)" class="resend-btn">重发</button>
            </div>
            <!-- 加载动画放在消息框外面左下角 -->
            <div v-if="message.status === 1" class="message-loading-indicator">
              <div class="loading-spinner"></div>
            </div>
            </template>
          </div>
        </ScrollContainer>
        <div class="chat-input">
          <div v-if="replyingMessage" class="reply-bar">
            <div class="reply-title">回复 {{ replyingMessage.senderName }}</div>
            <div class="reply-content">{{ getTextContent(replyingMessage) }}</div>
            <button class="reply-close" @click="clearReplyingMessage">×</button>
          </div>
          <div v-if="multiSelectMode" class="multi-select-bar">
            <div class="multi-select-count">已选择 {{ selectedMessagesCount }} 条</div>
            <div class="multi-select-actions">
              <button class="btn" @click="exitMultiSelect">取消</button>
              <button class="btn" :disabled="selectedMessagesCount === 0" @click="handleMessageMenuForward">转发</button>
              <button class="btn danger" :disabled="selectedMessagesCount === 0" @click="deleteSelectedMessages">删除</button>
            </div>
          </div>
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

    <!-- 创建群聊对话框 -->
    <CreateGroupDialog
      v-model:visible="showCreateGroupDialog"
      :contacts="contacts"
      :is-loading-contacts="isLoadingContacts"
      @create="handleCreateGroupConfirm"
      @load-contacts="loadContactsForGroup"
      @close="handleCancelCreateGroup"
    />

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

    <!-- 修改备注对话框 -->
    <Dialog
      v-model="showEditRemarkDialog"
      title="修改备注"
      @confirm="handleConfirmEditRemark"
      @cancel="handleCancelEditRemark"
      :confirm-text="isUpdatingRemark ? '保存中...' : '保存'"
      :confirm-disabled="isUpdatingRemark"
    >
      <div class="group-name-content">
        <DialogInput
          v-model="editingRemark"
          placeholder="请输入备注..."
          :disabled="isUpdatingRemark"
          maxlength="20"
          @keyup.enter="handleConfirmEditRemark"
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
      :is-group-owner="isCurrentUserGroupOwner"
      :global-mute-enabled="groupSettings?.globalMuteEnabled ?? false"
      :global-mute-loading="groupSettingsLoading || updatingGlobalMute"
      @close="showGroupSettings = false"
      @edit-group-name="handleEditGroupName"
      @edit-group-avatar="handleEditGroupAvatar"
      @edit-group-notice="handleEditGroupNotice"
      @edit-remark="handleEditRemark"
      @toggle-mute="handleToggleMute"
      @toggle-top="handleToggleTop"
      @add-member="handleAddMember"
      @remove-member="handleRemoveMember"
      @clear-history="handleClearHistory"
      @report-group="handleReportGroup"
      @leave-group="handleLeaveGroup"
      @toggle-global-mute="handleToggleGlobalMute"
      @transfer-owner="openTransferOwnerDialog"
      @dissolve-group="handleDissolveGroup"
    />

    <Dialog
      :visible="showTransferOwnerDialog"
      title="选择新的群主"
      :show-footer="false"
      @close="closeTransferOwnerDialog"
    >
      <div class="transfer-owner-dialog" v-if="transferableMembers.length">
        <div
          v-for="member in transferableMembers"
          :key="member.userId"
          class="transfer-owner-item"
          :class="{ 'transfer-owner-item--selected': member.userId === selectedTransferOwnerId }"
          @click="selectedTransferOwnerId = member.userId"
        >
          <Avatar
            :src="member.avatarUrl || ''"
            :text="member.nickname || member.username"
            :size="40"
          />
          <div class="transfer-owner-item__info">
            <div class="transfer-owner-item__name">{{ member.nickname || member.username }}</div>
            <div class="transfer-owner-item__username">@{{ member.username }}</div>
          </div>
        </div>
        <div class="transfer-owner-actions">
          <button class="transfer-owner-btn" @click="closeTransferOwnerDialog">取消</button>
          <button
            class="transfer-owner-btn transfer-owner-btn--primary"
            :disabled="!selectedTransferOwnerId || transferringOwner"
            @click="confirmTransferOwner"
          >
            {{ transferringOwner ? '转让中…' : '确认转让' }}
          </button>
        </div>
      </div>
      <div v-else class="transfer-owner-empty">暂无可转让的成员</div>
    </Dialog>

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

  <!-- 聊天列表右键菜单 -->
  <ChatContextMenu
    v-model:visible="showContextMenu"
    :position="contextMenuPosition"
    :chat="contextMenuChat"
    @pin="handleContextMenuPin"
    @mute="handleContextMenuMute"
    @delete="handleContextMenuDelete"
  />

  <!-- 消息右键菜单 -->
  <MessageContextMenu
    v-model:visible="showMessageContextMenu"
    :position="messageContextMenuPosition"
    :can-copy="!!messageContextMenuTarget && canCopyMessage(messageContextMenuTarget)"
    :can-quote="!!messageContextMenuTarget && !messageContextMenuTarget.isDeleted"
    :can-forward="!!messageContextMenuTarget && canForwardMessage(messageContextMenuTarget)"
    :can-pin="!!messageContextMenuTarget && !messageContextMenuTarget.isDeleted"
    :is-pinned="!!messageContextMenuTarget?.pinnedAt"
    :can-download="!!messageContextMenuTarget && canDownloadMessage(messageContextMenuTarget)"
    :can-delete="!!messageContextMenuTarget && messageContextMenuTarget.isSelf"
    @copy="handleMessageMenuCopy"
    @quote="handleMessageMenuQuote"
    @forward="handleMessageMenuForward"
    @pin="handleMessageMenuPin"
    @download="handleMessageMenuDownload"
    @delete="handleMessageMenuDelete"
  />

  <!-- 删除对话确认对话框 -->
  <ConfirmDialog
    v-model:visible="showDeleteConfirm"
    title="删除对话"
    :message="`确定要删除与'${deleteTargetChat?.name}'的对话吗？`"
    description="此操作将永久删除该对话及其所有消息记录，无法恢复。"
    confirm-text="删除"
    cancel-text="取消"
    type="danger"
    @confirm="confirmDelete"
    @cancel="cancelDelete"
  />

  <!-- 转发选择对话框 -->
  <Dialog
    :visible="showForwardDialog"
    title="选择转发会话"
    @close="showForwardDialog = false"
  >
    <div class="forward-dialog">
      <ScrollContainer class="forward-list">
        <label
          v-for="chat in forwardableChats"
          :key="chat.id"
          class="forward-item"
        >
          <input
            type="checkbox"
            :value="chat.groupId"
            v-model="forwardTargetIds"
          />
          <span class="forward-name">{{ chat.name }}</span>
        </label>
      </ScrollContainer>
      <div class="forward-actions">
        <button class="btn" @click="showForwardDialog = false">取消</button>
        <button class="btn primary" @click="confirmForward">确认转发</button>
      </div>
    </div>
  </Dialog>
</div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch, nextTick, reactive } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useStore } from 'vuex'
import ScrollContainer from '../components/ScrollContainer.vue'

// Props: 接收账号ID（用于多实例页面架构）
interface Props {
  accountId?: string
}

const props = withDefaults(defineProps<Props>(), {
  accountId: undefined
})
import Avatar from '../components/Avatar.vue'
import SearchInput from '../components/SearchInput.vue'
import Popover from '../components/Popover.vue'
import SearchDialog from '../components/SearchDialog.vue'
import { messageSearchService } from '../services/messageSearchService'
import EmojiPicker from '../components/EmojiPicker.vue'
import AddGroupMemberDialog from '../components/AddGroupMemberDialog.vue'
import CreateGroupDialog from '../components/CreateGroupDialog.vue'
import RemoveGroupMemberDialog from '../components/RemoveGroupMemberDialog.vue'
import ReportDialog from '../components/ReportDialog.vue'
import Dialog from '../components/Dialog.vue'
import DialogInput from '../components/DialogInput.vue'
import MediaPreview from '../components/MediaPreview.vue'
import GroupSettingsDrawer from '../components/GroupSettingsDrawer.vue'
import VoiceMessage from '../components/VoiceMessage.vue'
import ChatContextMenu from '../components/ChatContextMenu.vue'
import MessageContextMenu from '../components/MessageContextMenu.vue'
import ConfirmDialog from '../components/ConfirmDialog.vue'
import { api, MessageApi } from '../api'
import type { DirectUploadSignatureInfo, MessagePartPayloadInput } from '../api/message'
import { GroupApi } from '../api/group'
import type { GroupSettings } from '../api/group'
import { FriendApi } from '../api/friend'
import { FileApi } from '../api/file'
import { UserApi } from '../api/user'
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
  [MessageStatus.DELIVERED]: 3,
  [MessageStatus.READ]: 4,
  [MessageStatus.FAILED]: 5
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

const sanitizeAttachmentForCache = (attachment: MessageAttachment | null | undefined, partType?: MessagePartType): MessageAttachment | null => {
  if (!attachment) {
    return null
  }
  // 对于所有类型都保留localPath，但清除blob URL（会在恢复时重新获取）
  const shouldKeepLocalPath = attachment.localPath && !attachment.localPath.startsWith('blob:');

  return {
    ...attachment,
    downloadUrl: null,
    uploadProgress: null,
    // 只缓存非blob URL的本地路径
    localPath: shouldKeepLocalPath ? attachment.localPath : null,
  }
}

const sanitizeMessageForCache = (message: Message): Message => {
  const sanitizedParts = message.parts?.map((part) => ({
    ...part,
    attachment: sanitizeAttachmentForCache(part.attachment ?? undefined, part.type),
  }))

  let sanitizedContent: Message['content'] = message.content
  if (typeof message.content === 'object' && message.content) {
    sanitizedContent = {
      ...message.content,
      downloadUrl: undefined,
      uploadProgress: undefined,
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
          downloadUrl: null,
          uploadProgress: null,
        }
      : part.attachment ?? null,
  }))

  let restoredContent: Message['content'] = cached.content
  if (typeof cached.content === 'object' && cached.content) {
    restoredContent = {
      ...cached.content,
      downloadUrl: undefined,
      uploadProgress: undefined,
      isUploading: false,
    }
  }

  return {
    ...cached,
    content: restoredContent,
    parts: restoredParts,
    // 清除缓存中的头像 URL 和 LocalPath，等待后续同步
    senderAvatar: undefined,
    senderAvatarLocalPath: undefined,
    senderAvatarObjectKey: cached.senderAvatarObjectKey,
  }
}

const persistMessagesCache = async (groupId: string, messageList: Message[]) => {
  if (!groupId) return
  const sliced = messageList.slice(-MESSAGES_CACHE_LIMIT).map((msg) => sanitizeMessageForCache(msg))
  await saveCache(CACHE_KEYS.messages(groupId), sliced)
}

/**
 * 合并后端消息和本地缓存，保留本地localPath等字段
 */
const mergeMessagesWithCache = (backendMessages: Message[], cachedMessages: Message[]): Message[] => {
  if (!cachedMessages || cachedMessages.length === 0) {
    return backendMessages;
  }

  const cacheMap = new Map<string, Message>();
  cachedMessages.forEach(msg => {
    cacheMap.set(msg.id, msg);
  });

  return backendMessages.map(backendMsg => {
    const cachedMsg = cacheMap.get(backendMsg.id);
    if (!cachedMsg) {
      return backendMsg;
    }

    // 合并 attachment 中的 localPath 等本地字段
    if (Array.isArray(backendMsg.parts) && Array.isArray(cachedMsg.parts)) {
      const mergedParts = backendMsg.parts.map((backendPart, index) => {
        const cachedPart = cachedMsg.parts?.[index];
        if (!cachedPart?.attachment || !backendPart?.attachment) {
          return backendPart;
        }

        // 先保留缓存中的所有字段，再覆盖需要更新的字段
        const mergedAttachment = {
          ...cachedPart.attachment,
          // 覆盖后端数据中的字段（这些字段更准确）
          key: backendPart.attachment.key,
          name: backendPart.attachment.name,
          mime: backendPart.attachment.mime,
          size: backendPart.attachment.size,
          width: backendPart.attachment.width,
          height: backendPart.attachment.height,
          durationMs: backendPart.attachment.durationMs,
          thumbnailKey: backendPart.attachment.thumbnailKey,
          // 保留缓存中的本地字段
          localPath: cachedPart.attachment.localPath,
          downloadUrl: cachedPart.attachment.downloadUrl,
          uploadProgress: cachedPart.attachment.uploadProgress,
          downloadProgress: cachedPart.attachment.downloadProgress,
        };

        return {
          ...backendPart,
          attachment: mergedAttachment,
        };
      });

      return {
        ...backendMsg,
        parts: mergedParts,
      };
    }

    return backendMsg;
  });
};

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
      return {
        partType: 'image',
        mime,
        summary: buildAttachmentSummary('image', file.name)
      };
    }
  }

  if (mime.startsWith('video/')) {
    console.log('检测到视频文件，开始获取元数据:', file.name)
    try {
      // 设置超时，避免某些视频文件导致卡住
      const metadataPromise = getVideoMetadata(file)
      const timeoutPromise = new Promise<never>((_, reject) => {
        setTimeout(() => reject(new Error('获取视频元数据超时')), 10000) // 10秒超时
      })
      
      const { width, height, durationMs } = await Promise.race([metadataPromise, timeoutPromise])
      console.log('视频元数据获取成功:', { width, height, durationMs, fileName: file.name })
      return {
        partType: 'video',
        width,
        height,
        durationMs,
        mime,
        summary: buildAttachmentSummary('video', file.name)
      };
    } catch (error: any) {
      console.warn('获取视频元数据失败，继续上传（无元数据）:', error?.message || error, file.name)
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
  const index = messages.value.findIndex((msg: Message) => msg.id === messageId);
  if (index === -1) {
    return;
  }

  const message = messages.value[index];
  if (!Array.isArray(message.parts) || message.parts.length === 0) {
    return;
  }

  let changed = false;

  const updatedParts = message.parts.map((part: MessagePart) => {
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

const downloadAttachmentToLocalUrl = async (
  downloadUrl: string,
  mime?: string | null,
  onProgress?: (progress: number) => void
): Promise<{ localPath: string; fromBlob: boolean }> => {
  try {
    // 如果提供了进度回调，先设置进度为 0
    if (onProgress) {
      onProgress(0);
    }

    const response = await rustHttp.requestRaw<{ base64?: string; headers?: Record<string, string> }>({
      path: downloadUrl,
      method: 'GET',
      responseType: 'binary',
      injectToken: false
    });

    if (!response.success || !response.data || !response.data.base64) {
      throw new Error(`下载失败，状态码 ${response.code}`);
    }

    // 模拟进度更新（因为 rustHttp.requestRaw 可能不支持进度回调）
    if (onProgress) {
      onProgress(0.5);
    }

    const bytes = base64ToUint8Array(response.data.base64);
    const contentType = mime || response.data.headers?.['content-type'] || undefined;
    const arrayBuffer = new ArrayBuffer(bytes.byteLength);
    const view = new Uint8Array(arrayBuffer);
    view.set(bytes);
    const blob = new Blob([arrayBuffer], { type: contentType });
    const objectUrl = URL.createObjectURL(blob);
    
    // 下载完成，设置进度为 1
    if (onProgress) {
      onProgress(1);
    }
    
    return { localPath: objectUrl, fromBlob: true };
  } catch (error) {
    // 下载失败，清除进度
    if (onProgress) {
      onProgress(0);
    }
    return { localPath: downloadUrl, fromBlob: false };
  }
};

const setAttachmentLocalPath = (messageId: string, attachmentKey: string, localPath: string | null, extra: { downloadUrl?: string | null } = {}) => {
  const index = messages.value.findIndex((msg: Message) => msg.id === messageId);
  if (index === -1) {
    return;
  }

  const message = messages.value[index];
  if (!Array.isArray(message.parts)) {
    return;
  }

  let changed = false;

  const updatedParts = message.parts.map((part: MessagePart) => {
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
  if (!attachment) {
    return;
  }

  const { key } = attachment;
  if (!key) {
    return;
  }

  // 如果已有localPath，先检查文件是否真的存在
  if (attachment.localPath) {
    // 如果是blob URL，注册并直接使用
    if (attachment.localPath.startsWith('blob:')) {
      registerBlobUrl(attachment.localPath);
      return;
    }
    // 如果是真实路径，检查文件是否存在
    try {
      const { invoke } = await import('@tauri-apps/api/core');
      const exists = await invoke<boolean>('check_file_exists', { path: attachment.localPath });
      if (exists) {
        // 文件存在，使用缓存的路径
        return;
      }
      // 文件不存在，清除localPath，重新下载
      setAttachmentLocalPath(message.id, key, null);
    } catch (error) {
      console.warn('检查文件是否存在失败:', error);
      // 如果检查失败，清除路径
      setAttachmentLocalPath(message.id, key, null);
    }
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

  // 如果是文件类型，设置下载进度为 0
  if (part.type === MessagePartType.FILE) {
    updateFileDownloadProgress(message.id, key, 0);
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

        // 下载文件，支持进度回调
        const { localPath, fromBlob } = await downloadAttachmentToLocalUrl(
          payload.downloadUrl,
          attachment.mime ?? null,
          part.type === MessagePartType.FILE ? (progress) => {
            updateFileDownloadProgress(message.id, key, progress);
          } : undefined
        );
        if (fromBlob) {
          registerBlobUrl(localPath);
        }
        attachmentUrlCache.set(key, {
          localPath,
          expiresAt: Date.now() + ATTACHMENT_CACHE_TTL_MS,
          downloadUrl: payload.downloadUrl,
        });
        
        // 清除下载进度
        if (part.type === MessagePartType.FILE) {
          updateFileDownloadProgress(message.id, key, null);
        }
        
        return { localPath, downloadUrl: payload.downloadUrl };
      } catch (error: any) {
        // 清除下载进度
        if (part.type === MessagePartType.FILE) {
          updateFileDownloadProgress(message.id, key, null);
        }
        const errorMessage = part.type === MessagePartType.FILE ? '文件加载失败' : '图片加载失败';
        toast.error(error?.message || errorMessage);
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

// 获取文件类型图标类型
const getFileIconType = (message: Message): 'archive' | 'text' | 'other' => {
  let fileName = '';
  let mimeType = '';

  // 从 parts 中获取文件信息
  if (Array.isArray(message.parts)) {
    const filePart = message.parts.find((part) => part.type === MessagePartType.FILE);
    if (filePart?.attachment) {
      fileName = filePart.attachment.name || '';
      mimeType = filePart.attachment.mime || '';
    }
  }

  // 从 content 中获取文件信息（兼容旧格式）
  if (!fileName && typeof message.content === 'object' && message.content) {
    fileName = (message.content as any).name || '';
    mimeType = (message.content as any).mime || '';
  }

  // 根据文件扩展名判断
  if (fileName) {
    const ext = fileName.split('.').pop()?.toLowerCase() || '';
    // 压缩包格式
    if (['zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'z', 'cab', 'iso', 'dmg'].includes(ext)) {
      return 'archive';
    }
    // 文本文件格式
    if (['txt', 'md', 'json', 'xml', 'html', 'css', 'js', 'ts', 'jsx', 'tsx', 'vue', 'py', 'java', 'cpp', 'c', 'h', 'hpp', 'go', 'rs', 'php', 'rb', 'swift', 'kt', 'dart', 'sh', 'bat', 'ps1', 'yaml', 'yml', 'ini', 'conf', 'log', 'csv'].includes(ext)) {
      return 'text';
    }
  }

  // 根据 MIME 类型判断
  if (mimeType) {
    if (mimeType.includes('zip') || mimeType.includes('rar') || mimeType.includes('7z') || mimeType.includes('tar') || mimeType.includes('gzip') || mimeType.includes('x-compress') || mimeType.includes('x-compressed')) {
      return 'archive';
    }
    if (mimeType.startsWith('text/') || mimeType.includes('json') || mimeType.includes('xml') || mimeType.includes('javascript') || mimeType.includes('css')) {
      return 'text';
    }
  }

  return 'other';
};

// 获取文件图标 CSS 类
const getFileIconClass = (message: Message): string => {
  const iconType = getFileIconType(message);
  return `file-icon-${iconType}`;
};

// 获取文件名
const getFileName = (message: Message): string => {
  // 从 parts 中获取
  if (Array.isArray(message.parts)) {
    const filePart = message.parts.find((part) => part.type === MessagePartType.FILE);
    if (filePart?.attachment?.name) {
      return filePart.attachment.name;
    }
  }

  // 从 content 中获取（兼容旧格式）
  if (typeof message.content === 'object' && message.content) {
    const name = (message.content as any).name;
    if (name) {
      return name;
    }
  }

  return '文件';
};

// 获取文件大小
const getFileSize = (message: Message): number | null => {
  // 从 parts 中获取
  if (Array.isArray(message.parts)) {
    const filePart = message.parts.find((part) => part.type === MessagePartType.FILE);
    if (filePart?.attachment?.size) {
      return filePart.attachment.size;
    }
  }

  // 从 content 中获取（兼容旧格式）
  if (typeof message.content === 'object' && message.content) {
    const size = (message.content as any).size;
    if (typeof size === 'number') {
      return size;
    }
  }

  return null;
};

// 判断文件是否正在下载
const isFileDownloading = (message: Message): boolean => {
  if (Array.isArray(message.parts)) {
    const filePart = message.parts.find((part) => part.type === MessagePartType.FILE);
    if (filePart?.attachment) {
      const downloadProgress = filePart.attachment.downloadProgress;
      return typeof downloadProgress === 'number' && downloadProgress < 1 && downloadProgress > 0;
    }
  }
  return false;
};

// 文件存在性检查缓存（避免重复检查）
const fileExistsCache = new Map<string, { exists: boolean; checkedAt: number }>();
const FILE_EXISTS_CACHE_TTL = 5 * 60 * 1000; // 5 分钟缓存

// 检查文件是否存在（基于 localPath 和实际文件系统）
const isFileExists = async (message: Message): Promise<boolean> => {
  if (Array.isArray(message.parts)) {
    const filePart = message.parts.find((part) => part.type === MessagePartType.FILE);
    if (filePart?.attachment?.localPath) {
      const localPath = filePart.attachment.localPath;
      // blob URL 是临时缓存，不算已下载
      if (localPath.startsWith('blob:')) {
        return false;
      }
      
      // 检查缓存
      const cached = fileExistsCache.get(localPath);
      if (cached && Date.now() - cached.checkedAt < FILE_EXISTS_CACHE_TTL) {
        return cached.exists;
      }
      
      // 调用 Rust 检查文件是否存在
      try {
        const { invoke } = await import('@tauri-apps/api/core');
        const exists = await invoke<boolean>('check_file_exists', { path: localPath });
        fileExistsCache.set(localPath, { exists, checkedAt: Date.now() });
        return exists;
      } catch (error) {
        console.warn('检查文件是否存在失败:', error);
        // 如果检查失败，假设文件存在（基于 localPath）
        return true;
      }
    }
  }
  return false;
};

// 同步版本（用于模板中，基于 localPath 判断）
const isFileExistsSync = (message: Message): boolean => {
  if (Array.isArray(message.parts)) {
    const filePart = message.parts.find((part) => part.type === MessagePartType.FILE);
    if (filePart?.attachment?.localPath) {
      const localPath = filePart.attachment.localPath;
      // blob URL 是临时缓存，不算已下载
      if (!localPath.startsWith('blob:')) {
        // 直接基于 localPath 判断：如果有真实的文件路径则认为已下载
        // 缓存只用于优化，不影响判断结果
        return true;
      }
    }
  }
  return false;
};

// 检查文件是否需要显示下载图标（同步版本，用于模板）
const shouldShowDownloadIcon = (message: Message): boolean => {
  // 如果正在下载或上传，不显示下载图标
  if (isFileDownloading(message) || isMessageUploading(message)) {
    return false;
  }
  // 如果文件已存在（基于缓存），不显示下载图标
  if (isFileExistsSync(message)) {
    return false;
  }
  // 其他情况显示下载图标
  return true;
};

// 检查消息中的文件是否存在（异步，用于消息可见时检查）
const checkFileExistsForMessage = async (message: Message) => {
  if (Array.isArray(message.parts)) {
    const filePart = message.parts.find((part) => part.type === MessagePartType.FILE);
    if (filePart?.attachment?.localPath) {
      const localPath = filePart.attachment.localPath;
      // 只检查非 blob URL 的文件
      if (!localPath.startsWith('blob:')) {
        const exists = await isFileExists(message);
        // 如果文件不存在，清除 localPath
        if (!exists) {
          console.log('文件不存在，清除 localPath:', localPath);
          setAttachmentLocalPath(message.id, filePart.attachment.key, null);
          
          // 更新消息缓存
          const roomId = message.roomId || selectedChat.value?.groupId;
          if (roomId) {
            try {
              const cachedMessages = await loadCache<Message[]>(CACHE_KEYS.messages(roomId));
              if (cachedMessages && Array.isArray(cachedMessages)) {
                const cachedIndex = cachedMessages.findIndex((msg: Message) => msg.id === message.id);
                if (cachedIndex !== -1) {
                  const cachedMsg = cachedMessages[cachedIndex];
                  if (Array.isArray(cachedMsg.parts)) {
                    const partIndex = cachedMsg.parts.findIndex((p: MessagePart) => 
                      p.type === MessagePartType.FILE && p.attachment?.key === filePart.attachment.key
                    );
                    if (partIndex !== -1 && cachedMsg.parts[partIndex].attachment) {
                      cachedMsg.parts[partIndex].attachment = {
                        ...cachedMsg.parts[partIndex].attachment!,
                        localPath: null
                      };
                      await saveCache(CACHE_KEYS.messages(roomId), cachedMessages);
                    }
                  }
                }
              }
            } catch (error) {
              console.warn('更新消息缓存失败:', error);
            }
          }
        }
      }
    }
  }
};

// 获取文件下载/上传进度
const getFileProgress = (message: Message): number => {
  // 优先检查下载进度
  if (Array.isArray(message.parts)) {
    const filePart = message.parts.find((part) => part.type === MessagePartType.FILE);
    if (filePart?.attachment) {
      const downloadProgress = filePart.attachment.downloadProgress;
      if (typeof downloadProgress === 'number') {
        return downloadProgress;
      }
      const uploadProgress = filePart.attachment.uploadProgress;
      if (typeof uploadProgress === 'number') {
        return uploadProgress;
      }
    }
  }

  // 检查 content 中的上传进度（兼容旧格式）
  if (typeof message.content === 'object' && message.content) {
    const uploadProgress = (message.content as any).uploadProgress;
    if (typeof uploadProgress === 'number') {
      return uploadProgress;
    }
  }

  return 0;
};

// 处理文件下载
const handleFileDownload = async (message: Message) => {
  console.log('handleFileDownload 被调用:', message);
  
  if (!message) {
    console.error('消息对象为空');
    return;
  }

  // 查找文件 part
  let filePart: MessagePart | undefined;
  if (Array.isArray(message.parts)) {
    filePart = message.parts.find((part) => part.type === MessagePartType.FILE);
    console.log('找到文件 part:', filePart);
  } else {
    console.log('消息没有 parts 数组，尝试从 content 获取:', message.content);
    // 如果没有 parts，尝试从 content 中获取文件信息（兼容旧格式）
    if (typeof message.content === 'object' && message.content) {
      const content = message.content as any;
      if (content.key || content.downloadUrl) {
        // 构造一个临时的 filePart
        filePart = {
          position: 0,
          type: MessagePartType.FILE,
          attachment: {
            key: content.key || '',
            name: content.name || '文件',
            mime: content.mime || content.type || 'application/octet-stream',
            size: content.size || null,
            downloadUrl: content.downloadUrl || null,
            localPath: content.localUrl || content.localPath || null,
          }
        };
        console.log('从 content 构造的 filePart:', filePart);
      }
    }
  }

  if (!filePart?.attachment) {
    console.error('文件信息不存在，message:', message);
    toast.error('文件信息不存在');
    return;
  }

  const attachment = filePart.attachment;
  console.log('附件信息:', attachment);

  // 如果已有本地路径，打开文件所在目录
  if (attachment.localPath) {
    console.log('使用已有本地路径:', attachment.localPath);
    try {
      // 如果是 blob URL，使用浏览器下载功能
      if (attachment.localPath.startsWith('blob:')) {
        console.log('检测到 blob URL，使用浏览器下载');
        const link = document.createElement('a');
        link.href = attachment.localPath;
        link.download = attachment.name || 'file';
        document.body.appendChild(link);
        link.click();
        setTimeout(() => {
          document.body.removeChild(link);
        }, 100);
        return;
      }

      // 对于文件系统路径，使用 Rust 打开文件所在目录
      console.log('文件已下载，打开文件所在目录:', attachment.localPath);
      const { invoke } = await import('@tauri-apps/api/core');
      await invoke('open_file_directory', { filePath: attachment.localPath });
      return;
    } catch (error) {
      console.error('打开目录失败:', error);
      // 检查文件是否真的存在
      try {
        const { invoke } = await import('@tauri-apps/api/core');
        const exists = await invoke<boolean>('check_file_exists', { path: attachment.localPath });
        if (exists) {
          // 文件存在，只是打开目录失败（权限问题等），不下载
          toast.error('打开目录失败: ' + (error instanceof Error ? error.message : '未知错误'));
          return;
        }
        // 文件不存在，清除本地路径并下载
        console.log('文件不存在，清除 localPath 并重新下载');
        if (attachment.key) {
          setAttachmentLocalPath(message.id, attachment.key, null);
        }
        // 继续执行下载逻辑
      } catch (checkError) {
        console.error('检查文件是否存在失败:', checkError);
        // 如果检查失败，直接显示错误但不下载
        toast.error('打开目录失败: ' + (error instanceof Error ? error.message : '未知错误'));
        return;
      }
    }
  }

  // 如果没有本地路径，需要下载
  if (!attachment.key && !attachment.downloadUrl) {
    console.error('文件 key 和 downloadUrl 都不存在');
    toast.error('文件 key 不存在');
    return;
  }

  try {
    console.log('开始下载文件，key:', attachment.key, 'downloadUrl:', attachment.downloadUrl);
    
    let downloadUrl = attachment.downloadUrl;
    
    // 如果没有 downloadUrl，需要通过 key 获取下载 URL
    if (!downloadUrl && attachment.key) {
      const roomId = message.roomId || selectedChat.value?.groupId;
      if (!roomId) {
        toast.error('房间 ID 不存在');
        return;
      }

      console.log('获取文件下载 URL，key:', attachment.key);
      const response = await MessageApi.getAttachmentDownloadUrl({
        groupId: roomId,
        key: attachment.key,
        expiresInSeconds: ATTACHMENT_DOWNLOAD_EXPIRES_SECONDS,
      });

      if (!response.success || !response.data?.downloadUrl) {
        throw new Error(response.message || '获取文件下载链接失败');
      }

      downloadUrl = response.data.downloadUrl;
      console.log('获取到下载 URL:', downloadUrl);
    }

    if (!downloadUrl) {
      toast.error('无法获取文件下载链接');
      return;
    }

    // 设置下载进度为 0
    if (attachment.key) {
      updateFileDownloadProgress(message.id, attachment.key, 0);
    }

    // 获取下载目录
    const { getDownloadDir } = await import('../utils/download-settings');
    const downloadDir = await getDownloadDir();
    let fileName = attachment.name || 'file';
    
    // 生成唯一文件名（如果文件已存在，添加时间戳）
    const generateUniqueFileName = async (baseFileName: string): Promise<string> => {
      const basePath = `${downloadDir}/${baseFileName}`;
      
      // 检查文件是否存在
      const { invoke } = await import('@tauri-apps/api/core');
      const exists = await invoke<boolean>('check_file_exists', { path: basePath });
      
      if (!exists) {
        return baseFileName;
      }
      
      // 文件已存在，生成带时间戳的文件名
      // 时间戳格式：YYYYMMDDHHmmss，例如 20250101100000
      const now = new Date();
      const year = now.getFullYear().toString();
      const month = String(now.getMonth() + 1).padStart(2, '0');
      const day = String(now.getDate()).padStart(2, '0');
      const hours = String(now.getHours()).padStart(2, '0');
      const minutes = String(now.getMinutes()).padStart(2, '0');
      const seconds = String(now.getSeconds()).padStart(2, '0');
      const timestamp = `${year}${month}${day}${hours}${minutes}${seconds}`;
      
      // 分离文件名和扩展名
      const lastDotIndex = baseFileName.lastIndexOf('.');
      if (lastDotIndex > 0) {
        const nameWithoutExt = baseFileName.substring(0, lastDotIndex);
        const ext = baseFileName.substring(lastDotIndex);
        // 格式：文件名_时间戳.扩展名，例如 demo-1_20250101100000.zip
        return `${nameWithoutExt}_${timestamp}${ext}`;
      } else {
        // 没有扩展名
        return `${baseFileName}_${timestamp}`;
      }
    };
    
    fileName = await generateUniqueFileName(fileName);
    
    // 构建完整保存路径（使用绝对路径）
    const savePath = `${downloadDir}/${fileName}`;
    
    // 生成下载ID
    const downloadId = `${message.id}_${attachment.key || Date.now()}`;
    console.log('使用 Rust 下载文件:', downloadUrl, '保存路径:', downloadDir, fileName);
    
    try {
      // 使用带进度回调的下载
      const downloadResult = await rustHttp.download(
        downloadUrl, 
        savePath,
        downloadId,
        (progress: number) => {
          // 进度回调：更新下载进度
          if (attachment.key) {
            if (progress < 0) {
              // 错误
              updateFileDownloadProgress(message.id, attachment.key, null);
            } else if (progress >= 1) {
              // 完成
              updateFileDownloadProgress(message.id, attachment.key, null);
            } else {
              // 进行中
              updateFileDownloadProgress(message.id, attachment.key, progress);
            }
          }
        }
      );
      console.log('Rust 下载结果:', downloadResult);
      console.log('Rust 下载结果详情:', {
        success: downloadResult.success,
        message: downloadResult.message,
        path: downloadResult.path
      });
      
      if (!downloadResult.success || !downloadResult.path) {
        const errorMsg = downloadResult.message || '文件下载失败';
        console.error('下载失败，错误信息:', errorMsg);
        throw new Error(errorMsg);
      }
      
      console.log('文件下载成功，保存路径:', downloadResult.path);
      
      // 更新消息的本地路径
      if (attachment.key) {
        setAttachmentLocalPath(message.id, attachment.key, downloadResult.path, { downloadUrl });
        updateFileDownloadProgress(message.id, attachment.key, null);
        
        // 更新消息缓存中的本地路径
        const roomId = message.roomId || selectedChat.value?.groupId;
        if (roomId) {
          try {
            const cachedMessages = await loadCache<Message[]>(CACHE_KEYS.messages(roomId));
            if (cachedMessages && Array.isArray(cachedMessages)) {
              const cachedIndex = cachedMessages.findIndex((msg: Message) => msg.id === message.id);
              if (cachedIndex !== -1) {
                const cachedMsg = cachedMessages[cachedIndex];
                if (Array.isArray(cachedMsg.parts)) {
                  const partIndex = cachedMsg.parts.findIndex((p: MessagePart) => 
                    p.type === MessagePartType.FILE && p.attachment?.key === attachment.key
                  );
                  if (partIndex !== -1 && cachedMsg.parts[partIndex].attachment) {
                    cachedMsg.parts[partIndex].attachment = {
                      ...cachedMsg.parts[partIndex].attachment!,
                      localPath: downloadResult.path,
                      downloadUrl
                    };
                    await saveCache(CACHE_KEYS.messages(roomId), cachedMessages);
                    console.log('已更新消息缓存中的本地路径:', downloadResult.path);
                  }
                }
              }
            }
          } catch (error) {
            console.warn('更新消息缓存失败:', error);
          }
        }
      }
      
      toast.success('文件下载成功');
    } catch (downloadError: any) {
      console.error('Rust 下载失败，详细信息:', downloadError);
      toast.error('文件下载失败: ' + (downloadError?.message || '未知错误'));
      
      if (attachment.key) {
        updateFileDownloadProgress(message.id, attachment.key, null);
      }
    }
  } catch (error: any) {
    console.error('文件下载失败:', error);
    toast.error('文件下载失败: ' + (error?.message || '未知错误'));
    if (attachment.key) {
      updateFileDownloadProgress(message.id, attachment.key, null);
    }
  }
};

// 更新文件下载进度
const updateFileDownloadProgress = (messageId: string, attachmentKey: string, progress: number | null) => {
  const index = messages.value.findIndex((msg: Message) => msg.id === messageId);
  if (index === -1) {
    return;
  }

  const message = messages.value[index];
  if (!Array.isArray(message.parts) || message.parts.length === 0) {
    return;
  }

  let changed = false;

  const updatedParts = message.parts.map((part: MessagePart) => {
    if (part.attachment?.key !== attachmentKey) {
      return part;
    }
    if (part.attachment.downloadProgress === progress) {
      return part;
    }
    changed = true;
    return {
      ...part,
      attachment: {
        ...part.attachment,
        downloadProgress: progress,
      }
    };
  });

  if (!changed) {
    return;
  }

  messages.value[index] = {
    ...message,
    parts: updatedParts,
  };
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
  remark?: string | null
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
  senderAvatarLocalPath?: string | null
  senderAvatarObjectKey?: string | null
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
const store = useStore() as any
const selectedChat = (ref as any)<ChatItem | null>(null)

// 计算属性：获取当前账号的路由查询参数（用于多实例页面架构）
const routeQuery = computed(() => {
  if (props.accountId) {
    const account = store.getters['accounts/getAccountById'](props.accountId)
    return account?.routeState?.query || {}
  }
  return route.query
})
const newMessage = (ref as any)<string>('')
const searchText = (ref as any)<string>('')
const isResizing = (ref as any)<boolean>(false)
const startX = (ref as any)<number>(0)
const startWidth = (ref as any)<number>(0)

// 搜索功能状态
const showSearchDialog = (ref as any)<boolean>(false)
const availableRoomsForSearch = (ref as any)<Array<{ id: string; name: string }>>([])
const availableSendersForSearch = (ref as any)<Array<{ id: string; name: string }>>([])

// 表情选择器状态
const showEmojiPicker = (ref as any)<boolean>(false)

// 媒体预览状态
const showMediaPreview = (ref as any)<boolean>(false)
const previewMediaSrc = ref<string>('')
const previewMediaType = ref<'image' | 'video'>('image')
const previewMediaName = ref<string>('')
const previewMediaSize = ref<number>(0)

// 群组创建相关状态
const showCreateGroupDialog = ref<boolean>(false)
const showAddMemberDialog = ref<boolean>(false)
const isCreatingGroup = ref<boolean>(false)
const isLoadingContacts = ref<boolean>(false)
const contacts = ref<any[]>([])
const pendingGroupData = ref<any>(null)

// 聊天列表右键菜单状态
const showContextMenu = ref<boolean>(false)
const contextMenuPosition = ref<{ x: number; y: number }>({ x: 0, y: 0 })
const contextMenuChat = ref<ChatItem | null>(null)

// 消息右键菜单状态
const showMessageContextMenu = ref<boolean>(false)
const messageContextMenuPosition = ref<{ x: number; y: number }>({ x: 0, y: 0 })
const messageContextMenuTarget = ref<Message | null>(null)

// 删除对话确认对话框状态
const showDeleteConfirm = ref<boolean>(false)
const deleteTargetChat = ref<ChatItem | null>(null)

// 回复消息状态
const replyingMessage = ref<Message | null>(null)

// 群设置抽屉状态
const showGroupSettings = ref<boolean>(false)

// 群成员数据
const groupMembers = ref<RoomMember[]>([])

const groupSettings = ref<GroupSettings | null>(null)
const groupSettingsLoading = ref<boolean>(false)
const updatingGlobalMute = ref<boolean>(false)
const showTransferOwnerDialog = ref<boolean>(false)
const selectedTransferOwnerId = ref<string | null>(null)
const transferringOwner = ref<boolean>(false)
const dissolvingGroup = ref<boolean>(false)

// 打开群设置抽屉
const handleShowGroupSettings = async () => {
  if (!selectedChat.value) return


  // 如果是群聊且成员列表为空，先加载群成员
  if (selectedChat.value.groupType === 1 && groupMembers.value.length === 0) {
    await loadGroupMembers(selectedChat.value.groupId)
  }

  if (selectedChat.value.groupType === 1) {
    if (isCurrentUserGroupOwner.value) {
      await loadGroupSettings(selectedChat.value.groupId, { silent: true })
    } else {
      groupSettings.value = null
    }
  } else {
    groupSettings.value = null
  }

  showGroupSettings.value = true
}

// 可添加到群的联系人列表(排除已在群里的成员)
const availableContactsForGroup = computed(() => {
  if (!selectedChat.value || selectedChat.value.groupType !== 1) {
    return contacts.value
  }

  // 获取已在群里的成员 ID 列表
  const existingMemberIds = new Set(groupMembers.value.map((member: RoomMember) => member.userId))

  // 过滤掉已在群里的联系人
  return contacts.value.filter((contact: any) => !existingMemberIds.has(contact.id))
})

// 群名修改相关状态
const showEditGroupNameDialog = ref<boolean>(false)
const editingGroupName = ref<string>('')
const isUpdatingGroupName = ref<boolean>(false)
const groupNameError = ref<string>('')

// 群公告修改相关状态
const showEditGroupNoticeDialog = ref<boolean>(false)
const editingGroupNotice = ref<string>('')
const isUpdatingGroupNotice = ref<boolean>(false)

// 备注修改相关状态
const showEditRemarkDialog = ref<boolean>(false)
const editingRemark = ref<string>('')
const isUpdatingRemark = ref<boolean>(false)

// 消息列表相关
const messageList = ref<Message[]>([])

// 语音相关状态
const showVoiceRecorder = ref<boolean>(false)

// 聊天消息容器引用 (ScrollContainer 组件)
const chatMessagesRef = ref<InstanceType<typeof ScrollContainer> | null>(null)

// 获取消息列表的滚动视口元素
const getMessagesViewport = (): HTMLElement | null => {
  // ScrollContainer 内部使用 OverlayScrollbarsComponent，需要访问其子组件
  const scrollContainer = chatMessagesRef.value as any
  const viewport = scrollContainer?.$el?.querySelector('.os-viewport') ?? null

  if (!viewport) {
    console.log('[ScrollDebug] getMessagesViewport: viewport not found')
    console.log('[ScrollDebug] chatMessagesRef.value:', !!chatMessagesRef.value)
    console.log('[ScrollDebug] scrollContainer.$el:', !!scrollContainer?.$el)

    // 尝试其他选择器
    const alternativeViewport = document.querySelector('.chat-messages .os-viewport') as HTMLElement
    if (alternativeViewport) {
      console.log('[ScrollDebug] Found viewport using alternative selector')
      return alternativeViewport
    }
  }

  return viewport
}
const messageInput = ref<HTMLTextAreaElement | null>(null)
const quotedHighlightTimers = new Map<string, number>()

// 数据状态管理 - 使用store中的数据
const chatList = computed(() => store.getters.chatList)
const messages = ref<Message[]>([])
const loading = computed(() => store.getters.chatListLoading)
const messagesLoading = ref<boolean>(false)
const currentUserId = computed(() => store.getters.currentUser.id)

const isCurrentUserGroupOwner = computed(() => {
  if (!selectedChat.value || selectedChat.value.groupType !== 1) {
    return false
  }
  const selfId = currentUserId.value ? String(currentUserId.value) : null
  if (!selfId) return false

  const extra = selectedChat.value.extra || {}
  const ownerCandidate =
    (extra && (extra as Record<string, any>).owner_id) ||
    (extra && (extra as Record<string, any>).ownerId) ||
    (extra && (extra as Record<string, any>).ownerID) ||
    (extra && (extra as Record<string, any>).owner)

  if (ownerCandidate && String(ownerCandidate) === selfId) {
    return true
  }

  const ownerMember = groupMembers.value.find(
    (member) => String(member.userId) === selfId && member.role === 'owner'
  )
  return !!ownerMember
})

const transferableMembers = computed(() => {
  if (!groupMembers.value.length) return []
  const selfId = currentUserId.value ? String(currentUserId.value) : null
  return groupMembers.value.filter((member) => String(member.userId) !== selfId)
})

// 检查消息中的文件是否存在（批量检查，避免频繁调用）
const checkFilesExistsForMessages = async (messagesToCheck: Message[]) => {
  // 只检查有 localPath 的文件消息
  const fileMessages = messagesToCheck.filter((msg) => {
    if (Array.isArray(msg.parts)) {
      const filePart = msg.parts.find((part) => part.type === MessagePartType.FILE);
      return filePart?.attachment?.localPath && !filePart.attachment.localPath.startsWith('blob:');
    }
    return false;
  });
  
  // 批量检查文件是否存在（避免同时发起太多请求）
  const batchSize = 5;
  for (let i = 0; i < fileMessages.length; i += batchSize) {
    const batch = fileMessages.slice(i, i + batchSize);
    await Promise.all(batch.map((msg) => checkFileExistsForMessage(msg)));
    // 每批之间稍作延迟，避免阻塞
    if (i + batchSize < fileMessages.length) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  }
};

// 文件存在性检查防抖定时器
let fileCheckTimer: ReturnType<typeof setTimeout> | null = null

watch(
  () => [selectedChat.value?.groupId, messages.value] as [string | undefined | null, Message[]],
  ([groupId, messageList]: [string | undefined | null, Message[]]) => {
    if (!groupId) {
      return
    }
    scheduleMessagesCachePersist(groupId, messageList)
    
    // 延迟检查文件是否存在（防抖，避免频繁检查）
    if (fileCheckTimer) {
      clearTimeout(fileCheckTimer)
    }
    fileCheckTimer = setTimeout(() => {
      if (messageList && messageList.length > 0) {
        checkFilesExistsForMessages(messageList).catch((error) => {
          console.warn('检查文件存在性失败:', error)
        })
      }
    }, 1000) // 1秒后检查，避免频繁调用
  },
  { deep: true }
)

// 添加本地初始化状态，避免重复加载
const isInitialized = ref<boolean>(false)

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

    // 如果已经初始化过且不强制刷新，直接返回
    if (isInitialized.value && !forceRefresh) {
      return
    }

    // 如果不强制刷新且store中有数据，优先从store加载
    if (!forceRefresh && chatList.value.length > 0) {
      isInitialized.value = true
      return
    }

    // 调用store的loadChatList action，传入比对逻辑参数
    await store.dispatch('loadChatList', {
      forceRefresh,
      compareWithStore: true // 启用与store的数据比对
    })

    const roomIds = chatList.value
      .map((chat: ChatItem) => chat.groupId)
      .filter((groupId): groupId is string => typeof groupId === 'string' && groupId.length > 0)

    webSocketManager.ensureRoomsSubscribed(roomIds, false)

    isInitialized.value = true
  } catch (error: any) {
    // 静默处理错误，不显示toast
  }
}

// 发送群公告修改的系统消息（与bear-chat-uniapp保持一致）
const sendGroupNoticeUpdateSystemMessage = async (groupId: string, groupNotice: string) => {
  try {
    const user = store.getters.currentUser
    const timestamp = Date.now()


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


    // 通过WebSocket发送系统消息
    await new Promise((resolve, reject) => {
      webSocketManager.sendMessage(systemMessage, MESSAGE_CONSTANTS.BUSINESS_CODE.chatting, (success: boolean) => {
        if (success) {
          resolve(true)
        } else {
          reject(new Error('系统消息发送失败'))
        }
      })
    })

  } catch (error: any) {
    // 静默处理错误，不影响用户体验
  }
}

// 发送群头像修改的系统消息（与bear-chat-uniapp保持一致）
const sendGroupAvatarUpdateSystemMessage = async (groupId: string, avatarUrl: string) => {
  try {
    const user = store.getters.currentUser
    const timestamp = Date.now()


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


    // 通过WebSocket发送系统消息
    await new Promise((resolve, reject) => {
      webSocketManager.sendMessage(systemMessage, MESSAGE_CONSTANTS.BUSINESS_CODE.chatting, (success: boolean) => {
        if (success) {
          resolve(true)
        } else {
          reject(new Error('系统消息发送失败'))
        }
      })
    })

  } catch (error: any) {
    // 静默处理错误，不影响用户体验
  }
}

// 加载群组详细信息和成员列表（与bear-chat-uniapp保持一致）
const loadGroupDetailInfo = async (groupId: string) => {
  try {

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


      // 获取群头像的临时下载URL
      let avatarUrl = groupInfo.avatar || selectedChat.value?.avatar
      const roomAvatarObjectKey = groupInfo.extra?.room_avatar_object_key ||
                                   groupInfo.extra?.roomAvatarObjectKey


      if (roomAvatarObjectKey) {
        try {
          const localPath = await UserApi.syncGroupAvatarCache(
            groupId,
            roomAvatarObjectKey,
            false
          )
          if (localPath) {
            avatarUrl = localPath
          }
        } catch (error) {
        }
      } else {
      }

      if (selectedChat.value) {
        const mergedExtra: Record<string, any> = {
          ...(selectedChat.value.extra || {}),
          ...(groupInfo.extra || {}),
        }
        const ownerFromExtra = (groupInfo.extra || {}).owner_id || (groupInfo.extra || {}).ownerId
        if (ownerFromExtra) {
          mergedExtra.owner_id = ownerFromExtra
          mergedExtra.ownerId = ownerFromExtra
        }
        selectedChat.value = {
          ...selectedChat.value,
          roomId: groupInfo.roomId,
          name: groupInfo.name,
          avatar: avatarUrl,
          groupType: groupInfo.type === ChatType.GROUP ? 1 : 0,
          memberCount: groupInfo.memberCount ?? selectedChat.value.memberCount,
          groupNotice: description,
          showNoticeFlag: description.trim().length > 0,
          extra: mergedExtra,
        }

      }
    }

    // 2. 获取群成员列表
    const membersResponse = await GroupApi.getChatGroupMembers({
      chatGroupId: groupId
    })

    if (membersResponse.success && membersResponse.data) {

      // 保存群成员数据
      groupMembers.value = membersResponse.data

      // 更新成员数量
      if (selectedChat.value && membersResponse.data.length) {
        selectedChat.value.memberCount = membersResponse.data.length
      }
    } else {
      // 清空群成员数据
      groupMembers.value = []
    }

  } catch (error: any) {
    // 静默处理错误，不影响聊天功能
  }
}

const loadGroupSettings = async (
  groupId: string,
  options: { silent?: boolean } = {},
) => {
  if (!groupId || !isCurrentUserGroupOwner.value) {
    groupSettings.value = null
    groupSettingsLoading.value = false
    return
  }

  try {
    groupSettingsLoading.value = true
    const response = await GroupApi.getGroupSettings({ roomId: groupId })
    if (response.success && response.data) {
      groupSettings.value = response.data
    } else {
      groupSettings.value = null
      if (!options.silent) {
        toast.error(response.message || '加载群设置失败')
      }
    }
  } catch (error: any) {
    groupSettings.value = null
    if (!options.silent) {
      toast.error(error?.message || '加载群设置失败')
    }
  } finally {
    groupSettingsLoading.value = false
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
      messages.value = cached.data.map((item) => {
        const restoredMessage = restoreMessageFromCache(item)
        // 确保消息有 roomId，如果没有则使用当前群组ID
        if (!restoredMessage.roomId) {
          restoredMessage.roomId = groupId
        }
        return restoredMessage
      })
      usedCache = true
      
      // 从缓存恢复消息后，也需要同步头像（避免头像显示为空）
      // 异步执行，不阻塞消息显示
      void (async () => {
        const uniqueSenderIds = new Set<string>()
        messages.value.forEach(msg => {
          if (!msg.isSelf && msg.senderId && msg.senderAvatarObjectKey) {
            uniqueSenderIds.add(msg.senderId)
          }
        })

        if (uniqueSenderIds.size > 0) {
          const isPrivateChat = selectedChat.value?.groupType === 0

          await Promise.all(
            Array.from(uniqueSenderIds).map(async senderId => {
              const senderMessage = messages.value.find(msg => msg.senderId === senderId && !msg.isSelf && msg.senderAvatarObjectKey)
              if (!senderMessage?.senderAvatarObjectKey) {
                return
              }

              let avatarObjectKey: string | undefined = senderMessage.senderAvatarObjectKey

              // 如果消息中没有 avatarObjectKey，尝试从其他地方获取
              if (!avatarObjectKey) {
                if (isPrivateChat) {
                  avatarObjectKey = selectedChat.value?.extra?.friend_avatar_object_key ||
                                   selectedChat.value?.extra?.friendAvatarObjectKey ||
                                   selectedChat.value?.extra?.avatar_object_key ||
                                   selectedChat.value?.extra?.avatarObjectKey
                } else {
                  const member = groupMembers.value?.find(m => m.userId === senderId)
                  avatarObjectKey = member?.avatarObjectKey
                }
              }

              if (!avatarObjectKey) {
                return
              }

              try {
                const localPath = await UserApi.syncUserAvatarCache(senderId, avatarObjectKey, false)

                if (localPath) {
                  // 注册 blob URL，避免被过早释放
                  registerBlobUrl(localPath)

                  // 更新消息列表中该发送者的所有消息
                  messages.value.forEach(msg => {
                    if (msg.senderId === senderId && !msg.isSelf) {
                      msg.senderAvatarLocalPath = localPath
                      msg.senderAvatarObjectKey = avatarObjectKey
                    }
                  })
                }
              } catch (error) {
                // 静默失败，使用默认头像
              }
            })
          )
        }
      })()
    }

    if (!usedCache) {
      messagesLoading.value = true
    }

    const response = await MessageApi.getMessageListByChatGroupId({
      groupId,
      limit: 50,
      currentUserId: currentUserId.value
    })
    
    if (response.success && response.data) {
      const messageList = Array.isArray(response.data) ? (response.data as DomainMessage[]) : []

      const convertedMessages = messageList.map((msg) => {
        const uiMessage = mapDomainMessageToUi(msg)
        // 确保消息有 roomId，如果没有则使用当前群组ID
        if (!uiMessage.roomId) {
          uiMessage.roomId = groupId
        }
        return uiMessage
      })

      // 按时间排序：最早的消息在上面，最新的在下面
      // 使用 createTime 或 timestamp 进行排序
      const sortedMessages = convertedMessages.sort((a, b) => {
        // 优先使用 timestamp，如果没有则使用 createTime
        const timeA = a.timestamp || (a.createTime ? new Date(a.createTime).getTime() : 0)
        const timeB = b.timestamp || (b.createTime ? new Date(b.createTime).getTime() : 0)
        return timeA - timeB // 升序排列
      })

      // 合并后端消息和本地缓存，保留localPath等字段
      let mergedMessages = sortedMessages
      if (usedCache && cached?.data && Array.isArray(cached.data)) {
        mergedMessages = mergeMessagesWithCache(sortedMessages, cached.data)
      }

      messages.value = mergedMessages
      await persistMessagesCache(groupId, mergedMessages)

      // 优先级预加载媒体资源：最新消息优先
      const preloadMediaResources = async () => {
        const maxConcurrent = 3; // 最大并发数
        const priorityCount = 10; // 优先加载最新10条消息

        // 分离高优先级和普通优先级的消息
        const priorityMessages = mergedMessages.slice(-priorityCount);
        const normalMessages = mergedMessages.slice(0, -priorityCount);

        // 高优先级消息预加载（视频缩略图和图片）
        if (priorityMessages.length > 0) {
          const priorityPromises = priorityMessages.reverse().map(async (msg) => {
            // 预加载视频缩略图
            if (msg.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE && Array.isArray(msg.parts)) {
              const videoPart = msg.parts.find((part) => part.type === MessagePartType.VIDEO);
              if (videoPart?.attachment?.thumbnailKey) {
                void ensureVideoThumbnailLocalPath(msg, videoPart);
              }
            }

            // 预加载图片
            if (Array.isArray(msg.parts)) {
              const imagePart = msg.parts.find((part) => part.type === MessagePartType.IMAGE);
              if (imagePart?.attachment) {
                void ensureAttachmentLocalPath(msg, imagePart);
              }
            }
          });

          // 分批处理，控制并发
          for (let i = 0; i < priorityPromises.length; i += maxConcurrent) {
            await Promise.all(priorityPromises.slice(i, i + maxConcurrent));
          }
        }

        // 普通优先级消息预加载（延迟处理，避免阻塞主线程）
        setTimeout(() => {
          normalMessages.forEach((msg) => {
            if (msg.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE && Array.isArray(msg.parts)) {
              const videoPart = msg.parts.find((part) => part.type === MessagePartType.VIDEO);
              if (videoPart?.attachment?.thumbnailKey) {
                void ensureVideoThumbnailLocalPath(msg, videoPart);
              }
            }
          });
        }, 100);
      };

      void preloadMediaResources();


      // 同步消息发送者头像缓存
      const uniqueSenderIds = new Set<string>()
      mergedMessages.forEach(msg => {
        if (!msg.isSelf && msg.senderId) {
          uniqueSenderIds.add(msg.senderId)
        }
      })

      if (uniqueSenderIds.size > 0) {

        // 判断是否为私聊
        const isPrivateChat = selectedChat.value?.groupType === 0

        // 获取群成员列表或私聊对方信息以获取 avatarObjectKey
        await Promise.all(
          Array.from(uniqueSenderIds).map(async senderId => {
            let avatarObjectKey: string | undefined
            let userName: string | undefined

            // 优先从消息本身获取 avatarObjectKey(可能来自后端的相对路径 avatar_url)
            const senderMessage = mergedMessages.find(msg => msg.senderId === senderId && !msg.isSelf)
            if (senderMessage?.senderAvatarObjectKey) {
              avatarObjectKey = senderMessage.senderAvatarObjectKey
              userName = senderMessage.senderName
            } else if (isPrivateChat) {
              // 私聊:从 selectedChat.extra 中获取对方用户的 avatar_object_key
              const friendAvatarObjectKey = selectedChat.value?.extra?.friend_avatar_object_key ||
                                           selectedChat.value?.extra?.friendAvatarObjectKey ||
                                           selectedChat.value?.extra?.avatar_object_key ||
                                           selectedChat.value?.extra?.avatarObjectKey
              avatarObjectKey = friendAvatarObjectKey
              userName = selectedChat.value?.friendName || selectedChat.value?.name

            } else {
              // 群聊:从群成员列表中找到对应的成员
              const member = groupMembers.value?.find(m => m.userId === senderId)
              avatarObjectKey = member?.avatarObjectKey
              userName = member?.nickname || member?.username

            }

            if (!avatarObjectKey) {
              return
            }

            try {
              const localPath = await UserApi.syncUserAvatarCache(senderId, avatarObjectKey, false)

              if (localPath) {
                // 注册 blob URL，避免被过早释放
                registerBlobUrl(localPath)

                // 更新消息列表中该发送者的所有消息
                mergedMessages.forEach(msg => {
                  if (msg.senderId === senderId && !msg.isSelf) {
                    msg.senderAvatarLocalPath = localPath
                    msg.senderAvatarObjectKey = avatarObjectKey
                  }
                })
              }
            } catch (error) {
            }
          })
        )

      }

      // 初始化消息搜索索引
      if (messages.value.length > 0 && selectedChat.value) {
        messageSearchService.initializeSearchIndex(messages.value, selectedChat.value.name, selectedChat.value.groupId).catch(error => {
        })
      }
    } else {
      messages.value = []
    }
  } catch (error: any) {
    messages.value = []
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('加载消息失败: ' + errorMessage)
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

// 确保视频缩略图已下载到本地
const ensureVideoThumbnailLocalPath = async (message: Message, videoPart: MessagePart) => {
  const attachment = videoPart.attachment
  if (!attachment) {
    console.log('ensureVideoThumbnailLocalPath: 没有附件信息')
    return
  }

  const thumbnailKey = attachment.thumbnailKey

  // 如果有 thumbnailKey，使用原来的逻辑
  if (thumbnailKey) {
    console.log('ensureVideoThumbnailLocalPath: 开始处理缩略图', thumbnailKey)

    // 检查缓存
    const cached = attachmentUrlCache.get(thumbnailKey)
    if (cached && cached.expiresAt > Date.now()) {
      console.log('ensureVideoThumbnailLocalPath: 缓存命中', cached.localPath)
      if (cached.localPath && cached.localPath.startsWith('blob:')) {
        registerBlobUrl(cached.localPath)
      }
      // 更新视频 part 的缩略图 localPath（使用响应式更新）
      const index = messages.value.findIndex((msg: Message) => msg.id === message.id)
      if (index !== -1) {
        const msg = messages.value[index]
        if (Array.isArray(msg.parts)) {
          const partIndex = msg.parts.findIndex((p: MessagePart) => p === videoPart)
          if (partIndex !== -1 && msg.parts[partIndex].attachment) {
            // 创建新的 parts 数组以触发响应式更新
            const updatedParts = [...msg.parts]
            updatedParts[partIndex] = {
              ...updatedParts[partIndex],
              attachment: {
                ...updatedParts[partIndex].attachment!,
                localPath: cached.localPath
              }
            }
            messages.value[index] = {
              ...msg,
              parts: updatedParts
            }
            console.log('ensureVideoThumbnailLocalPath: 已更新消息的缩略图 localPath（从缓存）')
          }
        }
      }
      return
    }

    console.log('ensureVideoThumbnailLocalPath: 缓存未命中，开始下载')
  } else {
    console.log('ensureVideoThumbnailLocalPath: 没有缩略图 key，检查是否有视频文件')
  }

  // 如果有 thumbnailKey，下载缩略图
  if (thumbnailKey) {
    const roomId = message.roomId || selectedChat.value?.groupId
    if (!roomId) {
      return
    }

    let pending = pendingAttachmentDownloads.get(thumbnailKey)
    if (!pending) {
      pending = (async () => {
        try {
          const response = await MessageApi.getAttachmentDownloadUrl({
            groupId: roomId,
            key: thumbnailKey,
            expiresInSeconds: ATTACHMENT_DOWNLOAD_EXPIRES_SECONDS,
          })

          const payload = response.data
          if (!response.success || !payload || !payload.downloadUrl) {
            throw new Error(payload?.message || response.message || '获取缩略图下载链接失败')
          }

          const { localPath, fromBlob } = await downloadAttachmentToLocalUrl(payload.downloadUrl, 'image/jpeg')
          console.log('缩略图下载完成:', { localPath, fromBlob, thumbnailKey })
          if (fromBlob) {
            registerBlobUrl(localPath)
          }
          attachmentUrlCache.set(thumbnailKey, {
            localPath,
            expiresAt: Date.now() + ATTACHMENT_CACHE_TTL_MS,
            downloadUrl: payload.downloadUrl,
          })

          // 更新视频 part 的缩略图 localPath（使用响应式更新）
          const index = messages.value.findIndex((msg: Message) => msg.id === message.id)
          if (index !== -1) {
            const msg = messages.value[index]
            if (Array.isArray(msg.parts)) {
              const partIndex = msg.parts.findIndex((p: MessagePart) => p === videoPart)
              if (partIndex !== -1 && msg.parts[partIndex].attachment) {
                // 创建新的 parts 数组以触发响应式更新
                const updatedParts = [...msg.parts]
                updatedParts[partIndex] = {
                  ...updatedParts[partIndex],
                  attachment: {
                    ...updatedParts[partIndex].attachment!,
                    localPath: localPath
                  }
                }
                messages.value[index] = {
                  ...msg,
                  parts: updatedParts
                }
                console.log('ensureVideoThumbnailLocalPath: 已更新消息的缩略图 localPath（下载后）')
              }
            }
          }

          return { localPath, downloadUrl: payload.downloadUrl }
        } catch (error: any) {
          console.warn('视频缩略图下载失败:', error)
          return null
        }
      })()
      pendingAttachmentDownloads.set(thumbnailKey, pending)
    }

    await pending
    pendingAttachmentDownloads.delete(thumbnailKey)
    return
  }

  // 没有 thumbnailKey，尝试从视频文件生成首帧
  if (attachment.localPath && !attachment.localPath.startsWith('blob:')) {
    console.log('视频没有缩略图，开始生成首帧:', attachment.localPath)
    try {
      const { invoke } = await import('@tauri-apps/api/core')
      // 生成缩略图文件名
      const thumbnailPath = `${attachment.localPath}.jpg`
      // 调用 Rust 函数生成首帧
      const result = await invoke<string>('generate_video_thumbnail', {
        videoPath: attachment.localPath,
        outputPath: thumbnailPath,
        timeSec: 1.0  // 1秒处截取
      })
      console.log('视频首帧生成成功:', result)

      // 更新视频 part 的缩略图 localPath
      const index = messages.value.findIndex((msg: Message) => msg.id === message.id)
      if (index !== -1) {
        const msg = messages.value[index]
        if (Array.isArray(msg.parts)) {
          const partIndex = msg.parts.findIndex((p: MessagePart) => p === videoPart)
          if (partIndex !== -1 && msg.parts[partIndex].attachment) {
            const updatedParts = [...msg.parts]
            updatedParts[partIndex] = {
              ...updatedParts[partIndex],
              attachment: {
                ...updatedParts[partIndex].attachment!,
                localPath: result,
                thumbnailKey: `generated:${attachment.key}`
              }
            }
            messages.value[index] = {
              ...msg,
              parts: updatedParts
            }
            console.log('ensureVideoThumbnailLocalPath: 已生成并更新视频首帧')
          }
        }
      }

      // 缓存缩略图
      attachmentUrlCache.set(`generated:${attachment.key}`, {
        localPath: result,
        expiresAt: Date.now() + ATTACHMENT_CACHE_TTL_MS,
      })
    } catch (error) {
      console.warn('生成视频首帧失败:', error)
      // 生成失败不阻断视频播放
    }
  } else {
    console.log('视频需要下载，开始下载:', attachment.localPath)
    // 如果视频还没有下载，先下载视频
    await ensureAttachmentLocalPath(message, videoPart)
  }
}

const parseVideoScreenShotSrc = (message: Message): string => {
  if (Array.isArray(message.parts)) {
    const videoPart = message.parts.find((part) => part.type === MessagePartType.VIDEO)
    if (videoPart?.attachment) {
      const attachment = videoPart.attachment
      
      // 优先处理缩略图
      if (attachment.thumbnailKey) {
        console.log('解析视频缩略图:', {
          messageId: message.id,
          thumbnailKey: attachment.thumbnailKey,
          hasLocalPath: !!attachment.localPath,
          localPath: attachment.localPath
        })
        
        // 先检查缓存中是否有缩略图的 localPath
        const thumbnailCached = attachmentUrlCache.get(attachment.thumbnailKey)
        console.log('缩略图缓存检查:', {
          thumbnailKey: attachment.thumbnailKey,
          cached: !!thumbnailCached,
          cachedLocalPath: thumbnailCached?.localPath,
          expiresAt: thumbnailCached?.expiresAt,
          isExpired: thumbnailCached ? thumbnailCached.expiresAt <= Date.now() : false
        })
        
        if (thumbnailCached && thumbnailCached.expiresAt > Date.now() && thumbnailCached.localPath) {
          console.log('使用缓存的缩略图:', thumbnailCached.localPath)
          // 如果缓存中有缩略图，更新 attachment.localPath（用于显示）
          if (attachment.localPath !== thumbnailCached.localPath) {
            const index = messages.value.findIndex((msg: Message) => msg.id === message.id)
            if (index !== -1) {
              const msg = messages.value[index]
              if (Array.isArray(msg.parts)) {
                const partIndex = msg.parts.findIndex((p: MessagePart) => p === videoPart)
                if (partIndex !== -1 && msg.parts[partIndex].attachment) {
                  const updatedParts = [...msg.parts]
                  updatedParts[partIndex] = {
                    ...updatedParts[partIndex],
                    attachment: {
                      ...updatedParts[partIndex].attachment!,
                      localPath: thumbnailCached.localPath
                    }
                  }
                  messages.value[index] = {
                    ...msg,
                    parts: updatedParts
                  }
                  console.log('已更新消息的缩略图 localPath')
                }
              }
            }
          }
          return thumbnailCached.localPath
        }
        
        // 如果缓存中没有，异步预加载缩略图（类似图片的预加载逻辑）
        console.log('缓存中没有缩略图，开始预加载:', attachment.thumbnailKey)
        void ensureVideoThumbnailLocalPath(message, videoPart)
        
        // 返回缩略图的 URL（在下载完成前先显示服务器 URL）
        const url = resolveAttachmentUrl(attachment.thumbnailKey)
        console.log('返回缩略图 URL:', url)
        if (url) {
          return url
        }
      } else {
        console.log('视频没有缩略图 key:', {
          messageId: message.id,
          hasThumbnailKey: !!attachment.thumbnailKey,
          hasKey: !!attachment.key
        })
      }
      
      // 如果没有缩略图但有本地路径（可能是视频本身），不用于缩略图显示
      // 返回空，让模板显示默认占位符
    }
  }

  if (typeof message.content === 'object' && message.content) {
    const content = message.content as any

    // 只处理专门的缩略图字段，不使用视频文件本身
    if (content.screenShot) {
      const target = content.fileSaveTarget || 'local'
      const thumbnailUrl = target === 'local'
        ? `${fileConfig.getFileByPath}${content.screenShot}`
        : content.screenShot
      return thumbnailUrl
    }

    // 对于没有缩略图的视频，返回空字符串，让模板显示默认占位符
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


    // 1. 消息发送成功或历史消息，优先使用服务器地址
    if ((message.status >= 2 && message.status <= 4) || !message.status) {
      // 优先使用现有的完整 URL
      if (content.url && content.url.trim() !== '' && (content.url.startsWith('http://') || content.url.startsWith('https://'))) {
        return content.url
      }

      // 使用 fullPath 构建 URL
      if (content.fullPath) {
        const target = content.fileSaveTarget || 'local'
        const serverUrl = target === 'local'
          ? `${fileConfig.showFile}${content.fullPath}`
          : content.fullPath
        return serverUrl
      }

      // 处理历史消息：url为空但有fileName的情况
      if (content.fileName && (!content.url || content.url.trim() === '')) {
        const target = content.fileSaveTarget || 'local'
        if (target === 'local') {
          const constructedUrl = `${fileConfig.showFile}chattingFiles/${content.fileName}`
          return constructedUrl
        }
      }
    }

    // 2. 发送中或失败时，使用本地预览
    if (message.status === 1 || message.status === 5) {
      if (content.localUrl) {
        return content.localUrl
      }

      if (content.url && (content.url.startsWith('blob:') || content.url.startsWith('data:'))) {
        return content.url
      }
    }

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

const getQuotedSenderName = (quoted: QuotedMessage): string => {
  return quoted.senderNickname || quoted.senderName || quoted.senderUsername || quoted.senderId || '引用'
}

const getQuotedAvatar = (quoted: QuotedMessage | null | undefined): string | null => {
  if (!quoted) return null
  return quoted.senderAvatar || quoted.senderAvatarUrl || null
}

const getQuotedInitial = (quoted: QuotedMessage | null | undefined): string => {
  const name = getQuotedSenderName(quoted as QuotedMessage)
  if (!name) return '?'
  return name.trim().charAt(0).toUpperCase()
}

const getSenderAvatarById = (userId?: string | null): string | null => {
  if (!userId) return null

  // 先从当前消息列表里找本地已解析的头像
  const msgAvatar = messages.value.find((m) => m.senderId === userId && m.senderAvatar)?.senderAvatar
  if (msgAvatar) return msgAvatar

  const msgLocal = messages.value.find((m) => m.senderId === userId && m.senderAvatarLocalPath)?.senderAvatarLocalPath
  if (msgLocal) return msgLocal

  // 再从已加载的群成员列表里找头像 URL
  const member = groupMembers.value.find((m) => m.userId === userId)
  if (member?.avatarUrl) return member.avatarUrl

  return null
}

const getQuotedText = (quoted: QuotedMessage): string => {
  if (Array.isArray(quoted.parts) && quoted.parts.length > 0) {
    const textPart = quoted.parts.find((part) => part.type === MessagePartType.TEXT && part.text?.trim())
    if (textPart?.text) return textPart.text
    const first = quoted.parts[0]
    switch (first.type) {
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

  if (quoted.content) return quoted.content
  return '[引用消息]'
}

const scrollToQuoted = (quoted: QuotedMessage | null | undefined) => {
  if (!quoted?.id) return
  nextTick(() => {
    const container = getMessagesViewport()
    const target = container?.querySelector(`[data-message-id="${quoted.id}"]`) as HTMLElement | null
    if (!target) return

    target.scrollIntoView({ behavior: 'smooth', block: 'center' })

    // 触发高亮动画（覆盖层渐隐）
    const existingTimer = quotedHighlightTimers.get(quoted.id)
    if (existingTimer) {
      clearTimeout(existingTimer)
      quotedHighlightTimers.delete(quoted.id)
    }

    target.classList.remove('quoted-highlighted')
    void target.offsetWidth
    target.classList.add('quoted-highlighted')
    const timer = window.setTimeout(() => {
      target.classList.remove('quoted-highlighted')
      quotedHighlightTimers.delete(quoted.id)
    }, 5200)
    quotedHighlightTimers.set(quoted.id, timer)
  })
}

const canCopyMessage = (message: Message | null): boolean => {
  if (!message) return false
  if (message.messageType === MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG) return false
  const text = getTextContent(message)
  return Boolean(text && text.trim().length)
}

const canDownloadMessage = (message: Message | null): boolean => {
  if (!message) return false
  if (Array.isArray(message.parts)) {
    return message.parts.some(
      (part) => part.type === MessagePartType.FILE && Boolean(part.attachment?.key || part.attachment?.downloadUrl),
    )
  }

  if (typeof message.content === 'object' && message.content) {
    const content: any = message.content
    return Boolean(content.key || content.downloadUrl)
  }

  return false
}

const canForwardMessage = (message: Message | null): boolean => {
  if (!message || message.isDeleted) return false
  // 仅文本支持转发（与移动端保持一致）
  if (message.contentType && message.contentType !== MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE) {
    return false
  }
  if (typeof message.content === 'string' && message.content.trim()) return true
  if (Array.isArray(message.parts)) {
    const textPart = message.parts.find((p) => p.type === MessagePartType.TEXT && p.text?.trim())
    return Boolean(textPart?.text)
  }
  if (typeof message.content === 'object' && message.content) {
    const text = (message.content as any).text
    return Boolean(text && text.trim())
  }
  return false
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

const mapQuotedMessageToUi = (quotedRaw: DomainMessage['quotedMessage'] | null | undefined, fallbackRoomId?: string): QuotedMessage | undefined => {
  if (!quotedRaw) return undefined

  // 兼容后端 snake_case 和 camelCase 字段
  const quoted: any = quotedRaw as any

  const quotedParts = quoted.parts ? cloneMessageParts(quoted.parts) : undefined

  const senderName = quoted.senderNickname
    || quoted.sender_nickname
    || quoted.senderName
    || quoted.sender_name
    || quoted.senderUsername
    || quoted.sender_username
    || ''

  const senderUsername = quoted.senderUsername
    || quoted.sender_username
    || quoted.senderName
    || quoted.sender_name
    || ''

  return {
    id: quoted.id,
    roomId: quoted.roomId || quoted.room_id || fallbackRoomId || '',
    senderId: quoted.senderId || quoted.sender_id || '',
    senderUsername,
    senderName,
    senderAvatar: quoted.senderAvatar || quoted.sender_avatar || quoted.senderAvatarUrl || quoted.sender_avatar_url || null,
    content: quoted.content,
    type: quoted.type || quoted.messageType || MessageType.TEXT,
    createdAt: quoted.createdAt ? new Date(quoted.createdAt) : quoted.created_at ? new Date(quoted.created_at) : null,
    isDeleted: !!(quoted.isDeleted ?? quoted.is_deleted),
    parts: quotedParts,
  }
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

  // 过滤掉相对路径的 senderAvatar,避免浏览器尝试加载导致 403 错误
  // 只保留完整的 http/https URL 或 blob URL
  const isValidUrl = (url: string | undefined) => {
    if (!url) return false
    return url.startsWith('http://') || url.startsWith('https://') || url.startsWith('blob:')
  }
  const senderAvatar = isValidUrl(msg.senderAvatar) ? msg.senderAvatar : undefined

  return {
    id: msg.id,
    content: normalizedContent,
    isSelf: msg.isSelf,
    time: formatTime(timestamp.toISOString()),
    senderId: msg.senderId,
    senderName: msg.senderName,
    senderAvatar: senderAvatar,
    senderAvatarObjectKey: msg.senderAvatarObjectKey,
    messageType,
    contentType: resolvedContentType,
    status: messageStatusToUiStatus[msg.status] || 2,
    createTime: timestamp.toISOString(),
    timestamp: timestamp.getTime(),
    isEdited: !!(msg.extra && (msg.extra as Record<string, unknown>).edited),
    parts,
    roomId: msg.roomId,
    quotedMessage: mapQuotedMessageToUi((msg as any).quotedMessage || (msg as any).quoted_message, msg.roomId),
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
const scrollToBottom = (force = false, instant = true) => {
  const scroll = () => {
    const vp = getMessagesViewport()
    if (vp) {
      // 使用 scrollTo 方法，支持无动画模式
      vp.scrollTo({
        top: vp.scrollHeight,
        behavior: instant ? 'instant' : 'smooth'
      })
      return true // 返回 true 表示成功滚动
    }
    return false // 返回 false 表示还没找到 viewport
  }

  // 立即尝试滚动
  scroll()

  // 使用 requestAnimationFrame 确保浏览器完成渲染
  requestAnimationFrame(() => {
    scroll()
    // 再次延迟确保 OverlayScrollbars 初始化完成
    setTimeout(scroll, 50)
    setTimeout(scroll, 100)
  })

  // 如果强制滚动或有图片消息，额外延迟确保图片加载完成
  if (force || messages.value.some((msg: Message) =>
    msg.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE ||
    msg.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE
  )) {
    setTimeout(scroll, 200)
    setTimeout(scroll, 500) // 给图片更多加载时间
  }
}

// 专门用于首次加载消息时的滚动，会持续重试直到成功
const scrollToBottomOnLoad = () => {
  console.log('[ScrollDebug] scrollToBottomOnLoad called')
  let retryCount = 0
  const maxRetries = 30 // 增加到 30 次

  const tryScroll = () => {
    const vp = getMessagesViewport()
    console.log('[ScrollDebug] tryScroll attempt:', retryCount + 1, 'viewport found:', !!vp)

    if (vp) {
      const beforeScroll = {
        scrollTop: vp.scrollTop,
        scrollHeight: vp.scrollHeight,
        clientHeight: vp.clientHeight
      }

      // 尝试多种滚动方式
      // 方式1: scrollTo
      vp.scrollTo({
        top: vp.scrollHeight,
        behavior: 'instant'
      })

      // 方式2: 直接设置 scrollTop
      vp.scrollTop = vp.scrollHeight

      // 添加短暂延迟后再检查
      setTimeout(() => {
        const afterScroll = {
          scrollTop: vp.scrollTop,
          scrollHeight: vp.scrollHeight,
          clientHeight: vp.clientHeight
        }

        console.log('[ScrollDebug] Before scroll:', beforeScroll)
        console.log('[ScrollDebug] After scroll:', afterScroll)

        // 检查是否真的滚动到底部了
        const isAtBottom = Math.abs(vp.scrollTop + vp.clientHeight - vp.scrollHeight) <= 20
        console.log('[ScrollDebug] Is at bottom:', isAtBottom, 'diff:', Math.abs(vp.scrollTop + vp.clientHeight - vp.scrollHeight))

        if (!isAtBottom && retryCount < maxRetries) {
          retryCount++
          // 使用更短的延迟重试
          setTimeout(tryScroll, 50)
        } else if (isAtBottom) {
          console.log('[ScrollDebug] Successfully scrolled to bottom after', retryCount + 1, 'attempts')
        }
      }, 20)
    } else {
      // 如果还找不到 viewport，继续重试
      if (retryCount < maxRetries) {
        retryCount++
        setTimeout(tryScroll, 50)
      } else {
        console.error('[ScrollDebug] Failed to find viewport after', maxRetries, 'attempts')
      }
    }
  }

  // 等待一小段时间让DOM完全渲染
  setTimeout(() => {
    tryScroll()
    // 使用多个时间点尝试，增加成功率
    setTimeout(tryScroll, 100)
    setTimeout(tryScroll, 200)
    setTimeout(tryScroll, 500)
  }, 10)
}

// 专门用于图片加载完成后的滚动
const scrollToBottomAfterImageLoad = () => {
  scrollToBottom(true)
}

// 监听消息变化，自动滚动到底部
watch(messages, (newMessages, oldMessages) => {
  // 当首次加载消息或消息数量增加时，滚动到底部
  if (!oldMessages || oldMessages.length === 0 || newMessages.length > oldMessages.length) {
    // 使用无动画模式滚动
    scrollToBottom(false, true)
  }
}, { flush: 'post' }) // flush: 'post' 确保DOM更新后执行

// 为每个账号缓存页面状态
interface ChatAccountState {
  selectedChat: ChatItem | null
  messages: Message[]
  newMessage: string
  searchText: string
  isInitialized: boolean
  groupMembers: RoomMember[]
  editingGroupName: string
  editingGroupNotice: string
  editingRemark: string
}

const accountStates = new Map<string, ChatAccountState>()

// 保存当前账号的状态
const saveCurrentAccountState = (accountId: string) => {
  accountStates.set(accountId, {
    selectedChat: selectedChat.value,
    messages: [...messages.value],
    newMessage: newMessage.value,
    searchText: searchText.value,
    isInitialized: isInitialized.value,
    groupMembers: [...groupMembers.value],
    editingGroupName: editingGroupName.value,
    editingGroupNotice: editingGroupNotice.value,
    editingRemark: editingRemark.value
  })
}

// 恢复指定账号的状态
const restoreAccountState = async (accountId: string) => {
  const state = accountStates.get(accountId)
  if (state) {
    
    selectedChat.value = state.selectedChat
    messages.value = [...state.messages]
    newMessage.value = state.newMessage
    searchText.value = state.searchText
    isInitialized.value = state.isInitialized
    groupMembers.value = [...state.groupMembers]
    editingGroupName.value = state.editingGroupName
    editingGroupNotice.value = state.editingGroupNotice
    editingRemark.value = state.editingRemark
    
    // 如果有选中的对话，重新加入房间
    if (state.selectedChat) {
      store.commit('SET_CURRENT_CHAT_GROUP_ID', state.selectedChat.groupId)
      webSocketManager.joinRoom(state.selectedChat.groupId)
    }
  } else {
    
    // 初始化为空状态
    selectedChat.value = null
    messages.value = []
    newMessage.value = ''
    searchText.value = ''
    isInitialized.value = false
    groupMembers.value = []
    editingGroupName.value = ''
    editingGroupNotice.value = ''
    editingRemark.value = ''
    
    // 如果账号状态中没有保存的聊天，但 store 中有 currentChatGroupId，尝试根据它选择聊天
    const currentChatGroupId = store.state.currentChatGroupId
    if (currentChatGroupId && chatList.value.length > 0) {
      const chatToSelect = chatList.value.find(chat => chat.groupId === currentChatGroupId)
      if (chatToSelect) {
        await selectChat(chatToSelect)
      } else {
        // 如果找不到对应的聊天，清除 currentChatGroupId
        store.commit('SET_CURRENT_CHAT_GROUP_ID', null)
      }
    }
  }
  
  // 始终重置对话框状态（不需要保留）
  showCreateGroupDialog.value = false
  showAddMemberDialog.value = false
  showEditGroupNameDialog.value = false
  showEditGroupNoticeDialog.value = false
  showEditRemarkDialog.value = false
  showGroupSettings.value = false
  showAddExistingGroupMemberDialog.value = false
  showRemoveMemberDialog.value = false
  showReportDialog.value = false
  showSearchDialog.value = false
  showEmojiPicker.value = false
  showMediaPreview.value = false
  showVoiceRecorder.value = false
  recentSentMessages.value.clear()
}

// 监听账号切换，保存/恢复状态
watch(
  () => store.state.accounts?.currentAccountId,
  async (newAccountId: any, oldAccountId: any) => {
    if (newAccountId && oldAccountId && newAccountId !== oldAccountId) {
      
      // 保存旧账号的状态
      saveCurrentAccountState(oldAccountId)
      
      // 恢复新账号的状态
      await restoreAccountState(newAccountId)
      
    }
  }
)

const selectChat = async (chat: ChatItem) => {
  selectedChat.value = chat
  store.commit('SET_CURRENT_CHAT_GROUP_ID', chat.groupId)
  
  // 更新账号页面状态中的 currentChatGroupId
  // 在多账号模式下，确保路由状态是 /home/chat
  let currentRoute: any
  if (props.accountId) {
    // 多账号模式：使用 /home/chat 路由状态
    currentRoute = {
      path: '/home/chat',
      name: 'Chat',
      params: {},
      query: {}
    }
  } else {
    // 单账号模式：使用全局路由
    currentRoute = router.currentRoute.value
  }
  store.dispatch('accounts/saveCurrentAccountPageState', currentRoute)
  
  webSocketManager.joinRoom(chat.groupId)

  // 如果是群聊，获取群组详细信息和成员列表
  if (chat.groupType === 1) {
    await loadGroupDetailInfo(chat.groupId)
  }

  await loadMessages(chat.groupId)

  // 加载消息后，标记消息已读（参考移动端实现）
  // 找到最后一条接收到的消息（非自己发送的）
  let latestIncomingMessage: Message | null = null
  for (let i = messages.value.length - 1; i >= 0; i--) {
    const msg = messages.value[i]
    if (!msg.isSelf) {
      latestIncomingMessage = msg
      break
    }
  }

  // 如果有接收到的消息，标记为已读
  if (latestIncomingMessage && latestIncomingMessage.status !== messageStatusToUiStatus[MessageStatus.READ]) {
    try {
      await MessageApi.markMessagesAsRead({
        groupId: chat.groupId,
        messageIds: [latestIncomingMessage.id]
      })
      
      // 更新本地未读数
      if (chat.unreadCount > 0) {
        const updatedChat = { ...chat, unreadCount: 0 }
        store.dispatch('updateChatItem', updatedChat)
        selectedChat.value.unreadCount = 0
      }
    } catch (error: any) {
      console.error('标记消息已读失败:', error)
    }
  } else if (chat.unreadCount > 0) {
    // 如果没有接收到的消息但未读数大于0，直接更新本地状态
    const updatedChat = { ...chat, unreadCount: 0 }
    store.dispatch('updateChatItem', updatedChat)
    selectedChat.value.unreadCount = 0
  }

  // 选择聊天后滚动到底部
  // 等待 Vue 完成 DOM 渲染
  console.log('[ScrollDebug] selectChat: before nextTick')
  await nextTick()
  console.log('[ScrollDebug] selectChat: after nextTick, messages count:', messages.value.length)

  // 使用持续重试的滚动函数，确保真正滚动到底部
  scrollToBottomOnLoad()
}

// 标记聊天为已读状态
const markChatAsRead = async (chat: ChatItem) => {
  try {
    const currentUser = store.getters.currentUser
    
    if (!currentUser?.id) {
      return
    }
    
    if (!chat.groupId) {
      toast.error('群组ID为空，无法标记已读')
      return
    }
    
    if (!chat.lastMessageId) {
      return
    }


    const response = await MessageApi.markMessagesAsRead({
      groupId: chat.groupId,
      messageIds: [chat.lastMessageId]
    })

    if (response.success) {
      const updatedChat = { ...chat, unreadCount: 0 }
      store.dispatch('updateChatItem', updatedChat)
    } else {
      // 使用 API 返回的错误消息
      toast.error('标记已读失败: ' + (response.message || '未知错误'))
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('标记已读失败: ' + errorMessage)
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

  const quotedFromReply = replyingMessage.value
    ? {
        id: replyingMessage.value.id,
        roomId: replyingMessage.value.roomId || groupId,
        senderId: replyingMessage.value.senderId,
        senderUsername: replyingMessage.value.senderName,
        senderName: replyingMessage.value.senderName,
        senderNickname: (replyingMessage.value as any).senderNickname || replyingMessage.value.senderName,
        senderAvatar: replyingMessage.value.senderAvatar ?? undefined,
        content: getTextContent(replyingMessage.value),
        type: MessageType.TEXT,
        createdAt: replyingMessage.value.createTime ? new Date(replyingMessage.value.createTime) : null,
        parts: cloneMessageParts(replyingMessage.value.parts),
        isDeleted: replyingMessage.value.isDeleted,
      }
    : undefined

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
    timestamp,
    quotedMessage: quotedFromReply,
  }

  messages.value.push(tempMessage)
  // 将临时消息ID添加到recentSentMessages，让WebSocket能够正确匹配并替换
  recentSentMessages.value.add(tempId)
  newMessage.value = ''
  scrollToBottom(false, true)

  try {
    const apiMessage = await webSocketManager.sendMessage({
      roomId: groupId,
      content,
      replyToMessageId: replyingMessage.value?.id,
    }, MESSAGE_CONSTANTS.BUSINESS_CODE.chatting)

    if (apiMessage) {
      const uiMessage = mapDomainMessageToUi(apiMessage)
      
      // 先检查是否已经存在真实消息（可能 WebSocket 先到达）
      const existingRealMessageIndex = messages.value.findIndex(msg => msg.id === apiMessage.id)
      if (existingRealMessageIndex !== -1) {
        // 如果真实消息已存在，更新状态即可，不需要重复添加
        messages.value[existingRealMessageIndex] = {
          ...messages.value[existingRealMessageIndex],
          status: 2
        }
        // 删除临时消息ID（如果WebSocket先到达并替换了临时消息）
        recentSentMessages.value.delete(tempId)
        // 添加真实消息ID到 recentSentMessages 用于去重
        recentSentMessages.value.add(apiMessage.id)
        setTimeout(() => {
          recentSentMessages.value.delete(apiMessage.id)
        }, 10000)
        return // 消息已存在，直接返回
      }
      
      // 查找临时消息并替换
      // 注意：临时消息可能已经被 WebSocket 替换为真实消息 ID，所以需要同时检查 tempId 和真实消息 ID
      let messageIndex = messages.value.findIndex(msg => msg.id === tempId)
      
      // 如果找不到 tempId，可能是已经被 WebSocket 替换了，检查真实消息 ID
      if (messageIndex === -1) {
        messageIndex = messages.value.findIndex(msg => msg.id === apiMessage.id)
      }
      
      if (messageIndex !== -1) {
        // 找到消息，更新为真实消息（确保状态为2，移除转圈圈）
        messages.value[messageIndex] = {
          ...uiMessage,
          status: 2
        }
        // 删除临时消息ID，添加真实消息ID到 recentSentMessages
        recentSentMessages.value.delete(tempId)
        recentSentMessages.value.add(apiMessage.id)
        setTimeout(() => {
          recentSentMessages.value.delete(apiMessage.id)
        }, 10000)
        return // 消息已更新，直接返回，避免后续重复处理
      } else {
        // 临时消息不存在，检查真实消息是否已经在列表中（WebSocket可能已经替换了）
        const realMessageExists = messages.value.some((msg) => msg.id === apiMessage.id)
        
        if (!realMessageExists) {
          // 真实消息也不存在，才添加新消息
          messages.value.push({
            ...uiMessage,
            status: 2
          })
        } else {
        }
        
        // 删除临时消息ID，添加真实消息ID到 recentSentMessages 用于去重
        recentSentMessages.value.delete(tempId)
        recentSentMessages.value.add(apiMessage.id)
        setTimeout(() => {
          recentSentMessages.value.delete(apiMessage.id)
        }, 10000)
      }
    }
  } catch (error: any) {
    const messageIndex = messages.value.findIndex(msg => msg.id === tempId)
    if (messageIndex !== -1) {
      messages.value[messageIndex].status = 5
    }
    // 发送失败时，从 recentSentMessages 中删除临时消息ID
    recentSentMessages.value.delete(tempId)
    toast.error('消息发送失败: ' + (error.message || '网络错误'))
  } finally {
    clearReplyingMessage()
  }
}

// 重发消息功能
const resendMessage = async (message: Message) => {
  if (!selectedChat.value) {
    return
  }


  const messageIndex = messages.value.findIndex(msg => msg.id === message.id)
  if (messageIndex !== -1) {
    messages.value[messageIndex].status = 1
  }

  if (Array.isArray(message.parts) && message.parts.length > 0) {
    toast.error('文件消息暂不支持重发，请重新选择文件发送')
    if (messageIndex !== -1) {
      messages.value[messageIndex].status = 5
    }
    return
  }

  const messageContent = typeof message.content === 'string'
    ? message.content
    : (message.content as any)?.text || getTextContent(message)

  if (!messageContent) {
    toast.error('无法获取消息内容，重发失败')
    if (messageIndex !== -1) {
      messages.value[messageIndex].status = 5
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
      messages.value[messageIndex].status = 5
    }
    toast.error('消息重发失败: ' + (error.message || '网络错误'))
  }
}

const handleSearch = (value: string) => {
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
  showEmojiPicker.value = !showEmojiPicker.value
}

// 处理表情选择
// 发送表情消息
const sendEmojiMessage = async (emoji: string) => {
  if (!selectedChat.value) {
    toast.error('请先选择聊天对象')
    return
  }

  // 判断是图片 URL 还是 emoji 字符
  const isImageUrl = emoji.startsWith('http://') || emoji.startsWith('https://')

  if (isImageUrl) {
    // 图片表情：使用 Rust HTTP 客户端下载图片（绕过 CORS）并作为图片消息发送
    try {
      const response = await rustHttp.requestRaw<{ base64?: string; headers?: Record<string, string> }>({
        path: emoji,
        method: 'GET',
        responseType: 'binary',
        injectToken: false // 表情 URL 是公开的，不需要 token
      })

      if (!response.success || !response.data || !response.data.base64) {
        throw new Error(response.message || '下载表情图片失败')
      }

      // 将 base64 转换为 Uint8Array
      const bytes = base64ToUint8Array(response.data.base64)
      
      // 获取 content type，默认为 image/png
      const contentType = response.data.headers?.['content-type'] || response.data.headers?.['Content-Type'] || 'image/png'
      
      // 从 URL 推断文件扩展名
      let fileName = 'emoji.png'
      try {
        const url = new URL(emoji)
        const pathname = url.pathname
        const match = pathname.match(/\.(gif|jpg|jpeg|png|webp)$/i)
        if (match) {
          fileName = `emoji.${match[1]}`
        }
      } catch (e) {
        // 如果 URL 解析失败，使用默认文件名
      }

      // 创建 Blob 和 File
      const blob = new Blob([bytes], { type: contentType })
      const file = new File([blob], fileName, { type: contentType })
      
      await uploadAndSendFile(file)
    } catch (error: any) {
      console.error('发送表情图片失败:', error)
      toast.error(error?.message || '发送表情失败，请重试')
    }
  } else {
    // Emoji 字符：作为文本消息发送
    const groupId = selectedChat.value.groupId
    const timestamp = Date.now()
    const tempId = `${timestamp}`
    const user = store.getters.currentUser

    const tempMessage: Message = {
      id: tempId,
      content: emoji,
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

    messages.value.push(tempMessage)
    recentSentMessages.value.add(tempId)
    scrollToBottom(false, true)

    try {
      const apiMessage = await webSocketManager.sendMessage({
        roomId: groupId,
        content: emoji,
      }, MESSAGE_CONSTANTS.BUSINESS_CODE.chatting)

      if (apiMessage) {
        const uiMessage = mapDomainMessageToUi(apiMessage)
        const existingRealMessageIndex = messages.value.findIndex(msg => msg.id === apiMessage.id)
        if (existingRealMessageIndex !== -1) {
          messages.value[existingRealMessageIndex] = {
            ...messages.value[existingRealMessageIndex],
            status: 2
          }
          recentSentMessages.value.delete(tempId)
        } else {
          const tempMessageIndex = messages.value.findIndex(msg => msg.id === tempId)
          if (tempMessageIndex !== -1) {
            messages.value[tempMessageIndex] = {
              ...uiMessage,
              status: 2
            }
            recentSentMessages.value.delete(tempId)
          } else {
            messages.value.push({
              ...uiMessage,
              status: 2
            })
          }
        }
        recentSentMessages.value.add(apiMessage.id)
        setTimeout(() => {
          recentSentMessages.value.delete(apiMessage.id)
        }, 10000)
      }
      scrollToBottom(false, true)
    } catch (error: any) {
      console.error('发送表情消息失败:', error)
      const tempMessageIndex = messages.value.findIndex(msg => msg.id === tempId)
      if (tempMessageIndex !== -1) {
        messages.value[tempMessageIndex].status = 5
      }
      toast.error('发送失败，请重试')
    }
  }
}

const handleEmojiSelect = (emoji: string) => {
  // 直接发送表情消息，而不是插入到输入框
  sendEmojiMessage(emoji)
  // 关闭表情选择器
  showEmojiPicker.value = false
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
}

// 处理视频缩略图加载错误
const handleVideoThumbnailError = (event: Event) => {
  const img = event.target as HTMLImageElement
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
const handleVideoPlay = async (message: Message) => {
  try {
    let videoSrc = ''
    
    // 先确保视频附件已下载到本地
    if (Array.isArray(message.parts)) {
      const videoPart = message.parts.find((part) => part.type === MessagePartType.VIDEO)
      if (videoPart?.attachment) {
        // 如果还没有本地路径，先下载
        if (!videoPart.attachment.localPath && videoPart.attachment.key) {
          console.log('视频需要下载，开始下载:', videoPart.attachment.key)
          // 先尝试下载，但不显示错误 toast（我们会自己处理）
          try {
            await ensureAttachmentLocalPath(message, videoPart)
          } catch (error: any) {
            console.warn('视频下载失败，尝试使用原始 URL:', error)
          }
          
          // 重新获取消息，因为 ensureAttachmentLocalPath 会更新消息
          const updatedMessage = messages.value.find(m => m.id === message.id) || message
          const updatedVideoPart = updatedMessage.parts?.find((part) => part.type === MessagePartType.VIDEO)
          
          if (updatedVideoPart?.attachment?.localPath) {
            videoSrc = updatedVideoPart.attachment.localPath
            console.log('视频下载成功，使用本地路径:', videoSrc)
          } else {
            // 如果下载失败，尝试使用原始 URL
            const parsedSrc = parseVideoSrc(updatedMessage)
            if (parsedSrc) {
              videoSrc = parsedSrc
              console.log('使用原始 URL:', videoSrc)
            } else {
              toast.error('视频加载失败，请重试')
              return
            }
          }
        } else if (videoPart.attachment.localPath) {
          // 已有本地路径，直接使用
          videoSrc = videoPart.attachment.localPath
          console.log('使用已有本地路径:', videoSrc)
        } else {
          // 尝试使用 parseVideoSrc 获取 URL
          const parsedSrc = parseVideoSrc(message)
          if (parsedSrc) {
            videoSrc = parsedSrc
            console.log('使用 parseVideoSrc 获取的 URL:', videoSrc)
          } else {
            toast.error('视频地址无效')
            return
          }
        }
      } else {
        // 没有 attachment，尝试使用 parseVideoSrc
        const parsedSrc = parseVideoSrc(message)
        if (parsedSrc) {
          videoSrc = parsedSrc
        } else {
          toast.error('视频地址无效')
          return
        }
      }
    } else {
      // 没有 parts，尝试使用 parseVideoSrc
      const parsedSrc = parseVideoSrc(message)
      if (parsedSrc) {
        videoSrc = parsedSrc
      } else {
        toast.error('视频地址无效')
        return
      }
    }

    if (!videoSrc) {
      toast.error('无法获取视频地址')
      return
    }

    // 设置媒体信息并显示预览
    previewMediaSrc.value = videoSrc
    previewMediaType.value = 'video'
    if (typeof message.content === 'object' && message.content) {
      previewMediaName.value = message.content.name || '视频文件'
      previewMediaSize.value = message.content.size || 0
    }
    console.log('准备播放视频:', previewMediaSrc.value)
    showMediaPreview.value = true
  } catch (error: any) {
    console.error('视频播放失败:', error)
    toast.error('视频加载失败: ' + (error?.message || '未知错误'))
  }
}

// 处理上传点击
const handleUploadClick = () => {
  
  // 检查是否有选中的聊天
  if (!selectedChat.value || !selectedChat.value.groupId) {
    toast.error('请先选择聊天对象')
    return
  }
  
  // 创建文件输入元素
  const input = document.createElement('input')
  input.type = 'file'
  // 移除 accept 限制，允许选择所有文件类型
  input.multiple = true
  
  // 使用 addEventListener 而不是 onchange，确保事件正确绑定
  input.addEventListener('change', handleFileUpload, { once: true })
  
  input.click()
}

// 处理文件上传
const handleFileUpload = async (event: Event) => {
  const target = event.target as HTMLInputElement
  const files = target.files

  if (!files || files.length === 0) {
    return
  }

  // 创建文件数组的副本，因为 FileList 在处理后可能会被清空
  const fileArray = Array.from(files)
  
  console.log('开始处理文件上传，文件数量:', fileArray.length)
  for (let i = 0; i < fileArray.length; i++) {
    const file = fileArray[i]
    console.log(`处理文件 ${i + 1}/${fileArray.length}:`, {
      name: file.name,
      type: file.type,
      size: file.size,
      isVideo: file.type.startsWith('video/'),
      isImage: file.type.startsWith('image/')
    })
    try {
      await uploadAndSendFile(file)
    } catch (error: any) {
      console.error(`文件 ${file.name} 上传失败:`, error)
      toast.error(`文件 ${file.name} 上传失败: ${error?.message || '未知错误'}`)
    }
  }
  
  // 清理 input 元素
  target.value = ''
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
      resolve()
    }
    img.onerror = () => {
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
    console.log('开始处理文件:', file.name, '类型:', file.type, '大小:', file.size)
    const meta = await determineAttachmentMeta(file)
    console.log('文件元数据确定:', meta)

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

    console.log('请求上传签名:', {
      groupId: selectedChat.value.groupId,
      partType: meta.partType,
      fileName: file.name,
      contentType: meta.mime
    })
    const signatureResponse = await MessageApi.requestAttachmentSignature({
      groupId: selectedChat.value.groupId,
      partType: meta.partType,
      fileName: file.name,
      contentType: meta.mime,
    })

    if (!signatureResponse.success || !signatureResponse.data) {
      throw new Error(signatureResponse.message || '获取上传签名失败')
    }
    console.log('上传签名获取成功，开始上传文件')

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
    // 将临时消息ID添加到recentSentMessages，让WebSocket能够正确匹配并替换
    recentSentMessages.value.add(tempId)
    scrollToBottom(false, true)

    console.log('开始上传文件到COS:', file.name)
    await uploadWithSignature(signatureResponse.data.signature, file, (progress) => {
      console.log('上传进度:', progress, file.name)
      if (tempId) {
        updateAttachmentProgress(tempId, attachmentKey, progress)
      }
    })
    console.log('文件上传完成:', file.name)

    if (tempId) {
      updateAttachmentProgress(tempId, attachmentKey, null)
    }

    console.log('发送消息到服务器:', { partType: meta.partType, fileName: file.name })
    const apiMessage = await webSocketManager.sendMessage({
      roomId: selectedChat.value.groupId,
      content: meta.summary,
      parts: [buildAttachmentPartPayload(meta, attachmentKey, file)],
    }, MESSAGE_CONSTANTS.BUSINESS_CODE.chatting)
    console.log('消息发送完成:', apiMessage?.id)

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
          // 删除临时消息ID，添加真实消息ID
          recentSentMessages.value.delete(tempId)
        } else {
          // 临时消息不存在，检查真实消息是否已经在列表中（WebSocket可能已经替换了）
          const realMessageExists = messages.value.some((msg) => msg.id === apiMessage.id)
          if (!realMessageExists) {
            // 真实消息也不存在，才添加新消息
            messages.value.push({
              ...uiMessage,
              status: 2,
              roomId: uiMessage.roomId ?? selectedChat.value.groupId,
            })
          } else {
          }
          // 消息不存在，可能已被WebSocket替换，删除临时ID
          recentSentMessages.value.delete(tempId)
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

    scrollToBottom(false, true)
  } catch (error: any) {
    console.error('文件上传失败:', error, {
      fileName: file.name,
      fileType: file.type,
      fileSize: file.size,
      tempId,
      attachmentKey
    })
    if (tempId) {
      const messageIndex = messages.value.findIndex((msg) => msg.id === tempId)
      if (messageIndex !== -1) {
        messages.value[messageIndex].status = 5
        updateAttachmentProgress(tempId, attachmentKey, null)
      }
      // 上传失败时，从 recentSentMessages 中删除临时消息ID
      recentSentMessages.value.delete(tempId)
    }
    toast.error('文件发送失败: ' + (error.message || '网络错误'))
  }
}

const handleCreateGroup = async () => {
  // 显示创建群聊对话框
  showCreateGroupDialog.value = true
}

// 加载联系人列表用于群组创建
const loadContactsForGroup = async () => {
  isLoadingContacts.value = true
  try {

    // 获取好友列表
    const response = await FriendApi.getMyFriendList({
      page: 1,
      size: 1000
    })

    if (response.success && response.data && Array.isArray(response.data)) {
      // API响应格式：FriendInfo[]
      const allContacts: any[] = response.data.map((friend: any) => {
        const user = friend.user || {}
        return {
          id: user.id || friend.id || '',
          nickname: user.nickname?.trim() || user.username || '未知用户',
          avatar: user.avatarUrl || '',
          username: user.username || ''
        }
      })

      contacts.value = allContacts
    } else {
      toast.error('获取联系人列表失败: ' + (response.message || '未知错误'))
      contacts.value = []
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('获取联系人列表失败: ' + errorMessage)
    contacts.value = []
  } finally {
    isLoadingContacts.value = false
  }
}

// 处理群创建确认
const handleCreateGroupConfirm = async (data: {
  name: string
  notice?: string
  avatar?: string
  memberIds: string[]
}) => {

  try {
    isCreatingGroup.value = true

    // 如果提供了头像且是 base64 格式，需要先上传
    let avatarUrl: string | undefined
    if (data.avatar && data.avatar.startsWith('data:')) {
      try {
        // 直接从 data URL 创建 File 对象
        const response = await fetch(data.avatar)
        const blob = await response.blob()
        const file = new File([blob], 'group-avatar.jpg', { type: 'image/jpeg' })

        // 上传文件
        const uploadResult = await FileApi.uploadFile({
          file,
          category: 'group_avatar',
          isPublic: true,
          description: '群头像'
        })

        if (uploadResult.code === 200 && uploadResult.data) {
          avatarUrl = FileApi.buildImageUrl(uploadResult.data)
        }
      } catch (error: any) {
      }
    }

    // 调用创建群组API
    const currentUser = store.getters.currentUser
    const membersWithCreator = [...data.memberIds, currentUser.id] // 成员列表必须包含创建者


    const response = await GroupApi.launchChatGroup({
      name: data.name,
      memberIds: membersWithCreator,
      description: data.notice || undefined,
      avatarUrl: avatarUrl
    })

    if (response.success && response.data) {
      toast.success('群组创建成功')

      // 关闭对话框
      showCreateGroupDialog.value = false

      // 提取返回的群组信息
      const groupId = response.data.roomId
      const groupName = data.name

      // 重新加载聊天列表以显示新创建的群组
      await loadChatList(true) // 强制刷新获取最新数据

      // 使用返回的groupId和groupName查找新创建的群组
      let newGroup: ChatItem | undefined

      // 尝试多次查找新创建的群组（因为可能需要时间同步）
      for (let attempt = 0; attempt < 3; attempt++) {

        // 优先使用 groupId 查找，其次使用 groupName
        newGroup = chatList.value.find(chat =>
          chat.groupId === groupId ||
          chat.id === groupId ||
          chat.name === groupName ||
          chat.name.includes(groupName)
        )

        if (newGroup) {
          await selectChat(newGroup)

          // 发送群组创建的系统消息
          await sendGroupCreationSystemMessage(groupId, groupName)
          break
        } else {

          if (attempt < 2) { // 只在前两次尝试时等待
            await new Promise(resolve => setTimeout(resolve, 1000))
            await loadChatList(true) // 重新加载
          }
        }
      }

      // 如果最终没找到群组，提供备用方案
      if (!newGroup) {
        toast.warning('群组创建成功，但无法自动打开，请手动选择群组')
      }
    } else {
      toast.error('群组创建失败: ' + (response.message || '未知错误'))
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('群组创建失败: ' + errorMessage)
  } finally {
    isCreatingGroup.value = false
  }
}

// 取消创建群组
const handleCancelCreateGroup = () => {
  showCreateGroupDialog.value = false
  isCreatingGroup.value = false
}

// ==================== 聊天列表右键菜单处理 ====================

// 显示右键菜单
const handleChatContextMenu = (chat: ChatItem, event: MouseEvent) => {
  event.preventDefault()
  event.stopPropagation()
  
  contextMenuChat.value = chat
  contextMenuPosition.value = {
    x: event.clientX,
    y: event.clientY
  }
  showContextMenu.value = true
  
}

// 消息右键菜单
const handleMessageContextMenu = (message: Message, event: MouseEvent) => {
  if (message.messageType === MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG) return
  event.preventDefault()
  event.stopPropagation()

  messageContextMenuTarget.value = message
  messageContextMenuPosition.value = {
    x: event.clientX,
    y: event.clientY,
  }
  showMessageContextMenu.value = true
}

const handleMessageMenuCopy = async () => {
  const target = messageContextMenuTarget.value
  if (!target) return
  const text = getTextContent(target)
  if (!text || !text.trim()) {
    toast.warning('该消息没有可复制的文本')
    return
  }

  try {
    await navigator.clipboard.writeText(text)
    toast.success('复制成功')
  } catch (error) {
    console.error('复制失败', error)
    toast.error('复制失败，请重试')
  } finally {
    showMessageContextMenu.value = false
  }
}

const handleMessageMenuQuote = () => {
  const target = messageContextMenuTarget.value
  if (!target) return
  replyingMessage.value = target
  showMessageContextMenu.value = false
  // 聚焦输入框
  nextTick(() => {
    messageInput.value?.focus()
  })
}

// 清除回复状态
const clearReplyingMessage = () => {
  replyingMessage.value = null
}

// 转发相关状态
const showForwardDialog = ref(false)
const forwardSourceMessage = ref<Message | null>(null)
const forwardTargetIds = ref<string[]>([])

const handleMessageMenuForward = (message?: Message) => {
  const target = message ?? messageContextMenuTarget.value
  if (!multiSelectMode.value) {
    if (!target || !canForwardMessage(target)) return
    forwardSourceMessage.value = target
  } else {
    forwardSourceMessage.value = null
  }
  forwardTargetIds.value = []
  showMessageContextMenu.value = false
  showForwardDialog.value = true
}

const confirmForward = async () => {
  const sources: Message[] = multiSelectMode.value
    ? messages.value.filter((m) => selectedMessageIds.has(m.id))
    : (forwardSourceMessage.value ? [forwardSourceMessage.value] : [])

  if (!sources.length) {
    toast.warning('请选择要转发的消息')
    return
  }
  if (!forwardTargetIds.value.length) {
    toast.warning('请选择要转发的会话')
    return
  }

  try {
    for (const source of sources) {
      const res = await MessageApi.forwardMessage({
        groupId: source.roomId || selectedChat.value?.groupId || '',
        messageId: source.id,
        targetRoomIds: forwardTargetIds.value,
      })
      if (!res.success) {
        throw new Error(res.message || '转发失败')
      }
    }
    toast.success('已转发')
    if (multiSelectMode.value) {
      exitMultiSelect()
    }
  } catch (error) {
    console.error('转发失败', error)
    toast.error(error instanceof Error ? error.message : '转发失败，请稍后重试')
  } finally {
    showForwardDialog.value = false
    forwardSourceMessage.value = null
  }
}

const handleMessageMenuPin = async () => {
  const target = messageContextMenuTarget.value
  if (!target) return
  const roomId = target.roomId || selectedChat.value?.groupId
  if (!roomId) return

  const isPinned = Boolean(target.pinnedAt)
  try {
    if (isPinned) {
      const res = await MessageApi.unpinMessage({ groupId: roomId, messageId: target.id })
      if (res.success) {
        target.pinnedAt = null
        toast.success('已取消置顶')
      } else {
        toast.error(res.message || '取消置顶失败')
      }
    } else {
      const res = await MessageApi.pinMessage({ groupId: roomId, messageId: target.id, currentUserId: currentUserId.value })
      if (res.success) {
        target.pinnedAt = res.data?.pinnedAt || new Date()
        toast.success('消息已置顶')
      } else {
        toast.error(res.message || '置顶失败')
      }
    }
  } catch (error) {
    console.error('置顶/取消置顶失败', error)
    toast.error('操作失败，请稍后再试')
  } finally {
    showMessageContextMenu.value = false
  }
}

const handleMessageMenuDelete = async () => {
  const target = messageContextMenuTarget.value
  if (!target) return
  if (!target.isSelf) {
    toast.warning('只能删除自己发送的消息')
    showMessageContextMenu.value = false
    return
  }

  const roomId = target.roomId || selectedChat.value?.groupId
  if (!roomId) {
    toast.error('缺少房间信息，无法删除')
    showMessageContextMenu.value = false
    return
  }

  try {
    const res = await MessageApi.deleteMessage({ groupId: roomId, messageId: target.id })
    if (res.success) {
      const index = messages.value.findIndex((msg) => msg.id === target.id)
      if (index !== -1) {
        messages.value.splice(index, 1)
      }
      toast.success('消息已删除')
    } else {
      toast.error(res.message || '删除失败')
    }
  } catch (error) {
    console.error('删除消息失败', error)
    toast.error('删除失败，请重试')
  } finally {
    showMessageContextMenu.value = false
  }
}

// 多选模式（拖拽进入）
const multiSelectMode = ref(false)
const selectedMessageIds = reactive(new Set<string>())

const enterMultiSelect = () => {
  if (!multiSelectMode.value) {
    multiSelectMode.value = true
  }
}

const exitMultiSelect = () => {
  multiSelectMode.value = false
  selectedMessageIds.clear()
}

const selectMessage = (message: Message, selected: boolean) => {
  if (message.messageType === MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG) return
  if (selected) {
    selectedMessageIds.add(message.id)
  } else {
    selectedMessageIds.delete(message.id)
  }
}

const toggleMessageSelection = (message: Message) => {
  // 只有在多选模式下才能切换选中状态
  if (!multiSelectMode.value) return

  // 系统消息不能被选中
  if (message.messageType === MESSAGE_CONSTANTS.MSG_TYPE.SYSTEM_MSG) return

  if (selectedMessageIds.has(message.id)) {
    selectMessage(message, false)
  } else {
    selectMessage(message, true)
  }
}

const isMessageSelected = (message: Message) => selectedMessageIds.has(message.id)

const selectedMessagesCount = computed(() => selectedMessageIds.size)

const deleteSelectedMessages = async () => {
  if (!selectedMessageIds.size) return
  const roomId = selectedChat.value?.groupId
  if (!roomId) return

  const targets = messages.value.filter((m) => selectedMessageIds.has(m.id))
  const invalid = targets.filter((m) => !m.isSelf)
  if (invalid.length) {
    toast.warning('只能删除自己发送的消息')
    return
  }

  try {
    for (const msg of targets) {
      const res = await MessageApi.deleteMessage({ groupId: roomId, messageId: msg.id })
      if (!res.success) {
        throw new Error(res.message || '删除失败')
      }
      const idx = messages.value.findIndex((m) => m.id === msg.id)
      if (idx !== -1) messages.value.splice(idx, 1)
    }
    toast.success('已删除所选消息')
    exitMultiSelect()
  } catch (error) {
    console.error('批量删除失败', error)
    toast.error(error instanceof Error ? error.message : '删除失败')
  }
}

const handleMessageMenuDownload = async () => {
  const target = messageContextMenuTarget.value
  if (!target) return
  showMessageContextMenu.value = false
  await handleFileDownload(target)
}

const handleGlobalKeydown = (event: KeyboardEvent) => {
  if (event.key === 'Escape') {
    showMessageContextMenu.value = false
    showContextMenu.value = false
    if (multiSelectMode.value) {
      exitMultiSelect()
    }
  }
}

// 拖拽多选
const isDraggingSelect = ref(false)
const dragAnchorMessageId = ref<string | null>(null)
const dragStartPosition = ref<{ x: number; y: number } | null>(null)
const isDragSelectingClass = computed(() => isDraggingSelect.value || multiSelectMode.value)

const getMessageIdAtPoint = (clientX: number, clientY: number): string | null => {
  const el = document.elementFromPoint(clientX, clientY) as HTMLElement | null
  const target = el?.closest('[data-message-id]') as HTMLElement | null
  return target?.getAttribute('data-message-id') || null
}

const ensureMultiSelectMode = () => {
  if (!multiSelectMode.value) {
    enterMultiSelect()
    clearBrowserSelection()
  }
}

const clearBrowserSelection = () => {
  const selection = window.getSelection()
  if (selection && selection.removeAllRanges) {
    selection.removeAllRanges()
  }
}

const handleMouseDownOnMessages = (event: MouseEvent) => {
  if (event.button !== 0) return // 仅左键
  const target = (event.target as HTMLElement)?.closest('[data-message-id]') as HTMLElement | null
  dragAnchorMessageId.value = target?.getAttribute('data-message-id') || null
  // 记录鼠标按下位置，用于判断是否真的进行了拖拽
  dragStartPosition.value = { x: event.clientX, y: event.clientY }
  isDraggingSelect.value = false // 先不设置为拖拽状态，等鼠标移动后再确定
  if (dragAnchorMessageId.value) {
    clearBrowserSelection()
  }
}

const handleMouseMoveOnMessages = (event: MouseEvent) => {
  // 如果有锚点消息，检查是否真的在拖拽
  if (dragAnchorMessageId.value && dragStartPosition.value && !isDraggingSelect.value) {
    // 计算鼠标移动距离，超过阈值才认为是拖拽
    const deltaX = Math.abs(event.clientX - dragStartPosition.value.x)
    const deltaY = Math.abs(event.clientY - dragStartPosition.value.y)
    if (deltaX > 5 || deltaY > 5) {
      isDraggingSelect.value = true
    }
  }

  if (!isDraggingSelect.value) return
  const id = getMessageIdAtPoint(event.clientX, event.clientY)
  if (!id) return

  if (!multiSelectMode.value && dragAnchorMessageId.value && id !== dragAnchorMessageId.value) {
    // 第一次跨消息，进入多选模式
    ensureMultiSelectMode()
  }

  if (multiSelectMode.value && dragAnchorMessageId.value) {
    // 找到起点和终点的索引
    const anchorIndex = messages.value.findIndex((m) => m.id === dragAnchorMessageId.value)
    const currentIndex = messages.value.findIndex((m) => m.id === id)

    if (anchorIndex !== -1 && currentIndex !== -1) {
      // 计算范围（支持向上或向下拖拽）
      const startIndex = Math.min(anchorIndex, currentIndex)
      const endIndex = Math.max(anchorIndex, currentIndex)

      // 先清除所有选中状态
      selectedMessageIds.clear()

      // 选中范围内的所有消息
      for (let i = startIndex; i <= endIndex; i++) {
        selectMessage(messages.value[i], true)
      }
    }
  }
}

const handleMouseUpOnMessages = () => {
  if (multiSelectMode.value && isDraggingSelect.value) {
    clearBrowserSelection()
  }
  // 重置拖拽状态
  isDraggingSelect.value = false
  dragAnchorMessageId.value = null
  dragStartPosition.value = null
}

const handleIndicatorClick = (message: Message) => {
  ensureMultiSelectMode()
  toggleMessageSelection(message)
}

const handleMessageHover = (message: Message) => {
  // 只有在拖拽选择时才自动选中悬停的消息
  if (!isDraggingSelect.value) return
  // 拖拽时无需处理悬停，handleMouseMoveOnMessages 已经处理了
}

// 计算可用于转发的会话列表（排除当前会话）
const forwardableChats = computed(() => {
  const currentId = selectedChat.value?.groupId
  return chatList.value.filter((chat) => chat.groupId !== currentId)
})

// 处理置顶/取消置顶
const handleContextMenuPin = async (chat: ChatItem) => {
  try {
    const targetState = !chat.isTop
    
    // 调用API
    const response = targetState 
      ? await GroupApi.pinChat({ roomId: chat.groupId })
      : await GroupApi.unpinChat({ roomId: chat.groupId })
    
    if (response.success) {
      // 更新本地状态
      const chatIndex = chatList.value.findIndex(c => c.id === chat.id)
      if (chatIndex !== -1) {
        chatList.value[chatIndex].isTop = targetState
      }
      
      // 更新 store
      store.dispatch('updateChatItem', {
        ...chat,
        isTop: targetState
      })
      
      // 重新加载聊天列表以更新排序
      await loadChatList(true)
      
      toast.success(targetState ? '已置顶' : '已取消置顶')
    } else {
      toast.error(response.message || (targetState ? '置顶失败' : '取消置顶失败'))
    }
  } catch (error: any) {
    toast.error(error.message || '操作失败')
  }
}

// 处理消息免打扰/允许通知
const handleContextMenuMute = async (chat: ChatItem) => {
  try {
    const targetState = chat.chatStatus === 1 ? 0 : 2 // 0=允许通知, 2=免打扰
    
    // 调用API
    const response = await MessageApi.updateNotificationSettings({
      roomId: chat.groupId,
      notificationSettings: targetState
    })
    
    if (response.success) {
      // 更新本地状态
      const chatIndex = chatList.value.findIndex(c => c.id === chat.id)
      if (chatIndex !== -1) {
        chatList.value[chatIndex].chatStatus = targetState === 2 ? 1 : 0
      }
      
      // 更新 store
      store.dispatch('updateChatItem', {
        ...chat,
        chatStatus: targetState === 2 ? 1 : 0
      })
      
      toast.success(targetState === 2 ? '已开启消息免打扰' : '已允许消息通知')
    } else {
      toast.error(response.message || '设置失败')
    }
  } catch (error: any) {
    toast.error(error.message || '操作失败')
  }
}

// 处理删除对话 - 显示确认对话框
const handleContextMenuDelete = (chat: ChatItem) => {
  
  // 保存要删除的对话信息
  deleteTargetChat.value = chat
  
  // 显示确认对话框
  showDeleteConfirm.value = true
}

// 取消删除
const cancelDelete = () => {
  deleteTargetChat.value = null
}

// 确认删除对话
const confirmDelete = async () => {
  if (!deleteTargetChat.value) {
    return
  }
  
  const chat = deleteTargetChat.value
  
  try {
    
    // 调用后端 API 删除对话
    const response = await GroupApi.deleteChat({ roomId: chat.groupId })
    
    if (!response.success) {
      throw new Error(response.message || '删除失败')
    }
    
    
    // 如果删除的是当前选中的对话，清空选中状态
    if (selectedChat.value && selectedChat.value.id === chat.id) {
      selectedChat.value = null
      messages.value = []
      
      // 清空当前房间 ID
      store.commit('SET_CURRENT_CHAT_GROUP_ID', null)
    }
    
    // 通过 store 删除（这会触发 computed 重新计算）
    await store.dispatch('removeChatItem', chat.id)
    
    // 删除成功后立即刷新聊天列表，确保数据同步
    await loadChatList(true) // 强制刷新API数据
    
    toast.success('对话已永久删除')
  } catch (error: any) {
    toast.error(error.message || '删除失败')
  } finally {
    // 清理状态
    showDeleteConfirm.value = false
    deleteTargetChat.value = null
  }
}

// 旧的添加成员对话框处理函数（已废弃，保留以避免模板引用错误）
const handleConfirmAddMembers = () => {
  showAddMemberDialog.value = false
}

const handleCancelAddMembers = () => {
  showAddMemberDialog.value = false
}

// 处理群头像修改
const handleEditGroupAvatar = () => {
  if (!selectedChat.value) return


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

    // 使用 GroupApi.uploadGroupAvatar 上传到 COS
    const uploadResult = await GroupApi.uploadGroupAvatar(selectedChat.value.groupId, file)

    if (uploadResult.success && uploadResult.data) {
      toast.success('群头像修改成功')

      // 获取临时下载URL用于显示
      const downloadUrlResult = await GroupApi.getRoomAvatarDownloadUrl({
        roomId: selectedChat.value.groupId,
        expiresInSeconds: 3600 * 24 * 7 // 7天有效期
      })

      if (downloadUrlResult.success && downloadUrlResult.data) {
        const downloadUrl = downloadUrlResult.data.downloadUrl

        // 更新本地数据
        if (selectedChat.value) {
          // 1. 更新当前选中的聊天项
          selectedChat.value.avatar = downloadUrl

          // 2. 同步更新store中的聊天列表
          const updatedChat = { ...selectedChat.value, avatar: downloadUrl }
          store.dispatch('updateChatItem', updatedChat)

          // 3. 发送群头像修改的系统消息（使用downloadUrl）
          await sendGroupAvatarUpdateSystemMessage(selectedChat.value.groupId, downloadUrl)
        }
      } else {
        throw new Error(downloadUrlResult.message || '获取群头像临时下载URL失败')
      }
    } else {
      throw new Error(uploadResult.message || '群头像上传失败')
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('群头像修改失败: ' + errorMessage)
  }
}

// 处理群公告修改
const handleEditGroupNotice = () => {
  if (!selectedChat.value) return


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

  if (newGroupNotice.length > 500) {
    groupNameError.value = '群公告不能超过500个字符'
    return
  }

  if (!selectedChat.value?.groupId) {
    groupNameError.value = '未找到群组信息'
    return
  }

  isUpdatingGroupNotice.value = true
  groupNameError.value = ''

  try {
    const roomId = selectedChat.value.groupId

    // 1. 先获取现有的群公告列表
    const listResponse = await GroupApi.listAnnouncements({ roomId })

    let response: any

    if (listResponse.success && listResponse.data && listResponse.data.length > 0) {
      // 如果有现有公告，更新最新的一条
      const latestAnnouncement = listResponse.data[0]

      response = await GroupApi.updateAnnouncement({
        roomId,
        announcementId: latestAnnouncement.id,
        content: newGroupNotice
      })
    } else {
      // 如果没有公告，创建新的

      response = await GroupApi.createAnnouncement({
        roomId,
        content: newGroupNotice
      })
    }

    if (response.success) {
      toast.success('群公告修改成功')

      // 更新本地数据
      if (selectedChat.value) {
        selectedChat.value.groupNotice = newGroupNotice
        selectedChat.value.showNoticeFlag = 1

      }

      // 发送群公告修改的系统消息
      await sendGroupNoticeUpdateSystemMessage(roomId, newGroupNotice)

      // 重新加载群详情以确保数据同步
      await loadGroupDetailInfo(roomId)

      // 关闭弹窗
      showEditGroupNoticeDialog.value = false
    } else {
      // 使用 API 返回的错误消息
      groupNameError.value = response.message || '修改失败'
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误，请稍后重试';
    groupNameError.value = errorMessage
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

// 处理备注修改
const handleEditRemark = () => {
  if (!selectedChat.value) return


  // 设置当前备注作为默认值（如果有的话）
  editingRemark.value = selectedChat.value.remark || ''
  groupNameError.value = ''

  // 关闭群设置抽屉，打开备注修改弹窗
  showGroupSettings.value = false
  showEditRemarkDialog.value = true
}

// 确认修改备注
const handleConfirmEditRemark = async () => {
  const newRemark = editingRemark.value.trim()

  // 验证备注
  if (!newRemark) {
    groupNameError.value = '备注不能为空'
    return
  }

  if (!selectedChat.value) {
    groupNameError.value = '未选中聊天'
    return
  }

  try {
    isUpdatingRemark.value = true
    groupNameError.value = ''


    // 调用API更新备注
    const response = await FriendApi.updateRemark({
      friendId: selectedChat.value.groupId,
      remark: newRemark
    })

    if (response.success) {
      // 更新本地数据
      if (selectedChat.value) {
        selectedChat.value.remark = newRemark

        // 更新聊天列表中的对应项
        const chatItem = chatList.value.find((chat: ChatItem) => chat.id === selectedChat.value?.id)
        if (chatItem) {
          chatItem.remark = newRemark
          // 更新显示名称，优先使用备注
          chatItem.name = newRemark
        }
      }

      // 刷新联系人列表以同步备注
      await store.dispatch('getFriendList')

      toast.success('备注修改成功')

      // 关闭弹窗
      showEditRemarkDialog.value = false
    } else {
      // 使用 API 返回的错误消息
      groupNameError.value = response.message || '修改失败'
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    groupNameError.value = errorMessage
  } finally {
    isUpdatingRemark.value = false
  }
}

// 取消修改备注
const handleCancelEditRemark = () => {
  showEditRemarkDialog.value = false
  editingRemark.value = ''
  groupNameError.value = ''
  isUpdatingRemark.value = false
}

// 处理消息免打扰切换
const handleToggleMute = async (value: boolean) => {
  if (!selectedChat.value) return

  const oldValue = selectedChat.value.chatStatus

  try {

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
      // 使用 API 返回的错误消息
      throw new Error(response.message || '设置失败')
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('设置失败: ' + errorMessage)

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
    const targetState = !value
    
    // 调用API
    const response = targetState 
      ? await GroupApi.pinChat({ roomId: selectedChat.value.groupId || selectedChat.value.id })
      : await GroupApi.unpinChat({ roomId: selectedChat.value.groupId || selectedChat.value.id })
    
    if (response.success) {
      // 更新本地状态
      selectedChat.value.isTop = targetState
      
      // 更新聊天列表中的对应项
      const chatIndex = chatList.value.findIndex((c: ChatItem) => c.id === selectedChat.value?.id)
      if (chatIndex !== -1) {
        chatList.value[chatIndex].isTop = targetState
      }
      
      // 更新 store
      store.dispatch('updateChatItem', {
        ...selectedChat.value,
        isTop: targetState
      })
      
      // 重新加载聊天列表以更新排序
      await loadChatList(true)
      
      toast.success(targetState ? '已置顶' : '已取消置顶')
    } else {
      // 使用 API 返回的错误消息
      toast.error(response.message || (targetState ? '置顶失败' : '取消置顶失败'))
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('设置失败: ' + errorMessage)

    // 回滚本地状态
    if (selectedChat.value) {
      selectedChat.value.isTop = value
    }
  }
}

// 处理群名修改
const handleEditGroupName = () => {
  if (!selectedChat.value) return


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

    const response = await GroupApi.updateGroupInfo({
      groupId: selectedChat.value?.groupId || '',
      groupName: newGroupName  // 修正：使用 groupName 而不是 name
    })

    if (response.success) {
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
      // 使用 API 返回的错误消息
      groupNameError.value = response.message || '修改失败'
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误，请稍后重试';
    groupNameError.value = errorMessage
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

// 发送群组创建的系统消息（与bear-chat-uniapp保持一致）
// NOTE: 此功能已废弃 - 系统消息应由服务器自动生成并通过 WebSocket 推送
// 群聊创建流程：
// 1. 调用 HTTP API 创建群聊 (RoomApi.createRoom)
// 2. 服务器创建群聊并生成系统消息
// 3. 服务器通过 WebSocket 推送消息给所有成员
// 4. 客户端接收 'message' 事件并显示
const sendGroupCreationSystemMessage = async (groupId: string, groupName: string) => {
  // 功能已废弃，保留函数以避免调用处报错
  return;

  /* 原实现已注释
  try {
    const user = store.getters.currentUser
    const timestamp = Date.now()


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
    scrollToBottom(false, true)

    // 通过WebSocket发送系统消息
    await new Promise((resolve, reject) => {
      webSocketManager.sendMessage(systemMessage, MESSAGE_CONSTANTS.BUSINESS_CODE.launchGroup, (success: boolean) => {
        if (success) {

          // 更新本地消息状态为成功
          const messageIndex = messages.value.findIndex(msg => msg.id === localSystemMessage.id)
          if (messageIndex !== -1) {
            messages.value[messageIndex].status = 2 // 发送成功
          }

          resolve(true)
        } else {

          // 更新本地消息状态为失败
          const messageIndex = messages.value.findIndex(msg => msg.id === localSystemMessage.id)
          if (messageIndex !== -1) {
            messages.value[messageIndex].status = 5 // 发送失败
          }

          reject(new Error('系统消息发送失败'))
        }
      })
    })

  } catch (error: any) {
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
  // 如果有多账号架构，从账号的路由状态中获取参数
  let contactId: string | undefined
  let contactName: string | undefined
  
  if (props.accountId) {
    const account = store.getters['accounts/getAccountById'](props.accountId)
    contactId = account?.routeState?.query?.contactId as string | undefined
    contactName = account?.routeState?.query?.contactName as string | undefined
  } else {
    // 否则从全局路由中获取（向后兼容）
    contactId = route.query.contactId as string | undefined
    contactName = route.query.contactName as string | undefined
  }
  
  if (contactId) {
    
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
      return
    }
    
    // 没找到现有聊天，尝试创建新的单聊
    try {
      // 创建单聊 - 使用与bear-chat-uniapp相同的参数格式
      const response = await GroupApi.createSingleChat({
        friendId: contactId as string
      })
      
      if (response.success) {
        const createdRoomId = response.data?.roomId || ''

        // 同步好友头像到本地缓存
        if (response.data?.friendAvatarObjectKey && response.data?.friendId) {
          try {
            const { UserApi } = await import('../api/user')
            await UserApi.syncUserAvatarCache(
              response.data.friendId,
              response.data.friendAvatarObjectKey,
              false
            )
          } catch (error) {
          }
        }

        // 重新加载聊天列表以获取新创建的单聊
        await loadChatList()
        
        // 多次尝试查找新创建的聊天，使用更宽松的匹配条件
        let attempts = 0
        const maxAttempts = 5 // 增加尝试次数
        
        const findAndSelectChat = async () => {
          attempts++
          
          // 重新加载聊天列表以确保获取最新数据
          if (attempts > 1) {
            await loadChatList(true) // 强制刷新API数据
          }
          
          const newChat = chatList.value.find(chat => {
            // 优先使用roomId匹配
            const matchesId = createdRoomId && (chat.id === createdRoomId || chat.groupId === createdRoomId)
            
            // 备用匹配：使用联系人名称
            const matchesName = contactName && (
              chat.name === contactName ||
              chat.name.includes(contactName as string) ||
              (contactName as string).includes(chat.name)
            )
            
            // 额外匹配：检查是否是单聊类型且与联系人ID相关
            const isPrivateChat = chat.groupType === 0 // 单聊类型
            const matchesFriendId = contactId && isPrivateChat && (
              chat.groupId === contactId || 
              chat.extra?.friend_id === contactId ||
              chat.extra?.friendId === contactId
            )


            return matchesId || matchesName || matchesFriendId
          })
          
          if (newChat) {
            selectChat(newChat)
            return true
          }
          
          if (attempts < maxAttempts) {
            setTimeout(async () => {
              await findAndSelectChat()
            }, 300 * attempts) // 减少等待时间
          } else {
            // 如果实在找不到，至少显示一个提示
            toast.error('聊天创建成功，但无法自动打开，请手动选择')
          }
          
          return false
        }
        
        await findAndSelectChat()
        
      } else {
        toast.error('创建聊天失败: ' + (response.message || '未知错误'))
      }
    } catch (error: any) {
      toast.error('创建聊天失败: ' + (error.message || '网络错误'))
    }
    
    // 处理完路由参数后清除，避免刷新页面时重复处理
    router.replace({ path: '/home/chat' })
  }
}

// 比较消息内容是否匹配（用于识别重复消息）
const isContentMatch = (content1: any, content2: any): boolean => {

  // 如果都是字符串，直接比较
  if (typeof content1 === 'string' && typeof content2 === 'string') {
    const match = content1 === content2
    return match
  }

  // 如果都是对象，比较关键字段
  if (typeof content1 === 'object' && typeof content2 === 'object') {
    // 对于附件消息，优先比较 key（附件的唯一标识）
    if (content1.key && content2.key) {
      const match = content1.key === content2.key
      return match
    }
    // 对于图片/视频消息，比较文件名或URL
    if (content1.name && content2.name) {
      const match = content1.name === content2.name
      return match
    }
    if (content1.url && content2.url) {
      const match = content1.url === content2.url
      return match
    }
    if (content1.fullPath && content2.fullPath) {
      const match = content1.fullPath === content2.fullPath
      return match
    }
    if (content1.fileName && content2.fileName) {
      const match = content1.fileName === content2.fileName
      return match
    }
    // 对于文本消息，比较text字段
    if (content1.text && content2.text) {
      const match = content1.text === content2.text
      return match
    }
    // 如果一个有text，另一个是字符串
    if (content1.text && typeof content2 === 'string') {
      const match = content1.text === content2
      return match
    }
    if (content2.text && typeof content1 === 'string') {
      const match = content2.text === content1
      return match
    }
  }

  // 如果一个是对象，一个是字符串
  if (typeof content1 === 'object' && typeof content2 === 'string') {
    const match = content1.text === content2
    return match
  }
  if (typeof content2 === 'object' && typeof content1 === 'string') {
    const match = content2.text === content1
    return match
  }

  // 默认不匹配
  return false
}

// WebSocket消息监听
const handleWebSocketMessage = (event: CustomEvent) => {
  const detail = event.detail as { message?: DomainMessage; raw?: any }
  if (!detail?.message) {
    return
  }

  const messageData = detail.message
  
  const uiMessage = mapDomainMessageToUi(messageData)
  
  // 确保消息有 roomId
  if (!uiMessage.roomId && messageData.roomId) {
    uiMessage.roomId = messageData.roomId
  }
  const messageGroupId = messageData.roomId
  const isCurrentRoom = !!selectedChat.value && selectedChat.value.groupId === messageGroupId


  if (isCurrentRoom) {
    const existingMessageIndex = messages.value.findIndex(msg => msg.id === uiMessage.id)

    if (existingMessageIndex !== -1) {
      // 如果消息已存在，检查是否需要更新
      if (messageData.isSelf) {
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
        // 消息已存在且已更新，直接返回，避免重复添加
        return
      } else {
        // 如果是他人发送的消息且已存在，说明可能是重复推送，直接返回
        return
      }
    } else {
      let matchedLocalMessageId: string | null = null
      if (messageData.isSelf) {
        // 如果 recentSentMessages 中已经有真实消息 ID，说明 API 已经返回了
        // 即使消息不存在（可能是时序问题），也应该直接返回，避免重复添加
        if (recentSentMessages.value.has(uiMessage.id)) {
          // 再次检查消息是否存在（可能是时序问题导致第一次检查时不存在）
          const existingIndex = messages.value.findIndex(msg => msg.id === uiMessage.id)
          if (existingIndex !== -1) {
            // 消息存在，更新状态
            messages.value[existingIndex] = {
              ...messages.value[existingIndex],
              ...uiMessage,
              status: 2
            }
          } else {
          }
          // 无论消息是否存在，都直接返回，避免重复添加
          return
        } else {
          const resendMatchId = Array.from(recentSentMessages.value).find((sentId: string) =>
            sentId.startsWith('resend_') && messageData.content
          )
          if (resendMatchId) {
            recentSentMessages.value.delete(resendMatchId)
            return
          }
          for (const sentId of Array.from(recentSentMessages.value)) {
            // 只匹配临时消息ID（时间戳格式），跳过真实消息ID
            // 临时消息ID是纯数字字符串，真实消息ID通常包含字母或特殊字符
            if (!/^\d+$/.test(sentId)) {
              continue
            }

            const localMessage = messages.value.find(msg => msg.id === sentId)

            // 优先通过 parts 匹配（对于附件消息）
            let isMatch = false
            if (localMessage) {
              // 如果两个消息都有 parts，通过 attachment.key 匹配
              const localAttachment = localMessage.parts?.find(p => p.attachment?.key)?.attachment
              const wsAttachment = uiMessage.parts?.find(p => p.attachment?.key)?.attachment

              if (localAttachment?.key && wsAttachment?.key) {
                isMatch = localAttachment.key === wsAttachment.key
              } else if (localAttachment?.key && !wsAttachment) {
                // WebSocket 消息没有 parts，但有 content 字符串
                // 尝试从 WebSocket content 中提取文件名，与临时消息的 attachment.key 匹配
                if (typeof uiMessage.content === 'string' && uiMessage.content.includes(']')) {
                  // 提取文件名： "[图片] filename.jpg [图片]" -> "filename.jpg"
                  const fileNameMatch = uiMessage.content.match(/\]\s*(.+?)\s*\[/)
                  const wsFileName = fileNameMatch ? fileNameMatch[1].trim() : null
                  const localFileName = localAttachment.name || localAttachment.key.split('/').pop()

                  if (wsFileName && localFileName) {
                    isMatch = wsFileName === localFileName || localFileName.includes(wsFileName) || wsFileName.includes(localFileName)
                  }
                }

                // 如果文件名匹配失败，回退到 content 匹配
                if (!isMatch) {
                  isMatch = isContentMatch(localMessage.content, uiMessage.content)
                }
              } else {
                // 没有 parts 或 attachment，回退到 content 匹配
                isMatch = isContentMatch(localMessage.content, uiMessage.content)
              }

              if (isMatch) {
                matchedLocalMessageId = sentId as string
                break
              }
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
        }
      } else {
        // 如果没有匹配到临时消息，检查是否应该添加
        // 对于自己发送的消息，如果已经在 recentSentMessages 中，说明 API 已返回，不应该重复添加
        if (messageData.isSelf && recentSentMessages.value.has(uiMessage.id)) {
          // 消息已经在 recentSentMessages 中，说明 API 已返回，不应该重复添加
          return
        }
        
        messages.value.push(uiMessage)
        // 如果是自己发送的消息，应该添加到 recentSentMessages，防止 API 返回时重复添加
        if (messageData.isSelf) {
          recentSentMessages.value.add(uiMessage.id)
          setTimeout(() => {
            recentSentMessages.value.delete(uiMessage.id)
          }, 10000)
        } else {
          // 如果不是自己发送的消息，需要同步发送者头像
          if (uiMessage.senderId && uiMessage.senderAvatarObjectKey) {
            // 异步同步头像，不阻塞消息显示
            void (async () => {
              try {
                const localPath = await UserApi.syncUserAvatarCache(
                  uiMessage.senderId,
                  uiMessage.senderAvatarObjectKey!,
                  false
                )
                if (localPath) {
                  // 注册 blob URL，避免被过早释放
                  registerBlobUrl(localPath)
                  
                  // 更新消息的头像
                  const messageIndex = messages.value.findIndex(msg => msg.id === uiMessage.id)
                  if (messageIndex !== -1) {
                    messages.value[messageIndex].senderAvatarLocalPath = localPath
                  }
                }
              } catch (error) {
                // 静默失败，使用默认头像
              }
            })()
          }
        }

        // 索引新消息
        if (selectedChat.value) {
          messageSearchService.indexMessageAsync(uiMessage, selectedChat.value.name, selectedChat.value.groupId).catch(error => {
          })
        }

        scrollToBottom(false, true)
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
    
    // 同步更新当前账号的未读数
    const currentAccountId = store.state.accounts.currentAccountId
    if (currentAccountId && shouldIncreaseUnread) {
      store.dispatch('accounts/syncAccountUnreadCount', currentAccountId)
    }

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
  const detail = event.detail as { 
    room_id?: string; 
    roomId?: string; 
    message_ids?: string[]; 
    message_id?: string; 
    messageId?: string;
    reader_id?: string;
    readerId?: string;
  } | undefined
  if (!detail) return

  const roomId = detail.room_id || detail.roomId
  if (!roomId) {
    return
  }

  // 获取 reader_id，如果是自己触发的已读，无需处理
  const readerId = detail.reader_id || detail.readerId
  const currentUser = store.getters.currentUser
  if (readerId && currentUser?.id && readerId === currentUser.id) {
    // 自己触发的已读无需再次处理
    return
  }

  // 获取目标消息ID（取最后一个，表示已读到该消息）
  let targetMessageId: string | null = null
  if (Array.isArray(detail.message_ids) && detail.message_ids.length > 0) {
    targetMessageId = detail.message_ids[detail.message_ids.length - 1]
  } else if (detail.message_id) {
    targetMessageId = detail.message_id
  } else if (detail.messageId) {
    targetMessageId = detail.messageId
  }

  if (!targetMessageId) return

  // 无论是否选中，都要更新消息状态（多账号场景下，其他账号的聊天可能未选中）
  // 如果当前选中的聊天是目标聊天，更新当前消息列表
  if (selectedChat.value && roomId === selectedChat.value.groupId) {
    // 找到目标消息的索引
    const targetIndex = messages.value.findLastIndex((msg) => msg.id === targetMessageId)
    if (targetIndex === -1) {
      // 调试：如果没找到消息，输出调试信息
      const allMessageIds = messages.value.filter(msg => msg.isSelf).map(msg => msg.id)
      console.warn('[MessageRead] 未找到匹配的消息:', {
        targetId: targetMessageId,
        roomId,
        selectedChatGroupId: selectedChat.value?.groupId,
        availableMessageIds: allMessageIds,
        totalMessages: messages.value.length,
        selfMessages: messages.value.filter(msg => msg.isSelf).length
      })
    } else {
      // 更新从第一条消息到目标消息之间的所有自己发送的消息为已读状态
      // 参考移动端实现：for (var i = 0; i <= targetIndex && i < messages.length; i++)
      let updated = false
      for (let i = 0; i <= targetIndex && i < messages.value.length; i++) {
        const msg = messages.value[i]
        if (!msg.isSelf) continue
        if (msg.status === messageStatusToUiStatus[MessageStatus.READ]) continue

        // 只更新已发送状态的消息（status 2），避免更新其他状态
        if (msg.status === messageStatusToUiStatus[MessageStatus.SENT]) {
          messages.value[i].status = messageStatusToUiStatus[MessageStatus.READ]
          updated = true
        }
      }

      if (updated) {
        // 保存到缓存
        persistMessagesCache(roomId, messages.value).catch(() => {})
      }
    }
  }

  // 无论是否选中，都要更新该聊天在聊天列表中的消息状态
  // 这样当用户切换到该聊天时，能看到正确的消息状态
  // 需要从缓存中加载该聊天的消息并更新状态
  const chatItem = store.getters.getChatByGroupId(roomId)
  if (chatItem) {
    // 如果该聊天有缓存的消息，更新缓存中的消息状态
    loadCache<Message[]>(CACHE_KEYS.messages(roomId)).then(cached => {
      if (cached?.data && Array.isArray(cached.data) && cached.data.length > 0) {
        const targetIndex = cached.data.findLastIndex((msg: Message) => msg.id === targetMessageId)
        if (targetIndex !== -1) {
          let updated = false
          const currentUserId = store.getters.currentUser?.id
          
          for (let i = 0; i <= targetIndex && i < cached.data.length; i++) {
            const msg = cached.data[i]
            // 只更新自己发送的消息
            if (msg.senderId === currentUserId && msg.isSelf) {
              if (msg.status === messageStatusToUiStatus[MessageStatus.SENT]) {
                cached.data[i].status = messageStatusToUiStatus[MessageStatus.READ]
                updated = true
              }
            }
          }

          if (updated) {
            // 保存更新后的缓存
            persistMessagesCache(roomId, cached.data).catch(() => {})
          }
        }
      }
    }).catch(() => {})
  }

  // 无论是否选中，都要更新 store 中的未读数
  store.dispatch('setChatUnreadCount', { groupId: roomId, unreadCount: 0 })
  if (chatItem) {
    chatItem.unreadCount = 0
  }
  if (selectedChat.value && roomId === selectedChat.value.groupId) {
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

  // 重新加载聊天列表，使用后台同步方式避免闪烁
  store.dispatch('loadChatList', { forceRefresh: true, compareWithStore: true })
}

const handleGroupDissolvedEvent = (event: CustomEvent) => {
  const detail = event.detail || {}
  const roomId = detail.room_id || detail.roomId
  if (!roomId) return
  if (selectedChat.value && selectedChat.value.groupId === roomId) {
    toast.warning('当前群聊已被解散')
    selectedChat.value = null
    messages.value = []
    messageList.value = []
    groupMembers.value = []
    groupSettings.value = null
    showGroupSettings.value = false
  }
}

const handleGroupOwnerTransferredEvent = (event: CustomEvent) => {
  const detail = event.detail || {}
  const roomId = detail.room_id || detail.roomId
  const newOwnerId = detail.new_owner_id || detail.newOwnerId
  const oldOwnerId = detail.old_owner_id || detail.oldOwnerId
  if (!roomId || !newOwnerId) return

  if (selectedChat.value && selectedChat.value.groupId === roomId) {
    const extra = { ...(selectedChat.value.extra || {}) }
    extra.owner_id = newOwnerId
    extra.ownerId = newOwnerId
    selectedChat.value = {
      ...selectedChat.value,
      extra
    }
    void loadGroupDetailInfo(roomId)

    if (String(newOwnerId) === String(currentUserId.value)) {
      toast.success('你已成为新的群主')
      void loadGroupSettings(roomId, { silent: true })
    } else if (oldOwnerId && String(oldOwnerId) === String(currentUserId.value)) {
      toast.info('群主已转让给其他成员')
      groupSettings.value = null
    }
  }
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
  eventManager.addWindowListener('websocket-group-dissolved', handleGroupDissolvedEvent as EventListener)
  eventManager.addWindowListener('websocket-group-owner-transferred', handleGroupOwnerTransferredEvent as EventListener)

  // 添加点击外部关闭表情选择器的监听器
  document.addEventListener('click', handleClickOutside)
  window.addEventListener('keydown', handleGlobalKeydown)
  // 添加全局 mouseup 监听，确保在任何地方释放鼠标都能重置拖拽状态
  window.addEventListener('mouseup', handleMouseUpOnMessages)

  // 尝试恢复当前账号的缓存状态
  const currentAccountId = store.state.accounts?.currentAccountId
  if (currentAccountId) {
    const hasCache = accountStates.has(currentAccountId)
    if (hasCache) {
      restoreAccountState(currentAccountId)
    }
  }

  // 先处理路由参数，如果有联系人参数，会在处理过程中加载聊天列表
  // 如果有多账号架构，从账号的路由状态中检查；否则从全局路由中检查
  let hasRouteParams = false
  if (props.accountId) {
    const account = store.getters['accounts/getAccountById'](props.accountId)
    hasRouteParams = !!account?.routeState?.query?.contactId
  } else {
    hasRouteParams = !!route.query.contactId
  }
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
          // 即使失败也不影响用户体验，用户可以看到store中的数据
        }
      }, 500) // 500ms 后开始后台刷新
    }
  }
})

// 监听账号路由状态变化（用于多实例页面架构）
// 当从 Contact 页面跳转到 Chat 页面时，需要处理 contactId 参数
watch(
  () => {
    if (props.accountId) {
      const account = store.getters['accounts/getAccountById'](props.accountId)
      return account?.routeState?.query?.contactId
    }
    return null
  },
  async (newContactId, oldContactId) => {
    // 如果路由状态变化，且新的 contactId 存在，且与旧的不同，处理路由参数
    if (newContactId && newContactId !== oldContactId && props.accountId) {
      // 延迟处理，确保组件已完全渲染
      await new Promise(resolve => setTimeout(resolve, 100))
      await handleRouteParams()
    }
  },
  { immediate: false }
)

onUnmounted(async () => {
  // 重置初始化状态
  isInitialized.value = false

  // 如果有选中的聊天，更新已读时间
  if (selectedChat.value) {
    await updateReadTimeOnLeave(selectedChat.value)
  }

  // 清理所有临时本地URL，避免内存泄漏
  Array.from(blobUrlRegistry).forEach((url) => releaseBlobUrl(url))

  quotedHighlightTimers.forEach((t) => clearTimeout(t))
  quotedHighlightTimers.clear()

  // 清理图片预缓存
  imagePreloadCache.value.clear()

  // 手动清理监听器（事件管理器会自动清理，但为了保险起见）
  window.removeEventListener('resize', handleWindowResize)
  document.removeEventListener('mousemove', handleResize)
  document.removeEventListener('mouseup', stopResize)

  // 移除点击外部关闭表情选择器的监听器
  document.removeEventListener('click', handleClickOutside)
  window.removeEventListener('keydown', handleGlobalKeydown)
  // 移除全局 mouseup 监听
  window.removeEventListener('mouseup', handleMouseUpOnMessages)

  // 移除WebSocket事件监听
  window.removeEventListener('websocket-chat-message', handleWebSocketMessage as EventListener)
  window.removeEventListener('websocket-launch-group', handleWebSocketGroupMessage as EventListener)
  window.removeEventListener('websocket-room-created', handleWebSocketGroupMessage as EventListener)
  window.removeEventListener('websocket-delete-group', handleWebSocketGroupMessage as EventListener)
  window.removeEventListener('websocket-message-update', handleWebSocketMessageUpdate as EventListener)
  window.removeEventListener('websocket-message-read', handleWebSocketMessageRead as EventListener)
  window.removeEventListener('websocket-pin-update', handleWebSocketPinUpdate as EventListener)
  window.removeEventListener('websocket-group-dissolved', handleGroupDissolvedEvent as EventListener)
  window.removeEventListener('websocket-group-owner-transferred', handleGroupOwnerTransferredEvent as EventListener)
})

// 离开聊天时更新已读时间
const updateReadTimeOnLeave = async (chat: ChatItem) => {
  try {
    const currentUser = store.getters.currentUser
    const currentTime = getTimeStr(Date.now())
    
    
    if (!chat.groupId) {
      return
    }
    
  } catch (error: any) {
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

const handleAddMember = async () => {
  if (!selectedChat.value || selectedChat.value.groupType !== 1) {
    toast.error('请先选择一个群聊')
    return
  }
  
  // 加载联系人列表
  await loadContactsForGroup()
  
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


  try {
    isAddingMembers.value = true

    // 调用添加成员 API
    const response = await MessageApi.addGroupMembers({
      roomId: selectedChat.value.id,
      userIds: selectedMemberIds
    })

    if (response.success) {
      toast.success(`成功添加 ${selectedMemberIds.length} 位成员`)

      // 刷新群成员列表
      await loadGroupMembers(selectedChat.value.id)

      // 关闭对话框
      showAddExistingGroupMemberDialog.value = false
    } else {
      throw new Error(response.message || '添加成员失败')
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('添加成员失败: ' + errorMessage)
  } finally {
    isAddingMembers.value = false
  }
}

const handleRemoveMember = () => {
  if (!selectedChat.value || selectedChat.value.groupType !== 1) {
    toast.error('请先选择一个群聊')
    return
  }
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
      toast.success(`成功删除 ${successCount} 位成员${failedCount > 0 ? `，${failedCount} 位失败` : ''}`)

      // 刷新群成员列表
      if (selectedChat.value) {
        await loadGroupMembers(selectedChat.value.id)
      }

      // 关闭对话框
      showRemoveMemberDialog.value = false
    } else {
      throw new Error('所有成员删除失败')
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('删除成员失败: ' + errorMessage)
  } finally {
    isRemovingMembers.value = false
  }
}

const handleClearHistory = async () => {
  if (!selectedChat.value) return

  try {
    const confirmed = confirm('确定要清除该群聊的所有聊天记录吗？此操作不可撤销。')
    if (!confirmed) return

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
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('清除失败: ' + errorMessage)
  }
}

const handleReportGroup = () => {
  if (!selectedChat.value || selectedChat.value.groupType !== 1) {
    toast.error('请先选择一个群聊')
    return
  }
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


  try {
    isReportingGroup.value = true

    // 调用举报 API
    const response = await MessageApi.reportGroup({
      roomId: selectedChat.value.id,
      reason: reason.trim()
    })

    if (response.success) {
      toast.success('举报已提交，感谢您的反馈')

      // 关闭对话框
      showReportDialog.value = false
    } else {
      throw new Error(response.message || '举报失败')
    }
  } catch (error: any) {
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('举报失败: ' + errorMessage)
  } finally {
    isReportingGroup.value = false
  }
}

const handleLeaveGroup = async () => {
  if (!selectedChat.value) return

  try {
    const confirmed = confirm('确定要退出该群聊吗？')
    if (!confirmed) return

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
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('退出失败: ' + errorMessage)
  }
}

const handleToggleGlobalMute = async (value: boolean) => {
  if (!selectedChat.value) return
  if (!isCurrentUserGroupOwner.value) {
    toast.error('只有群主可以操作')
    return
  }
  try {
    updatingGlobalMute.value = true
    const response = await GroupApi.updateGlobalMute({
      roomId: selectedChat.value.groupId,
      enabled: value
    })
    if (response.success && response.data) {
      groupSettings.value = response.data
      toast.success(value ? '已开启全体禁言' : '已关闭全体禁言')
    } else {
      throw new Error(response.message || '操作失败')
    }
  } catch (error: any) {
    toast.error(error?.message || '操作失败')
    await loadGroupSettings(selectedChat.value.groupId, { silent: true })
  } finally {
    updatingGlobalMute.value = false
  }
}

const openTransferOwnerDialog = () => {
  if (!selectedChat.value) return
  if (!transferableMembers.value.length) {
    toast.warning('暂无可转让的成员')
    return
  }
  selectedTransferOwnerId.value = null
  showTransferOwnerDialog.value = true
}

const closeTransferOwnerDialog = () => {
  showTransferOwnerDialog.value = false
  selectedTransferOwnerId.value = null
}

const confirmTransferOwner = async () => {
  if (!selectedChat.value) return
  const targetId = selectedTransferOwnerId.value
  if (!targetId) {
    toast.warning('请选择新的群主')
    return
  }
  try {
    transferringOwner.value = true
    const response = await GroupApi.transferGroupOwner({
      roomId: selectedChat.value.groupId,
      newOwnerId: targetId
    })
    if (!response.success) {
      throw new Error(response.message || '转让失败')
    }
    toast.success('已成功转让群主')
    showTransferOwnerDialog.value = false
    await loadGroupDetailInfo(selectedChat.value.groupId)
    await loadGroupSettings(selectedChat.value.groupId, { silent: true })
  } catch (error: any) {
    toast.error(error?.message || '转让失败')
  } finally {
    transferringOwner.value = false
  }
}

const handleDissolveGroup = async () => {
  if (!selectedChat.value) return
  if (!isCurrentUserGroupOwner.value) {
    toast.error('只有群主可以解散群聊')
    return
  }
  const confirmed = window.confirm('解散群聊后所有成员将失去该会话，确认继续？')
  if (!confirmed) return

  try {
    dissolvingGroup.value = true
    const response = await GroupApi.dissolveGroup({ roomId: selectedChat.value.groupId })
    if (!response.success) {
      throw new Error(response.message || '解散失败')
    }
    toast.success('群聊已解散')
    store.dispatch('removeChatItem', selectedChat.value.groupId)
    webSocketManager.leaveRoom(selectedChat.value.groupId)
    selectedChat.value = null
    messages.value = []
    messageList.value = []
    groupMembers.value = []
    groupSettings.value = null
    showGroupSettings.value = false
    await store.dispatch('loadChatList', { forceRefresh: true, compareWithStore: true })
  } catch (error: any) {
    toast.error(error?.message || '解散失败')
  } finally {
    dissolvingGroup.value = false
  }
}

// 语音功能
const handleVoiceClick = () => {
  showVoiceRecorder.value = true
}

const closeVoiceRecorder = () => {
  showVoiceRecorder.value = false
}

const handleVoiceSend = async (recording: any) => {
  if (!selectedChat.value) return

  try {

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
    const headersObj: Record<string, string> = {}
    
    // 将 Headers 转换为普通对象
    if (signature.headers) {
      Object.entries(signature.headers).forEach(([key, value]) => {
        headersObj[key] = String(value)
      })
    }
    headersObj['Content-Type'] = 'audio/webm'
    if (!headersObj['Content-Length']) {
      headersObj['Content-Length'] = String(recording.blob.size)
    }

    const voiceBuffer = new Uint8Array(await recording.blob.arrayBuffer())
    const uploadResponse = await rustHttp.requestRaw({
      path: signature.url,
      method: (signature.method || 'PUT').toUpperCase() as HttpRequestParams['method'],
      headers: headersObj,
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
        type: 'audio',
        key,
        name: `voice_${recording.id}.webm`,
        mime: 'audio/webm',
        durationMs: Math.round(recording.duration),
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
    // 优先使用 API 返回的错误消息
    const errorMessage = error?.response?.message || error?.message || '网络错误';
    toast.error('发送失败: ' + errorMessage)
  }
}

// 加载群成员列表
const loadGroupMembers = async (groupId: string) => {
  try {
    const response = await GroupApi.getChatGroupMembers({ chatGroupId: groupId })
    if (response.success && response.data) {
      groupMembers.value = response.data
    } else {
      groupMembers.value = []
    }
  } catch (error: any) {
    groupMembers.value = []
  }
}

// 加载消息列表
const loadMessageList = async (groupId: string) => {
  if (!groupId) return
  
  try {
    messagesLoading.value = true
    const response = await MessageApi.getMessageListByChatGroupId({ 
      groupId,
      currentUserId: currentUserId.value 
    })
    if (response.success && response.data) {
      messages.value = response.data
    }
  } catch (error: any) {
  } finally {
    messagesLoading.value = false
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
    min-width: 240px; /* 与chat-list保持一致的最小宽度 */
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
  min-width: 240px; /* 降低最小宽度，给聊天窗口更多响应空间 */
  max-width: 70vw;
  flex-shrink: 0;
  height: 100%;
  position: relative;
  // OverlayScrollbars 会自动处理滚动
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
  padding: 24px 12px; /* 上下 24px，左右 12px */
  display: flex;
  flex-direction: column;
  user-select: none; /* 默认禁用文本选中 */

  .message-content,
  .quoted-block,
  .system-message-text,
  .file-name,
  .file-size,
  .message-sender-name,
  .message-time-other,
  .message-time,
  .quoted-text,
  .quoted-sender {
    user-select: text;
  }

  &.multi-select-active {
    user-select: none;
  }

  &.drag-selecting {
    user-select: none;
  }
}

  .message {
    display: flex;
    align-items: flex-start; /* 顶部对齐，让用户名和头像顶部对齐 */
    gap: 8px;
    position: relative; /* 添加相对定位以支持绝对定位的加载动画 */
    margin-bottom: 8px; /* 添加消息间距 */

  &.selected-message {
    &::before {
      content: '';
      position: absolute;
      top: 0;
      bottom: 0;
      left: -12px;
      right: -12px;
      background-color: rgba(0, 0, 0, 0.05); /* 浅灰色背景 */
      border-radius: 8px;
      pointer-events: none;
      z-index: 0;
    }

    > *:not(.select-indicator) {
      position: relative;
      z-index: 1;
    }
  }

  .message-checkbox {
    padding-top: 4px;
  }

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
      max-width: 60%; /* 与对方消息宽度保持一致 */

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
        display: flex;
        align-items: center;
        justify-content: flex-end;
        gap: 6px;
      }

      .message-status-icon {
        width: 16px;
        height: 16px;
        flex-shrink: 0;
        
        &.sent {
          color: white;
        }
        
        &.read {
          color: white;
        }
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
    max-width: 100%; /* 占满 message-wrapper 的宽度，message-wrapper 已设置 60% */
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

  // 对方消息整体右移，为左侧选择控件留白
  &:not(.own-message) {
    padding-left: 32px;
  }
}

.select-indicator {
  position: absolute;
  width: 15px;
  height: 15px;
  border-radius: 50%;
  background: transparent;
  border: 1.5px solid rgba(0, 0, 0, 0.25); /* 未选中时使用更细的灰色边框 */
  display: flex;
  align-items: center;
  justify-content: center;
  color: transparent;
  font-size: 9px;
  font-weight: bold;
  transition: all 0.2s ease;
  z-index: 2; /* 确保在选中背景之上 */
  flex-shrink: 0; /* 防止被压缩 */
  left: 8px; /* 所有消息的指示器都在容器左侧 8px */
  top: 12px; /* 距离容器顶部 12px */
}

.select-indicator.active {
  background: var(--primary-color, #00c2b3);
  color: #fff;
  border: 1.5px solid var(--primary-color, #00c2b3); /* 选中时保持相同粗细的主题色边框 */
}

.chat-input {
  padding: 16px 24px 40px 24px;

  .reply-bar {
    position: relative;
    padding: 10px 36px 10px 12px;
    margin-bottom: 10px;
    border-radius: 10px;
    background: #f5f7fb;
    border: 1px solid #e5e7ee;

    .reply-title {
      font-size: 13px;
      font-weight: 600;
      color: #4a5568;
      margin-bottom: 4px;
    }

    .reply-content {
      font-size: 13px;
      color: #1f2937;
      line-height: 1.4;
      max-height: 2.8em;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .reply-close {
      position: absolute;
      right: 8px;
      top: 8px;
      border: none;
      background: transparent;
      font-size: 16px;
      color: #6b7280;
      padding: 4px;

      &:hover {
        color: #111827;
      }
    }
  }
  
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

  .multi-select-bar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 12px;
    margin-bottom: 10px;
    border-radius: 10px;
    background: #eef2ff;
    border: 1px solid #dfe4ff;

    .multi-select-count {
      font-size: 13px;
      color: #1f2937;
      font-weight: 600;
    }

    .multi-select-actions {
      display: flex;
      gap: 8px;

      .btn {
        min-width: 70px;
        padding: 6px 10px;
        border-radius: 8px;
        border: 1px solid #d1d5db;
        background: white;
        transition: all 0.2s ease;

        &:disabled {
          opacity: 0.5;
          cursor: not-allowed;
        }

        &.danger {
          background: #ffecef;
          border-color: #ffcdd4;
          color: #d1434b;
        }

        &:hover:not(:disabled) {
          opacity: 0.9;
        }
      }
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
  background: var(--primary-color, #00C2B3);
  color: #fff;
  border-radius: 999px;
  padding: 0 6px;
  font-size: 11px;
  font-weight: 600;
  min-width: 18px;
  height: 18px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  line-height: 1;
}

.chat-badge.is-single-digit {
  width: 18px;
  min-width: 18px;
  padding: 0;
  border-radius: 50%;
}

.top-indicator {
  font-size: 12px;
  margin-left: 4px;
  color: #ffa502;
}

// 头像容器样式
.avatar-container {
  position: relative;
  display: inline-flex;
  flex-shrink: 0;
}

// 免打扰状态的小红点
.mute-dot {
  position: absolute;
  top: -2px;
  right: -2px;
  width: 8px;
  height: 8px;
  background-color: #ff4757;
  border-radius: 50%;
  border: 2px solid #ffffff;
  z-index: 1;
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

.message-content {
  position: relative;
}

// 对于他人消息，message-content-row使用flex布局
.message:not(.own-message) .message-wrapper {
  display: flex;
  flex-direction: column;
  max-width: 40vw; /* 使用视口宽度单位，更好地响应窗口大小变化 */
  min-width: 200px; /* 设置最小宽度，避免过窄 */
}

// 对于自己的消息，也使用flex布局
.message.own-message {
  .message-content {
    display: inline-block;
    max-width: 40vw; /* 使用视口宽度单位，与对方消息保持一致 */
    min-width: 200px; /* 设置最小宽度，避免过窄 */
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

// 文件消息样式
.file-message {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 16px;
  transition: background-color 0.2s;
  border-radius: 8px;
  min-width: 200px;
  max-width: 300px;

  &:hover {
    background-color: rgba(0, 0, 0, 0.02);
  }

  .file-icon-wrapper {
    position: relative;
    flex-shrink: 0;
    width: 48px;
    height: 48px;
    display: flex;
    align-items: center;
    justify-content: center;

    .file-icon {
      width: 48px;
      height: 48px;
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 8px;
      background-color: #f5f5f5;
      color: #666;

      svg {
        width: 32px;
        height: 32px;
      }

      &.file-icon-archive {
        background-color: #fff3e0;
        color: #f57c00;
      }

      &.file-icon-text {
        background-color: #e3f2fd;
        color: #1976d2;
      }

      &.file-icon-other {
        background-color: #f5f5f5;
        color: #999;
      }
    }

    .file-progress-circle {
      position: absolute;
      top: 0;
      left: 0;
      width: 48px;
      height: 48px;
      display: flex;
      align-items: center;
      justify-content: center;

      .progress-svg {
        width: 48px;
        height: 48px;
        transform: rotate(-90deg);

        .progress-background {
          stroke: rgba(0, 0, 0, 0.1);
        }

        .progress-bar {
          transition: stroke-dashoffset 0.3s ease;
        }
      }

      .progress-text {
        position: absolute;
        font-size: 10px;
        font-weight: 600;
        color: #666;
      }
    }

    .file-download-icon {
      position: absolute;
      bottom: -4px;
      right: -4px;
      width: 20px;
      height: 20px;
      background-color: #007AFF;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      color: white;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);

      svg {
        width: 12px;
        height: 12px;
      }
    }
  }

  .file-info {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 4px;

    .file-name {
      font-size: 14px;
      font-weight: 500;
      color: #262626;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .file-size {
      font-size: 12px;
      color: #8c8c8c;
    }
  }
}

// 自己发送的文件消息样式
.message.own-message {
  .file-message {
    .file-icon-wrapper {
      .file-progress-circle {
        .progress-svg {
          .progress-bar {
            stroke: #fff;
          }
        }

        .progress-text {
          color: #fff;
        }
      }

      .file-download-icon {
        background-color: rgba(255, 255, 255, 0.9);
        color: #007AFF;
      }
    }

    .file-info {
      .file-name {
        color: #fff;
      }

      .file-size {
        color: rgba(255, 255, 255, 0.8);
      }
    }
  }
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

/* 滚动条美化样式 - 覆盖模式 */
::-webkit-scrollbar {
  width: 6px;
  height: 6px;
}

::-webkit-scrollbar-track {
  background: transparent;
}

::-webkit-scrollbar-thumb {
  background-color: rgba(0, 0, 0, 0.15);
  border-radius: 3px;
  transition: all 0.2s ease;
}

::-webkit-scrollbar-thumb:hover {
  background-color: rgba(0, 0, 0, 0.3);
}

::-webkit-scrollbar-corner {
  background: transparent;
}

/* 针对Firefox的滚动条样式 */
* {
  scrollbar-width: thin;
  scrollbar-color: rgba(0, 0, 0, 0.15) transparent;
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

.transfer-owner-dialog {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.transfer-owner-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 12px;
  border: 1px solid transparent;
  border-radius: 12px;
  background: #f7f7fb;
  transition: border-color 0.2s ease, background 0.2s ease;
}

.transfer-owner-item--selected {
  border-color: var(--primary-color, #4ecdc4);
  background: #e6fffa;
}

.transfer-owner-item__info {
  flex: 1;
  display: flex;
  flex-direction: column;
}

.transfer-owner-item__name {
  font-size: 15px;
  font-weight: 600;
  color: #1e1f24;
}

.transfer-owner-item__username {
  font-size: 12px;
  color: #6b6b7b;
}

.transfer-owner-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 12px;
}

.transfer-owner-btn {
  min-width: 96px;
  padding: 8px 16px;
  border-radius: 999px;
  border: 1px solid #d0d1db;
  background: #fff;
  font-weight: 500;
  transition: opacity 0.2s ease;
}

.transfer-owner-btn--primary {
  border-color: transparent;
  background: linear-gradient(135deg, #36d1dc, #5b86e5);
  color: #fff;
}

.transfer-owner-btn--primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.transfer-owner-empty {
  text-align: center;
  color: #6b6b7b;
  padding: 16px 0;
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

.quoted-highlighted {
  position: relative;
  border-radius: 0;
}

.quoted-highlighted::before {
  content: '';
  position: absolute;
  top: 0;
  bottom: 0;
  left: -24px;
  right: -24px;
  background-color: rgba(78, 205, 196, 0.5);
  pointer-events: none;
  animation: quoted-highlight-fade 5s ease-out forwards;
  z-index: 0;
}

.quoted-highlighted > * {
  position: relative;
  z-index: 1;
}

@keyframes quoted-highlight-fade {
  0% {
    background-color: rgba(78, 205, 196, 0.5);
  }
  100% {
    background-color: rgba(78, 205, 196, 0);
  }
}

.quoted-block {
  padding: 12px 16px;
  margin-bottom: 8px;
  background: #f9fcfd;
  border-radius: 16px;

  .quoted-header {
    display: flex;
    align-items: center;
    gap: 6px;
    margin-bottom: 6px;
  }

  .quoted-avatar-fallback {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    background: #cfd8e3;
    color: #4b5563;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    font-weight: 600;
  }

  .quoted-sender {
    font-size: 12px;
    font-weight: 600;
    color: #9a9bb1;
  }

  .quoted-text {
    font-size: 16px;
    color: #2c2d3a;
    line-height: 1.4;
    word-break: break-word;
  }
}

.forward-dialog {
  min-width: 320px;
  max-width: 520px;
  display: flex;
  flex-direction: column;
  gap: 12px;

  .forward-list {
    max-height: 280px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .forward-item {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 12px;
    border: 1px solid #e5e7eb;
    border-radius: 10px;
    transition: border-color 0.2s ease, background 0.2s ease;

    &:hover {
      border-color: var(--primary-color, #4ecdc4);
      background: #f7fffd;
    }

    input[type='radio'] {
    }

    .forward-name {
      font-size: 14px;
      color: #1f2937;
      flex: 1;
    }
  }

  .forward-actions {
    display: flex;
    justify-content: flex-end;
    gap: 12px;

    .btn {
      min-width: 88px;
      padding: 8px 12px;
      border-radius: 8px;
      border: 1px solid #d1d5db;
      background: white;
      transition: all 0.2s ease;

      &.primary {
        background: linear-gradient(135deg, #36d1dc, #5b86e5);
        border-color: transparent;
        color: white;
      }

      &:hover {
        opacity: 0.9;
      }
    }
  }
}
</style>
