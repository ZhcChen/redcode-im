<template>
  <!-- 普通用户消息内容（根据 isSelf 区分左右） -->
  <!-- 左侧 / 对方消息 -->
  <div
    v-if="!isSelf"
    class="message-content"
    :class="{
      'media-only-content':
        message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE ||
        message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE
    }"
  >
    <!-- 引用消息预览 -->
    <template v-if="message.quotedMessage">
      <div class="quoted-block" @click.stop="scrollToQuoted(message.quotedMessage)">
        <div class="quoted-header">
          <Avatar
            :src="getQuotedAvatar(message.quotedMessage)
              || getSenderAvatarById(message.quotedMessage.senderId)
              || undefined"
            :text="getQuotedInitial(message.quotedMessage)"
            :color-seed="message.quotedMessage?.senderId || message.quotedMessage?.senderUsername || message.quotedMessage?.senderName"
            :size="24"
          />
          <div class="quoted-sender">{{ getQuotedSenderName(message.quotedMessage) }}</div>
        </div>
        <div class="quoted-content">
          <div v-if="getQuotedMediaType(message.quotedMessage) !== 'image'" class="quoted-text">
            {{ getQuotedText(message.quotedMessage) }}
          </div>
          <img
            v-if="getQuotedMediaType(message.quotedMessage) === 'image' && getQuotedImageSrc(message.quotedMessage)"
            :src="getQuotedImageSrc(message.quotedMessage)"
            class="quoted-image"
            alt="引用图片"
            @load="scrollToBottomAfterImageLoad"
          />
        </div>
      </div>
    </template>

    <!-- 文本消息 -->
    <template v-if="!message.contentType || message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE">
      {{ getTextContent(message) }}
    </template>

    <!-- 音频消息 -->
    <template v-else-if="message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.AUDIO_CONTENT_TYPE || hasAudioPart(message)">
      <VoiceMessage
        :voice-url="audioUrlCache[message.id] || ensureAudioUrlLoading(message)"
        :duration="getAudioDuration(message)"
        :is-mine="message.isSelf"
        :message-id="message.id"
      />
    </template>

    <!-- 图片消息 -->
    <template v-else-if="message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE">
      <div class="media-message image-message">
        <div class="media-main">
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

          <div
            v-if="isMessageUploading(message)"
            class="media-loading-overlay"
          >
            <div class="media-loading-spinner">
              <div class="loading-spinner"></div>
            </div>
          </div>

          <div class="media-time-badge">
            <span class="media-time-text">
              {{ formatMessageTime(message.createTime || message.time) }}
            </span>
            <svg
              v-if="message.isSelf && message.status === 2"
              class="media-status-icon sent"
              width="14"
              height="14"
              viewBox="0 0 14 14"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M9.03789 4.04543C9.21991 4.20434 9.23865 4.48071 9.07974 4.66273L4.49641 9.91273C4.41333 10.0079 4.29317 10.0625 4.16684 10.0625C4.04051 10.0625 3.92034 10.0079 3.83726 9.91273L2.00393 7.81273C1.84502 7.63071 1.86376 7.35434 2.04578 7.19543C2.2278 7.03652 2.50417 7.05526 2.66308 7.23728L4.16684 8.95977L8.42059 4.08728C8.5795 3.90526 8.85587 3.88652 9.03789 4.04543Z"
                fill="currentColor"
              />
            </svg>
            <svg
              v-if="message.isSelf && message.status === 4"
              class="media-status-icon read"
              width="14"
              height="14"
              viewBox="0 0 14 14"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M9.03789 4.04543C9.21991 4.20434 9.23865 4.48071 9.07974 4.66273L4.49641 9.91273C4.41333 10.0079 4.29317 10.0625 4.16684 10.0625C4.04051 10.0625 3.92034 10.0079 3.83726 9.91273L2.00393 7.81273C1.84502 7.63071 1.86376 7.35434 2.04578 7.19543C2.2278 7.03652 2.50417 7.05526 2.66308 7.23728L4.16684 8.95977L8.42059 4.08728C8.5795 3.90526 8.85587 3.88652 9.03789 4.04543Z"
                fill="currentColor"
              />
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M11.9687 4.09469C12.1436 4.26133 12.1504 4.53825 11.9838 4.71322L6.98361 9.96322C6.89524 10.056 6.77064 10.1054 6.6427 10.0983C6.51476 10.0913 6.39635 10.0285 6.31872 9.92654L6.06887 9.59841C5.92249 9.40618 5.95966 9.13167 6.1519 8.98529C6.31705 8.85954 6.54291 8.86925 6.69609 8.99637L11.3501 4.10976C11.5168 3.9348 11.7937 3.92805 11.9687 4.09469Z"
                fill="currentColor"
              />
            </svg>
          </div>
        </div>
      </div>
    </template>

    <!-- 视频消息 -->
    <template v-else-if="message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE">
      <div class="media-message video-message">
        <div class="video-container" @click="handleVideoPlay(message)">
          <!-- 如果有视频缩略图则显示，否则显示默认占位 UI -->
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
          <div v-else class="video-placeholder">
            <div class="video-placeholder-inner">
              <!-- 使用视频资源渲染首帧（如可用） -->
              <video
                v-if="parseVideoSrc(message)"
                class="video-placeholder-video"
                :src="parseVideoSrc(message)"
                preload="metadata"
                muted
                playsinline
                @loadeddata="handleVideoFirstFrameLoaded"
                @error="handleVideoThumbnailError"
              ></video>
              <!-- 居中覆盖的占位内容 -->
              <div class="video-placeholder-overlay">
                <div class="video-icon">🎬</div>
                <div class="video-placeholder-text">
                  {{ (typeof message.content === 'object' && message.content.name) || '视频加载中...' }}
                </div>
              </div>
            </div>
          </div>
          <div class="video-play-overlay">
            <div class="play-icon">▶</div>
          </div>

          <div
            v-if="isMessageUploading(message)"
            class="media-loading-overlay"
          >
            <div class="media-loading-spinner">
              <div class="loading-spinner"></div>
            </div>
          </div>

          <div class="media-time-badge">
            <span class="media-time-text">
              {{ formatMessageTime(message.createTime || message.time) }}
            </span>
            <svg
              v-if="message.isSelf && message.status === 2"
              class="media-status-icon sent"
              width="14"
              height="14"
              viewBox="0 0 14 14"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M9.03789 4.04543C9.21991 4.20434 9.23865 4.48071 9.07974 4.66273L4.49641 9.91273C4.41333 10.0079 4.29317 10.0625 4.16684 10.0625C4.04051 10.0625 3.92034 10.0079 3.83726 9.91273L2.00393 7.81273C1.84502 7.63071 1.86376 7.35434 2.04578 7.19543C2.2278 7.03652 2.50417 7.05526 2.66308 7.23728L4.16684 8.95977L8.42059 4.08728C8.5795 3.90526 8.85587 3.88652 9.03789 4.04543Z"
                fill="currentColor"
              />
            </svg>
            <svg
              v-if="message.isSelf && message.status === 4"
              class="media-status-icon read"
              width="14"
              height="14"
              viewBox="0 0 14 14"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M9.03789 4.04543C9.21991 4.20434 9.23865 4.48071 9.07974 4.66273L4.49641 9.91273C4.41333 10.0079 4.29317 10.0625 4.16684 10.0625C4.04051 10.0625 3.92034 10.0079 3.83726 9.91273L2.00393 7.81273C1.84502 7.63071 1.86376 7.35434 2.04578 7.19543C2.2278 7.03652 2.50417 7.05526 2.66308 7.23728L4.16684 8.95977L8.42059 4.08728C8.5795 3.90526 8.85587 3.88652 9.03789 4.04543Z"
                fill="currentColor"
              />
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M11.9687 4.09469C12.1436 4.26133 12.1504 4.53825 11.9838 4.71322L6.98361 9.96322C6.89524 10.056 6.77064 10.1054 6.6427 10.0983C6.51476 10.0913 6.39635 10.0285 6.31872 9.92654L6.06887 9.59841C5.92249 9.40618 5.95966 9.13167 6.1519 8.98529C6.31705 8.85954 6.54291 8.86925 6.69609 8.99637L11.3501 4.10976C11.5168 3.9348 11.7937 3.92805 11.9687 4.09469Z"
                fill="currentColor"
              />
            </svg>
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
            <svg
              v-if="getFileIconType(message) === 'archive'"
              width="32"
              height="32"
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path d="M4 6h16v2H4V6zm0 4h16v10H4V10zm2 2v6h12v-6H6z" fill="currentColor" />
              <path d="M6 8h12v2H6V8z" fill="currentColor" opacity="0.5" />
            </svg>
            <!-- 文本文件图标 -->
            <svg
              v-else-if="getFileIconType(message) === 'text'"
              width="32"
              height="32"
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                d="M5 4v3h5.5v12h3V7H19V4H5zm-1-2h16a1 1 0 011 1v19a1 1 0 01-1 1H4a1 1 0 01-1-1V3a1 1 0 011-1z"
                fill="currentColor"
              />
              <path
                d="M7 9h10v1.5H7V9zm0 3h10v1.5H7V12zm0 3h7v1.5H7V15z"
                fill="currentColor"
                opacity="0.3"
              />
            </svg>
            <!-- 其他文件图标（问号） -->
            <svg
              v-else
              width="32"
              height="32"
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" fill="none" />
              <path
                d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3M12 17h.01"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                fill="none"
              />
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
              <path
                d="M12 15.577l-3.539-3.538 1.414-1.414L11 12.586V3h2v9.586l1.125-1.125 1.414 1.414L12 15.577zm-7 4.423h14v2H5v-2z"
                fill="currentColor"
              />
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

    <div
      class="message-time-other"
      v-if="message.contentType !== MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE &&
            message.contentType !== MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE"
    >
      {{ formatMessageTime(message.createTime || message.time) }}
    </div>
  </div>

  <!-- 右侧 / 自己的消息 -->
  <div
    v-else
    class="message-content"
    :class="{
      'media-only-content':
        message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE ||
        message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE
    }"
  >
    <template v-if="message.quotedMessage">
      <div class="quoted-block" @click.stop="scrollToQuoted(message.quotedMessage)">
        <div class="quoted-header">
          <Avatar
            :src="getQuotedAvatar(message.quotedMessage)
              || getSenderAvatarById(message.quotedMessage.senderId)
              || undefined"
            :text="getQuotedInitial(message.quotedMessage)"
            :color-seed="message.quotedMessage?.senderId || message.quotedMessage?.senderUsername || message.quotedMessage?.senderName"
            :size="24"
          />
          <div class="quoted-sender">{{ getQuotedSenderName(message.quotedMessage) }}</div>
        </div>
        <div class="quoted-content">
          <div v-if="getQuotedMediaType(message.quotedMessage) !== 'image'" class="quoted-text">
            {{ getQuotedText(message.quotedMessage) }}
          </div>
          <img
            v-if="getQuotedMediaType(message.quotedMessage) === 'image' && getQuotedImageSrc(message.quotedMessage)"
            :src="getQuotedImageSrc(message.quotedMessage)"
            class="quoted-image"
            alt="引用图片"
            @load="scrollToBottomAfterImageLoad"
          />
        </div>
      </div>
    </template>

    <!-- 文本消息 -->
    <template v-if="!message.contentType || message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE">
      {{ getTextContent(message) }}
    </template>

    <!-- 音频消息 -->
    <template v-else-if="message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.AUDIO_CONTENT_TYPE || hasAudioPart(message)">
      <VoiceMessage
        :voice-url="audioUrlCache[message.id] || ensureAudioUrlLoading(message)"
        :duration="getAudioDuration(message)"
        :is-mine="message.isSelf"
      />
    </template>

    <!-- 图片消息 -->
    <template v-else-if="message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE">
      <div class="media-message image-message">
        <div class="media-main">
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

          <div
            v-if="isMessageUploading(message)"
            class="media-loading-overlay"
          >
            <div class="media-loading-spinner">
              <div class="loading-spinner"></div>
            </div>
          </div>

          <div class="media-time-badge">
            <span class="media-time-text">
              {{ formatMessageTime(message.createTime || message.time) }}
            </span>
            <svg
              v-if="message.isSelf && message.status === 2"
              class="media-status-icon sent"
              width="14"
              height="14"
              viewBox="0 0 14 14"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M9.03789 4.04543C9.21991 4.20434 9.23865 4.48071 9.07974 4.66273L4.49641 9.91273C4.41333 10.0079 4.29317 10.0625 4.16684 10.0625C4.04051 10.0625 3.92034 10.0079 3.83726 9.91273L2.00393 7.81273C1.84502 7.63071 1.86376 7.35434 2.04578 7.19543C2.2278 7.03652 2.50417 7.05526 2.66308 7.23728L4.16684 8.95977L8.42059 4.08728C8.5795 3.90526 8.85587 3.88652 9.03789 4.04543Z"
                fill="currentColor"
              />
            </svg>
            <svg
              v-if="message.isSelf && message.status === 4"
              class="media-status-icon read"
              width="14"
              height="14"
              viewBox="0 0 14 14"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M9.03789 4.04543C9.21991 4.20434 9.23865 4.48071 9.07974 4.66273L4.49641 9.91273C4.41333 10.0079 4.29317 10.0625 4.16684 10.0625C4.04051 10.0625 3.92034 10.0079 3.83726 9.91273L2.00393 7.81273C1.84502 7.63071 1.86376 7.35434 2.04578 7.19543C2.2278 7.03652 2.50417 7.05526 2.66308 7.23728L4.16684 8.95977L8.42059 4.08728C8.5795 3.90526 8.85587 3.88652 9.03789 4.04543Z"
                fill="currentColor"
              />
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M11.9687 4.09469C12.1436 4.26133 12.1504 4.53825 11.9838 4.71322L6.98361 9.96322C6.89524 10.056 6.77064 10.1054 6.6427 10.0983C6.51476 10.0913 6.39635 10.0285 6.31872 9.92654L6.06887 9.59841C5.92249 9.40618 5.95966 9.13167 6.1519 8.98529C6.31705 8.85954 6.54291 8.86925 6.69609 8.99637L11.3501 4.10976C11.5168 3.9348 11.7937 3.92805 11.9687 4.09469Z"
                fill="currentColor"
              />
            </svg>
          </div>
        </div>
      </div>
    </template>

    <!-- 视频消息 -->
    <template v-else-if="message.contentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE">
      <div class="media-message video-message">
        <div class="video-container" @click="handleVideoPlay(message)">
          <!-- 如果有视频缩略图则显示，否则显示默认占位 UI -->
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
          <div v-else class="video-placeholder">
            <div class="video-placeholder-inner">
              <!-- 使用视频资源渲染首帧（如可用） -->
              <video
                v-if="parseVideoSrc(message)"
                class="video-placeholder-video"
                :src="parseVideoSrc(message)"
                preload="metadata"
                muted
                playsinline
                @loadeddata="handleVideoFirstFrameLoaded"
                @error="handleVideoThumbnailError"
              ></video>
              <!-- 居中覆盖的占位内容 -->
              <div class="video-placeholder-overlay">
                <div class="video-icon">🎬</div>
                <div class="video-placeholder-text">
                  {{ (typeof message.content === 'object' && message.content.name) || '视频加载中...' }}
                </div>
              </div>
            </div>
          </div>
          <div class="video-play-overlay">
            <div class="play-icon">▶</div>
          </div>

          <div
            v-if="isMessageUploading(message)"
            class="media-loading-overlay"
          >
            <div class="media-loading-spinner">
              <div class="loading-spinner"></div>
            </div>
          </div>

          <div class="media-time-badge">
            <span class="media-time-text">
              {{ formatMessageTime(message.createTime || message.time) }}
            </span>
            <svg
              v-if="message.isSelf && message.status === 2"
              class="media-status-icon sent"
              width="14"
              height="14"
              viewBox="0 0 14 14"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M9.03789 4.04543C9.21991 4.20434 9.23865 4.48071 9.07974 4.66273L4.49641 9.91273C4.41333 10.0079 4.29317 10.0625 4.16684 10.0625C4.04051 10.0625 3.92034 10.0079 3.83726 9.91273L2.00393 7.81273C1.84502 7.63071 1.86376 7.35434 2.04578 7.19543C2.2278 7.03652 2.50417 7.05526 2.66308 7.23728L4.16684 8.95977L8.42059 4.08728C8.5795 3.90526 8.85587 3.88652 9.03789 4.04543Z"
                fill="currentColor"
              />
            </svg>
            <svg
              v-if="message.isSelf && message.status === 4"
              class="media-status-icon read"
              width="14"
              height="14"
              viewBox="0 0 14 14"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M9.03789 4.04543C9.21991 4.20434 9.23865 4.48071 9.07974 4.66273L4.49641 9.91273C4.41333 10.0079 4.29317 10.0625 4.16684 10.0625C4.04051 10.0625 3.92034 10.0079 3.83726 9.91273L2.00393 7.81273C1.84502 7.63071 1.86376 7.35434 2.04578 7.19543C2.2278 7.03652 2.50417 7.05526 2.66308 7.23728L4.16684 8.95977L8.42059 4.08728C8.5795 3.90526 8.85587 3.88652 9.03789 4.04543Z"
                fill="currentColor"
              />
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M11.9687 4.09469C12.1436 4.26133 12.1504 4.53825 11.9838 4.71322L6.98361 9.96322C6.89524 10.056 6.77064 10.1054 6.6427 10.0983C6.51476 10.0913 6.39635 10.0285 6.31872 9.92654L6.06887 9.59841C5.92249 9.40618 5.95966 9.13167 6.1519 8.98529C6.31705 8.85954 6.54291 8.86925 6.69609 8.99637L11.3501 4.10976C11.5168 3.9348 11.7937 3.92805 11.9687 4.09469Z"
                fill="currentColor"
              />
            </svg>
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
            <svg
              v-if="getFileIconType(message) === 'archive'"
              width="32"
              height="32"
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path d="M4 6h16v2H4V6zm0 4h16v10H4V10zm2 2v6h12v-6H6z" fill="currentColor" />
              <path d="M6 8h12v2H6V8z" fill="currentColor" opacity="0.5" />
            </svg>
            <!-- 文本文件图标 -->
            <svg
              v-else-if="getFileIconType(message) === 'text'"
              width="32"
              height="32"
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                d="M5 4v3h5.5v12h3V7H19V4H5zm-1-2h16a1 1 0 011 1v19a1 1 0 01-1 1H4a1 1 0 01-1-1V3a1 1 0 011-1z"
                fill="currentColor"
              />
              <path
                d="M7 9h10v1.5H7V9zm0 3h10v1.5H7V12zm0 3h7v1.5H7V15z"
                fill="currentColor"
                opacity="0.3"
              />
            </svg>
            <!-- 其他文件图标（问号） -->
            <svg
              v-else
              width="32"
              height="32"
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
            >
              <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" fill="none" />
              <path
                d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3M12 17h.01"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                fill="none"
              />
            </svg>
          </div>
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
              <path
                d="M12 15.577l-3.539-3.538 1.414-1.414L11 12.586V3h2v9.586l1.125-1.125 1.414 1.414L12 15.577zm-7 4.423h14v2H5v-2z"
                fill="currentColor"
              />
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

    <div
      class="message-time"
      v-if="message.contentType !== MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE &&
            message.contentType !== MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE"
    >
      {{ formatMessageTime(message.createTime || message.time) }}
      <svg
        v-if="message.isSelf && message.status === 2"
        class="message-status-icon sent"
        width="20"
        height="20"
        viewBox="0 0 14 14"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          fill-rule="evenodd"
          clip-rule="evenodd"
          d="M9.03789 4.04543C9.21991 4.20434 9.23865 4.48071 9.07974 4.66273L4.49641 9.91273C4.41333 10.0079 4.29317 10.0625 4.16684 10.0625C4.04051 10.0625 3.92034 10.0079 3.83726 9.91273L2.00393 7.81273C1.84502 7.63071 1.86376 7.35434 2.04578 7.19543C2.2278 7.03652 2.50417 7.05526 2.66308 7.23728L4.16684 8.95977L8.42059 4.08728C8.5795 3.90526 8.85587 3.88652 9.03789 4.04543Z"
          fill="currentColor"
        />
      </svg>
      <svg
        v-if="message.isSelf && message.status === 4"
        class="message-status-icon read"
        width="20"
        height="20"
        viewBox="0 0 14 14"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          fill-rule="evenodd"
          clip-rule="evenodd"
          d="M9.03789 4.04543C9.21991 4.20434 9.23865 4.48071 9.07974 4.66273L4.49641 9.91273C4.41333 10.0079 4.29317 10.0625 4.16684 10.0625C4.04051 10.0625 3.92034 10.0079 3.83726 9.91273L2.00393 7.81273C1.84502 7.63071 1.86376 7.35434 2.04578 7.19543C2.2278 7.03652 2.50417 7.05526 2.66308 7.23728L4.16684 8.95977L8.42059 4.08728C8.5795 3.90526 8.85587 3.88652 9.03789 4.04543Z"
          fill="currentColor"
        />
        <path
          fill-rule="evenodd"
          clip-rule="evenodd"
          d="M11.9687 4.09469C12.1436 4.26133 12.1504 4.53825 11.9838 4.71322L6.98361 9.96322C6.89524 10.056 6.77064 10.1054 6.6427 10.0983C6.51476 10.0913 6.39635 10.0285 6.31872 9.92654L6.06887 9.59841C5.92249 9.40618 5.95966 9.13167 6.1519 8.98529C6.31705 8.85954 6.54291 8.86925 6.69609 8.99637L11.3501 4.10976C11.5168 3.9348 11.7937 3.92805 11.9687 4.09469Z"
          fill="currentColor"
        />
      </svg>
    </div>
  </div>
</template>

<script setup lang="ts">
import { toRefs } from 'vue'
import Avatar from './Avatar.vue'
import VoiceMessage from './VoiceMessage.vue'
import type { Message, QuotedMessage } from '@/types/models'

interface Props {
  message: Message
  isSelf: boolean
  context: MessageBubbleContext
}

interface MessageBubbleContext {
  MESSAGE_CONSTANTS: any
  audioUrlCache: Record<string, string>
  getTextContent: (m: Message) => string
  hasAudioPart: (m: Message) => boolean
  ensureAudioUrlLoading: (m: Message) => string
  getAudioDuration: (m: Message) => number
  parseImageSrc: (m: Message) => string
  getImageAlt: (m: Message) => string
  isMessageUploading: (m: Message) => boolean
  handleImagePreview: (src: string, m: Message) => void
  scrollToBottomAfterImageLoad: () => void
  handleImageError: (e: Event) => void
  parseVideoScreenShotSrc: (m: Message) => string
  parseVideoSrc: (m: Message) => string
  handleVideoPlay: (m: Message) => void
  handleVideoThumbnailError: (e: Event) => void
  handleVideoFirstFrameLoaded: (e: Event) => void
  isFileDownloading: (m: Message) => boolean
  getFileIconType: (m: Message) => string
  getFileIconClass: (m: Message) => string
  getFileProgress: (m: Message) => number
  shouldShowDownloadIcon: (m: Message) => boolean
  handleFileDownload: (m: Message) => void
  getFileName: (m: Message) => string
  getFileSize: (m: Message) => number | null | undefined
  formatFileSize: (n: number) => string
  formatMessageTime: (timeStr: string) => string
  getQuotedAvatar: (q: QuotedMessage | null | undefined) => string | null
  getQuotedInitial: (q: QuotedMessage | null | undefined) => string
  getQuotedSenderName: (q: QuotedMessage) => string
  getQuotedText: (q: QuotedMessage) => string
  getQuotedMediaType: (q: QuotedMessage) => 'image' | 'video' | 'audio' | 'file' | null
  getQuotedImageSrc: (q: QuotedMessage) => string
  getSenderAvatarById: (senderId: string) => string | null
  scrollToQuoted: (q: QuotedMessage) => void
}

const props = defineProps<Props>()
const { message, isSelf, context } = toRefs(props)

const {
  MESSAGE_CONSTANTS,
  audioUrlCache,
  getTextContent,
  hasAudioPart,
  ensureAudioUrlLoading,
  getAudioDuration,
  parseImageSrc,
  getImageAlt,
  isMessageUploading,
  handleImagePreview,
  scrollToBottomAfterImageLoad,
  handleImageError,
  parseVideoScreenShotSrc,
  parseVideoSrc,
  handleVideoPlay,
  handleVideoThumbnailError,
  handleVideoFirstFrameLoaded,
  isFileDownloading,
  getFileIconType,
  getFileIconClass,
  getFileProgress,
  shouldShowDownloadIcon,
  handleFileDownload,
  getFileName,
  getFileSize,
  formatFileSize,
  formatMessageTime,
  getQuotedAvatar,
  getQuotedInitial,
  getQuotedSenderName,
  getQuotedText,
  getQuotedMediaType,
  getQuotedImageSrc,
  getSenderAvatarById,
  scrollToQuoted
} = context.value
</script>
