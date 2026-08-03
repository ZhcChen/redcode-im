<script setup lang="ts">
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';
import CachedAvatar from '@/components/CachedAvatar.vue';
import { useGroupDirectoryStore } from '@/stores/group-directory';

const router = useRouter();
const store = useGroupDirectoryStore();
onMounted(() => void store.load());
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header">
      <button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'home' })">‹</button>
      <div><h1>群聊</h1><p>{{ store.entries.length }} 个已加入群聊</p></div>
      <button class="contact-page__primary rc-focus-ring" type="button" @click="router.push({ name: 'group-create' })">新建</button>
    </header>
    <section class="contact-page__content">
      <label class="contact-page__search"><input v-model="store.keyword" class="rc-focus-ring" placeholder="搜索群名称或简介" /></label>
      <p v-if="store.error" class="contact-page__notice contact-page__notice--error">{{ store.error }}</p>
      <p v-if="store.loading && store.entries.length === 0" class="contact-page__empty">正在加载群聊...</p>
      <p v-else-if="store.filteredEntries.length === 0" class="contact-page__empty">暂无匹配群聊</p>
      <article v-for="entry in store.filteredEntries" :key="entry.roomId" class="contact-page__row">
        <CachedAvatar kind="room" :entity-id="entry.roomId" :object-key="entry.avatarObjectKey" :label="entry.name" :size="44" />
        <button class="group-directory__body rc-focus-ring" type="button" @click="router.push({ name: 'chat-detail', params: { roomId: entry.roomId } })">
          <h2>{{ entry.name }}</h2><p>{{ entry.description || `${entry.memberCount} 位成员` }}</p>
        </button>
        <div class="contact-page__actions">
          <button class="contact-page__action rc-focus-ring" type="button" :aria-label="entry.isFavorited ? '取消收藏群聊' : '收藏群聊'" @click="store.toggleFavorite(entry.roomId)">{{ entry.isFavorited ? '已收藏' : '收藏' }}</button>
          <button class="contact-page__action rc-focus-ring" type="button" @click="router.push({ name: 'group-settings', params: { roomId: entry.roomId } })">设置</button>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.group-directory__body { min-width: 0; cursor: pointer; background: transparent; text-align: left; }
</style>
