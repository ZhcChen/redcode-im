<template>
  <router-view />
</template>

<script setup lang="ts">
// 根组件保持轻量，由路由负责呈现具体页面
</script>

<style>
html, body {
  margin: 0;
  padding: 0;
  height: 100%;
  background: #f7f8fb;
  color: #1f2933;
}

#app {
  height: 100%;
}
</style>
