<template>
  <!-- 普通用户消息内容（根据 isSelf 区分左右） -->
  <!-- 左侧 / 对方消息 -->
  <div
    v-if="!isSelf"
	    class="message-content"
	    :class="{
	      'media-only-content':
	        !isMixed && (
	          resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE ||
	          resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE
	        ),
        'is-mixed-mode': isMixed,
	      'is-self': isSelf
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

	    <!-- 混合消息 / 多部分消息 -->
	    <template v-if="isMixed">
	      <div
	        class="mixed-stack"
	        :class="{
	          'has-media': mediaParts.length > 0,
	          'has-files': fileParts.length > 0,
	          'has-text': !!textPart,
	        }"
	      >
	        <!-- 1) 媒体网格 (图片/视频) -->
	        <div v-if="mediaParts.length > 0" class="media-grid" :class="gridClass">
	          <div v-for="(part, mIdx) in mediaParts" :key="mIdx" class="grid-item">
            <!-- 图片部分 -->
            <template v-if="part.type === 'image'">
              <img
                v-if="getPartImageSrc(message, part)"
                :src="getPartImageSrc(message, part)"
                class="grid-media grid-image"
                @click="handleImagePreview(getPartImageSrc(message, part), message)"
                @load="scrollToBottomAfterImageLoad"
              />
              <MediaSkeleton v-else type="image" />
            </template>
            <!-- 视频部分 -->
            <template v-else-if="part.type === 'video'">
              <div class="grid-media grid-video" @click="handleVideoPlay(message)">
                <img
                  v-if="getPartVideoThumbnailSrc(message, part)"
                  :src="getPartVideoThumbnailSrc(message, part)"
                  class="video-thumbnail"
                  @load="scrollToBottomAfterImageLoad"
                />
                <MediaSkeleton v-else type="video" />
                <div class="video-play-overlay">
                  <div class="play-icon">▶</div>
                </div>
              </div>
            </template>
          </div>

          <!-- 纯媒体混合：时间/状态角标叠加在媒体上；若存在文字说明则放到文字容器内 -->
          <div v-if="!textPart" class="media-time-badge">
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

        <!-- 2) 文件 + 文字（紧贴展示） -->
        <div
          v-if="fileParts.length > 0 || textPart"
          class="mixed-file-text"
          :class="{
            'has-files': fileParts.length > 0,
            'has-text': !!textPart,
          }"
        >
          <!-- 文件列表 -->
          <div v-if="fileParts.length > 0" class="file-parts-list">
            <div v-for="(part, fIdx) in fileParts" :key="fIdx" class="file-message" @click="handleFileDownload(message)">
              <div class="file-icon-wrapper">
                <div class="file-icon" :class="getPartFileIconClass(part)">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" fill="none" />
                    <path d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3M12 17h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none" />
                  </svg>
                </div>
              </div>
              <div class="file-info">
                <div class="file-size" v-if="getPartFileSize(part)">{{ formatFileSize(getPartFileSize(part)!) }}</div>
              </div>
            </div>
          </div>

          <!-- 文本内容（作为说明/caption） -->
          <div v-if="textPart" class="mixed-text">
            {{ textPart.text }}
            <div class="mixed-text-meta">
              <span class="mixed-time">{{ formatMessageTime(message.createTime || message.time) }}</span>
              <svg
                v-if="message.isSelf && message.status === 2"
                class="mixed-status-icon sent"
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
                class="mixed-status-icon read"
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

        <!-- 4) 仅文件/无媒体时：时间行 -->
        <div v-if="mediaParts.length === 0 && !textPart" class="mixed-footer">
          <span class="mixed-time">{{ formatMessageTime(message.createTime || message.time) }}</span>
        </div>
      </div>
    </template>

	    <template v-else>
	      <!-- 文本消息 -->
	      <template v-if="resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE">
	        {{ getTextContent(message) }}
	      </template>

	      <!-- 音频消息 -->
	      <template v-else-if="resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.AUDIO_CONTENT_TYPE || hasAudioPart(message)">
	        <VoiceMessage
	          :voice-url="audioUrlCache[message.id] || ensureAudioUrlLoading(message)"
	          :duration="getAudioDuration(message)"
	          :is-mine="message.isSelf"
          :message-id="message.id"
        />
	      </template>

	      <!-- 图片消息 -->
	      <template v-else-if="resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE">
	        <div class="media-message image-message">
	          <div class="media-main">
            <img
              v-if="parseImageSrc(message)"
              :src="parseImageSrc(message)"
              :alt="'图片'"
              class="message-image"
              :class="{ uploading: isMessageUploading(message) }"
              @click="handleImagePreview(parseImageSrc(message), message)"
              @load="scrollToBottomAfterImageLoad"
              @error="handleImageError"
              loading="lazy"
            />
            <MediaSkeleton v-else type="image" :width="200" :height="150" />

            <div v-if="isMessageUploading(message)" class="media-loading-overlay">
              <div class="media-loading-spinner">
                <div class="loading-spinner"></div>
              </div>
            </div>

            <div class="media-time-badge">
              <span class="media-time-text">
                {{ formatMessageTime(message.createTime || message.time) }}
              </span>
            </div>
          </div>
        </div>
	      </template>

	      <!-- 视频消息 -->
	      <template v-else-if="resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE">
	        <div class="media-message video-message">
	          <div class="video-container" @click="handleVideoPlay(message)">
            <div v-if="parseVideoScreenShotSrc(message)" class="video-thumbnail-wrapper">
              <img
                :src="parseVideoScreenShotSrc(message)"
                :alt="'视频'"
                class="video-thumbnail"
                @load="scrollToBottomAfterImageLoad"
                @error="handleVideoThumbnailError"
                loading="lazy"
              />
            </div>
            <template v-else>
              <MediaSkeleton type="video" :width="300" :height="180" />
            </template>
            <div class="video-play-overlay">
              <div class="play-icon">▶</div>
            </div>

            <div v-if="isMessageUploading(message)" class="media-loading-overlay">
              <div class="media-loading-spinner">
                <div class="loading-spinner"></div>
              </div>
            </div>

            <div class="media-time-badge">
              <span class="media-time-text">
                {{ formatMessageTime(message.createTime || message.time) }}
              </span>
            </div>
          </div>
        </div>
	      </template>

	      <!-- 文件消息 -->
	      <template v-else-if="resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.FILE_CONTENT_TYPE">
	        <div class="file-message" @click="handleFileDownload(message)">
	          <div class="file-icon-wrapper">
	            <div class="file-icon" :class="getFileIconClass(message)">
              <svg width="32" height="32" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" fill="none" />
                <path d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3M12 17h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none" />
              </svg>
            </div>
          </div>
          <div class="file-info">
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
	        v-if="resolvedContentType !== MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE &&
	              resolvedContentType !== MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE"
	      >
	        {{ formatMessageTime(message.createTime || message.time) }}
	      </div>
	    </template>
	  </div>

  <!-- 右侧 / 自己的消息 -->
  <div
    v-else
	    class="message-content"
	    :class="{
	      'media-only-content':
	        !isMixed && (
	          resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE ||
	          resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE
	        ),
        'is-mixed-mode': isMixed,
	      'is-self': isSelf
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

	    <!-- 混合消息 / 多部分消息 -->
	    <template v-if="isMixed">
	      <div
	        class="mixed-stack"
	        :class="{
	          'has-media': mediaParts.length > 0,
	          'has-files': fileParts.length > 0,
	          'has-text': !!textPart,
	        }"
	      >
	        <!-- 1) 媒体网格 (图片/视频) -->
	        <div v-if="mediaParts.length > 0" class="media-grid" :class="gridClass">
	          <div v-for="(part, mIdx) in mediaParts" :key="mIdx" class="grid-item">
            <!-- 图片部分 -->
            <template v-if="part.type === 'image'">
              <img
                v-if="getPartImageSrc(message, part)"
                :src="getPartImageSrc(message, part)"
                class="grid-media grid-image"
                @click="handleImagePreview(getPartImageSrc(message, part), message)"
                @load="scrollToBottomAfterImageLoad"
              />
              <MediaSkeleton v-else type="image" />
            </template>
            <!-- 视频部分 -->
            <template v-else-if="part.type === 'video'">
              <div class="grid-media grid-video" @click="handleVideoPlay(message)">
                <img
                  v-if="getPartVideoThumbnailSrc(message, part)"
                  :src="getPartVideoThumbnailSrc(message, part)"
                  class="video-thumbnail"
                  @load="scrollToBottomAfterImageLoad"
                />
                <MediaSkeleton v-else type="video" />
                <div class="video-play-overlay">
                  <div class="play-icon">▶</div>
                </div>
              </div>
            </template>
          </div>

          <!-- 纯媒体混合：时间/状态角标叠加在媒体上；若存在文字说明则放到文字容器内 -->
          <div v-if="!textPart" class="media-time-badge">
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

        <!-- 2) 文件 + 文字（紧贴展示） -->
        <div
          v-if="fileParts.length > 0 || textPart"
          class="mixed-file-text"
          :class="{
            'has-files': fileParts.length > 0,
            'has-text': !!textPart,
          }"
        >
          <!-- 文件列表 -->
          <div v-if="fileParts.length > 0" class="file-parts-list">
            <div v-for="(part, fIdx) in fileParts" :key="fIdx" class="file-message" @click="handleFileDownload(message)">
              <div class="file-icon-wrapper">
                <div class="file-icon" :class="getPartFileIconClass(part)">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2" fill="none" />
                    <path d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3M12 17h.01" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none" />
                  </svg>
                </div>
              </div>
              <div class="file-info">
                <div class="file-size" v-if="getPartFileSize(part)">{{ formatFileSize(getPartFileSize(part)!) }}</div>
              </div>
            </div>
          </div>

          <!-- 文本内容（作为说明/caption） -->
          <div v-if="textPart" class="mixed-text">
            {{ textPart.text }}
            <div class="mixed-text-meta">
              <span class="mixed-time">{{ formatMessageTime(message.createTime || message.time) }}</span>
              <svg
                v-if="message.status === 2"
                class="mixed-status-icon sent"
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
                v-if="message.status === 4"
                class="mixed-status-icon read"
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

        <!-- 4) 仅文件/无媒体时：时间 + 状态 -->
        <div v-if="mediaParts.length === 0 && !textPart" class="mixed-footer">
          <span class="mixed-time">{{ formatMessageTime(message.createTime || message.time) }}</span>
          <svg
            v-if="message.status === 2"
            class="mixed-status-icon sent"
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
            v-if="message.status === 4"
            class="mixed-status-icon read"
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
    </template>

	    <template v-else>
	      <!-- 文本消息 -->
	      <template v-if="resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE">
	        {{ getTextContent(message) }}
	      </template>

	      <!-- 音频消息 -->
	      <template v-else-if="resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.AUDIO_CONTENT_TYPE || hasAudioPart(message)">
	        <VoiceMessage
	          :voice-url="audioUrlCache[message.id] || ensureAudioUrlLoading(message)"
	          :duration="getAudioDuration(message)"
          :is-mine="message.isSelf"
        />
	      </template>

	      <!-- 图片消息 -->
	      <template v-else-if="resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE">
	        <div class="media-message image-message">
	          <div class="media-main">
            <img
              v-if="parseImageSrc(message)"
              :src="parseImageSrc(message)"
              :alt="'图片'"
              class="message-image"
              :class="{ uploading: isMessageUploading(message) }"
              @click="handleImagePreview(parseImageSrc(message), message)"
              @load="scrollToBottomAfterImageLoad"
              @error="handleImageError"
              loading="lazy"
            />
            <MediaSkeleton v-else type="image" :width="200" :height="150" />

            <div v-if="isMessageUploading(message)" class="media-loading-overlay">
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
	      <template v-else-if="resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE">
	        <div class="media-message video-message">
	          <div class="video-container" @click="handleVideoPlay(message)">
            <!-- 如果有视频缩略图则显示，否则显示默认占位 UI -->
            <div v-if="parseVideoScreenShotSrc(message)" class="video-thumbnail-wrapper">
              <img
                :src="parseVideoScreenShotSrc(message)"
                :alt="'视频'"
                class="video-thumbnail"
                @load="scrollToBottomAfterImageLoad"
                @error="handleVideoThumbnailError"
                loading="lazy"
              />
            </div>
            <template v-else>
              <!-- 有视频源时尝试加载首帧 -->
              <div v-if="parseVideoSrc(message)" class="video-placeholder">
                <div class="video-placeholder-inner">
                  <video
                    class="video-placeholder-video"
                    :src="parseVideoSrc(message)"
                    preload="metadata"
                    muted
                    playsinline
                    @loadeddata="handleVideoFirstFrameLoaded"
                    @error="handleVideoThumbnailError"
                  ></video>
                  <div class="video-placeholder-overlay">
                    <div class="video-icon">🎬</div>
                    <div class="video-placeholder-text">
                      {{ '视频加载中...' }}
                    </div>
                  </div>
                </div>
              </div>
              <!-- 没有视频源时显示骨架屏 -->
              <MediaSkeleton v-else type="video" :width="300" :height="180" />
            </template>
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
	      <template v-else-if="resolvedContentType === MESSAGE_CONSTANTS.CONTENT_TYPE.FILE_CONTENT_TYPE">
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
	        v-if="resolvedContentType !== MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE &&
	            resolvedContentType !== MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE"
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
    </template>
  </div>
</template>

<script setup lang="ts">
import Avatar from './Avatar.vue'
import VoiceMessage from './VoiceMessage.vue'
import MediaSkeleton from './MediaSkeleton.vue'
import { MessageType } from '@/types/models'
import type { Message, QuotedMessage, MessagePart } from '@/types/models'

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
  // 混合消息部分支持
  getPartImageSrc: (m: Message, p: MessagePart) => string
  getPartVideoSrc: (m: Message, p: MessagePart) => string
  getPartVideoThumbnailSrc: (m: Message, p: MessagePart) => string
  getPartFileName: (p: MessagePart) => string
  getPartFileSize: (p: MessagePart) => number | null | undefined
  getPartFileIconType: (p: MessagePart) => 'archive' | 'text' | 'other'
  getPartFileIconClass: (p: MessagePart) => string
}

const props = defineProps<Props>()

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
  scrollToQuoted,
  // 混合消息部分支持
  getPartImageSrc,
  getPartVideoSrc,
  getPartVideoThumbnailSrc,
  getPartFileName,
  getPartFileSize,
  getPartFileIconType,
  getPartFileIconClass
} = props.context

import { computed } from 'vue'

const mediaParts = computed(() => {
  if (!props.message.parts) return []
  return props.message.parts.filter(p => p.type === 'image' || p.type === 'video')
})

const fileParts = computed(() => {
  if (!props.message.parts) return []
  return props.message.parts.filter(p => p.type === 'file')
})

const isAttachmentPlaceholderText = (text: string) => {
  const normalized = text.trim()
  if (!normalized) return false

  return (
    normalized === '[混合消息]'
    || normalized === '[附件]'
    || normalized === '[图片]'
    || normalized === '[视频]'
    || normalized === '[文件]'
    || normalized.startsWith('[混合消息]')
    || normalized.startsWith('[附件]')
    || normalized.startsWith('[图片]')
    || normalized.startsWith('[视频]')
    || normalized.startsWith('[文件]')
  )
}

const getAttachmentNames = (parts: MessagePart[]) => (
  parts
    .filter((part) =>
      part.type !== 'text'
      && Boolean(part.attachment?.name && String(part.attachment.name).trim()),
    )
    .map((part) => String(part.attachment!.name).trim())
)

const textPart = computed(() => {
  if (!props.message.parts) return null
  const parts = props.message.parts
  const hasAttachment = parts.some((part) =>
    part.type !== 'text' && Boolean(part.attachment?.key || part.attachment?.localPath || part.attachment?.downloadUrl),
  )
  const attachmentNames = hasAttachment ? getAttachmentNames(parts) : []

  return (
    parts.find((part) =>
      part.type === 'text'
      && Boolean(part.text && String(part.text).trim())
      && (!hasAttachment || (
        !isAttachmentPlaceholderText(String(part.text))
        && !attachmentNames.includes(String(part.text).trim())
      )),
    ) ?? null
  )
})

const isMixed = computed(() => {
  const explicitType = (props.message as any)?.type
  const parts = Array.isArray(props.message.parts) ? props.message.parts : []
  if (parts.length === 0) {
    return false
  }

  const attachmentParts = parts.filter((part) =>
    part.type !== 'text'
    && Boolean(part.attachment?.key || part.attachment?.localPath || part.attachment?.downloadUrl),
  )

  if (attachmentParts.length === 0) {
    return false
  }

  const attachmentNames = getAttachmentNames(parts)
  const meaningfulTextParts = parts.filter((part) =>
    part.type === 'text'
    && Boolean(part.text && String(part.text).trim())
    && !isAttachmentPlaceholderText(String(part.text)),
  ).filter((part) =>
    !attachmentNames.includes(String(part.text).trim()),
  )

  // 1) 多个附件（同类型也算，例如多图/多文件）
  const computedMixed =
    attachmentParts.length > 1
    || meaningfulTextParts.length > 0

  // 兼容历史数据：后端可能把“占位文本 + 单附件”误判为 mixed
  if (explicitType === MessageType.MIXED || explicitType === 'mixed') {
    return computedMixed
  }
  if (explicitType) {
    return false
  }

  return computedMixed
})

const resolvedContentType = computed(() => {
  const explicit = (props.message as any)?.contentType
  if (typeof explicit === 'number') {
    return explicit
  }

  if (Array.isArray(props.message.parts) && props.message.parts.length > 0) {
    if (props.message.parts.some((p) => p.type === 'image')) {
      return MESSAGE_CONSTANTS.CONTENT_TYPE.IMG_CONTENT_TYPE
    }
    if (props.message.parts.some((p) => p.type === 'video')) {
      return MESSAGE_CONSTANTS.CONTENT_TYPE.VIDEO_CONTENT_TYPE
    }
    if (props.message.parts.some((p) => p.type === 'audio')) {
      return MESSAGE_CONSTANTS.CONTENT_TYPE.AUDIO_CONTENT_TYPE
    }
    if (props.message.parts.some((p) => p.type === 'file')) {
      return MESSAGE_CONSTANTS.CONTENT_TYPE.FILE_CONTENT_TYPE
    }
  }

  return MESSAGE_CONSTANTS.CONTENT_TYPE.TEXT_CONTENT_TYPE
})

const gridClass = computed(() => {
  const count = mediaParts.value.length
  if (count <= 1) return 'grid-single'
  if (count === 2) return 'grid-2'
  if (count === 3) return 'grid-3'
  return 'grid-4'
})
</script>

<style lang="scss" scoped>
.mixed-parts-container {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-width: 100%;

  .message-part-item {
    & + .message-part-item {
      padding-top: 4px;
      border-top: 1px solid rgba(0, 0, 0, 0.05);
    }
    
    .text-part {
      white-space: pre-wrap;
      word-break: break-word;
      line-height: 1.5;
    }

    .media-message {
      margin: 4px 0;
      border-radius: 8px;
      overflow: hidden;
      max-width: 300px;
    }

    .file-message {
      margin: 4px 0;
    }
  }
}

.is-self .mixed-parts-container .message-part-item + .message-part-item {
  border-top-color: rgba(255, 255, 255, 0.1);
}

// 混合模式根容器重置
.message-content.is-mixed-mode {
  background-color: transparent !important;
  padding: 0 !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  min-width: 0;
  color: #262626 !important;
}

.mixed-stack {
  max-width: 320px;
  display: flex;
  flex-direction: column;
  gap: 8px;

  &.has-text {
    gap: 0;
  }

  &.has-media.has-text {
    .media-grid {
      border-bottom-left-radius: 0;
      border-bottom-right-radius: 0;
    }

    .mixed-file-text.has-files.has-text {
      border-top-left-radius: 0;
      border-top-right-radius: 0;
    }

    .mixed-text {
      border-top-left-radius: 0;
      border-top-right-radius: 0;
    }
  }
}

.media-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 2px;
  background: #f0f0f0;
  border-radius: 8px;
  overflow: hidden;
  position: relative;

  .grid-item {
    flex: 1 1 auto;
    min-width: 0;
    position: relative;
    overflow: hidden;

    .grid-media {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
      cursor: pointer;
      min-height: 150px;
      max-height: 300px;
    }
  }

  &.grid-2 .grid-item {
    flex-basis: calc(50% - 1px);
  }

  &.grid-3 .grid-item:first-child {
    flex-basis: 100%;
  }
  &.grid-3 .grid-item:not(:first-child) {
    flex-basis: calc(50% - 1px);
  }

  &.grid-4 .grid-item {
    flex-basis: calc(50% - 1px);
  }
}

.file-parts-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.mixed-file-text {
  display: flex;
  flex-direction: column;
  gap: 0;
}

.mixed-file-text.has-files.has-text {
  border-radius: 10px;
  overflow: hidden;
  background: #ffffff;

  .file-parts-list {
    background: transparent;
    border-radius: 0;
  }

  .file-message {
    border-radius: 0;
    min-width: 0;
    max-width: none;
    padding: 8px 12px;
  }

  .mixed-text {
    background: #ffffff;
    border-radius: 0;
  }
}

.mixed-text {
  position: relative;
  padding: 8px 10px 24px 10px;
  border-radius: 10px;
  background: #ffffff;
  font-size: 15px;
  line-height: 1.5;
  white-space: pre-wrap;
  word-break: break-word;
}

.mixed-text-meta {
  position: absolute;
  right: 8px;
  bottom: 6px;
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  color: #8c8c8c;
  line-height: 1;
  pointer-events: none;
}

.mixed-footer {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  color: #8c8c8c;
  line-height: 1;
}

.message-content.is-self .mixed-footer {
  justify-content: flex-end;
}

.mixed-status-icon {
  width: 14px;
  height: 14px;
  flex-shrink: 0;

  &.sent {
    color: #8c8c8c;
  }

  &.read {
    color: #40a9ff;
  }
}

// 视频网格特殊细节
.grid-video {
  position: relative;
  
  .video-thumbnail {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }

  .video-play-overlay {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(0, 0, 0, 0.2);

    .play-icon {
      width: 40px;
      height: 40px;
      background: rgba(255, 255, 255, 0.9);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #333;
      font-size: 18px;
      padding-left: 3px;
    }
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

  .quoted-content {
    display: flex;
    align-items: flex-start;
    gap: 10px;
  }

  .quoted-image {
    max-width: 120px;
    max-height: 120px;
    border-radius: 8px;
    object-fit: cover;
    flex-shrink: 0;
  }
}
// --- 标准消息样式 (从 Chat.vue 迁移以恢复样式) ---
.message-content {
  position: relative;
  background-color: #ffffff;
  padding: 12px 16px;
  border-radius: 0 16px 16px 16px;
  max-width: 100%;
  word-wrap: break-word;
  word-break: break-word;
  white-space: pre-wrap;
  font-size: 16px;
  color: #262626; // $text-primary 默认值
  
  &.is-self {
    background-color: #00C2B3; // $primary-color 默认值
    color: white;
    border-radius: 16px 16px 0 16px;
  }

  &.media-only-content {
    background-color: transparent !important;
    padding: 0 !important;
    border-radius: 0 !important;
    box-shadow: none !important;
  }
}

.message-time-other {
  font-size: 12px;
  color: #8c8c8c;
  margin-top: 8px;
  text-align: left;
  line-height: 1;
  display: flex;
  align-items: center;
  gap: 4px;
}

.message-time {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.8);
  margin-top: 8px;
  text-align: right;
  line-height: 1;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 6px;
}

.message-status-icon {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
  color: white;
}

.media-message {
  margin: -4px -4px 4px -4px;
  border-radius: 8px;
  overflow: hidden;
  display: inline-block;

  .message-image {
    max-width: 300px;
    max-height: 300px;
    width: auto;
    height: auto;
    display: block;
    border-radius: 8px;
  }
}

.media-only-content .media-message {
  margin: 0;
}

.loading-spinner {
  width: 12px;
  height: 12px;
  border: 2px solid rgba(255, 255, 255, 0.35);
  border-top-color: #ffffff;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.media-main {
  position: relative;
  display: inline-block;
}

.media-loading-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2;
}

.media-loading-spinner {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 8px;
  border-radius: 999px;
  background: rgba(0, 0, 0, 0.25);

  .loading-spinner {
    width: 18px;
    height: 18px;
    border-width: 2px;
    border-color: rgba(255, 255, 255, 0.4);
    border-top-color: #ffffff;
  }
}

.media-time-badge {
  position: absolute;
  right: 8px;
  bottom: 8px;
  height: 18px;
  padding: 0 8px;
  border-radius: 9px;
  background: rgba(0, 0, 0, 0.7);
  color: #ffffff;
  font-size: 12px;
  line-height: 18px;
  display: inline-flex;
  align-items: center;
  gap: 4px;
  z-index: 3;
}

.media-time-text {
  white-space: nowrap;
}

.media-status-icon {
  width: 14px;
  height: 14px;
  flex-shrink: 0;

  &.sent,
  &.read {
    color: #ffffff;
  }
}

// 文件消息（含上传/下载进度）
.file-message {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 200px;
  max-width: 300px;
  border-radius: 8px;
  user-select: none;
  cursor: pointer;

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

.message-content.is-self:not(.is-mixed-mode) {
  .file-message {
    &:hover {
      background-color: rgba(255, 255, 255, 0.12);
    }

    .file-icon-wrapper {
      .file-progress-circle {
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

// 视频相关样式
.video-container {
  position: relative;
  display: inline-block;
  border-radius: 8px;
  overflow: hidden;
  user-select: none;
  cursor: default;

  &:hover .video-play-overlay {
    opacity: 0.9;
  }
}

.video-container .video-thumbnail-wrapper {
  display: block;
}

.video-container .video-thumbnail {
  max-width: 300px;
  max-height: 300px;
  border-radius: 8px;
  display: block;
  transition: opacity 0.2s;
}

.video-container .video-play-overlay {
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
    margin-left: 3px;
  }
}

.video-container .video-placeholder {
  position: relative;
  width: 300px;
  height: 180px;
  background-color: #e5e7eb;
  border-radius: 8px;
  border: 1px dashed #cbd5e1;

  .video-placeholder-inner {
    position: relative;
    width: 100%;
    height: 100%;
    overflow: hidden;
    border-radius: inherit;
  }

  .video-icon {
    font-size: 28px;
  }

  .video-placeholder-text {
    font-size: 12px;
    color: #6b7280;
  }
}

.video-container .video-placeholder-video {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  border-radius: inherit;
}

.video-container .video-placeholder-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 6px;
  pointer-events: none;
}
</style>
```
