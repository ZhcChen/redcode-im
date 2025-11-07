<template>
  <div v-if="visible" class="search-dialog-overlay" @click="handleOverlayClick">
    <div class="search-dialog" @click.stop>
      <div class="search-dialog-header">
        <h3>搜索消息</h3>
        <button class="close-btn" @click="handleClose">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
      </div>

      <div class="search-dialog-content">
        <MessageSearch
          :visible="visible"
          :current-room-id="currentRoomId"
          :available-rooms="availableRooms"
          :available-senders="availableSenders"
          @result-click="handleResultClick"
          @close="handleClose"
        />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { defineProps, defineEmits } from 'vue';
import MessageSearch from './MessageSearch.vue';
import type { MessageSearchResult } from '@/api/search';

// Props
const props = defineProps<{
  visible: boolean;
  currentRoomId?: string;
  availableRooms?: Array<{ id: string; name: string }>;
  availableSenders?: Array<{ id: string; name: string }>;
}>();

// Emits
const emit = defineEmits<{
  close: [];
  resultClick: [result: MessageSearchResult];
}>();

// 方法
const handleClose = () => {
  emit('close');
};

const handleOverlayClick = () => {
  handleClose();
};

const handleResultClick = (result: MessageSearchResult) => {
  emit('resultClick', result);
  handleClose();
};
</script>

<style scoped>
.search-dialog-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  backdrop-filter: blur(4px);
}

.search-dialog {
  background: white;
  border-radius: 12px;
  width: 90vw;
  max-width: 700px;
  max-height: 85vh;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.search-dialog-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 24px 16px;
  border-bottom: 1px solid #e2e8f0;
}

.search-dialog-header h3 {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: #1e293b;
}

.close-btn {
  background: none;
  border: none;
  padding: 8px;
  border-radius: 6px;
  cursor: pointer;
  color: #64748b;
  transition: background-color 0.2s, color 0.2s;
}

.close-btn:hover {
  background-color: #f1f5f9;
  color: #374151;
}

.search-dialog-content {
  flex: 1;
  overflow: hidden;
  padding: 0 24px 24px;
}
</style>