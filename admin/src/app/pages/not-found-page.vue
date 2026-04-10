<template>
  <div class="content">
    <a-result class="result" status="404" :subtitle="'not found'"> </a-result>
    <div class="operation-row">
      <a-button key="back" type="primary" @click="back"> back </a-button>
    </div>
  </div>
</template>

<script lang="ts" setup>
  import type { RouteRecordRaw } from 'vue-router';
  import { useRouter } from 'vue-router';
  import usePermission from '@/hooks/permission';
  import { isLogin } from '@/services/auth-runtime';

  const router = useRouter();
  const permission = usePermission();

  const back = () => {
    if (!isLogin()) {
      router.push({ name: 'login' });
      return;
    }

    const fallbackCandidates = router
      .getRoutes()
      .filter((route) => route.name !== 'notFound' && route.meta?.requiresAuth);
    const fallbackRoute = permission.findFirstPermissionRoute(
      fallbackCandidates as unknown as RouteRecordRaw[]
    ) || {
      name: 'login',
    };
    router.push(fallbackRoute);
  };
</script>

<style scoped lang="less">
  .content {
    position: absolute;
    top: 50%;
    left: 50%;
    margin-top: -121px;
    margin-left: -95px;
    text-align: center;
  }
</style>
