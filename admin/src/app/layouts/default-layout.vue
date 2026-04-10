<template>
  <a-layout class="layout" :class="{ mobile: appStore.hideMenu }">
    <div v-if="navbar" class="layout-navbar">
      <NavBar />
    </div>
    <a-layout>
      <a-layout>
        <a-layout-sider
          v-if="renderMenu"
          v-show="!hideMenu"
          class="layout-sider"
          breakpoint="xl"
          :collapsed="collapsed"
          :collapsible="true"
          :width="menuWidth"
          :style="{ paddingTop: navbar ? '60px' : '' }"
          :hide-trigger="true"
          @collapse="setCollapsed"
        >
          <div class="menu-wrapper">
            <Menu />
          </div>
        </a-layout-sider>
        <a-drawer
          v-if="hideMenu"
          :visible="drawerVisible"
          placement="left"
          :footer="false"
          mask-closable
          :closable="false"
          @cancel="drawerCancel"
        >
          <Menu />
        </a-drawer>
        <a-layout class="layout-content" :style="paddingStyle">
          <TabBar v-if="appStore.tabBar" />
          <a-layout-content>
            <PageLayout />
          </a-layout-content>
          <Footer v-if="footer" />
        </a-layout>
      </a-layout>
    </a-layout>
    <!-- 回到顶部按钮 -->
    <div v-if="showBackTop" class="back-top-btn" @click="scrollToTop">
      <a-button type="primary" shape="circle" size="large">
        <template #icon>
          <icon-arrow-up />
        </template>
      </a-button>
    </div>
  </a-layout>
</template>

<script lang="ts" setup>
  import { ref, computed, watch, provide, onMounted, onUnmounted } from 'vue';
  import { useRouter, useRoute } from 'vue-router';
  import { useAppStore, useUserStore } from '@/store';
  import NavBar from '@/components/navbar/index.vue';
  import Menu from '@/components/menu/index.vue';
  import Footer from '@/components/footer/index.vue';
  import TabBar from '@/components/tab-bar/index.vue';
  import usePermission from '@/hooks/permission';
  import useResponsive from '@/hooks/responsive';
  import { IconArrowUp } from '@arco-design/web-vue/es/icon';
  import PageLayout from './page-layout.vue';

  const isInit = ref(false);
  const appStore = useAppStore();
  const userStore = useUserStore();
  const router = useRouter();
  const route = useRoute();
  const permission = usePermission();
  useResponsive(true);
  const navbarHeight = `60px`;
  const navbar = computed(() => appStore.navbar);
  const renderMenu = computed(() => appStore.menu && !appStore.topMenu);
  const hideMenu = computed(() => appStore.hideMenu);
  const footer = computed(() => appStore.footer);
  const menuWidth = computed(() => {
    return appStore.menuCollapse ? 48 : appStore.menuWidth;
  });
  const collapsed = computed(() => {
    return appStore.menuCollapse;
  });
  const paddingStyle = computed(() => {
    const paddingLeft =
      renderMenu.value && !hideMenu.value
        ? { paddingLeft: `${menuWidth.value}px` }
        : {};
    const paddingTop = navbar.value ? { paddingTop: navbarHeight } : {};
    return { ...paddingLeft, ...paddingTop };
  });
  const setCollapsed = (val: boolean) => {
    if (!isInit.value) return; // for page initialization menu state problem
    appStore.updateSettings({ menuCollapse: val });
  };
  watch(
    () =>
      `${userStore.role}|${userStore.isSuperAdmin}|${userStore.roleCodes.join(
        ','
      )}|${userStore.permissionKeys.join(',')}`,
    (accessSignature) => {
      if (accessSignature && !permission.accessRouter(route))
        router.push({ name: 'notFound' });
    }
  );
  const drawerVisible = ref(false);
  const drawerCancel = () => {
    drawerVisible.value = false;
  };
  provide('toggleDrawerMenu', () => {
    drawerVisible.value = !drawerVisible.value;
  });

  // 回到顶部按钮逻辑
  const showBackTop = ref(false);
  const scrollContainers = new Set<HTMLElement>();
  const layoutContentEl = ref<HTMLElement | null>(null);
  const arcoContentEl = ref<HTMLElement | null>(null);

  const getScrollTop = () => {
    const windowScroll =
      window.pageYOffset ||
      document.documentElement.scrollTop ||
      document.body.scrollTop ||
      0;

    const containerScrolls = Array.from(scrollContainers).map(
      (el) => el.scrollTop
    );

    return Math.max(windowScroll, ...containerScrolls);
  };

  function addScrollContainer(
    el: HTMLElement | null | undefined,
    handler: (event: Event) => void
  ) {
    if (!el) return;
    if (scrollContainers.has(el)) return;
    scrollContainers.add(el);
    el.addEventListener('scroll', handler, { passive: true });
  }

  function handleScroll(event?: Event) {
    // 动态捕捉新的可滚动容器（如富文本编辑器内部滚动区域）
    if (event?.target instanceof HTMLElement) {
      addScrollContainer(event.target, handleScroll);
    }
    showBackTop.value = getScrollTop() > 100;
  }

  const scrollToTop = () => {
    scrollContainers.forEach((el) => {
      el.scrollTo({ top: 0, behavior: 'smooth' });
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  onMounted(() => {
    isInit.value = true;
    layoutContentEl.value = document.querySelector('.layout-content');
    arcoContentEl.value = document.querySelector('.arco-layout-content');

    window.addEventListener('scroll', handleScroll, {
      passive: true,
      capture: true,
    });
    addScrollContainer(layoutContentEl.value, handleScroll);
    if (arcoContentEl.value && arcoContentEl.value !== layoutContentEl.value) {
      addScrollContainer(arcoContentEl.value, handleScroll);
    }

    // 富文本编辑器内部滚动容器（wangeditor）
    document
      .querySelectorAll<HTMLElement>('.w-e-scroll, .w-e-text-container')
      .forEach((el) => addScrollContainer(el, handleScroll));
    handleScroll();
  });

  onUnmounted(() => {
    window.removeEventListener('scroll', handleScroll, true);
    scrollContainers.forEach((el) => {
      el.removeEventListener('scroll', handleScroll);
    });
    scrollContainers.clear();
  });
</script>

<style scoped lang="less">
  @nav-size-height: 60px;
  @layout-max-width: 1100px;

  .layout {
    width: 100%;
    height: 100%;
  }

  .layout-navbar {
    position: fixed;
    top: 0;
    left: 0;
    z-index: 100;
    width: 100%;
    height: @nav-size-height;
  }

  .layout-sider {
    position: fixed;
    top: 0;
    left: 0;
    z-index: 99;
    height: 100%;
    transition: all 0.2s cubic-bezier(0.34, 0.69, 0.1, 1);

    &::after {
      position: absolute;
      top: 0;
      right: -1px;
      display: block;
      width: 1px;
      height: 100%;
      background-color: var(--color-border);
      content: '';
    }

    > :deep(.arco-layout-sider-children) {
      overflow-y: hidden;
    }
  }

  .menu-wrapper {
    height: 100%;
    overflow: auto;
    overflow-x: hidden;

    :deep(.arco-menu) {
      ::-webkit-scrollbar {
        width: 12px;
        height: 4px;
      }

      ::-webkit-scrollbar-thumb {
        background-color: var(--color-text-4);
        background-clip: padding-box;
        border: 4px solid transparent;
        border-radius: 7px;
      }

      ::-webkit-scrollbar-thumb:hover {
        background-color: var(--color-text-3);
      }
    }
  }

  .layout-content {
    height: 100vh;
    min-height: 100vh;
    overflow-y: auto;
    background-color: var(--color-fill-2);
    transition: padding 0.2s cubic-bezier(0.34, 0.69, 0.1, 1);
  }

  .back-top-btn {
    position: fixed;
    right: 30px;
    bottom: 30px;
    z-index: 1000;
    cursor: pointer;
    transition: all 0.3s cubic-bezier(0.34, 0.69, 0.1, 1);

    :deep(.arco-btn) {
      box-shadow: 0 2px 12px 0 rgb(0 0 0 / 10%);
      transition: all 0.3s cubic-bezier(0.34, 0.69, 0.1, 1);
    }

    &:hover {
      transform: translateY(-2px);

      :deep(.arco-btn) {
        box-shadow: 0 4px 16px 0 rgb(0 0 0 / 15%);
      }
    }
  }
</style>
