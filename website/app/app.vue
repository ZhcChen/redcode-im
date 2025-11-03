<template>
  <div
    class="relative flex h-auto min-h-screen w-full flex-col bg-white group/design-root overflow-x-hidden"
    style='font-family: "Space Grotesk", "Noto Sans", sans-serif;'
  >
    <div class="layout-container flex h-full grow flex-col">
      <header class="flex items-center justify-between whitespace-nowrap border-b border-solid border-b-[#f0f3f4] px-10 py-3">
        <div class="flex items-center gap-4 text-[#111618]">
          <div class="size-4">
            <svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M24 4H6V17.3333V30.6667H24V44H42V30.6667V17.3333H24V4Z"
                fill="currentColor"
              />
            </svg>
          </div>
          <h2 class="text-[#111618] text-lg font-bold leading-tight tracking-[-0.015em]">即时通</h2>
        </div>
        <div class="flex flex-1 justify-end gap-8">
          <div class="flex items-center gap-9">
            <a class="text-[#111618] text-sm font-medium leading-normal" href="#">功能</a>
            <a class="text-[#111618] text-sm font-medium leading-normal" href="#">支持</a>
          </div>
          <button
            class="flex min-w-[84px] max-w-[480px] cursor-pointer items-center justify-center overflow-hidden rounded-xl h-10 px-4 bg-[#13a4ec] text-white text-sm font-bold leading-normal tracking-[0.015em]"
          >
            <span class="truncate">下载</span>
          </button>
        </div>
      </header>

      <div class="px-40 flex flex-1 justify-center py-5">
        <div class="layout-content-container flex flex-col max-w-[960px] flex-1">
          <div class="@container">
            <div class="@[480px]:p-4">
              <div
                class="flex min-h-[480px] flex-col gap-6 bg-cover bg-center bg-no-repeat @[480px]:gap-8 @[480px]:rounded-xl items-center justify-center p-4"
                :style="{
                  backgroundImage: `linear-gradient(rgba(0, 0, 0, 0.1) 0%, rgba(0, 0, 0, 0.4) 100%), url('https://lh3.googleusercontent.com/aida-public/AB6AXuAdh1y3LMLnfPmOUIy3XlbstCsn9NWdcPUxPjof996Az5CQE7CG_lkWO0JghDDZboScdNrONcwon85uZwyPmrwrD2YGlIJcnmXKXTg9XyUBli1-yCb3arjHiBAOgF_cG1vpTwfEzW1DsJKwU7wx3qj8GrNhLNr9Y6soRH0dMLDUtiLGy-xiIY8_RCwO-RUOesGRplMLrRGdAJH76U74y-tpxdhv7SOsGHcIM1ZU4x8kuRqBKFE0FrkOfiWQ9JxDYi2iJkFh2s37vPYw')`
                }"
              >
                <div class="flex flex-col gap-2 text-center">
                  <h1
                    class="text-white text-4xl font-black leading-tight tracking-[-0.033em] @[480px]:text-5xl @[480px]:font-black @[480px]:leading-tight @[480px]:tracking-[-0.033em]"
                  >
                    即时通：为每个人打造的即时通讯
                  </h1>
                  <h2
                    class="text-white text-sm font-normal leading-normal @[480px]:text-base @[480px]:font-normal @[480px]:leading-normal"
                  >
                    体验即时通带来的无缝沟通。与朋友、家人和同事即时连接，跨越所有设备。
                  </h2>
                </div>
                <button
                  class="flex min-w-[84px] max-w-[480px] cursor-pointer items-center justify-center overflow-hidden rounded-xl h-10 px-4 @[480px]:h-12 @[480px]:px-5 bg-[#13a4ec] text-white text-sm font-bold leading-normal tracking-[0.015em] @[480px]:text-base @[480px]:font-bold @[480px]:leading-normal @[480px]:tracking-[0.015em]"
                >
                  <span class="truncate">立即下载</span>
                </button>
              </div>
            </div>
          </div>

          <h2 class="text-[#111618] text-[22px] font-bold leading-tight tracking-[-0.015em] px-4 pb-3 pt-5">
            核心功能
          </h2>

          <div class="flex flex-col gap-10 px-4 py-10 @container">
            <div class="flex flex-col gap-4">
              <h1
                class="text-[#111618] tracking-light text-[32px] font-bold leading-tight @[480px]:text-4xl @[480px]:font-black @[480px]:leading-tight @[480px]:tracking-[-0.033em] max-w-[720px]"
              >
                即时通功能
              </h1>
              <p class="text-[#111618] text-base font-normal leading-normal max-w-[720px]">
                即时通提供一系列旨在增强您的沟通体验的功能。
              </p>
            </div>

            <div class="grid grid-cols-[repeat(auto-fit,minmax(158px,1fr))] gap-3 p-0">
              <div class="flex flex-1 gap-3 rounded-lg border border-[#dbe2e6] bg-white p-4 flex-col">
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
                    使用即时通的闪电般快速的消息服务，即时发送和接收消息。
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

              <div class="flex flex-1 gap-3 rounded-lg border border-[#dbe2e6] bg-white p-4 flex-col">
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
                    通过适用于Windows和macOS的本地应用程序在桌面上保持连接。
                  </p>
                </div>
              </div>

              <div class="flex flex-1 gap-3 rounded-lg border border-[#dbe2e6] bg-white p-4 flex-col">
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

          <h2 class="text-[#111618] text-[22px] font-bold leading-tight tracking-[-0.015em] px-4 pb-3 pt-5">
            下载即时通
          </h2>

          <div class="flex justify-center">
            <div class="flex flex-1 gap-3 flex-wrap px-4 py-3 max-w-[480px] justify-center">
              <button
                class="flex min-w-[84px] max-w-[480px] cursor-pointer items-center justify-center overflow-hidden rounded-xl h-10 px-4 bg-[#13a4ec] text-white text-sm font-bold leading-normal tracking-[0.015em] grow"
              >
                <span class="truncate">下载 iOS 版</span>
              </button>
              <button
                class="flex min-w-[84px] max-w-[480px] cursor-pointer items-center justify-center overflow-hidden rounded-xl h-10 px-4 bg-[#13a4ec] text-white text-sm font-bold leading-normal tracking-[0.015em] grow"
              >
                <span class="truncate">下载 Android 版</span>
              </button>
            </div>
          </div>

          <div class="flex justify-center">
            <div class="flex flex-1 gap-3 flex-wrap px-4 py-3 max-w-[480px] justify-center">
              <button
                class="flex min-w-[84px] max-w-[480px] cursor-pointer items-center justify-center overflow-hidden rounded-xl h-10 px-4 bg-[#13a4ec] text-white text-sm font-bold leading-normal tracking-[0.015em] grow"
              >
                <span class="truncate">下载 Windows 版</span>
              </button>
              <button
                class="flex min-w-[84px] max-w-[480px] cursor-pointer items-center justify-center overflow-hidden rounded-xl h-10 px-4 bg-[#13a4ec] text-white text-sm font-bold leading-normal tracking-[0.015em] grow"
              >
                <span class="truncate">下载 macOS 版</span>
              </button>
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
            <p class="text-[#617c89] text-base font-normal leading-normal">© 2023 即时通。保留所有权利。</p>
          </footer>
        </div>
      </footer>
    </div>
  </div>
</template>

<script setup>
useHead({
  title: '即时通',
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
