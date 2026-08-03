<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import CachedAvatar from '@/components/CachedAvatar.vue';
import { useContactsStore } from '@/stores/contacts';

const router = useRouter();
const store = useContactsStore();
const message = ref('');
const requestedIds = computed(() => new Set(store.outgoingRequests.map((request) => request.targetUserId)));
const send = async (userId: string) => store.sendFriendRequest(userId, message.value);
onMounted(() => void store.initialize());
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header">
      <button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'home' })">‹</button>
      <div><h1>添加好友</h1><p>通过账号或昵称查找</p></div>
    </header>
    <section class="contact-page__content">
      <form class="contact-page__search" @submit.prevent="store.searchUsers()">
        <input v-model="store.searchKeyword" class="rc-focus-ring" placeholder="搜索账号 / 昵称" />
        <button class="contact-page__primary rc-focus-ring" type="submit" :disabled="store.searching">搜索</button>
      </form>
      <label class="contact-page__field">申请消息<input v-model="message" class="rc-focus-ring" maxlength="80" placeholder="介绍一下自己" /></label>
      <p v-if="store.error" class="contact-page__notice contact-page__notice--error">{{ store.error }}</p>
      <p v-if="store.searchKeyword && !store.searching && store.searchResults.length === 0" class="contact-page__empty">没有找到匹配用户</p>
      <article v-for="user in store.searchResults" :key="user.id" class="contact-page__row">
        <CachedAvatar kind="user" :entity-id="user.id" :object-key="user.avatarObjectKey" :label="user.nickname || user.username" :size="42" />
        <div><h2>{{ user.nickname || user.username }}</h2><p>{{ user.username }}</p></div>
        <button class="contact-page__primary rc-focus-ring" type="button" :disabled="requestedIds.has(user.id) || store.submitting" @click="send(user.id)">
          {{ requestedIds.has(user.id) ? '已申请' : '添加' }}
        </button>
      </article>
    </section>
  </main>
</template>
