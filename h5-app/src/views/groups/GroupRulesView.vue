<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { appEnv } from '@/config/env';
import { roomService } from '@/services/room-service';
import { useAuthStore } from '@/stores/auth';
import { useGroupSettingsStore } from '@/stores/group-settings';
import type { GroupRule } from '@/types/room';

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const group = useGroupSettingsStore();
const roomId = computed(() => String(route.params.roomId ?? ''));
const rules = ref<GroupRule[]>([]);
const title = ref('');
const content = ref('');
const editingId = ref('');
const confirmingDelete = ref('');
const submitting = ref(false);
const error = ref('');
const notice = ref('');
const myRole = computed(() => group.members.find((member) => member.userId === auth.currentUser?.id)?.role ?? 'member');
const canManage = computed(() => myRole.value === 'owner' || myRole.value === 'admin');
const visibleRules = computed(() => rules.value.filter((rule) => rule.isActive).sort((a, b) => a.orderIndex - b.orderIndex));

const loadRules = async () => {
  rules.value = appEnv.useMockData ? rules.value : await roomService.listRules(roomId.value);
};

const resetForm = () => {
  title.value = '';
  content.value = '';
  editingId.value = '';
};

const edit = (rule: GroupRule) => {
  title.value = rule.title;
  content.value = rule.content;
  editingId.value = rule.id;
};

const save = async () => {
  if (!title.value.trim() || !content.value.trim()) return;
  submitting.value = true;
  error.value = '';
  notice.value = '';
  try {
    if (editingId.value) {
      if (appEnv.useMockData) {
        rules.value = rules.value.map((rule) => rule.id === editingId.value
          ? { ...rule, title: title.value.trim(), content: content.value.trim(), updatedAt: new Date().toISOString() }
          : rule);
      } else {
        await roomService.updateRule(roomId.value, editingId.value, { title: title.value, content: content.value });
        await loadRules();
      }
      notice.value = '群规已更新';
    } else {
      if (appEnv.useMockData) {
        rules.value.push({
          id: `mock-rule-${Date.now()}`,
          roomId: roomId.value,
          title: title.value.trim(),
          content: content.value.trim(),
          creatorId: auth.currentUser?.id ?? '',
          orderIndex: rules.value.length,
          isActive: true,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        });
      } else {
        await roomService.createRule(roomId.value, {
          title: title.value,
          content: content.value,
          orderIndex: rules.value.length,
        });
        await loadRules();
      }
      notice.value = '群规已添加';
    }
    resetForm();
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '保存群规失败';
  } finally {
    submitting.value = false;
  }
};

const remove = async (ruleId: string) => {
  submitting.value = true;
  error.value = '';
  notice.value = '';
  try {
    if (appEnv.useMockData) {
      rules.value = rules.value.filter((rule) => rule.id !== ruleId);
    } else {
      await roomService.deleteRule(roomId.value, ruleId);
      await loadRules();
    }
    confirmingDelete.value = '';
    if (editingId.value === ruleId) resetForm();
    notice.value = '群规已删除';
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '删除群规失败';
  } finally {
    submitting.value = false;
  }
};

onMounted(async () => {
  await group.enterRoom(roomId.value);
  try {
    await loadRules();
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '加载群规失败';
  }
});
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header">
      <button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'group-settings', params: { roomId } })">‹</button>
      <div><h1>群规</h1><p>{{ visibleRules.length }} 条有效规则</p></div>
    </header>
    <section class="contact-page__content">
      <p v-if="error || group.error" class="contact-page__notice contact-page__notice--error">{{ error || group.error }}</p>
      <p v-if="notice" class="contact-page__notice">{{ notice }}</p>

      <form v-if="canManage" class="rule-form" @submit.prevent="save">
        <h2>{{ editingId ? '编辑群规' : '添加群规' }}</h2>
        <label class="contact-page__field">标题<input v-model="title" class="rc-focus-ring" maxlength="50" placeholder="请输入群规标题" /></label>
        <label class="contact-page__field">内容<textarea v-model="content" class="rc-focus-ring" maxlength="500" placeholder="请输入群规内容" /></label>
        <div class="contact-page__actions">
          <button class="contact-page__primary rc-focus-ring" type="submit" :disabled="submitting || !title.trim() || !content.trim()">{{ submitting ? '保存中' : '保存' }}</button>
          <button v-if="editingId" class="contact-page__action rc-focus-ring" type="button" :disabled="submitting" @click="resetForm">取消编辑</button>
        </div>
      </form>

      <p v-if="!group.loading && visibleRules.length === 0" class="contact-page__empty">{{ canManage ? '暂无群规，可以添加第一条规则' : '暂无群规' }}</p>
      <article v-for="(rule, index) in visibleRules" :key="rule.id" class="rule-card">
        <div class="rule-card__index">{{ index + 1 }}</div>
        <div class="rule-card__body"><h2>{{ rule.title }}</h2><p>{{ rule.content }}</p></div>
        <div v-if="canManage" class="contact-page__actions">
          <button class="contact-page__action rc-focus-ring" type="button" @click="edit(rule)">编辑</button>
          <button v-if="confirmingDelete !== rule.id" class="contact-page__action contact-page__danger rc-focus-ring" type="button" @click="confirmingDelete = rule.id">删除</button>
          <template v-else><button class="contact-page__action contact-page__danger rc-focus-ring" type="button" :disabled="submitting" @click="remove(rule.id)">确认删除</button><button class="contact-page__action rc-focus-ring" type="button" :disabled="submitting" @click="confirmingDelete = ''">取消</button></template>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.rule-form, .rule-card { border-radius: 8px; background: var(--rc-surface); padding: 14px; }
.rule-form { display: grid; gap: 12px; }
.rule-form h2, .rule-card h2, .rule-card p { margin: 0; }
.rule-form h2 { font-size: 16px; }
.rule-card { display: grid; grid-template-columns: 24px minmax(0, 1fr); gap: 10px; }
.rule-card__index { display: grid; place-items: center; width: 24px; height: 24px; border-radius: 50%; background: var(--rc-primary); color: #fff; font-size: 12px; font-weight: 700; }
.rule-card__body { min-width: 0; }
.rule-card__body h2 { font-size: 15px; }
.rule-card__body p { margin-top: 7px; color: var(--rc-text-secondary); line-height: 1.6; white-space: pre-wrap; }
.rule-card > .contact-page__actions { grid-column: 2; justify-content: flex-end; }
</style>
