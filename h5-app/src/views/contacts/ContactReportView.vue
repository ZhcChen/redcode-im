<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { reportService } from '@/services/report-service';

const route = useRoute();
const router = useRouter();
const userId = computed(() => String(route.params.userId ?? ''));
const content = ref('');
const screenshot = ref<File | null>(null);
const submitting = ref(false);
const error = ref('');
const submitted = ref(false);
const selectScreenshot = (event: Event) => { screenshot.value = (event.target as HTMLInputElement).files?.[0] ?? null; };
const submit = async () => {
  if (!content.value.trim() || !screenshot.value) return;
  submitting.value = true;
  error.value = '';
  try {
    await reportService.reportUser(userId.value, content.value, screenshot.value);
    submitted.value = true;
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : '提交举报失败';
  } finally { submitting.value = false; }
};
</script>

<template>
  <main class="contact-page app-phone-frame">
    <header class="contact-page__header">
      <button class="contact-page__back rc-focus-ring" type="button" aria-label="返回" @click="router.back()">‹</button>
      <div><h1>举报用户</h1><p>举报将提交平台审核</p></div>
    </header>
    <section class="contact-page__content">
      <template v-if="!submitted">
        <label class="contact-page__field">举报说明<textarea v-model="content" class="rc-focus-ring" maxlength="500" placeholder="请描述具体问题" /></label>
        <label class="contact-page__field">截图凭证<input class="rc-focus-ring" type="file" accept="image/*" aria-label="选择举报截图" @change="selectScreenshot" /></label>
        <p v-if="screenshot" class="contact-page__notice">已选择：{{ screenshot.name }}</p>
        <p v-if="error" class="contact-page__notice contact-page__notice--error">{{ error }}</p>
        <button class="contact-page__primary rc-focus-ring" type="button" :disabled="submitting || !content.trim() || !screenshot" @click="submit">{{ submitting ? '正在提交...' : '提交举报' }}</button>
      </template>
      <template v-else>
        <p class="contact-page__notice">举报已提交，我们会尽快审核。</p>
        <button class="contact-page__primary rc-focus-ring" type="button" @click="router.replace({ name: 'contact-profile', params: { userId } })">完成</button>
      </template>
    </section>
  </main>
</template>
