<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import CachedAvatar from '@/components/CachedAvatar.vue';
import { useContactsStore } from '@/stores/contacts';

const router = useRouter();
const store = useContactsStore();
const outgoing = ref(false);
const requests = computed(() => outgoing.value ? store.outgoingRequests : store.incomingRequests);
const userOf = (request: typeof store.incomingRequests[number]) => outgoing.value ? request.targetUser : request.requester;
const nameOf = (request: typeof store.incomingRequests[number]) => {
  const user = userOf(request);
  return user?.nickname || user?.username || (outgoing.value ? request.targetUserId : request.requesterId);
};
onMounted(() => void store.initialize());
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header">
      <button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'home' })">‹</button>
      <div><h1>好友申请</h1><p>查看收到和发出的申请</p></div>
      <button class="contact-page__action rc-focus-ring" type="button" @click="store.refreshRequests">刷新</button>
    </header>
    <section class="contact-page__content">
      <div class="contact-page__tabs" role="tablist">
        <button :class="{ active: !outgoing }" type="button" @click="outgoing = false">收到 {{ store.incomingRequests.length }}</button>
        <button :class="{ active: outgoing }" type="button" @click="outgoing = true">发出 {{ store.outgoingRequests.length }}</button>
      </div>
      <p v-if="store.error" class="contact-page__notice contact-page__notice--error">{{ store.error }}</p>
      <p v-if="requests.length === 0" class="contact-page__empty">暂无好友申请</p>
      <article v-for="request in requests" :key="request.id" class="contact-page__row">
        <CachedAvatar kind="user" :entity-id="userOf(request)?.id || (outgoing ? request.targetUserId : request.requesterId)" :label="nameOf(request)" :size="42" />
        <div><h2>{{ nameOf(request) }}</h2><p>{{ request.message || (outgoing ? '等待对方处理' : '请求添加你为好友') }}</p></div>
        <div v-if="!outgoing && request.status === 'pending'" class="contact-page__actions">
          <button class="contact-page__primary rc-focus-ring" type="button" @click="store.respondRequest(request.id, 'accept')">同意</button>
          <button class="contact-page__action rc-focus-ring" type="button" @click="store.respondRequest(request.id, 'decline')">拒绝</button>
        </div>
        <span v-else>{{ request.status === 'pending' ? '待处理' : request.status }}</span>
      </article>
    </section>
  </main>
</template>
