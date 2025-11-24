<template>
  <div class="message-search">
    <!-- 搜索输入框 -->
    <div class="search-input-container">
      <div class="search-input-wrapper">
        <div class="search-icon">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="11" cy="11" r="8"></circle>
            <path d="m21 21-4.35-4.35"></path>
          </svg>
        </div>
        <input
          ref="searchInput"
          v-model="searchQuery"
          type="text"
          placeholder="搜索消息内容..."
          class="search-input"
          @input="handleSearchInput"
          @keydown.enter="handleSearch"
          @keydown.esc="handleEscape"
          @focus="handleInputFocus"
          @blur="handleInputBlur"
        />
        <div v-if="searchQuery" class="clear-icon" @click="clearSearch">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </div>
      </div>

      <!-- 搜索建议 -->
      <div v-if="showSuggestions && suggestions.length > 0" class="search-suggestions">
        <div
          v-for="(suggestion, index) in suggestions"
          :key="index"
          class="suggestion-item"
          @click="selectSuggestion(suggestion)"
          @mouseenter="selectedIndex = index"
          @mouseleave="selectedIndex = -1"
          :class="{ active: selectedIndex === index }"
        >
          <div class="suggestion-icon">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="11" cy="11" r="8"></circle>
              <path d="m21 21-4.35-4.35"></path>
            </svg>
          </div>
          <div class="suggestion-text">{{ suggestion }}</div>
        </div>
      </div>
    </div>

    <!-- 搜索过滤器 -->
    <div v-if="showFilters" class="search-filters">
      <div class="filter-item">
        <label>房间:</label>
        <select v-model="filters.roomId" class="filter-select">
          <option value="">所有房间</option>
          <option v-for="room in availableRooms" :key="room.id" :value="room.id">
            {{ room.name }}
          </option>
        </select>
      </div>
      <div class="filter-item">
        <label>发送者:</label>
        <select v-model="filters.senderId" class="filter-select">
          <option value="">所有人</option>
          <option v-for="sender in availableSenders" :key="sender.id" :value="sender.id">
            {{ sender.name }}
          </option>
        </select>
      </div>
      <div class="filter-item">
        <label>消息类型:</label>
        <select v-model="filters.messageType" class="filter-select">
          <option value="">所有类型</option>
          <option value="text">文本</option>
          <option value="image">图片</option>
          <option value="file">文件</option>
          <option value="video">视频</option>
          <option value="audio">语音</option>
        </select>
      </div>
      <div class="filter-item">
        <label>日期范围:</label>
        <div class="date-range">
          <input
            v-model="dateFromText"
            type="date"
            class="date-input"
            @change="handleDateFromChange"
          />
          <span>至</span>
          <input
            v-model="dateToText"
            type="date"
            class="date-input"
            @change="handleDateToChange"
          />
        </div>
      </div>
    </div>

    <!-- 搜索状态 -->
    <div v-if="isSearching" class="search-status">
      <div class="loading-spinner"></div>
      <span>搜索中...</span>
    </div>

    <!-- 搜索统计 -->
    <div v-if="searchStats && !isSearching" class="search-stats">
      <span>找到 {{ searchStats.totalResults }} 条结果</span>
      <span>耗时 {{ searchStats.searchTimeMs }}ms</span>
    </div>

    <!-- 搜索结果 -->
    <ScrollContainer v-if="searchResults.length > 0" class="search-results">
      <!-- 按日期分组 -->
      <div v-for="group in groupedResults" :key="group.date" class="result-group">
        <div class="group-header">{{ group.date }}</div>
        <div
          v-for="result in group.results"
          :key="result.id"
          class="result-item"
          @click="handleResultClick(result)"
        >
          <div class="result-header">
            <div class="result-room">{{ result.roomName }}</div>
            <div class="result-time">{{ formatTime(result.timestamp) }}</div>
          </div>
          <div class="result-sender">{{ result.senderName }}</div>
          <div class="result-content">
            <div v-if="result.matchedText" v-html="formatHighlightedText(result.matchedText)"></div>
            <div v-else>{{ result.content }}</div>
          </div>
          <div v-if="result.messageType !== 'text'" class="result-type-badge">
            {{ getMessageTypeLabel(result.messageType) }}
          </div>
        </div>
      </div>

      <!-- 加载更多 -->
      <div v-if="hasMoreResults" class="load-more">
        <button @click="loadMoreResults" :disabled="isLoadingMore" class="load-more-btn">
          {{ isLoadingMore ? '加载中...' : '加载更多' }}
        </button>
      </div>
    </ScrollContainer>

    <!-- 无搜索结果 -->
    <div v-if="!isSearching && searchQuery && searchResults.length === 0" class="no-results">
      <div class="no-results-icon">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
          <circle cx="11" cy="11" r="8"></circle>
          <path d="m21 21-4.35-4.35"></path>
          <path d="M8 11h6"></path>
        </svg>
      </div>
      <div class="no-results-text">
        <div>未找到相关消息</div>
        <div class="no-results-hint">尝试使用不同的关键词或调整筛选条件</div>
      </div>
    </div>

    <!-- 搜索帮助 -->
    <div v-if="!searchQuery && !showSuggestions" class="search-help">
      <div class="help-title">搜索提示</div>
      <div class="help-items">
        <div class="help-item">
          <span class="help-key">关键词</span>
          <span class="help-desc">搜索包含特定词语的消息</span>
        </div>
        <div class="help-item">
          <span class="help-key">"精确短语"</span>
          <span class="help-desc">搜索包含完整短语的消息</span>
        </div>
        <div class="help-item">
          <span class="help-key">关键词1 AND 关键词2</span>
          <span class="help-desc">搜索同时包含多个词语的消息</span>
        </div>
        <div class="help-item">
          <span class="help-key">关键词1 OR 关键词2</span>
          <span class="help-desc">搜索包含任一词语的消息</span>
        </div>
        <div class="help-item">
          <span class="help-key">关键词 NOT 排除词</span>
          <span class="help-desc">排除包含特定词语的消息</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue';
import { SearchApi, SearchUtils, type MessageSearchResult, type SearchParams, type SearchStats } from '@/api/search';
import ScrollContainer from './ScrollContainer.vue';

// Props
const props = defineProps<{
  visible?: boolean;
  currentRoomId?: string;
  availableRooms?: Array<{ id: string; name: string }>;
  availableSenders?: Array<{ id: string; name: string }>;
}>();

// Emits
const emit = defineEmits<{
  resultClick: [result: MessageSearchResult];
  close: [];
}>();

// 响应式数据
const searchInput = ref<HTMLInputElement>();
const searchQuery = ref('');
const showSuggestions = ref(false);
const suggestions = ref<string[]>([]);
const selectedIndex = ref(-1);
const isSearching = ref(false);
const searchResults = ref<MessageSearchResult[]>([]);
const searchStats = ref<SearchStats | null>(null);
const isLoadingMore = ref(false);
const hasMoreResults = ref(false);
const currentOffset = ref(0);

// 过滤器
const showFilters = ref(false);
const filters = ref({
  roomId: props.currentRoomId || '',
  senderId: '',
  messageType: '',
  dateFrom: undefined as Date | undefined,
  dateTo: undefined as Date | undefined,
});
const dateFromText = ref('');
const dateToText = ref('');

// 防抖搜索建议
const debouncedGetSuggestions = SearchUtils.debounceSuggestions(async (query: string) => {
  if (query.length >= 2) {
    try {
      suggestions.value = await SearchApi.getSearchSuggestions(query, 10);
      showSuggestions.value = true;
    } catch (error) {
      suggestions.value = [];
    }
  } else {
    suggestions.value = [];
    showSuggestions.value = false;
  }
}, 300);

// 计算属性
const groupedResults = computed(() => {
  return SearchResultsUtils.groupResultsByDate(searchResults.value);
});

// 方法
const handleSearchInput = () => {
  selectedIndex.value = -1;

  // 获取搜索建议
  debouncedGetSuggestions(searchQuery.value);
};

const handleSearch = async () => {
  const validation = SearchUtils.validateSearchQuery(searchQuery.value);
  if (!validation.isValid) {
    // 显示错误提示
    return;
  }

  showSuggestions.value = false;
  isSearching.value = true;
  searchResults.value = [];
  currentOffset.value = 0;

  try {
    const params = SearchUtils.buildSearchQuery(searchQuery.value, filters.value);
    const [results, stats] = await SearchApi.searchMessages(params);

    searchResults.value = results;
    searchStats.value = stats;
    hasMoreResults.value = results.length === params.limit;
    currentOffset.value = results.length;
  } catch (error) {
  } finally {
    isSearching.value = false;
  }
};

const loadMoreResults = async () => {
  if (isLoadingMore.value || !hasMoreResults.value) return;

  isLoadingMore.value = true;

  try {
    const params = SearchUtils.buildSearchQuery(searchQuery.value, filters.value);
    params.offset = currentOffset.value;

    const [results] = await SearchApi.searchMessages(params);

    searchResults.value.push(...results);
    currentOffset.value += results.length;
    hasMoreResults.value = results.length === params.limit;
  } catch (error) {
  } finally {
    isLoadingMore.value = false;
  }
};

const selectSuggestion = (suggestion: string) => {
  searchQuery.value = suggestion;
  showSuggestions.value = false;
  nextTick(() => {
    handleSearch();
  });
};

const clearSearch = () => {
  searchQuery.value = '';
  searchResults.value = [];
  searchStats.value = null;
  suggestions.value = [];
  showSuggestions.value = false;
  searchInput.value?.focus();
};

const handleEscape = () => {
  if (showSuggestions.value) {
    showSuggestions.value = false;
  } else {
    emit('close');
  }
};

const handleInputFocus = () => {
  if (searchQuery.value.length >= 2) {
    debouncedGetSuggestions(searchQuery.value);
  }
};

const handleInputBlur = () => {
  // 延迟隐藏建议，以便点击建议项
  setTimeout(() => {
    showSuggestions.value = false;
  }, 200);
};

const handleResultClick = (result: MessageSearchResult) => {
  emit('resultClick', result);
};

const handleDateFromChange = () => {
  if (dateFromText.value) {
    filters.value.dateFrom = new Date(dateFromText.value);
  } else {
    filters.value.dateFrom = undefined;
  }
};

const handleDateToChange = () => {
  if (dateToText.value) {
    filters.value.dateTo = new Date(dateToText.value);
  } else {
    filters.value.dateTo = undefined;
  }
};

const formatTime = (timestamp: number) => {
  return SearchUtils.formatTimestamp(timestamp);
};

const formatHighlightedText = (text: string) => {
  return SearchUtils.formatHighlightedText(text);
};

const getMessageTypeLabel = (type: string) => {
  const labels: Record<string, string> = {
    text: '文本',
    image: '图片',
    file: '文件',
    video: '视频',
    audio: '语音',
  };
  return labels[type] || type;
};

// 键盘导航
const handleKeydown = (event: KeyboardEvent) => {
  if (!showSuggestions.value || suggestions.value.length === 0) return;

  switch (event.key) {
    case 'ArrowDown':
      event.preventDefault();
      selectedIndex.value = Math.min(selectedIndex.value + 1, suggestions.value.length - 1);
      break;
    case 'ArrowUp':
      event.preventDefault();
      selectedIndex.value = Math.max(selectedIndex.value - 1, -1);
      break;
    case 'Enter':
      event.preventDefault();
      if (selectedIndex.value >= 0 && selectedIndex.value < suggestions.value.length) {
        selectSuggestion(suggestions.value[selectedIndex.value]);
      } else {
        handleSearch();
      }
      break;
  }
};

// 监听器
watch(() => props.currentRoomId, (newRoomId) => {
  if (newRoomId) {
    filters.value.roomId = newRoomId;
  }
});

watch(filters, () => {
  // 如果已有搜索查询，自动重新搜索
  if (searchQuery.value.trim()) {
    handleSearch();
  }
}, { deep: true });

// 生命周期
onMounted(() => {
  document.addEventListener('keydown', handleKeydown);
  searchInput.value?.focus();
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown);
});
</script>

<style scoped>
.message-search {
  max-width: 600px;
  margin: 0 auto;
  padding: 16px;
}

.search-input-container {
  position: relative;
  margin-bottom: 16px;
}

.search-input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.search-input {
  width: 100%;
  padding: 12px 40px 12px 40px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  font-size: 14px;
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
}

.search-input:focus {
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.search-icon {
  position: absolute;
  left: 12px;
  color: #64748b;
  pointer-events: none;
}

.clear-icon {
  position: absolute;
  right: 12px;
  color: #64748b;
  padding: 4px;
  border-radius: 4px;
  transition: background-color 0.2s;
}

.clear-icon:hover {
  background-color: #f1f5f9;
}

.search-suggestions {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  z-index: 1000;
  max-height: 200px;
}

.suggestion-item {
  display: flex;
  align-items: center;
  padding: 12px 16px;
  transition: background-color 0.2s;
}

.suggestion-item:hover,
.suggestion-item.active {
  background-color: #f8fafc;
}

.suggestion-icon {
  margin-right: 12px;
  color: #64748b;
}

.suggestion-text {
  flex: 1;
  font-size: 14px;
  color: #1e293b;
}

.search-filters {
  display: flex;
  flex-wrap: wrap;
  gap: 16px;
  margin-bottom: 16px;
  padding: 16px;
  background: #f8fafc;
  border-radius: 8px;
}

.filter-item {
  display: flex;
  align-items: center;
  gap: 8px;
}

.filter-item label {
  font-size: 14px;
  color: #64748b;
  white-space: nowrap;
}

.filter-select,
.date-input {
  padding: 6px 8px;
  border: 1px solid #e2e8f0;
  border-radius: 4px;
  font-size: 14px;
  background: white;
}

.date-range {
  display: flex;
  align-items: center;
  gap: 8px;
}

.date-range span {
  font-size: 14px;
  color: #64748b;
}

.search-status {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 16px;
  color: #64748b;
}

.loading-spinner {
  width: 16px;
  height: 16px;
  border: 2px solid #e2e8f0;
  border-top: 2px solid #3b82f6;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.search-stats {
  display: flex;
  justify-content: space-between;
  padding: 8px 16px;
  background: #f1f5f9;
  border-radius: 6px;
  font-size: 12px;
  color: #64748b;
  margin-bottom: 16px;
}

.search-results {
  max-height: 500px;
}

.result-group {
  margin-bottom: 24px;
}

.group-header {
  font-weight: 600;
  color: #374151;
  margin-bottom: 8px;
  padding: 0 4px;
  font-size: 14px;
}

.result-item {
  padding: 12px 16px;
  border-radius: 8px;
  transition: background-color 0.2s;
  margin-bottom: 4px;
  border: 1px solid transparent;
}

.result-item:hover {
  background-color: #f8fafc;
  border-color: #e2e8f0;
}

.result-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 4px;
}

.result-room {
  font-weight: 500;
  color: #374151;
  font-size: 13px;
}

.result-time {
  font-size: 12px;
  color: #64748b;
}

.result-sender {
  font-size: 12px;
  color: #059669;
  margin-bottom: 4px;
}

.result-content {
  font-size: 14px;
  color: #1e293b;
  line-height: 1.4;
  word-break: break-word;
}

.result-type-badge {
  display: inline-block;
  padding: 2px 6px;
  background: #e0e7ff;
  color: #3730a3;
  border-radius: 4px;
  font-size: 11px;
  margin-top: 4px;
}

:deep(.search-highlight) {
  background-color: #fef3c7;
  color: #92400e;
  padding: 1px 2px;
  border-radius: 2px;
}

.load-more {
  text-align: center;
  padding: 16px;
}

.load-more-btn {
  padding: 8px 16px;
  background: #3b82f6;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  transition: background-color 0.2s;
}

.load-more-btn:hover:not(:disabled) {
  background: #2563eb;
}

.load-more-btn:disabled {
  background: #94a3b8;
  cursor: not-allowed;
}

.no-results {
  text-align: center;
  padding: 32px 16px;
  color: #64748b;
}

.no-results-icon {
  margin-bottom: 16px;
  opacity: 0.5;
}

.no-results-text {
  font-size: 16px;
  margin-bottom: 8px;
}

.no-results-hint {
  font-size: 14px;
  opacity: 0.7;
}

.search-help {
  padding: 24px 16px;
  text-align: center;
}

.help-title {
  font-weight: 600;
  color: #374151;
  margin-bottom: 16px;
}

.help-items {
  text-align: left;
  max-width: 400px;
  margin: 0 auto;
}

.help-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
  border-bottom: 1px solid #f1f5f9;
}

.help-key {
  font-family: monospace;
  background: #f1f5f9;
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 13px;
  color: #374151;
}

.help-desc {
  font-size: 13px;
  color: #64748b;
  margin-left: 12px;
}
</style>