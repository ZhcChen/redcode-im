<template>
  <div
    class="page-shell relative flex h-auto min-h-screen w-full flex-col overflow-x-hidden"
    style='font-family: "Space Grotesk", "Noto Sans", sans-serif;'
  >
    <div class="layout-container relative z-10 flex h-full grow flex-col">
      <header
        class="flex flex-wrap items-center gap-4 px-5 py-3 sm:px-8 md:flex-nowrap md:gap-8 md:px-10"
      >
        <div class="flex items-center gap-3 text-[#111618]">
          <img
            src="/logo.svg"
            alt="Chatly logo"
            width="32"
            height="32"
            loading="lazy"
            decoding="async"
            class="h-8 w-8"
          />
          <h2 class="text-[#111618] text-lg font-bold leading-tight tracking-[-0.015em]">Chatly</h2>
        </div>
        <div class="flex w-full flex-col gap-3 sm:flex-row sm:items-center sm:justify-end md:w-auto md:flex-1 md:gap-6">
          <div class="flex items-center justify-between gap-4 text-sm font-medium text-[#111618] sm:justify-end md:gap-9">
            <a href="#">功能</a>
            <a href="#">支持</a>
          </div>
          <button
            class="flex h-11 w-full min-w-[120px] cursor-pointer items-center justify-center rounded-xl px-4 text-sm font-bold tracking-[0.015em] text-white bg-[#13a4ec] sm:w-auto"
          >
            <span class="truncate">下载</span>
          </button>
        </div>
      </header>

      <div class="flex flex-1 justify-center px-5 py-6 sm:px-8 md:px-20 md:py-10 lg:px-40">
        <div class="layout-content-container flex flex-col max-w-[960px] flex-1">
          <div class="@container">
            <div class="p-3 @[480px]:p-4">
              <div
                class="flex min-h-[360px] flex-col items-center justify-center gap-5 rounded-2xl bg-cover bg-center bg-no-repeat p-4 text-center @[480px]:min-h-[480px] @[480px]:gap-8 @[480px]:rounded-[32px]"
                :style="{
                  backgroundImage: `linear-gradient(rgba(0, 0, 0, 0.1) 0%, rgba(0, 0, 0, 0.4) 100%), url('https://lh3.googleusercontent.com/aida-public/AB6AXuAdh1y3LMLnfPmOUIy3XlbstCsn9NWdcPUxPjof996Az5CQE7CG_lkWO0JghDDZboScdNrONcwon85uZwyPmrwrD2YGlIJcnmXKXTg9XyUBli1-yCb3arjHiBAOgF_cG1vpTwfEzW1DsJKwU7wx3qj8GrNhLNr9Y6soRH0dMLDUtiLGy-xiIY8_RCwO-RUOesGRplMLrRGdAJH76U74y-tpxdhv7SOsGHcIM1ZU4x8kuRqBKFE0FrkOfiWQ9JxDYi2iJkFh2s37vPYw')`
                }"
              >
                <div class="flex flex-col gap-2 text-center">
                  <h1
                    class="text-white text-3xl font-black leading-tight tracking-[-0.03em] sm:text-4xl md:text-5xl"
                  >
                    Chatly：为每个人打造的实时沟通体验
                  </h1>
                  <h2
                    class="text-white text-sm font-normal leading-relaxed sm:text-base"
                  >
                    体验 Chatly 带来的无缝沟通。与朋友、家人和同事即时连接，跨越所有设备。
                  </h2>
                </div>
                <button
                  class="flex h-12 w-full min-w-[180px] max-w-[320px] cursor-pointer items-center justify-center rounded-xl bg-[#13a4ec] px-5 text-base font-bold leading-normal tracking-[0.015em] text-white sm:w-auto"
                >
                  <span class="truncate">立即下载</span>
                </button>
              </div>
            </div>
          </div>

          <h2 class="px-5 pb-3 pt-6 text-[22px] font-bold leading-tight tracking-[-0.015em] text-[#111618] sm:px-4">
            核心功能
          </h2>

          <div class="@container flex flex-col gap-8 px-5 py-8 sm:gap-10 sm:px-4 sm:py-10">
            <div class="flex flex-col gap-4">
              <h1
                class="text-[28px] font-bold leading-tight tracking-[-0.02em] text-[#111618] @[480px]:text-4xl @[480px]:font-black @[480px]:leading-tight @[480px]:tracking-[-0.033em] max-w-[720px]"
              >
                Chatly 功能
              </h1>
              <p class="text-base font-normal leading-relaxed text-[#111618] max-w-[720px]">
                Chatly 提供一系列旨在增强您的沟通体验的功能。
              </p>
            </div>

            <div class="grid grid-cols-[repeat(auto-fit,minmax(158px,1fr))] gap-4 p-0 sm:gap-5">
              <div class="flex flex-1 flex-col gap-3 rounded-xl border border-[#dbe2e6] bg-white p-4">
                <div class="text-[#111618]" data-icon="ChatCircleDots" data-size="24px" data-weight="regular">
                  <svg xmlns="http://www.w3.org/2000/svg" width="24px" height="24px" fill="currentColor" viewBox="0 0 256 256">
                    <path
                      d="M140,128a12,12,0,1,1-12-12A12,12,0,0,1,140,128ZM84,116a12,12,0,1,0,12,12A12,12,0,0,0,84,116Zm88,0a12,12,0,1,0,12,12A12,12,0,0,0,172,116Zm60,12A104,104,0,0,1,79.12,219.82L45.07,231.17a16,16,0,0,1-20.24-20.24l11.35-34.05A104,104,0,1,1,232,128Zm-16,0A88,88,0,1,0,51.81,172.06a8,8,0,0,1,.66,6.54L40,216,77.4,203.53a7.85,7.85,0,0,1,2.53-.42,8,8,0,0,1,4,1.08A88,88,0,0,0,216,128Z"
                    />
                  </svg>
                </div>
                <div class="flex flex-col gap-1">
                  <h2 class="text-[#111618] text-base font-bold leading-tight">即时消息</h2>
                  <p class="text-[#617c89] text-sm font-normal leading-normal">
                    使用 Chatly 的闪电般快速的消息服务，即时发送和接收消息。
                  </p>
                </div>
              </div>

              <div class="flex flex-1 gap-3 rounded-lg border border-[#dbe2e6] bg-white p-4 flex-col">
                <div class="text-[#111618]" data-icon="Users" data-size="24px" data-weight="regular">
                  <svg xmlns="http://www.w3.org/2000/svg" width="24px" height="24px" fill="currentColor" viewBox="0 0 256 256">
                    <path
                      d="M117.25,157.92a60,60,0,1,0-66.5,0A95.83,95.83,0,0,0,3.53,195.63a8,8,0,1,0,13.4,8.74,80,80,0,0,1,134.14,0,8,8,0,0,0,13.4-8.74A95.83,95.83,0,0,0,117.25,157.92ZM40,108a44,44,0,1,1,44,44A44.05,44.05,0,0,1,40,108Zm210.14,98.7a8,8,0,0,1-11.07-2.33A79.83,79.83,0,0,0,172,168a8,8,0,0,1,0-16,44,44,0,1,0-16.34-84.87,8,8,0,1,1-5.94-14.85,60,60,0,0,1,55.53,105.64,95.83,95.83,0,0,1,47.22,37.71A8,8,0,0,1,250.14,206.7Z"
                    />
                  </svg>
                </div>
                <div class="flex flex-col gap-1">
                  <h2 class="text-[#111618] text-base font-bold leading-tight">群聊</h2>
                  <p class="text-[#617c89] text-sm font-normal leading-normal">
                    创建和管理多达1000名成员的群聊，实现无缝团队协作。
                  </p>
                </div>
              </div>

              <div class="flex flex-1 gap-3 rounded-lg border border-[#dbe2e6] bg-white p-4 flex-col">
                <div class="text-[#111618]" data-icon="Lock" data-size="24px" data-weight="regular">
                  <svg xmlns="http://www.w3.org/2000/svg" width="24px" height="24px" fill="currentColor" viewBox="0 0 256 256">
                    <path
                      d="M208,80H176V56a48,48,0,0,0-96,0V80H48A16,16,0,0,0,32,96V208a16,16,0,0,0,16,16H208a16,16,0,0,0,16-16V96A16,16,0,0,0,208,80ZM96,56a32,32,0,0,1,64,0V80H96ZM208,208H48V96H208V208Zm-68-56a12,12,0,1,1-12-12A12,12,0,0,1,140,152Z"
                    />
                  </svg>
                </div>
                <div class="flex flex-col gap-1">
                  <h2 class="text-[#111618] text-base font-bold leading-tight">端到端加密</h2>
                  <p class="text-[#617c89] text-sm font-normal leading-normal">
                    您的消息受到端到端加密的保护，确保您的隐私和安全。
                  </p>
                </div>
              </div>

              <div class="flex flex-1 flex-col gap-3 rounded-xl border border-[#dbe2e6] bg-white p-4">
                <div class="text-[#111618]" data-icon="Desktop" data-size="24px" data-weight="regular">
                  <svg xmlns="http://www.w3.org/2000/svg" width="24px" height="24px" fill="currentColor" viewBox="0 0 256 256">
                    <path
                      d="M208,40H48A24,24,0,0,0,24,64V176a24,24,0,0,0,24,24h72v16H96a8,8,0,0,0,0,16h64a8,8,0,0,0,0-16H136V200h72a24,24,0,0,0,24-24V64A24,24,0,0,0,208,40ZM48,56H208a8,8,0,0,1,8,8v80H40V64A8,8,0,0,1,48,56ZM208,184H48a8,8,0,0,1-8-8V160H216v16A8,8,0,0,1,208,184Z"
                    />
                  </svg>
                </div>
                <div class="flex flex-col gap-1">
                  <h2 class="text-[#111618] text-base font-bold leading-tight">桌面应用</h2>
                  <p class="text-[#617c89] text-sm font-normal leading-normal">
                    Tauri 桌面客户端覆盖 Windows（含 Windows 7）和 macOS，保持消息无缝同步。
                  </p>
                </div>
              </div>

              <div class="flex flex-1 flex-col gap-3 rounded-xl border border-[#dbe2e6] bg-white p-4">
                <div class="text-[#111618]" data-icon="DeviceMobile" data-size="24px" data-weight="regular">
                  <svg xmlns="http://www.w3.org/2000/svg" width="24px" height="24px" fill="currentColor" viewBox="0 0 256 256">
                    <path
                      d="M176,16H80A24,24,0,0,0,56,40V216a24,24,0,0,0,24,24h96a24,24,0,0,0,24-24V40A24,24,0,0,0,176,16ZM72,64H184V192H72Zm8-32h96a8,8,0,0,1,8,8v8H72V40A8,8,0,0,1,80,32Zm96,192H80a8,8,0,0,1-8-8v-8H184v8A8,8,0,0,1,176,224Z"
                    />
                  </svg>
                </div>
                <div class="flex flex-col gap-1">
                  <h2 class="text-[#111618] text-base font-bold leading-tight">移动应用</h2>
                  <p class="text-[#617c89] text-sm font-normal leading-normal">
                    使用适用于iOS和Android的本地应用程序随时随地保持连接。
                  </p>
                </div>
              </div>
            </div>
          </div>

          <h2 class="px-5 pb-3 pt-5 text-[22px] font-bold leading-tight tracking-[-0.015em] text-[#111618] sm:px-4">
            下载 Chatly
          </h2>

          <div class="px-5 pb-10 sm:px-4">
            <div class="grid gap-5 rounded-3xl border border-[#dbe2e6] bg-[#f8fbfc] p-5 shadow-sm sm:gap-6 sm:p-6 md:grid-cols-2">
              <section class="flex flex-col gap-4">
                <div class="flex items-start gap-3">
                  <div class="rounded-2xl bg-white p-3 text-[#13a4ec] shadow-sm">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 256 256"
                      width="28"
                      height="28"
                      fill="currentColor"
                    >
                      <path
                        d="M184,16H72A24,24,0,0,0,48,40V216a24,24,0,0,0,24,24H184a24,24,0,0,0,24-24V40A24,24,0,0,0,184,16ZM72,32H184a8,8,0,0,1,8,8V64H64V40A8,8,0,0,1,72,32ZM192,216a8,8,0,0,1-8,8H72a8,8,0,0,1-8-8V80H192Z"
                      />
                    </svg>
                  </div>
                  <div class="flex flex-col gap-1">
                    <p class="text-lg font-bold text-[#111618]">移动端</p>
                    <p class="text-sm text-[#617c89]">
                      原生 iOS 与 Android 应用保持消息实时同步，具备完整通知与系统分享体验。
                    </p>
                  </div>
                </div>
                <div class="flex flex-wrap gap-3">
                  <a
                    v-for="item in mobileDownloads"
                    :key="item.label"
                    :href="item.href"
                    class="flex min-w-[160px] flex-1 cursor-pointer items-center justify-between rounded-2xl bg-[#13a4ec] px-4 py-3 text-left text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-[#0f7bcf] hover:shadow-lg"
                  >
                    <div class="flex flex-col">
                      <span class="text-sm font-bold text-white">{{ item.label }}</span>
                      <span v-if="item.subLabel" class="text-xs font-medium text-[#d7ecfb]">{{ item.subLabel }}</span>
                    </div>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 256 256"
                      width="20"
                      height="20"
                      fill="none"
                      stroke="currentColor"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="14"
                    >
                      <path d="M104 64l64 64-64 64" />
                      <path d="M168 128H48" />
                    </svg>
                  </a>
                </div>
              </section>

              <section class="flex flex-col gap-4">
                <div class="flex items-start gap-3">
                  <div class="rounded-2xl bg-white p-3 text-[#13a4ec] shadow-sm">
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 256 256"
                      width="28"
                      height="28"
                      fill="currentColor"
                    >
                      <path
                        d="M208,48H48A16,16,0,0,0,32,64V192a16,16,0,0,0,16,16H208a16,16,0,0,0,16-16V64A16,16,0,0,0,208,48Zm0,16V96H48V64ZM48,192V112H208v80Z"
                      />
                    </svg>
                  </div>
                  <div class="flex flex-col gap-1">
                    <p class="text-lg font-bold text-[#111618]">桌面端</p>
                    <p class="text-sm text-[#617c89]">
                      提供 Windows 7+、macOS 双架构安装包，支持原生通知、托盘与多窗口体验。
                    </p>
                  </div>
                </div>
                <div class="flex flex-col gap-3">
                  <a
                    v-for="item in desktopDownloads"
                    :key="item.label"
                    :href="item.href"
                    class="flex w-full items-center justify-between rounded-2xl bg-[#111618] px-4 py-3 text-left text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-[#0b1114] hover:shadow-lg"
                  >
                    <div class="flex flex-col">
                      <span class="text-sm font-bold text-white">{{ item.label }}</span>
                      <span class="text-xs font-medium text-[#d9dde0]">{{ item.subLabel }}</span>
                    </div>
                    <svg
                      xmlns="http://www.w3.org/2000/svg"
                      viewBox="0 0 256 256"
                      width="20"
                      height="20"
                      fill="none"
                      stroke="currentColor"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="14"
                    >
                      <path d="M104 64l64 64-64 64" />
                      <path d="M168 128H48" />
                    </svg>
                  </a>
                </div>
              </section>
            </div>
          </div>
        </div>
      </div>

      <footer class="flex justify-center">
        <div class="flex max-w-[960px] flex-1 flex-col">
          <footer class="flex flex-col gap-6 px-5 py-10 text-center @container">
            <div class="flex flex-wrap items-center justify-center gap-6 @[480px]:flex-row @[480px]:justify-around">
              <a class="text-[#617c89] text-base font-normal leading-normal min-w-40" href="#">隐私政策</a>
              <a class="text-[#617c89] text-base font-normal leading-normal min-w-40" href="#">服务条款</a>
              <a class="text-[#617c89] text-base font-normal leading-normal min-w-40" href="#">联系我们</a>
            </div>
            <p class="text-[#617c89] text-base font-normal leading-normal">© 2023 Chatly。保留所有权利。</p>
          </footer>
        </div>
      </footer>
    </div>
  </div>
</template>

<script setup>
const mobileDownloads = [
  {
    label: '下载 iOS 版',
    subLabel: 'App Store 安装',
    href: '#'
  },
  {
    label: '下载 Android 版',
    subLabel: '应用商店 / APK 包',
    href: '#'
  }
]

const desktopDownloads = [
  {
    label: '下载 Windows 版',
    subLabel: '适配 Windows 7 及以上',
    href: '#'
  },
  {
    label: '下载 macOS 版 (Intel)',
    subLabel: 'x64 处理器专用安装包',
    href: '#'
  },
  {
    label: '下载 macOS 版 (Apple 芯片)',
    subLabel: '适配 Apple Silicon (M 系列)',
    href: '#'
  }
]

useHead({
  title: 'Chatly',
  link: [
    {
      rel: 'preconnect',
      href: 'https://fonts.gstatic.com/',
      crossorigin: ''
    },
    {
      rel: 'stylesheet',
      href: 'https://fonts.googleapis.com/css2?display=swap&family=Noto+Sans:wght@400;500;700;900&family=Space+Grotesk:wght@400;500;700'
    }
  ]
})
</script>

<style scoped>
.page-shell {
  background:
    radial-gradient(circle at top right, rgba(19, 164, 236, 0.15), transparent 45%),
    radial-gradient(circle at 20% 20%, rgba(94, 202, 248, 0.2), transparent 40%),
    #f5f8fb;
}

.page-shell::before,
.page-shell::after {
  content: '';
  position: fixed;
  width: 520px;
  height: 520px;
  pointer-events: none;
  background: radial-gradient(circle, rgba(19, 164, 236, 0.12), transparent 60%);
  filter: blur(60px);
  animation: float 18s ease-in-out infinite;
  z-index: 0;
}

.page-shell::before {
  top: -140px;
  right: -120px;
}

.page-shell::after {
  width: 400px;
  height: 400px;
  bottom: -120px;
  left: -80px;
  background: radial-gradient(circle, rgba(17, 22, 24, 0.12), transparent 60%);
  animation-duration: 22s;
  animation-delay: 4s;
}

@keyframes float {
  0% {
    transform: translate3d(0, 0, 0) scale(1);
  }
  50% {
    transform: translate3d(20px, -30px, 0) scale(1.08);
  }
  100% {
    transform: translate3d(-10px, 10px, 0) scale(1);
  }
}
</style>
