<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import CachedAvatar from '@/components/CachedAvatar.vue';
import { useContactsStore } from '@/stores/contacts';

const route = useRoute();
const router = useRouter();
const store = useContactsStore();
const userId = computed(() => String(route.params.userId ?? ''));
const friend = computed(() => store.friends.find((item) => item.user.id === userId.value) ?? null);
const remark = ref('');
const confirmingDelete = ref(false);
const notice = ref('');
watch(friend, (value) => { remark.value = value?.remark ?? ''; }, { immediate: true });
const saveRemark = async () => {
  await store.updateFriendRemark(userId.value, remark.value);
  notice.value = remark.value.trim() ? '备注已更新' : '备注已清除';
};
const openChat = async () => {
  const roomId = await store.openPrivateChat(userId.value);
  if (roomId) await router.push({ name: 'chat-detail', params: { roomId } });
};
const remove = async () => {
  await store.deleteFriend(userId.value);
  await router.replace({ name: 'home' });
};
onMounted(() => void store.initialize());
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header">
      <button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'home' })">‹</button>
      <div><h1>联系人名片</h1><p>资料与好友设置</p></div>
    </header>
    <template v-if="friend">
      <section class="contact-profile__hero">
        <CachedAvatar kind="user" :entity-id="friend.user.id" :object-key="friend.user.avatarObjectKey" :label="friend.remark || friend.user.nickname || friend.user.username" :size="72" />
        <h2>{{ friend.remark || friend.user.nickname || friend.user.username }}</h2>
        <p>{{ friend.user.username }}</p>
      </section>
      <section class="contact-page__content">
        <label class="contact-page__field">好友备注<input v-model="remark" class="rc-focus-ring" maxlength="32" placeholder="留空可清除备注" /></label>
        <button class="contact-page__action rc-focus-ring" type="button" :disabled="store.submitting" @click="saveRemark">保存备注</button>
        <p v-if="notice" class="contact-page__notice">{{ notice }}</p>
        <p v-if="store.error" class="contact-page__notice contact-page__notice--error">{{ store.error }}</p>
        <div class="contact-profile__commands">
          <button class="contact-page__primary rc-focus-ring" type="button" @click="openChat">发送消息</button>
          <button class="contact-page__action rc-focus-ring" type="button" @click="router.push({ name: 'contact-report', params: { userId } })">举报该用户</button>
          <button v-if="!confirmingDelete" class="contact-page__action contact-page__danger rc-focus-ring" type="button" @click="confirmingDelete = true">删除好友</button>
          <template v-else>
            <button class="contact-page__action contact-page__danger rc-focus-ring" type="button" @click="remove">确认删除好友</button>
            <button class="contact-page__action rc-focus-ring" type="button" @click="confirmingDelete = false">取消</button>
          </template>
        </div>
      </section>
    </template>
    <p v-else class="contact-page__empty">联系人不存在或已被删除</p>
  </main>
</template>
