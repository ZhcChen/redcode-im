<script setup lang="ts">
import { useRouter } from 'vue-router';

const router = useRouter();
</script>

<template>
  <main class="settings-page app-phone-frame">
    <header class="settings-header">
      <button class="settings-back rc-focus-ring" type="button" aria-label="返回" @click="router.push({ name: 'home' })">‹</button>
      <div><p>我的</p><h1>设置</h1></div>
    </header>
    <section class="settings-content">
      <section class="settings-card settings-list">
        <button class="settings-overview-row rc-focus-ring" type="button" @click="router.push({ name: 'account-security' })"><span>账号与安全</span><strong>›</strong></button>
        <button class="settings-overview-row rc-focus-ring" type="button" @click="router.push({ name: 'chat-settings' })"><span>聊天设置</span><strong>›</strong></button>
      </section>
      <section class="settings-card settings-list">
        <button class="settings-overview-row rc-focus-ring" type="button" @click="router.push({ name: 'privacy-policy' })"><span>隐私协议</span><strong>›</strong></button>
        <button class="settings-overview-row rc-focus-ring" type="button" @click="router.push({ name: 'user-agreement' })"><span>用户协议</span><strong>›</strong></button>
        <button class="settings-overview-row rc-focus-ring" type="button" @click="router.push({ name: 'feedback' })"><span>意见反馈</span><strong>›</strong></button>
        <button class="settings-overview-row rc-focus-ring" type="button" @click="router.push({ name: 'about' })"><span>关于 RedCode IM</span><strong>›</strong></button>
      </section>
    </section>
  </main>
</template>

<style scoped>
@import './settings-page.css';
.settings-list { gap: 0; padding-block: 4px; }
.settings-overview-row { display: flex; align-items: center; justify-content: space-between; min-height: 52px; cursor: pointer; background: transparent; color: var(--rc-text-primary); font-size: 15px; text-align: left; }
.settings-overview-row + .settings-overview-row { border-top: 1px solid var(--rc-divider); }
.settings-overview-row strong { color: var(--rc-text-tertiary); font-size: 20px; font-weight: 400; }
</style>
