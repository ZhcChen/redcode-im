(function bootstrapIMPrototype() {
  const source = window.RedcodeIMPrototypeData;
  const root = document.getElementById("app");
  const STORAGE_KEY = "redcode-im-ui-prototype/design-source-v2";
  const DEVICE_FRAMES = {
    "iphone-12-pro": {
      label: "iPhone 12 Pro",
    },
    "pixel-8-pro": {
      label: "Pixel 8 Pro",
    },
  };

  if (!source || !root) {
    return;
  }

  const data = JSON.parse(JSON.stringify(source));
  const state = {
    theme: "light",
    density: "regular",
    deviceFrame: "iphone-12-pro",
    activeChatId: data.chats[0] ? data.chats[0].id : null,
    activeContactId: data.contacts[0] ? data.contacts[0].id : null,
    activeGroupId: data.groups[0] ? data.groups[0].id : null,
    activeSpecTab: "components",
    chatFilter: "",
    contactFilter: "",
    friendSearch: "",
    friendNote: "你好，我想一起评审 RedCode IM 的移动端重构方案。",
    searchQuery: "",
    groupMemberFilter: "",
    createGroupName: "移动端重构评审群",
    createGroupMembers: new Set(["u_alice", "u_zoe"]),
    chatDrafts: {},
    composerPanel: null,
    highlightMessageId: null,
    recentMessageId: null,
    navigationStack: [],
    pendingNavigationPath: null,
    toasts: [],
    orderCursor: 1000,
  };

  const toneClassMap = {
    amber: "avatar--amber",
    mint: "avatar--mint",
    violet: "avatar--violet",
  };

  const iconPaths = {
    chats: [
      '<path d="M7.65 19.25 4.8 20.1l.9-2.75A8.3 8.3 0 1 1 19.5 14.55a8.3 8.3 0 0 1-11.85 4.7Z" />',
      '<path d="M8.35 10.35h7.3" />',
      '<path d="M8.35 13.75h4.7" />',
    ],
    contacts: [
      '<circle cx="8.95" cy="8.2" r="2.8" />',
      '<circle cx="16.65" cy="9.1" r="2.1" />',
      '<path d="M4.6 18.55c.65-2.68 2.47-4.15 4.4-4.15 2.05 0 3.88 1.47 4.5 4.15" />',
      '<path d="M14.35 15.2c1.8.02 3.2.92 3.98 2.7" />',
    ],
    discover: [
      '<circle cx="12" cy="12" r="8.1" />',
      '<path d="m14.9 9.1-1.72 3.98-3.98 1.72 1.72-3.98L14.9 9.1Z" />',
    ],
    profile: [
      '<circle cx="12" cy="8.1" r="3.35" />',
      '<path d="M5.45 19.25c.78-3.32 3.13-5.1 6.55-5.1s5.77 1.78 6.55 5.1" />',
    ],
    settings: [
      '<path d="M12.22 3.25h-.44a1.8 1.8 0 0 0-1.8 1.8v.37c0 .64-.34 1.22-.9 1.54l-.32.18a1.8 1.8 0 0 1-1.8 0l-.32-.18a1.8 1.8 0 0 0-2.46.66l-.22.38a1.8 1.8 0 0 0 .66 2.46l.32.19c.56.32.9.9.9 1.54v.36c0 .64-.34 1.22-.9 1.54l-.32.19a1.8 1.8 0 0 0-.66 2.46l.22.38a1.8 1.8 0 0 0 2.46.66l.32-.18a1.8 1.8 0 0 1 1.8 0l.32.18c.56.32.9.9.9 1.54v.37a1.8 1.8 0 0 0 1.8 1.8h.44a1.8 1.8 0 0 0 1.8-1.8v-.37c0-.64.34-1.22.9-1.54l.32-.18a1.8 1.8 0 0 1 1.8 0l.32.18a1.8 1.8 0 0 0 2.46-.66l.22-.38a1.8 1.8 0 0 0-.66-2.46l-.32-.19a1.8 1.8 0 0 1-.9-1.54v-.36c0-.64.34-1.22.9-1.54l.32-.19a1.8 1.8 0 0 0 .66-2.46l-.22-.38a1.8 1.8 0 0 0-2.46-.66l-.32.18a1.8 1.8 0 0 1-1.8 0l-.32-.18a1.8 1.8 0 0 1-.9-1.54v-.37a1.8 1.8 0 0 0-1.8-1.8Z" />',
      '<circle cx="12" cy="12" r="3.1" />',
    ],
    shield: [
      '<path d="M12 3.9 18.1 6.2v4.38c0 4.03-2.28 7.16-6.1 9.02-3.82-1.86-6.1-4.99-6.1-9.02V6.2L12 3.9Z" />',
      '<path d="m9.1 11.9 1.85 1.85 4.1-4.12" />',
    ],
    back: [
      '<path d="M14.9 6.5L8.75 12l6.15 5.5" />',
      '<path d="M9.15 12H19" />',
    ],
    chevronRight: ['<path d="m9.25 5.5 6.5 6.5-6.5 6.5" />'],
    search: [
      '<circle cx="10.7" cy="10.7" r="4.95" />',
      '<path d="M14.35 14.35 18.65 18.65" />',
    ],
    plus: [
      '<path d="M12 5.75v12.5" />',
      '<path d="M5.75 12h12.5" />',
    ],
    emoji: [
      '<circle cx="12" cy="12" r="7.2" />',
      '<path d="M9.15 10.3h.01" />',
      '<path d="M14.85 10.3h.01" />',
      '<path d="M8.95 13.9c.74 1.13 1.8 1.7 3.05 1.7 1.25 0 2.31-.57 3.05-1.7" />',
    ],
    more: [
      '<circle cx="6.9" cy="12" r="1.2" />',
      '<circle cx="12" cy="12" r="1.2" />',
      '<circle cx="17.1" cy="12" r="1.2" />',
    ],
    send: [
      '<path d="M4.95 11.75 18.95 5.7c.45-.19.92.2.78.67l-3.15 11.3c-.12.45-.7.57-.98.19l-3.08-4.07" />',
      '<path d="M4.95 11.75 12.55 13.95" />',
      '<path d="M12.55 13.95 18.2 8.65" />',
      '<path d="M12.55 13.95 11.4 18.2" />',
    ],
    moments: [
      '<rect x="4.9" y="5.3" width="14.2" height="13.4" rx="3.3" />',
      '<path d="M7.65 14.5 10.25 11.95l2.2 2.1 3.95-4.05 2.2 2.3" />',
      '<circle cx="9.15" cy="9.15" r="1.15" />',
    ],
    scan: [
      '<path d="M7.45 5.5H5.8A1.8 1.8 0 0 0 4 7.3v1.65" />',
      '<path d="M16.55 5.5h1.65A1.8 1.8 0 0 1 20 7.3v1.65" />',
      '<path d="M7.45 18.5H5.8A1.8 1.8 0 0 1 4 16.7v-1.65" />',
      '<path d="M16.55 18.5h1.65a1.8 1.8 0 0 0 1.8-1.8v-1.65" />',
      '<path d="M7.15 12h9.7" />',
      '<path d="M8.9 8.8h6.2" />',
      '<path d="M8.9 15.2h6.2" />',
    ],
    nearby: [
      '<path d="M12 19.35c3.2-3.35 4.8-5.94 4.8-7.82A4.8 4.8 0 0 0 12 6.7a4.8 4.8 0 0 0-4.8 4.83c0 1.88 1.6 4.47 4.8 7.82Z" />',
      '<circle cx="12" cy="11.55" r="1.9" />',
    ],
    games: [
      '<path d="M8.1 9.15h7.8c2.28 0 3.95 1.65 3.95 3.92 0 2.3-1.52 4.18-3.45 4.18-1.22 0-1.98-.57-2.75-1.55l-.65-.8h-1l-.65.8c-.77.98-1.53 1.55-2.75 1.55-1.93 0-3.45-1.88-3.45-4.18 0-2.27 1.67-3.92 3.95-3.92Z" />',
      '<path d="M8.55 12.2h3.05" />',
      '<path d="M10.1 10.65v3.05" />',
      '<circle cx="15.7" cy="11.2" r="0.9" />',
      '<circle cx="17.55" cy="13.05" r="0.9" />',
    ],
  };

  let toastTimerId = 0;

  initializeChats();
  hydrateUiState();
  applyBodyState();

  if (!window.location.hash) {
    window.location.hash = "#/entry";
  }

  window.addEventListener("hashchange", () => {
    const path = currentPath();
    if (state.pendingNavigationPath === path) {
      state.pendingNavigationPath = null;
    } else {
      reconcileNavigationStack(path);
    }
    const route = parseRoute(path);
    syncSelection(route);
    if (route.section !== "chat-detail") {
      state.composerPanel = null;
    }
    render();
  });

  let resizeRenderTimer = 0;
  window.addEventListener("resize", () => {
    window.clearTimeout(resizeRenderTimer);
    resizeRenderTimer = window.setTimeout(render, 120);
  });

  root.addEventListener("click", handleClick);
  root.addEventListener("input", handleInput);
  root.addEventListener("change", handleChange);
  root.addEventListener("submit", handleSubmit);

  render();

  function initializeChats() {
    data.chats.forEach((chat, index) => {
      chat.sortKey = 1000 - index;
    });
    state.orderCursor = 2000;
  }

  function hydrateUiState() {
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      if (!raw) {
        data.settings.theme = state.theme;
        data.settings.density = state.density;
        return;
      }

      const persisted = JSON.parse(raw);
      if (persisted.theme === "light" || persisted.theme === "dark") {
        state.theme = persisted.theme;
      }
      if (["regular", "mid", "compact"].includes(persisted.density)) {
        state.density = persisted.density;
      }
      if (isSupportedDeviceFrame(persisted.deviceFrame)) {
        state.deviceFrame = persisted.deviceFrame;
      }
      if (persisted.notifications && typeof persisted.notifications === "object") {
        Object.assign(data.settings.notifications, persisted.notifications);
      }
      if (persisted.privacy && typeof persisted.privacy === "object") {
        Object.assign(data.settings.privacy, persisted.privacy);
      }
      data.settings.theme = state.theme;
      data.settings.density = state.density;
    } catch (error) {
      console.warn("Failed to hydrate prototype UI state.", error);
    }
  }

  function persistUiState() {
    try {
      window.localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({
          theme: state.theme,
          density: state.density,
          deviceFrame: state.deviceFrame,
          notifications: data.settings.notifications,
          privacy: data.settings.privacy,
        }),
      );
    } catch (error) {
      console.warn("Failed to persist prototype UI state.", error);
    }
  }

  function applyBodyState() {
    document.body.dataset.theme = state.theme;
    document.body.dataset.density = state.density;
  }

  function isSupportedDeviceFrame(value) {
    return Object.prototype.hasOwnProperty.call(DEVICE_FRAMES, value);
  }

  function currentPath() {
    const hash = window.location.hash.replace(/^#/, "").trim();
    return hash || "/entry";
  }

  function parseRoute(path) {
    const segments = path.split("/").filter(Boolean);

    if (segments.length === 0 || segments[0] === "entry") {
      return { section: "entry" };
    }

    if (segments[0] === "spec") {
      return { section: "spec" };
    }

    if (segments[0] === "pc-design") {
      return { section: "pc-design" };
    }

    if (segments[0] === "mobile-design") {
      const previewSegments = segments.slice(1);
      const previewPath = previewSegments.length ? `/${previewSegments.join("/")}` : "/chats";
      const nestedRoute = parseRoute(previewPath);
      const previewRoute = ["entry", "spec", "pc-design", "mobile-design", "not-found"].includes(nestedRoute.section)
        ? { section: "chats" }
        : nestedRoute;

      return {
        section: "mobile-design",
        previewPath: previewRoute === nestedRoute ? previewPath : "/chats",
        previewRoute,
      };
    }

    if (segments[0] === "auth") {
      return { section: "auth", subview: segments[1] || "login" };
    }

    if (segments[0] === "chats") {
      return { section: "chats" };
    }

    if (segments[0] === "chat") {
      return { section: "chat-detail", chatId: segments[1] || state.activeChatId };
    }

    if (segments[0] === "contacts") {
      if (segments[1] === "requests") {
        return { section: "contact-requests" };
      }
      if (segments[1] === "add") {
        return { section: "contact-add" };
      }
      if (segments[1] === "profile") {
        return { section: "contact-profile", contactId: segments[2] || state.activeContactId };
      }
      return { section: "contacts" };
    }

    if (segments[0] === "discover") {
      if (segments[1] === "moments") {
        return { section: "discover-moments" };
      }
      if (segments[1] === "scan") {
        return { section: "discover-scan" };
      }
      if (segments[1] === "nearby") {
        return { section: "discover-nearby" };
      }
      if (segments[1] === "games") {
        return { section: "discover-games" };
      }
      return { section: "discover" };
    }

    if (segments[0] === "groups") {
      if (segments[1] === "create") {
        return { section: "group-create" };
      }
      if (segments[1] === "settings") {
        return { section: "group-settings", groupId: segments[2] || state.activeGroupId };
      }
      return { section: "groups" };
    }

    if (segments[0] === "search") {
      return { section: "search" };
    }

    if (segments[0] === "lab") {
      return { section: "lab", moduleId: segments[1] || null };
    }

    if (segments[0] === "mine") {
      if (segments[1] === "profile") {
        return { section: "settings-detail", settingsSection: "profile" };
      }
      return { section: "mine" };
    }

    if (segments[0] === "settings") {
      if (segments[1]) {
        return { section: "settings-detail", settingsSection: segments[1] };
      }
      return { section: "settings" };
    }

    return { section: "not-found", path };
  }

  function renderIcon(name, className, label) {
    const paths = iconPaths[name] || iconPaths.search;
    const classes = ["ui-icon", className].filter(Boolean).join(" ");
    const aria = label ? `role="img" aria-label="${escapeHtml(label)}"` : 'aria-hidden="true"';

    return `
      <span class="${classes}" ${aria}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round">
          ${paths.join("")}
        </svg>
      </span>
    `;
  }

  function renderRowChevron() {
    return `<span class="runtime-row-chevron">${renderIcon("chevronRight", "runtime-row-chevron__glyph")}</span>`;
  }

  function isWideStageRoute(route) {
    return route.section === "entry" || route.section === "spec" || route.section === "pc-design" || route.section === "not-found";
  }

  function isMobileUiSection(section) {
    return [
      "mobile-design",
      "auth",
      "chats",
      "chat-detail",
      "contacts",
      "contact-requests",
      "contact-add",
      "contact-profile",
      "discover",
      "discover-moments",
      "discover-scan",
      "discover-nearby",
      "discover-games",
      "groups",
      "group-create",
      "group-settings",
      "search",
      "lab",
      "mine",
      "settings",
      "settings-detail",
    ].includes(section);
  }

  function resolveMobilePreviewRoute(route) {
    return route.section === "mobile-design" && route.previewRoute ? route.previewRoute : route;
  }

  function syncSelection(route) {
    const selectedRoute = resolveMobilePreviewRoute(route);
    if (selectedRoute.chatId && findChat(selectedRoute.chatId)) {
      state.activeChatId = selectedRoute.chatId;
    }
    if (selectedRoute.contactId && findContact(selectedRoute.contactId)) {
      state.activeContactId = selectedRoute.contactId;
    }
    if (selectedRoute.groupId && findGroup(selectedRoute.groupId)) {
      state.activeGroupId = selectedRoute.groupId;
    }
  }

  function isDesignSourceRoutePath(path) {
    return ["/entry", "/spec", "/pc-design", "/mobile-design"].includes(path);
  }

  function resolveBackFallbackPath(path) {
    const route = parseRoute(currentPath());
    if (route.section === "mobile-design" && isDesignSourceRoutePath(path)) {
      return "/chats";
    }
    return path;
  }

  function reconcileNavigationStack(path) {
    const index = state.navigationStack.lastIndexOf(path);
    state.navigationStack = index >= 0 ? state.navigationStack.slice(0, index) : [];
  }

  function resolveNavigationPath(path) {
    const requestedPath = path && path.startsWith("/") ? path : `/${path || "entry"}`;
    const currentRoute = parseRoute(currentPath());

    if (currentRoute.section !== "mobile-design") {
      return requestedPath;
    }

    if (
      requestedPath === "/entry" ||
      requestedPath === "/spec" ||
      requestedPath === "/pc-design" ||
      requestedPath.startsWith("/mobile-design")
    ) {
      return requestedPath;
    }

    return `/mobile-design${requestedPath}`;
  }

  function navigate(path, options = {}) {
    const nextPath = resolveNavigationPath(path);
    const current = currentPath();
    if (!options.keepHighlight) {
      state.highlightMessageId = null;
    }
    if (current === nextPath) {
      render();
      return;
    }
    if (options.resetNavigationStack) {
      state.navigationStack = [];
    } else if (options.trackNavigation !== false) {
      state.navigationStack.push(current);
      state.navigationStack = state.navigationStack.slice(-24);
    }
    state.pendingNavigationPath = nextPath;
    window.location.hash = `#${nextPath}`;
  }

  function navigateBack(fallbackPath) {
    let previousPath = state.navigationStack.pop();
    const route = parseRoute(currentPath());
    if (route.section === "mobile-design" && (!previousPath || !previousPath.startsWith("/mobile-design"))) {
      previousPath = null;
    }
    navigate(previousPath || resolveBackFallbackPath(fallbackPath) || "/chats", { trackNavigation: false });
  }

  function isReviewOnlyRoute(route) {
    return ["entry", "spec", "pc-design", "mobile-design"].includes(route.section);
  }

  function resolvePreviewMode(route) {
    const requested = new URLSearchParams(window.location.search).get("mode");
    if (requested === "review" || requested === "app") {
      return requested;
    }
    if (isReviewOnlyRoute(route)) {
      return "review";
    }
    return window.matchMedia("(max-width: 640px)").matches ? "app" : "review";
  }

  function render() {
    applyBodyState();
    const route = parseRoute(currentPath());
    syncSelection(route);
    const mobilePreviewMode = route.section === "mobile-design";
    const previewMode = mobilePreviewMode ? "device" : resolvePreviewMode(route);
    const runtimeMode = !mobilePreviewMode && previewMode === "app" && !isReviewOnlyRoute(route);
    const wideStage = !runtimeMode && !mobilePreviewMode && isWideStageRoute(route);
    const showPrototypeToolbar = !runtimeMode && !mobilePreviewMode && route.section !== "entry" && route.section !== "spec";
    const fullBleedStage = route.section === "spec";
    const specWorkspace = route.section === "spec";

    root.innerHTML = `
      <div class="prototype-shell ${specWorkspace ? "prototype-shell--spec" : ""} ${runtimeMode ? "prototype-shell--app" : ""} ${mobilePreviewMode ? "prototype-shell--mobile-preview" : ""}" data-preview-mode="${previewMode}">
        ${showPrototypeToolbar ? renderPrototypeToolbar(route) : ""}
        <main class="prototype-main ${wideStage ? "prototype-main--wide" : ""} ${specWorkspace ? "prototype-main--spec" : ""} ${runtimeMode ? "prototype-main--app" : ""} ${mobilePreviewMode ? "prototype-main--mobile-preview" : ""}">
          <div class="prototype-stage ${wideStage ? "prototype-stage--wide" : ""} ${fullBleedStage ? "prototype-stage--bleed" : ""} ${mobilePreviewMode ? "prototype-stage--mobile-preview" : ""}">
            ${renderStage(route, { runtimeMode, mobilePreviewMode })}
          </div>
          ${runtimeMode || mobilePreviewMode ? "" : renderRouteReview(route)}
        </main>
      </div>
      ${mobilePreviewMode ? "" : renderToasts()}
    `;
  }

  function renderPrototypeToolbar(route) {
    const system = data.designSystem;
    const shortcuts = [
      {
        label: "入口",
        route: "/entry",
        active: route.section === "entry",
      },
      {
        label: "规范",
        route: "/spec",
        active: route.section === "spec",
      },
      {
        label: "PC 设计",
        route: "/pc-design",
        active: route.section === "pc-design",
      },
      {
        label: "移动 UI",
        route: "/mobile-design",
        active: isMobileUiSection(route.section),
      },
    ];

    return `
      <header class="prototype-toolbar">
        <div class="prototype-toolbar__brand">
          <span class="prototype-toolbar__eyebrow">2.0 Design Source</span>
          <div>
            <h1>RedCode IM 2.0 UI 设计源</h1>
            <p>先把规范、PC 端与移动端三层入口收敛到同一个 HTML 设计源，再映射 Flutter 正式实现。</p>
          </div>
          <div class="prototype-toolbar__meta">
            ${system.priorities
              .map(
                (item) => `
                  <span class="meta-pill">
                    <strong>${escapeHtml(item.label)}</strong>
                    <span>${escapeHtml(item.title)}</span>
                  </span>
                `,
              )
              .join("")}
          </div>
        </div>
        <div class="prototype-toolbar__controls">
          <div class="toolbar-block">
            <span class="toolbar-label">快速跳转</span>
            <div class="segmented segmented--toolbar">
              ${shortcuts
                .map(
                  (item) => `
                    <button
                      class="segmented__item ${item.active ? "is-active" : ""}"
                      data-action="navigate"
                      data-route="${item.route}"
                    >
                      ${escapeHtml(item.label)}
                    </button>
                  `,
                )
                .join("")}
            </div>
          </div>
          <div class="toolbar-inline">
            <div class="toolbar-block">
              <span class="toolbar-label">主题</span>
              <div class="segmented">
                ${renderThemeButton("light", "浅色")}
                ${renderThemeButton("dark", "深色")}
              </div>
            </div>
            <div class="toolbar-block">
              <span class="toolbar-label">密度</span>
              <div class="segmented">
                ${renderDensityButton("regular", "2K")}
                ${renderDensityButton("mid", "1.5K")}
                ${renderDensityButton("compact", "1K")}
              </div>
            </div>
          </div>
        </div>
      </header>
    `;
  }

  function renderThemeButton(value, label) {
    return `
      <button
        class="segmented__item ${state.theme === value ? "is-active" : ""}"
        data-action="set-theme"
        data-theme="${value}"
      >
        ${label}
      </button>
    `;
  }

  function renderDensityButton(value, label) {
    return `
      <button
        class="segmented__item ${state.density === value ? "is-active" : ""}"
        data-action="set-density"
        data-density="${value}"
      >
        ${label}
      </button>
    `;
  }

  function renderStage(route, options = {}) {
    if (route.section === "entry") {
      return renderEntryStage();
    }
    if (route.section === "spec") {
      return renderSpecScreen();
    }
    if (route.section === "pc-design") {
      return renderPCDesignStage();
    }
    if (route.section === "mobile-design") {
      return renderMobileDesignScreen(route);
    }
    if (route.section === "not-found") {
      return renderBrokenRouteStage(route);
    }
    return renderPhone(route, options);
  }

  function renderEntryStage() {
    const system = data.designSystem;

    return `
      <section class="design-hub" aria-label="设计源总入口">
        <div class="design-hub__grid">
          ${system.entryCards.map((item, index) => renderEntryCard(item, index)).join("")}
        </div>
      </section>
    `;
  }

  function renderPCDesignStage() {
    const system = data.designSystem;
    const activeChat = findChat(state.activeChatId) || sortedChats()[0];
    const group = activeChat ? findGroupByChatId(activeChat.id) : null;
    const desktopChats = sortedChats().slice(0, 4);
    const files = activeChat && activeChat.files ? activeChat.files.slice(0, 3) : [];

    return `
      <section class="desktop-stage" aria-label="PC 端设计画布">
        <section class="surface-card desktop-stage__hero">
          <div>
            <span class="eyebrow">Desktop Blueprint</span>
            <h2>桌面端不是把手机页横向放大，而是重组为安静的工作台。</h2>
            <p>${escapeHtml(system.desktopBlueprint.thesis)}</p>
          </div>
          <div class="inline-actions">
            <button class="ghost-button" data-action="navigate" data-route="/spec">查看规范</button>
            <button class="primary-button" data-action="navigate" data-route="/mobile-design">回到移动端</button>
          </div>
        </section>

        <section class="desktop-canvas">
          <div class="desktop-app">
            <aside class="desktop-nav">
              <div class="desktop-nav__brand">
                <span>RC</span>
                <strong>RedCode IM</strong>
              </div>
              <div class="desktop-nav__items">
                <div class="desktop-nav__item is-active">聊天</div>
                <div class="desktop-nav__item">联系人</div>
                <div class="desktop-nav__item">发现</div>
                <div class="desktop-nav__item">我的</div>
              </div>
              <div class="desktop-nav__meta">
                <span class="badge">AMD64 构建</span>
                <span class="badge">${escapeHtml(densityLabel(state.density))}</span>
              </div>
            </aside>

            <aside class="desktop-pane desktop-pane--list">
              <div class="desktop-pane__header">
                <div>
                  <strong>会话</strong>
                  <span>未读与分组集中收纳</span>
                </div>
                <button class="ghost-button ghost-button--small" data-action="navigate" data-route="/chats">看手机链路</button>
              </div>
              <div class="desktop-conversation-list">
                ${desktopChats
                  .map(
                    (chat) => `
                      <button
                        class="desktop-conversation ${activeChat && chat.id === activeChat.id ? "is-active" : ""}"
                        data-action="set-desktop-chat"
                        data-chat-id="${chat.id}"
                      >
                        ${renderAvatar(chat.name, chat.avatarTone, "avatar--sm")}
                        <span class="desktop-conversation__body">
                          <strong>${escapeHtml(chat.name)}</strong>
                          <span>${escapeHtml(chat.lastMessage)}</span>
                        </span>
                        <span class="badge ${chat.unread ? "badge--danger" : ""}">${chat.unread || chat.lastTime}</span>
                      </button>
                    `,
                  )
                  .join("")}
              </div>
            </aside>

            <section class="desktop-chat-pane">
              <div class="desktop-chat-pane__header">
                <div>
                  <strong>${escapeHtml(activeChat ? activeChat.name : "会话预览")}</strong>
                  <span>${escapeHtml(group ? `${group.memberCount} 位成员 · 在线 ${group.onlineCount}` : activeChat ? activeChat.description : "桌面消息工作台")}</span>
                </div>
                <div class="chip-row">
                  <span class="chip chip--filled">主消息流</span>
                  <span class="chip">底部输入区</span>
                  <span class="chip">右侧资料栏</span>
                </div>
              </div>
              <div class="desktop-chat-surface">
                ${(activeChat && activeChat.messages ? activeChat.messages : [])
                  .slice(0, 4)
                  .map(
                    (message) => `
                      <div class="desktop-chat-bubble ${message.self ? "desktop-chat-bubble--self" : ""}">
                        <strong>${escapeHtml(message.senderName)}</strong>
                        <p>${escapeHtml(message.content)}</p>
                      </div>
                    `,
                  )
                  .join("")}
              </div>
              <div class="composer composer--preview desktop-composer-preview">
                <div class="composer__inner">
                  <button class="icon-button icon-button--soft" disabled type="button">
                    ${renderIcon("emoji", "icon-button__glyph", "表情")}
                  </button>
                  <div class="composer__field composer__field--preview">
                    <span>桌面端继续保留单底部输入区，不把附件、资料和成员操作塞进同一层。</span>
                  </div>
                  <button class="icon-button icon-button--soft" disabled type="button">
                    ${renderIcon("plus", "icon-button__glyph", "更多")}
                  </button>
                  <button class="primary-button primary-button--small" disabled type="button">发送</button>
                </div>
              </div>
            </section>

            <aside class="desktop-pane desktop-pane--inspector">
              <div class="desktop-pane__header">
                <div>
                  <strong>上下文侧栏</strong>
                  <span>只在需要时展开，不抢主消息层级</span>
                </div>
              </div>
              <div class="desktop-info-stack">
                <section class="surface-block">
                  <p class="section-title">结构分区</p>
                  <div class="desktop-chip-list">
                    ${system.desktopBlueprint.columns
                      .map((item) => `<span class="page-map__item">${escapeHtml(item.title)}</span>`)
                      .join("")}
                  </div>
                </section>
                <section class="surface-block">
                  <p class="section-title">共享文件</p>
                  <ul class="bullet-list">
                    ${files.length
                      ? files
                          .map((file) => `<li>${escapeHtml(file.name)} · ${escapeHtml(file.type)}</li>`)
                          .join("")
                      : "<li>当前会话暂无文件 mock。</li>"}
                  </ul>
                </section>
                <section class="surface-block">
                  <p class="section-title">桌面约束</p>
                  <ul class="bullet-list">
                    ${system.desktopBlueprint.rules
                      .map((item) => `<li>${escapeHtml(item)}</li>`)
                      .join("")}
                  </ul>
                </section>
              </div>
            </aside>
          </div>
        </section>

        <div class="design-note-grid">
          ${system.desktopBlueprint.columns
            .map(
              (item) => `
                <article class="summary-tile">
                  <span class="summary-tile__label">Desktop Zone</span>
                  <strong>${escapeHtml(item.title)}</strong>
                  <p>${escapeHtml(item.summary)}</p>
                </article>
              `,
            )
            .join("")}
        </div>
      </section>
    `;
  }

  function renderBrokenRouteStage(route) {
    return `
      <section class="design-hub" aria-label="无效路由提示">
        <section class="surface-card design-hub__hero">
          <span class="eyebrow">Route Fallback</span>
          <h2>当前 hash 没有对应页面</h2>
          <p>检测到未注册路由：<code>${escapeHtml(route.path || "/")}</code>。这里不再静默跳回首页，避免把错误导航误判成成功渲染。</p>
          <div class="inline-actions">
            <button class="primary-button" data-action="navigate" data-route="/entry">回到总入口</button>
            <button class="ghost-button" data-action="navigate" data-route="/spec">查看规范页</button>
            <button class="ghost-button" data-action="navigate" data-route="/mobile-design">查看移动端入口</button>
          </div>
        </section>
      </section>
    `;
  }

  function renderMobileDesignScreen(route) {
    const previewRoute = resolveMobilePreviewRoute(route);

    return `
      <section class="mobile-preview-canvas" aria-label="RedCode IM 移动端预览">
        <div class="mobile-preview-device-switcher" role="group" aria-label="设备外壳选择">
          ${Object.entries(DEVICE_FRAMES)
            .map(
              ([id, device]) => `
                <button
                  class="mobile-preview-device-switcher__item ${state.deviceFrame === id ? "is-active" : ""}"
                  type="button"
                  data-action="set-device-frame"
                  data-device-frame="${id}"
                  aria-pressed="${state.deviceFrame === id}"
                >
                  <span class="mobile-preview-device-switcher__glyph mobile-preview-device-switcher__glyph--${id}" aria-hidden="true"></span>
                  <span>${escapeHtml(device.label)}</span>
                </button>
              `,
            )
            .join("")}
        </div>
        ${renderPhone(previewRoute, { devicePreview: true })}
      </section>
    `;
  }

  function renderPhone(route, options = {}) {
    const screenClasses = [
      "phone-screen",
      options.runtimeMode ? "phone-screen--runtime" : "",
      options.devicePreview ? "phone-screen--preview" : "",
    ]
      .filter(Boolean)
      .join(" ");
    const screen = `
      <div class="${screenClasses}">
        ${options.runtimeMode ? "" : `
          <div class="phone-status-bar">
            <span>9:41</span>
            <span>5G · 87%</span>
          </div>
        `}
        ${renderRoute(route)}
        ${renderTabBar(route)}
        ${options.devicePreview ? renderToasts({ embedded: true }) : ""}
      </div>
    `;

    if (options.runtimeMode) {
      return `<section class="mobile-runtime" aria-label="移动端应用预览">${screen}</section>`;
    }

    if (options.devicePreview) {
      const deviceId = isSupportedDeviceFrame(state.deviceFrame) ? state.deviceFrame : "iphone-12-pro";
      const device = DEVICE_FRAMES[deviceId];

      return `
        <section
          class="phone-frame phone-frame--mobile-preview phone-frame--${deviceId}"
          data-device-frame="${deviceId}"
          aria-label="${escapeHtml(device.label)} 设备预览画布"
        >
          <span class="phone-frame__side-button phone-frame__side-button--action" aria-hidden="true"></span>
          <span class="phone-frame__side-button phone-frame__side-button--volume-up" aria-hidden="true"></span>
          <span class="phone-frame__side-button phone-frame__side-button--volume-down" aria-hidden="true"></span>
          <span class="phone-frame__side-button phone-frame__side-button--power" aria-hidden="true"></span>
          <div class="phone-frame__screen-clip">
            ${screen}
          </div>
          <span class="phone-frame__earpiece" aria-hidden="true"></span>
          <span class="phone-frame__sensor" aria-hidden="true"></span>
        </section>
      `;
    }

    return `
      <section class="phone-frame" aria-label="移动端原型画布">
        <div class="phone-frame__notch"></div>
        ${screen}
      </section>
    `;
  }

  function renderMobileNavPreview(activeId) {
    return `
      <div class="mobile-nav-preview">
        ${data.designSystem.mobileBlueprint.routes
          .map(
            (item) => `
              <span class="mobile-nav-preview__item ${item.id === activeId ? "is-active" : ""}">
                ${renderIcon(item.icon, "mobile-nav-preview__icon", item.title)}
                <span class="mobile-nav-preview__label">${escapeHtml(item.title)}</span>
                <span class="mobile-nav-preview__hint">${escapeHtml(item.hint)}</span>
              </span>
            `,
          )
          .join("")}
      </div>
    `;
  }

  function renderTabBar(route) {
    const items = data.designSystem.mobileBlueprint.routes;

    if (!["chats", "contacts", "discover", "mine"].includes(route.section)) {
      return "";
    }

    return `
      <nav class="runtime-tab-bar" aria-label="底部主导航">
        <div class="runtime-tab-bar__items">
        ${items
          .map((item) => {
            const active = route.section === item.id;
            return `
              <button
                class="runtime-tab-bar__item ${active ? "is-active" : ""}"
                data-action="navigate"
                data-route="${item.route}"
              >
                <span class="runtime-tab-bar__icon">${renderIcon(item.icon, "runtime-tab-bar__glyph", item.title)}</span>
                <span class="runtime-tab-bar__label">${escapeHtml(item.title)}</span>
              </button>
            `;
          })
          .join("")}
        </div>
      </nav>
    `;
  }

  function renderRoute(route) {
    if (route.section === "spec") {
      return renderSpecScreen();
    }
    if (route.section === "auth") {
      return renderAuthScreen(route);
    }
    if (route.section === "chats") {
      return renderChatListScreen();
    }
    if (route.section === "chat-detail") {
      return renderChatDetailScreen(route.chatId);
    }
    if (route.section === "contacts") {
      return renderContactsScreen();
    }
    if (route.section === "discover") {
      return renderDiscoverScreen();
    }
    if (route.section === "discover-moments") {
      return renderDiscoverMomentsScreen();
    }
    if (route.section === "discover-scan") {
      return renderDiscoverScanScreen();
    }
    if (route.section === "discover-nearby") {
      return renderDiscoverNearbyScreen();
    }
    if (route.section === "discover-games") {
      return renderDiscoverGamesScreen();
    }
    if (route.section === "contact-requests") {
      return renderFriendRequestsScreen();
    }
    if (route.section === "contact-add") {
      return renderAddFriendScreen();
    }
    if (route.section === "contact-profile") {
      return renderContactProfileScreen(route.contactId);
    }
    if (route.section === "groups") {
      return renderGroupsScreen();
    }
    if (route.section === "group-create") {
      return renderCreateGroupScreen();
    }
    if (route.section === "group-settings") {
      return renderGroupSettingsScreen(route.groupId);
    }
    if (route.section === "search") {
      return renderSearchScreen();
    }
    if (route.section === "lab") {
      return route.moduleId ? renderLabDetailScreen(route.moduleId) : renderLabOverviewScreen();
    }
    if (route.section === "mine") {
      return renderMineScreen();
    }
    if (route.section === "settings") {
      return renderSettingsScreen();
    }
    if (route.section === "settings-detail") {
      return renderSettingsDetailScreen(route.settingsSection);
    }
    return renderSpecScreen();
  }

  function renderScreenHeader(options) {
    const fallbackPath = options.backPath ? resolveBackFallbackPath(options.backPath) : null;
    const backButton = fallbackPath
      ? `
        <button
          class="icon-button"
          data-action="go-back"
          data-fallback-route="${escapeHtml(fallbackPath)}"
          aria-label="返回"
        >
          ${renderIcon("back", "icon-button__glyph", "返回")}
        </button>
      `
      : "";

    const actions = options.actions && options.actions.length
      ? `<div class="screen-header__actions">${options.actions.join("")}</div>`
      : "";

    return `
      <header class="screen-header runtime-header ${options.root ? "screen-header--root" : ""}">
        ${backButton}
        <div class="screen-header__main">
          <h2>${escapeHtml(options.title)}</h2>
          ${options.subtitle ? `<p>${escapeHtml(options.subtitle)}</p>` : ""}
        </div>
        ${actions}
      </header>
    `;
  }

  function renderEntryCard(item, index) {
    const iconMap = {
      spec: "规",
      pc: "桌",
      mobile: "移",
    };

    return `
      <article class="entry-card">
        <div class="entry-card__top">
          <span class="badge">入口 0${index + 1}</span>
          <span class="entry-card__eyebrow">${escapeHtml(item.eyebrow)}</span>
        </div>
        <span class="entry-card__icon">${iconMap[item.id] || "R"}</span>
        <h3>${escapeHtml(item.title)}</h3>
        <p>${escapeHtml(item.summary)}</p>
        <ul class="entry-card__list">
          ${item.bullets.map((bullet) => `<li>${escapeHtml(bullet)}</li>`).join("")}
        </ul>
        <button class="primary-button" data-action="navigate" data-route="${item.route}">进入 ${escapeHtml(item.title)}</button>
      </article>
    `;
  }

  function renderIconSpecGroup(group) {
    return `
      <section class="surface-card">
        <div class="surface-card__header">
          <h3>${escapeHtml(group.title)}</h3>
          <span class="badge">Icon Group</span>
        </div>
        <p class="surface-caption">${escapeHtml(group.note)}</p>
        <div class="icon-spec-grid">
          ${group.items
            .map(
              (item) => `
                <article class="icon-spec-card">
                  ${renderIcon(item.icon, "icon-spec-card__glyph", item.label)}
                  <div class="icon-spec-card__copy">
                    <strong>${escapeHtml(item.label)}</strong>
                    <span>${escapeHtml(item.usage)}</span>
                  </div>
                  <span class="icon-spec-card__token">icon.${escapeHtml(item.icon)}</span>
                </article>
              `,
            )
            .join("")}
        </div>
      </section>
    `;
  }

  function renderComponentInventoryCard(item) {
    return `
      <article class="component-inventory-card">
        <span class="section-title">Component</span>
        <strong>${escapeHtml(item.title)}</strong>
        <p>${escapeHtml(item.summary)}</p>
        <div class="component-state-list">
          ${item.states
            .map((stateItem) => `<span class="component-state-pill">${escapeHtml(stateItem)}</span>`)
            .join("")}
        </div>
        <div class="component-inventory-card__footer">
          <span>Flutter 映射</span>
          <code>${escapeHtml(item.flutter)}</code>
        </div>
      </article>
    `;
  }

  function renderShellPreview() {
    return `
      <div class="shell-preview">
        <div class="shell-preview__status">
          <span>9:41</span>
          <span>5G · 87%</span>
        </div>
        <div class="shell-preview__bar">
          <div class="shell-preview__bar-copy">
            <strong>聊天</strong>
            <span>Root App Bar · Safe Area</span>
          </div>
          <span class="badge">Shell</span>
        </div>
        <div class="shell-preview__body">
          <div class="shell-preview__surface">
            <span class="chip chip--filled">内容优先</span>
            <span class="chip">单列节奏</span>
          </div>
          <div class="shell-preview__row">
            <span class="shell-preview__marker"></span>
            <div>
              <strong>滚动主区</strong>
              <span>一级页保留单滚动主体，信息不分裂。</span>
            </div>
          </div>
          <div class="shell-preview__row shell-preview__row--muted">
            <span class="shell-preview__marker"></span>
            <div>
              <strong>详情承载</strong>
              <span>返回、搜索、群设置都下沉二级，不和根页争层级。</span>
            </div>
          </div>
        </div>
        <div class="shell-preview__nav">
          ${renderMobileNavPreview("chats")}
        </div>
      </div>
    `;
  }

  function renderComponentShowcase(chat, contact) {
    return `
      <div class="component-showcase-grid">
        <div class="preview-surface preview-surface--shell">
          <p class="section-title">App Shell + Tab Bar</p>
          ${renderShellPreview()}
          <p class="surface-caption">壳层只做四件事：Safe Area、Root App Bar、内容滚动区、稳定底栏。</p>
        </div>
        <div class="preview-surface">
          <p class="section-title">Search Box + Chip</p>
          <div class="search-box search-box--component-preview">
            <span>Context Search</span>
            <label class="search-box__field">
              ${renderIcon("search", "search-box__icon", "搜索")}
              <input class="search-box__input" value="发布节奏" readonly />
              <span class="badge">群聊内</span>
            </label>
          </div>
          <div class="chip-row">
            <span class="chip chip--filled">已选中</span>
            <span class="chip">弱标签</span>
            <span class="chip">可筛选</span>
          </div>
        </div>
        <div class="preview-surface">
          <p class="section-title">Button Set</p>
          <div class="button-preview-row">
            <button class="primary-button primary-button--small">继续</button>
            <button class="ghost-button ghost-button--small">稍后</button>
            <button class="icon-button icon-button--soft" type="button">
              ${renderIcon("plus", "icon-button__glyph", "新增")}
            </button>
            <button class="icon-button is-active" type="button">
              ${renderIcon("emoji", "icon-button__glyph", "表情")}
            </button>
          </div>
          <div class="button-preview-row">
            <button class="primary-button primary-button--small" disabled>处理中</button>
            <button class="ghost-button ghost-button--small" disabled>禁用态</button>
          </div>
        </div>
        <div class="preview-surface">
          <p class="section-title">会话卡片</p>
          <div class="list-card">
            ${renderConversationRow(chat)}
          </div>
        </div>
        <div class="preview-surface">
          <p class="section-title">消息气泡 + 输入区</p>
          <div class="mini-message-preview">
            ${renderMessageBubble(chat, chat.messages[0])}
            ${renderMessageBubble(chat, chat.messages[1])}
          </div>
          <div class="composer composer--preview">
            <div class="composer__inner">
              <button class="icon-button icon-button--soft" disabled type="button">
                ${renderIcon("emoji", "icon-button__glyph", "表情")}
              </button>
              <div class="composer__field composer__field--preview">
                <span>发送消息...</span>
              </div>
              <button class="icon-button icon-button--soft" disabled type="button">
                ${renderIcon("plus", "icon-button__glyph", "更多")}
              </button>
              <button class="primary-button primary-button--small" disabled type="button">发送</button>
            </div>
          </div>
          <p class="surface-caption">输入区先保证垂直居中、面板切换和发送态节奏，再扩语音、附件和更多动作。</p>
        </div>
        <div class="preview-surface">
          <p class="section-title">联系人 + 设置项</p>
          <div class="list-card">
            ${renderContactRow(contact)}
          </div>
          <div class="settings-list">
            ${renderMenuRow("账号与安全", "手机号、设备、密码与登录态", false)}
            ${renderMenuRow("聊天", "消息、字体、通知和存储偏好", false)}
          </div>
        </div>
        <div class="preview-surface">
          <p class="section-title">Empty State</p>
          ${renderEmptyState("暂无筛选结果", "空态也必须保持轻量说明和明确回路，不靠大插画撑场。")}
        </div>
      </div>
    `;
  }

  function activeSpecGroup() {
    const groups = data.designSystem.specGroups || [];
    return groups.find((item) => item.id === state.activeSpecTab) || groups[0] || {
      id: "components",
      title: "组件",
      eyebrow: "UI Kit",
      summary: "",
    };
  }

  function renderSpecNavItem(item, index) {
    return `
      <button
        class="spec-nav-item ${state.activeSpecTab === item.id ? "is-active" : ""}"
        data-action="set-spec-tab"
        data-tab="${item.id}"
      >
        <span class="spec-nav-item__index">0${index + 1}</span>
        <span class="spec-nav-item__body">
          <span class="spec-nav-item__eyebrow">${escapeHtml(item.eyebrow)}</span>
          <strong>${escapeHtml(item.title)}</strong>
          <span>${escapeHtml(item.summary)}</span>
        </span>
      </button>
    `;
  }

  function renderTypographyRamp() {
    const samples = [
      ["Display / 28", "RedCode IM 主标题", "用于规范页、首屏和一级视觉焦点。", "type-ramp__sample--display"],
      ["Headline / 22", "聊天详情标题", "用于一级页面标题和关键分组名称。", "type-ramp__sample--headline"],
      ["Body / 16", "这是一段标准正文，用于列表说明和核心描述。", "用于正文、输入区、表单和卡片主体。", "type-ramp__sample--body"],
      ["Caption / 12", "辅助说明与标签", "用于注释、时间、状态和弱层级信息。", "type-ramp__sample--caption"],
    ];

    return `
      <div class="type-ramp">
        ${samples
          .map(
            (item) => `
              <article class="type-ramp__item">
                <span class="type-ramp__meta">${escapeHtml(item[0])}</span>
                <strong class="type-ramp__sample ${item[3]}">${escapeHtml(item[1])}</strong>
                <p>${escapeHtml(item[2])}</p>
              </article>
            `,
          )
          .join("")}
      </div>
    `;
  }

  function renderInteractionStateBoard(compact) {
    const groups = data.designSystem.interactionStates || [];

    return `
      <div class="interaction-state-grid ${compact ? "interaction-state-grid--compact" : ""}">
        ${groups
          .map(
            (group) => `
              <article class="interaction-state-card">
                <div class="interaction-state-card__header">
                  <strong>${escapeHtml(group.title)}</strong>
                  <p>${escapeHtml(group.summary)}</p>
                </div>
                <div class="interaction-state-card__list">
                  ${group.items
                    .map(
                      (item) => `
                        <span class="interaction-state-pill interaction-state-pill--${escapeHtml(item.tone)}">
                          <strong>${escapeHtml(item.state)}</strong>
                          <span>${escapeHtml(item.detail)}</span>
                        </span>
                      `,
                    )
                    .join("")}
                </div>
              </article>
            `,
          )
          .join("")}
      </div>
    `;
  }

  function renderDensityCalibrationBoard(compact) {
    const items = data.designSystem.densityCalibration || [];

    return `
      <div class="density-calibration-grid ${compact ? "density-calibration-grid--compact" : ""}">
        ${items
          .map(
            (item) => `
              <article class="density-calibration-card">
                <div class="density-calibration-card__header">
                  <strong>${escapeHtml(item.label)}</strong>
                  <span>scale ${escapeHtml(item.scale)}</span>
                </div>
                <div class="density-calibration-card__metrics">
                  ${item.metrics
                    .map((metric) => `<span class="density-calibration-card__metric">${escapeHtml(metric)}</span>`)
                    .join("")}
                </div>
                <p>${escapeHtml(item.note)}</p>
              </article>
            `,
          )
          .join("")}
      </div>
    `;
  }

  function renderNavIconBlueprintBoard(compact) {
    const items = data.designSystem.navIconBlueprints || [];

    return `
      <div class="nav-icon-blueprint-grid ${compact ? "nav-icon-blueprint-grid--compact" : ""}">
        ${items
          .map(
            (item) => `
              <article class="nav-icon-blueprint-card ${item.id === "chats" ? "is-primary" : ""}">
                <div class="nav-icon-blueprint-card__top">
                  ${renderIcon(item.icon, "nav-icon-blueprint-card__glyph", item.title)}
                  <div class="nav-icon-blueprint-card__copy">
                    <strong>${escapeHtml(item.title)}</strong>
                    <span>${escapeHtml(item.hint)}</span>
                  </div>
                  <span class="badge">${escapeHtml(item.hotArea)}</span>
                </div>
                <div class="nav-icon-blueprint-card__meta">
                  <span class="nav-icon-blueprint-chip">${escapeHtml(item.emphasis)}</span>
                  <span class="nav-icon-blueprint-chip">${escapeHtml(item.stroke)}</span>
                </div>
                <p>${escapeHtml(item.note)}</p>
              </article>
            `,
          )
          .join("")}
      </div>
    `;
  }

  function renderPageBlueprintBoard(compact) {
    const items = data.designSystem.pageBlueprints || [];

    return `
      <div class="page-blueprint-grid ${compact ? "page-blueprint-grid--compact" : ""}">
        ${items
          .map(
            (item) => `
              <article class="page-blueprint-card">
                <div class="page-blueprint-card__header">
                  <div>
                    <span class="section-title">${escapeHtml(item.shell)}</span>
                    <strong>${escapeHtml(item.title)}</strong>
                  </div>
                  <span class="badge">${escapeHtml(item.routes.length)} Routes</span>
                </div>
                <p>${escapeHtml(item.summary)}</p>
                <div class="page-blueprint-card__stack">
                  <div class="page-blueprint-card__group">
                    <span class="section-title">页面分块</span>
                    <div class="page-blueprint-card__chips">
                      ${item.sections.map((section) => `<span class="page-map__item">${escapeHtml(section)}</span>`).join("")}
                    </div>
                  </div>
                  <div class="page-blueprint-card__group">
                    <span class="section-title">主动作</span>
                    <div class="page-blueprint-card__chips">
                      ${item.actions.map((action) => `<span class="chip">${escapeHtml(action)}</span>`).join("")}
                    </div>
                  </div>
                  <div class="page-blueprint-card__group">
                    <span class="section-title">共用组件</span>
                    <div class="page-blueprint-card__chips">
                      ${item.components.map((component) => `<span class="page-map__item">${escapeHtml(component)}</span>`).join("")}
                    </div>
                  </div>
                  <div class="page-blueprint-card__group">
                    <span class="section-title">路由</span>
                    <div class="page-blueprint-card__route-list">
                      ${item.routes.map((routeItem) => `<code>${escapeHtml(routeItem)}</code>`).join("")}
                    </div>
                  </div>
                  <div class="page-blueprint-card__group">
                    <span class="section-title">滚动策略</span>
                    <p class="surface-caption">${escapeHtml(item.scrolling)}</p>
                  </div>
                </div>
                <p class="surface-caption">${escapeHtml(item.note)}</p>
              </article>
            `,
          )
          .join("")}
      </div>
    `;
  }

  function renderRootPagePreviewCard(item) {
    let canvas = "";

    if (item.id === "chats") {
      canvas = `
        <div class="root-page-preview__toolbar">
          <span class="root-page-preview__title">消息 18</span>
          <span class="root-page-preview__meta">+ 建群</span>
        </div>
        <div class="root-page-preview__search">搜索会话 / 消息</div>
        <div class="root-page-preview__rows">
          <div class="root-page-preview__row is-accent">
            <span class="root-page-preview__avatar"></span>
            <div class="root-page-preview__lines">
              <span></span>
              <span></span>
            </div>
            <span class="root-page-preview__badge">3</span>
          </div>
          <div class="root-page-preview__row">
            <span class="root-page-preview__avatar"></span>
            <div class="root-page-preview__lines">
              <span></span>
              <span></span>
            </div>
          </div>
          <div class="root-page-preview__row">
            <span class="root-page-preview__avatar"></span>
            <div class="root-page-preview__lines">
              <span></span>
              <span></span>
            </div>
          </div>
        </div>
      `;
    } else if (item.id === "contacts") {
      canvas = `
        <div class="root-page-preview__toolbar">
          <span class="root-page-preview__title">联系人</span>
          <span class="root-page-preview__meta">新增</span>
        </div>
        <div class="root-page-preview__chips">
          <span>新的朋友</span>
          <span>群聊入口</span>
        </div>
        <div class="root-page-preview__rows">
          <div class="root-page-preview__row">
            <span class="root-page-preview__avatar"></span>
            <div class="root-page-preview__lines">
              <span></span>
              <span></span>
            </div>
          </div>
          <div class="root-page-preview__row">
            <span class="root-page-preview__avatar"></span>
            <div class="root-page-preview__lines">
              <span></span>
              <span></span>
            </div>
          </div>
        </div>
      `;
    } else if (item.id === "discover") {
      canvas = `
        <div class="root-page-preview__toolbar">
          <span class="root-page-preview__title">发现</span>
          <span class="root-page-preview__meta">内容</span>
        </div>
        <div class="root-page-preview__hero">
          <span>朋友圈 / 附近 / 游戏</span>
          <strong>四个入口统一分流</strong>
        </div>
        <div class="root-page-preview__grid">
          ${["朋友圈", "扫一扫", "附近的人", "游戏"]
            .map(
              (label) => `
                <span class="root-page-preview__tile">
                  <span class="root-page-preview__tile-dot"></span>
                  <strong>${escapeHtml(label)}</strong>
                </span>
              `,
            )
            .join("")}
        </div>
      `;
    } else {
      canvas = `
        <div class="root-page-preview__toolbar">
          <span class="root-page-preview__title">我的</span>
          <span class="root-page-preview__meta">账户</span>
        </div>
        <div class="root-page-preview__profile">
          <span class="root-page-preview__avatar root-page-preview__avatar--lg"></span>
          <div class="root-page-preview__lines">
            <span></span>
            <span></span>
          </div>
        </div>
        <div class="root-page-preview__setting-list">
          <div class="root-page-preview__setting-row"><span>账号与安全</span><span class="root-page-preview__chevron"></span></div>
          <div class="root-page-preview__setting-row"><span>设置</span><span class="root-page-preview__chevron"></span></div>
          <div class="root-page-preview__setting-row"><span>隐私协议</span><span class="root-page-preview__chevron"></span></div>
          <div class="root-page-preview__setting-row"><span>关于 RedCode IM</span><span class="root-page-preview__chevron"></span></div>
        </div>
      `;
    }

    return `
      <article class="root-page-preview-card root-page-preview-card--${item.id}">
        <div class="root-page-preview-card__header">
          <div>
            <span class="section-title">${escapeHtml(item.shell)}</span>
            <strong>${escapeHtml(item.title)}</strong>
          </div>
          <span class="badge">${escapeHtml(item.routes.length)} Routes</span>
        </div>
        <div class="root-page-preview-card__canvas">
          ${canvas}
        </div>
        <div class="root-page-preview-card__footer">
          ${item.components.slice(0, 4).map((component) => `<span class="chip">${escapeHtml(component)}</span>`).join("")}
        </div>
      </article>
    `;
  }

  function renderRootPagePreviewDeck() {
    const items = data.designSystem.pageBlueprints || [];

    return `
      <div class="root-page-preview-stack">
        ${items.map(renderRootPagePreviewCard).join("")}
      </div>
    `;
  }

  function renderFlowEntrySequence() {
    const primaryRoutes = data.designSystem.mobileBlueprint.routes || [];
    const secondaryRoutes = data.designSystem.mobileBlueprint.secondary || [];

    return `
      <section class="surface-card">
        <div class="surface-card__header">
          <h3>手机入口顺序</h3>
          <span class="badge">Mobile Order</span>
        </div>
        <div class="flow-board">
          ${primaryRoutes
            .map(
              (item, index) => `
                <div class="flow-step">
                  <span class="flow-step__index">0${index + 1}</span>
                  <div>
                    <strong>${escapeHtml(item.title)}</strong>
                    <p>${escapeHtml(item.note)}</p>
                  </div>
                </div>
              `,
            )
            .join("")}
        </div>
      </section>
      <section class="surface-card">
        <div class="surface-card__header">
          <h3>关键二级入口</h3>
          <span class="badge">Secondary</span>
        </div>
        <div class="quick-action-grid quick-action-grid--compact">
          ${secondaryRoutes
            .map(
              (item) => `
                <span class="quick-action-card quick-action-card--mini">
                  <strong>${escapeHtml(item.title)}</strong>
                  <span>${escapeHtml(item.note)}</span>
                </span>
              `,
            )
            .join("")}
        </div>
      </section>
    `;
  }

  function renderChatPageBlueprintBoard(compact) {
    const items = data.designSystem.chatPageSpec?.blueprints || [];

    return `
      <div class="page-blueprint-grid ${compact ? "page-blueprint-grid--compact" : ""}">
        ${items
          .map(
            (item) => `
              <article class="page-blueprint-card">
                <div class="page-blueprint-card__header">
                  <div>
                    <span class="section-title">${escapeHtml(item.shell)}</span>
                    <strong>${escapeHtml(item.title)}</strong>
                  </div>
                </div>
                <p>${escapeHtml(item.summary)}</p>
                <div class="page-blueprint-card__stack">
                  <div class="page-blueprint-card__group">
                    <span class="section-title">页面分块</span>
                    <div class="page-blueprint-card__chips">
                      ${item.sections.map((section) => `<span class="page-map__item">${escapeHtml(section)}</span>`).join("")}
                    </div>
                  </div>
                  <div class="page-blueprint-card__group">
                    <span class="section-title">主动作</span>
                    <div class="page-blueprint-card__chips">
                      ${item.actions.map((action) => `<span class="chip">${escapeHtml(action)}</span>`).join("")}
                    </div>
                  </div>
                  <div class="page-blueprint-card__group">
                    <span class="section-title">共用组件</span>
                    <div class="page-blueprint-card__chips">
                      ${item.components.map((component) => `<span class="page-map__item">${escapeHtml(component)}</span>`).join("")}
                    </div>
                  </div>
                  <div class="page-blueprint-card__group">
                    <span class="section-title">滚动策略</span>
                    <p class="surface-caption">${escapeHtml(item.scrolling)}</p>
                  </div>
                </div>
              </article>
            `,
          )
          .join("")}
      </div>
    `;
  }

  function renderChatFocusAreaBoard(compact) {
    const areas = data.designSystem.chatPageSpec?.focusAreas || [];

    return `
      <div class="chat-focus-grid ${compact ? "chat-focus-grid--compact" : ""}">
        ${areas
          .map(
            (item) => `
              <article class="chat-focus-card">
                <div class="chat-focus-card__header">
                  <strong>${escapeHtml(item.title)}</strong>
                  <p>${escapeHtml(item.target)}</p>
                </div>
                <div class="chat-focus-card__checks">
                  ${item.checks.map((check) => `<span class="page-map__item">${escapeHtml(check)}</span>`).join("")}
                </div>
                <div class="chat-focus-card__footer">
                  <span>Flutter handoff</span>
                  <code>${escapeHtml(item.handoff)}</code>
                </div>
              </article>
            `,
          )
          .join("")}
      </div>
    `;
  }

  function renderChatSignalMatrix(compact) {
    const signals = data.designSystem.chatPageSpec?.signalMatrix || [];

    return `
      <div class="chat-signal-grid ${compact ? "chat-signal-grid--compact" : ""}">
        ${signals
          .map(
            (item) => `
              <article class="chat-signal-card">
                <div class="chat-signal-card__header">
                  <strong>${escapeHtml(item[0])}</strong>
                  <span>${escapeHtml(item[1])}</span>
                </div>
                <p>${escapeHtml(item[2])}</p>
              </article>
            `,
          )
          .join("")}
      </div>
    `;
  }

  function renderChatInteractionSequence(compact) {
    const steps = data.designSystem.chatPageSpec?.interactionSequence || [];

    return `
      <div class="chat-sequence-board ${compact ? "chat-sequence-board--compact" : ""}">
        ${steps
          .map(
            (item) => `
              <article class="chat-sequence-step">
                <span class="chat-sequence-step__index">${escapeHtml(item[0])}</span>
                <div class="chat-sequence-step__body">
                  <strong>${escapeHtml(item[1])}</strong>
                  <p>${escapeHtml(item[2])}</p>
                </div>
              </article>
            `,
          )
          .join("")}
      </div>
    `;
  }

  function renderChatSpecActionGrid() {
    const actions = data.designSystem.chatPageSpec?.panelActions || [];

    return `
      <div class="chat-spec-action-grid">
        ${actions
          .map(
            (item) => `
              <article class="chat-spec-action-card">
                <strong>${escapeHtml(item[0])}</strong>
                <span>${escapeHtml(item[1])}</span>
              </article>
            `,
          )
          .join("")}
      </div>
    `;
  }

  function renderChatSpecPhoneDeck(chat) {
    const secondaryChat = sortedChats().find((item) => item.id !== chat.id) || chat;
    const previewMessages = chat.messages.slice(0, 3);
    const emojiSamples = ["😀", "😂", "🤝", "🔥", "✅", "🚀"];

    return `
      <div class="chat-spec-preview-stack">
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>会话列表</h3>
            <span class="badge">Root</span>
          </div>
          <div class="search-box search-box--component-preview chat-spec-search-preview">
            <span>Conversation Search</span>
            <label class="search-box__field">
              ${renderIcon("search", "search-box__icon", "搜索")}
              <input class="search-box__input" value="搜索会话 / 消息" readonly />
            </label>
          </div>
          <div class="list-card">
            ${renderConversationRow(chat)}
            ${renderConversationRow(secondaryChat)}
          </div>
        </section>

        <section class="surface-card">
          <div class="surface-card__header">
            <h3>聊天详情</h3>
            <span class="badge">Thread</span>
          </div>
          <section class="surface-banner surface-banner--subtle">
            <strong>Pinned 摘要</strong>
            <p>置顶摘要只在消息流上方轻量出现，不把资料信息抬成主层级。</p>
          </section>
          <div class="chat-spec-thread">
            ${previewMessages.map((message) => renderMessageBubble(chat, message)).join("")}
          </div>
        </section>

        <section class="surface-card">
          <div class="surface-card__header">
            <h3>输入区与面板</h3>
            <span class="badge">Composer</span>
          </div>
          <div class="chat-spec-composer-shell">
            <div class="composer composer--preview chat-spec-composer-preview">
              <div class="composer__inner">
                <button class="icon-button icon-button--soft is-active" disabled type="button">
                  ${renderIcon("emoji", "icon-button__glyph", "表情")}
                </button>
                <div class="composer__field composer__field--preview is-panel-active">
                  <span>发送消息...</span>
                </div>
                <button class="icon-button icon-button--soft" disabled type="button">
                  ${renderIcon("plus", "icon-button__glyph", "更多")}
                </button>
                <button class="primary-button primary-button--small" disabled type="button">发送</button>
              </div>
            </div>
            <div class="chat-spec-panel-grid">
              <article class="chat-spec-panel-card">
                <div class="composer-panel__header">
                  <strong>表情面板</strong>
                  <span>发送后仍留在当前面板，适合连续输入。</span>
                </div>
                <div class="emoji-grid">
                  ${emojiSamples.map((emoji) => `<span class="emoji-grid__item">${emoji}</span>`).join("")}
                </div>
              </article>
              <article class="chat-spec-panel-card">
                <div class="composer-panel__header">
                  <strong>更多面板</strong>
                  <span>图片、文件、拍摄和位置拆成独立动作位。</span>
                </div>
                <div class="quick-action-grid quick-action-grid--compact">
                  ${data.designSystem.chatPageSpec.panelActions
                    .map(
                      (item) => `
                        <span class="quick-action-card quick-action-card--mini chat-spec-action-chip">
                          <strong>${escapeHtml(item[0])}</strong>
                          <span>${escapeHtml(item[1])}</span>
                        </span>
                      `,
                    )
                    .join("")}
                </div>
              </article>
            </div>
          </div>
        </section>

        <section class="surface-card">
          <div class="surface-card__header">
            <h3>状态信号校准</h3>
            <span class="badge">Signals</span>
          </div>
          ${renderChatSignalMatrix(true)}
        </section>

        <section class="surface-card">
          <div class="surface-card__header">
            <h3>交互时序</h3>
            <span class="badge">Sequence</span>
          </div>
          ${renderChatInteractionSequence(true)}
        </section>
      </div>
    `;
  }

  function renderSpecPhoneContent(group) {
    const system = data.designSystem;
    const chat = sortedChats()[0];
    const contact = filteredContacts()[0] || data.contacts[0];

    if (group.id === "components") {
      return `
        <div class="screen-stack">
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>核心组件</h3>
              <span class="badge">UI Kit</span>
            </div>
            <div class="page-map page-map--dense">
              <span class="page-map__item">Cell / Row</span>
              <span class="page-map__item">Composer</span>
              <span class="page-map__item">Search Box</span>
              <span class="page-map__item">Button Set</span>
              <span class="page-map__item">Chip / Empty</span>
            </div>
          </section>
          ${renderComponentShowcase(chat, contact)}
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>交互状态</h3>
              <span class="badge">States</span>
            </div>
            ${renderInteractionStateBoard(true)}
          </section>
        </div>
      `;
    }

    if (group.id === "typography") {
      return `
        <div class="screen-stack">
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>字体分组</h3>
              <span class="badge">Typography</span>
            </div>
            ${renderTypographyRamp()}
          </section>
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>字体 Tokens</h3>
              <span class="badge">Type Stack</span>
            </div>
            <ul class="token-list">
              ${system.tokens.typography
                .map((item) => `<li><strong>${escapeHtml(item[0])}</strong><span>${escapeHtml(item[1])}</span></li>`)
                .join("")}
            </ul>
          </section>
        </div>
      `;
    }

    if (group.id === "colors") {
      return `
        <div class="screen-stack">
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>颜色分组</h3>
              <span class="badge">Color</span>
            </div>
            <div class="token-grid">
              ${system.tokens.colors
                .map(
                  (item) => `
                    <div class="token-card token-card--swatch">
                      <span class="swatch" style="background:${item[1]}"></span>
                      <strong>${escapeHtml(item[0])}</strong>
                      <span>${escapeHtml(item[1])}</span>
                    </div>
                  `,
                )
                .join("")}
            </div>
          </section>
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>颜色规则</h3>
              <span class="badge">Usage</span>
            </div>
            <ul class="bullet-list">
              <li>Primary / Strong 负责动作，Primary Soft / Ring 只用于选中底和 focus。</li>
              <li>正文层级由 Text Primary / Secondary / Tertiary 递减，不靠额外杂色区分。</li>
              <li>Danger / Success 只服务状态反馈，不扩散到装饰层。</li>
            </ul>
          </section>
        </div>
      `;
    }

    if (group.id === "icons") {
      return `
        <div class="screen-stack">
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>底部导航 Icon</h3>
              <span class="badge">Tab Bar</span>
            </div>
            ${renderNavIconBlueprintBoard(true)}
          </section>
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>底部导航预览</h3>
              <span class="badge">Active / Inactive</span>
            </div>
            ${renderMobileNavPreview("discover")}
          </section>
          ${system.iconLibrary.map(renderIconSpecGroup).join("")}
        </div>
      `;
    }

    if (group.id === "shell") {
      return `
        <div class="screen-stack">
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>移动端壳层</h3>
              <span class="badge">App Shell</span>
            </div>
            ${renderShellPreview()}
          </section>
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>底部导航</h3>
              <span class="badge">Stable Tab Bar</span>
            </div>
            ${renderMobileNavPreview("chats")}
            <p class="surface-caption">底部主导航固定为聊天 / 联系人 / 发现 / 我的四个一级入口。</p>
          </section>
        </div>
      `;
    }

    if (group.id === "chat-page") {
      return `
        <div class="screen-stack">
          ${renderChatSpecPhoneDeck(chat)}
        </div>
      `;
    }

    if (group.id === "flows") {
      return `
        <div class="screen-stack">
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>一级页面视觉稿</h3>
              <span class="badge">Root Views</span>
            </div>
            ${renderRootPagePreviewDeck()}
          </section>
          ${renderFlowEntrySequence()}
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>主链路顺序</h3>
              <span class="badge">Flow Map</span>
            </div>
            <div class="flow-board">
              <div class="flow-step">
                <span class="flow-step__index">01</span>
                <div>
                  <strong>先看规范</strong>
                  <p>颜色、字体、组件和密度先统一，再进入页面重构。</p>
                </div>
              </div>
              <div class="flow-step">
                <span class="flow-step__index">02</span>
                <div>
                  <strong>再看移动端</strong>
                  <p>聊天、联系人、发现、我的作为手机端唯一一级入口。</p>
                </div>
              </div>
              <div class="flow-step">
                <span class="flow-step__index">03</span>
                <div>
                  <strong>最后补桌面</strong>
                  <p>桌面只重组版式，不再回头污染手机信息架构。</p>
                </div>
              </div>
            </div>
          </section>
          <section class="surface-card">
            <div class="surface-card__header">
              <h3>页面地图</h3>
              <span class="badge">Routes</span>
            </div>
            <div class="page-map">
              ${system.pageTemplates
                .map((item) => `<span class="page-map__item">${escapeHtml(item)}</span>`)
                .join("")}
            </div>
          </section>
        </div>
      `;
    }

    return `
      <div class="screen-stack">
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>基础 Tokens</h3>
            <span class="badge">Foundation</span>
          </div>
          <div class="token-stack">
            ${system.tokens.spacing
              .filter((item) => item[0] !== "Density")
              .map(
                (item) => `
                  <div class="token-card">
                    <span class="section-title">${escapeHtml(item[0])}</span>
                    <strong>${escapeHtml(item[1])}</strong>
                  </div>
                `,
              )
              .join("")}
          </div>
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>密度档位</h3>
            <span class="badge">Density</span>
          </div>
          ${renderDensityCalibrationBoard(true)}
          <div class="density-preview density-preview--grid">
            ${system.densityBands
              .map(
                (item) => `
                  <article class="density-preview__item">
                    <strong>${escapeHtml(item.label)}</strong>
                    <span>scale ${escapeHtml(item.scale)}</span>
                    <p>${escapeHtml(item.title)} · ${escapeHtml(item.note)}</p>
                  </article>
                `,
              )
              .join("")}
          </div>
        </section>
      </div>
    `;
  }

  function renderSpecDetailRail(group) {
    const system = data.designSystem;

    if (group.id === "components") {
      return `
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>组件清单</h3>
            <span class="badge">Runtime</span>
          </div>
          <div class="component-inventory-grid spec-detail-grid">
            ${system.componentInventory.map(renderComponentInventoryCard).join("")}
          </div>
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>状态矩阵</h3>
            <span class="badge">States</span>
          </div>
          ${renderInteractionStateBoard(false)}
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>封装原则</h3>
            <span class="badge">Rules</span>
          </div>
          <ul class="bullet-list">
            ${system.componentRules.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}
          </ul>
        </section>
      `;
    }

    if (group.id === "typography") {
      return `
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>字体约束</h3>
            <span class="badge">Rules</span>
          </div>
          <ul class="bullet-list">
            <li>Display 只用于入口、规范和一级标题，不进入常规列表正文。</li>
            <li>业务页正文统一回到 UI 字体节奏，防止页面之间字号飘散。</li>
            <li>1K / 1.5K / 2K 的字号差异统一走密度 token，不允许页面局部手调。</li>
          </ul>
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>字体栈</h3>
            <span class="badge">Stack</span>
          </div>
          <ul class="token-list">
            ${system.tokens.typography
              .map((item) => `<li><strong>${escapeHtml(item[0])}</strong><span>${escapeHtml(item[1])}</span></li>`)
              .join("")}
          </ul>
        </section>
      `;
    }

    if (group.id === "colors") {
      return `
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>颜色清单</h3>
            <span class="badge">Semantic</span>
          </div>
          <div class="token-grid spec-detail-token-grid">
            ${system.tokens.colors
              .map(
                (item) => `
                  <div class="token-card token-card--swatch">
                    <span class="swatch" style="background:${item[1]}"></span>
                    <strong>${escapeHtml(item[0])}</strong>
                    <span>${escapeHtml(item[1])}</span>
                  </div>
                `,
              )
              .join("")}
          </div>
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>执行原则</h3>
            <span class="badge">Usage</span>
          </div>
          <ul class="bullet-list">
            <li>表面层、分隔线、文字层级优先靠 token 递减，不靠阴影硬堆层级。</li>
            <li>按钮激活态、导航激活态和 focus ring 共享同一套科技蓝语义。</li>
            <li>Danger / Success 只服务状态反馈，禁止扩大到装饰层。</li>
          </ul>
        </section>
      `;
    }

    if (group.id === "icons") {
      return `
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>底部导航细化</h3>
            <span class="badge">Tab Bar</span>
          </div>
          ${renderNavIconBlueprintBoard(false)}
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>Icon 规则</h3>
            <span class="badge">Hot Area</span>
          </div>
          <ul class="bullet-list">
            <li>导航、操作、发现三类 icon 全部保持轮廓风格一致。</li>
            <li>未来 Flutter 落地时统一进入同一 icon registry，不再页面私自引图。</li>
            <li>点击目标优先对齐 40-44dp，确保小屏设备触达稳定。</li>
          </ul>
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>关键 Key</h3>
            <span class="badge">Registry</span>
          </div>
          <div class="page-map">
            ${["chats", "contacts", "discover", "profile", "settings", "shield", "back", "search", "plus", "emoji", "more", "send"]
              .map((item) => `<span class="page-map__item">icon.${escapeHtml(item)}</span>`)
              .join("")}
          </div>
        </section>
      `;
    }

    if (group.id === "shell") {
      return `
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>壳层清单</h3>
            <span class="badge">Shell</span>
          </div>
          <div class="page-map">
            <span class="page-map__item">Safe Area</span>
            <span class="page-map__item">Status Bar</span>
            <span class="page-map__item">App Bar</span>
            <span class="page-map__item">Scroll Area</span>
            <span class="page-map__item">Tab Bar</span>
          </div>
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>壳层原则</h3>
            <span class="badge">Rules</span>
          </div>
          <ul class="bullet-list">
            <li>根页固定四个一级入口，详情、搜索、申请和群设置全部下沉二级。</li>
            <li>输入区、列表和导航共享同一密度体系，不能局部单独放大。</li>
            <li>桌面端复用同一语言，但只重组布局，不改手机信息架构。</li>
          </ul>
        </section>
      `;
    }

    if (group.id === "chat-page") {
      return `
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>聊天页蓝图</h3>
            <span class="badge">Blueprint</span>
          </div>
          ${renderChatPageBlueprintBoard(false)}
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>聊天页专项焦点</h3>
            <span class="badge">Focus</span>
          </div>
          ${renderChatFocusAreaBoard(false)}
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>关键状态</h3>
            <span class="badge">States</span>
          </div>
          <ul class="bullet-list">
            ${system.chatPageSpec.stateRules.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}
          </ul>
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>信号矩阵</h3>
            <span class="badge">Signals</span>
          </div>
          ${renderChatSignalMatrix(false)}
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>交互动效</h3>
            <span class="badge">Motion</span>
          </div>
          <ul class="bullet-list">
            ${system.chatPageSpec.motionRules.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}
          </ul>
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>交互时序</h3>
            <span class="badge">Sequence</span>
          </div>
          ${renderChatInteractionSequence(false)}
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>面板动作清单</h3>
            <span class="badge">Actions</span>
          </div>
          ${renderChatSpecActionGrid()}
        </section>
      `;
    }

    if (group.id === "flows") {
      return `
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>一级页面规范拆分</h3>
            <span class="badge">Blueprint</span>
          </div>
          ${renderPageBlueprintBoard(false)}
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>Flutter Handoff</h3>
            <span class="badge">Tracks</span>
          </div>
          <ul class="bullet-list">
            ${system.handoffTracks.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}
          </ul>
        </section>
        <section class="surface-card">
          <div class="surface-card__header">
            <h3>页面组</h3>
            <span class="badge">Map</span>
          </div>
          <div class="page-map-grid">
            ${system.pageGroups
              .map(
                (item) => `
                  <article class="page-map-card">
                    <span class="section-title">${escapeHtml(item.title)}</span>
                    <strong>${escapeHtml(item.items.join(" / "))}</strong>
                  </article>
                `,
              )
              .join("")}
          </div>
        </section>
      `;
    }

    return `
      <section class="surface-card">
        <div class="surface-card__header">
          <h3>基础约束</h3>
          <span class="badge">Foundation</span>
        </div>
        <ul class="token-list">
          ${system.tokens.spacing
            .map((item) => `<li><strong>${escapeHtml(item[0])}</strong><span>${escapeHtml(item[1])}</span></li>`)
            .join("")}
        </ul>
      </section>
      <section class="surface-card">
        <div class="surface-card__header">
          <h3>密度校准板</h3>
          <span class="badge">Scale</span>
        </div>
        ${renderDensityCalibrationBoard(false)}
      </section>
      <section class="surface-card">
        <div class="surface-card__header">
          <h3>执行说明</h3>
          <span class="badge">Rules</span>
        </div>
        <ul class="bullet-list">
          ${system.principles.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}
        </ul>
      </section>
    `;
  }

  function renderSpecSecondaryColumn(group) {
    return `
      <section class="spec-secondary-column" aria-label="${escapeHtml(group.title)} 二级列表内容">
        <section class="surface-card spec-secondary-column__intro">
          <span class="eyebrow">${escapeHtml(group.eyebrow)}</span>
          <h3>${escapeHtml(group.title)}</h3>
          <p>${escapeHtml(group.summary)}</p>
        </section>
        <div class="spec-secondary-column__list spec-scroll-area">
          ${renderSpecDetailRail(group)}
        </div>
      </section>
    `;
  }

  function renderSpecPreviewColumn(group) {
    return `
      <section class="surface-card spec-preview-column" aria-label="${escapeHtml(group.title)} 预览界面">
        <div class="spec-preview-column__meta">
          <span class="spec-preview-column__label">${escapeHtml(group.title)} · 实时预览</span>
          <div class="chip-row">
            <span class="chip chip--filled">${escapeHtml(group.eyebrow)}</span>
            <span class="chip">手机画布</span>
          </div>
        </div>
        <div class="spec-preview-column__body spec-scroll-area">
          <section class="phone-frame phone-frame--spec" aria-label="规范手机预览画布">
            <div class="phone-frame__notch"></div>
            <div class="phone-screen">
              <div class="phone-status-bar">
                <span>9:41</span>
                <span>5G · 87%</span>
              </div>
              <section class="screen screen--spec-preview">
                <header class="screen-header screen-header--root">
                  <div class="screen-header__main">
                    <h2>${escapeHtml(group.title)}</h2>
                    <p>${escapeHtml(group.eyebrow)} · 规范分组预览</p>
                  </div>
                  <div class="screen-header__actions">
                    <span class="badge">${escapeHtml(group.title)}</span>
                  </div>
                </header>
                <div class="screen-scroll screen-scroll--spec">
                  ${renderSpecPhoneContent(group)}
                </div>
              </section>
            </div>
          </section>
        </div>
      </section>
    `;
  }

  function renderSpecScreen() {
    const system = data.designSystem;
    const group = activeSpecGroup();

    return `
      <section class="spec-stage" aria-label="规范设计工作台">
        <aside class="surface-card spec-sidebar">
          <div class="spec-sidebar__group-list spec-scroll-area">
            ${system.specGroups.map(renderSpecNavItem).join("")}
          </div>
          <div class="spec-sidebar__aux">
            <div class="surface-block spec-sidebar__settings">
              <div class="spec-sidebar__settings-header">
                <p class="section-title">显示设置</p>
                <div class="chip-row">
                  <span class="chip chip--filled">${themeLabel(state.theme)}</span>
                  <span class="chip">${densityLabel(state.density)}</span>
                </div>
              </div>
              <div class="spec-setting-group">
                <span class="toolbar-label">主题</span>
                <div class="segmented segmented--fluid">
                  ${renderThemeButton("light", "浅色")}
                  ${renderThemeButton("dark", "深色")}
                </div>
              </div>
              <div class="spec-setting-group">
                <span class="toolbar-label">密度</span>
                <div class="segmented segmented--fluid">
                  ${renderDensityButton("regular", "2K")}
                  ${renderDensityButton("mid", "1.5K")}
                  ${renderDensityButton("compact", "1K")}
                </div>
              </div>
            </div>
          </div>
        </aside>

        ${renderSpecSecondaryColumn(group)}
        ${renderSpecPreviewColumn(group)}
      </section>
    `;
  }

  function renderAuthScreen() {
    return `
      <section class="screen screen--auth runtime-auth-screen">
        <div class="screen-scroll runtime-scroll runtime-auth-scroll">
          <div class="runtime-auth-brand">
            <span class="runtime-auth-brand__mark">R</span>
            <span>RedCode IM</span>
          </div>
          <div class="runtime-auth-copy">
            <h2>欢迎回来</h2>
            <p>登录后继续与你的朋友保持联系。</p>
          </div>
          <form class="runtime-auth-form" data-form="login-form">
            <label class="runtime-auth-field">
              <span>手机号</span>
              <input name="phone" inputmode="tel" autocomplete="tel" placeholder="请输入手机号" />
            </label>
            <label class="runtime-auth-field">
              <span>验证码</span>
              <input name="otp" inputmode="numeric" autocomplete="one-time-code" placeholder="请输入验证码" />
            </label>
            <button class="runtime-auth-submit" type="submit">登录</button>
          </form>
          <p class="runtime-auth-terms">登录即表示你已阅读并同意用户协议与隐私政策。</p>
        </div>
      </section>
    `;
  }

  function renderChatListScreen() {
    const chats = sortedChats();
    const pinnedChats = chats.filter((chat) => chat.pinned);
    const recentChats = chats.filter((chat) => !chat.pinned);

    return `
      <section class="screen screen--tabbed runtime-screen runtime-screen--list runtime-screen--chat-list">
        <div class="screen-scroll runtime-scroll">
          ${renderScreenHeader({
            title: "聊天",
            root: true,
            actions: [
              `<button class="runtime-icon-button" data-action="navigate" data-route="/search" aria-label="搜索消息">${renderIcon("search", "runtime-icon-button__glyph", "搜索")}</button>`,
              `<button class="runtime-icon-button" data-action="navigate" data-route="/groups/create" aria-label="创建群聊">${renderIcon("plus", "runtime-icon-button__glyph", "创建群聊")}</button>`,
            ],
          })}
          <div class="runtime-list-content">
            ${renderConversationSection("置顶", pinnedChats)}
            ${renderConversationSection(pinnedChats.length ? "全部消息" : "消息", recentChats)}
            ${chats.length ? "" : renderEmptyState("暂无会话", "从联系人中发起一段新对话。")}
          </div>
        </div>
      </section>
    `;
  }

  function renderConversationSection(title, chats) {
    if (!chats.length) {
      return "";
    }

    return `
      <section class="runtime-conversation-section">
        <div class="runtime-section-heading">
          <h3>${escapeHtml(title)}</h3>
        </div>
        <div class="runtime-conversation-list">
          ${chats.map((chat) => renderConversationRow(chat)).join("")}
        </div>
      </section>
    `;
  }

  function chatTypeLabel(chat) {
    return chat.type === "group" ? "群聊" : "私聊";
  }

  function chatSecondaryLabel(chat) {
    if (chat.type === "group") {
      const members = chat.metrics?.activeMembers || chat.participants?.length || 0;
      return `${members} 人活跃`;
    }
    if (chat.remark) {
      return chat.remark;
    }
    if (chat.muted) {
      return "静音会话";
    }
    return "直接沟通";
  }

  function renderConversationRow(chat) {
    const unread = chat.unread > 0 ? `<span class="runtime-unread-badge">${chat.unread}</span>` : "";
    const context = chat.pinned
      ? "置顶"
      : chat.metrics?.unreadMention
      ? `@我 ${chat.metrics.unreadMention}`
      : chat.muted
      ? "已静音"
      : chat.type === "group"
      ? "群聊"
      : "";
    const contextLabel = context ? `<span class="runtime-conversation__context">${escapeHtml(context)}</span>` : "";

    return `
      <button
        class="runtime-conversation"
        data-action="navigate"
        data-route="/chat/${chat.id}"
      >
        <span class="runtime-conversation__avatar">
          ${renderAvatar(chat.name, chat.avatarTone, "avatar--md")}
          <span class="runtime-conversation__presence ${chat.type === "group" ? "is-group" : chat.muted ? "is-muted" : "is-online"}"></span>
        </span>
        <span class="runtime-conversation__body">
          <strong>${escapeHtml(chat.name)}</strong>
          <span class="runtime-conversation__summary">
            ${contextLabel}
            <span class="runtime-conversation__summary-text">${escapeHtml(chat.lastMessage)}</span>
          </span>
        </span>
        <span class="runtime-conversation__meta">
          <time>${escapeHtml(chat.lastTime)}</time>
          ${unread}
        </span>
      </button>
    `;
  }

  function renderChatDetailScreen(chatId) {
    const chat = findChat(chatId);
    if (!chat) {
      return renderFallbackScreen("会话不存在", "/chats");
    }

    const group = findGroupByChatId(chat.id);
    const targetContact = chat.type === "single" ? findDirectContact(chat) : null;
    const draft = state.chatDrafts[chat.id] || "";
    const activePanel = state.composerPanel;
    const contextualNote = group?.notice || chat.pinnedMessages?.[0] || "";
    const contextualNoteAction = group
      ? `data-action="navigate" data-route="/groups/settings/${group.id}"`
      : `data-action="show-hint" data-message="${escapeHtml(contextualNote)}"`;

    return `
      <section class="screen screen--chat-detail runtime-chat-screen">
        ${renderScreenHeader({
          title: chat.name,
          subtitle: group
            ? `${group.memberCount} 位成员`
            : targetContact
            ? targetContact.status
            : "在线",
          backPath: "/chats",
          actions: [
            group
              ? `<button class="runtime-header-link" data-action="navigate" data-route="/groups/settings/${group.id}">群设置</button>`
              : targetContact
              ? `<button class="runtime-header-link" data-action="navigate" data-route="/contacts/profile/${targetContact.id}">资料</button>`
              : "",
          ].filter(Boolean),
        })}
        <div class="screen-scroll runtime-scroll runtime-chat-scroll">
          ${
            contextualNote
              ? `
                <button class="runtime-announcement" ${contextualNoteAction}>
                  <span class="runtime-announcement__label">${group ? "群公告" : "置顶消息"}</span>
                  <span class="runtime-announcement__text">${escapeHtml(contextualNote)}</span>
                  <span class="runtime-announcement__arrow">›</span>
                </button>
              `
              : ""
          }
          <div class="runtime-message-list">
            ${renderMessageTimeline(chat)}
          </div>
        </div>
        ${renderComposerPanel()}
        <form class="runtime-composer" data-form="send-message" data-chat-id="${chat.id}">
          <div class="runtime-composer__inner">
            <button
              class="runtime-composer__action ${activePanel === "emoji" ? "is-active" : ""}"
              type="button"
              data-action="toggle-composer-panel"
              data-panel="emoji"
              aria-label="表情"
            >
              ${renderIcon("emoji", "runtime-composer__glyph", "表情")}
            </button>
            <label class="runtime-composer__field ${draft.trim() ? "is-filled" : ""}">
              <textarea
                id="chat-draft-input"
                rows="1"
                placeholder="发消息"
                data-chat-id="${chat.id}"
              >${escapeHtml(draft)}</textarea>
            </label>
            <button
              class="runtime-composer__action ${activePanel === "more" ? "is-active" : ""}"
              type="button"
              data-action="toggle-composer-panel"
              data-panel="more"
              aria-label="更多操作"
            >
              ${renderIcon("plus", "runtime-composer__glyph", "更多操作")}
            </button>
            <button class="runtime-composer__send" type="submit" aria-label="发送消息">
              ${renderIcon("send", "runtime-composer__send-icon", "发送消息")}
            </button>
          </div>
        </form>
      </section>
    `;
  }

  function renderComposerPanel() {
    if (state.composerPanel === "emoji") {
      const emojis = ["😀", "😂", "🤝", "🔥", "✅", "🎯", "📎", "🚀", "👀", "💡", "👏", "🙌"];
      return `
        <section class="runtime-composer-panel runtime-composer-panel--emoji">
          <div class="runtime-composer-panel__header"><strong>表情</strong></div>
          <div class="emoji-grid">
            ${emojis
              .map(
                (emoji) => `
                  <button
                    class="emoji-grid__item"
                    type="button"
                    data-action="append-emoji"
                    data-emoji="${emoji}"
                    aria-label="${emoji}"
                  >
                    ${emoji}
                  </button>
                `,
              )
              .join("")}
          </div>
        </section>
      `;
    }

    if (state.composerPanel === "more") {
      const actions = [
        ["图片", "选择图片"],
        ["文件", "选择文件"],
        ["拍摄", "打开相机"],
        ["位置", "发送位置"],
      ];
      return `
        <section class="runtime-composer-panel runtime-composer-panel--actions">
          <div class="runtime-composer-panel__header"><strong>更多操作</strong></div>
          <div class="runtime-composer-actions">
            ${actions
              .map(
                (item) => `
                  <button class="runtime-composer-action-card" data-action="show-hint" data-message="${item[1]}">
                    <span>${item[0]}</span>
                  </button>
                `,
              )
              .join("")}
          </div>
        </section>
      `;
    }

    return "";
  }

  function renderMessageTimeline(chat) {
    let previousBucket = "";

    return chat.messages
      .map((message) => {
        const bucket = messageDayLabel(message.time);
        const divider = bucket !== previousBucket
          ? `
            <div class="message-day-divider">
              <span>${escapeHtml(bucket)}</span>
            </div>
          `
          : "";
        previousBucket = bucket;
        return `${divider}${renderMessageBubble(chat, message)}`;
      })
      .join("");
  }

  function messageDayLabel(time) {
    if (typeof time !== "string" || !time.trim()) {
      return "今天";
    }
    if (time.startsWith("昨天")) {
      return "昨天";
    }
    if (time.startsWith("前天")) {
      return "前天";
    }
    return "今天";
  }

  function renderMessageBubble(chat, message) {
    const isHighlighted = state.highlightMessageId === message.id;
    const isRecent = state.recentMessageId === message.id;
    const reactions = Array.isArray(message.reactions) && message.reactions.length
      ? `
        <div class="reaction-row">
          ${message.reactions
            .map((item) => `<span class="reaction-pill">${escapeHtml(item.emoji)} ${item.count}</span>`)
            .join("")}
        </div>
      `
      : "";

    return `
      <div class="message-row ${message.self ? "message-row--self" : ""}">
        ${message.self ? "" : renderAvatar(message.senderName, message.senderTone, "avatar--sm")}
        <div class="message-block ${message.self ? "message-block--self" : ""}">
          ${message.self ? "" : `<span class="message-sender">${escapeHtml(message.senderName)}</span>`}
          <div class="message-bubble ${message.self ? "message-bubble--self" : ""} ${isHighlighted ? "is-highlighted" : ""} ${isRecent ? "is-recent" : ""}">
            ${message.quote
              ? `
                <div class="message-quote">
                  <span class="message-quote__label">引用</span>
                  <p>${escapeHtml(message.quote)}</p>
                </div>
              `
              : ""}
            <p class="message-bubble__text">${escapeHtml(message.content)}</p>
          </div>
          ${reactions}
          <div class="message-meta">
            <span>${escapeHtml(message.time)}</span>
            ${message.self ? `<span>${escapeHtml(message.status || "已送达")}</span>` : ""}
          </div>
        </div>
      </div>
    `;
  }

  function renderContactsScreen() {
    const sections = groupContacts(filteredContacts());
    const pendingIncoming = data.friendRequests.filter(
      (item) => item.type === "incoming" && item.status === "pending",
    ).length;

    return `
      <section class="screen screen--tabbed runtime-screen runtime-screen--list">
        <div class="screen-scroll runtime-scroll">
          ${renderScreenHeader({
            title: "联系人",
            root: true,
            actions: [
              `<button class="runtime-icon-button" data-action="navigate" data-route="/contacts/add" aria-label="添加好友">${renderIcon("plus", "runtime-icon-button__glyph", "添加好友")}</button>`,
            ],
          })}
          <div class="runtime-list-content">
            <div class="runtime-contact-shortcuts">
              <button class="runtime-contact-shortcut" data-action="navigate" data-route="/contacts/requests">
                <span class="runtime-contact-shortcut__icon">${renderIcon("contacts", "runtime-contact-shortcut__glyph", "新的朋友")}</span>
                <span class="runtime-contact-shortcut__copy"><strong>新的朋友</strong><span>${pendingIncoming ? `${pendingIncoming} 条待处理` : "好友申请"}</span></span>
                ${pendingIncoming ? `<span class="runtime-unread-badge">${pendingIncoming}</span>` : ""}
              </button>
              <button class="runtime-contact-shortcut" data-action="navigate" data-route="/groups">
                <span class="runtime-contact-shortcut__icon">${renderIcon("chats", "runtime-contact-shortcut__glyph", "群聊")}</span>
                <span class="runtime-contact-shortcut__copy"><strong>群聊</strong><span>${data.groups.length} 个群聊</span></span>
                ${renderRowChevron()}
              </button>
            </div>
            <label class="runtime-search-field">
              ${renderIcon("search", "runtime-search-field__icon", "搜索联系人")}
              <input
                id="contact-filter-input"
                value="${escapeHtml(state.contactFilter)}"
                placeholder="搜索联系人"
                aria-label="搜索联系人"
              />
            </label>
            <div class="runtime-contact-directory">
              ${sections.length ? sections.map(renderContactSection).join("") : renderEmptyState("暂无联系人", "添加好友后会显示在这里。")}
            </div>
          </div>
        </div>
      </section>
    `;
  }

  function renderDiscoverScreen() {
    const discover = data.discover;
    const moments = discover.entries.find((item) => item.id === "moments") || discover.entries[0];
    const quickEntries = discover.entries.filter((item) => item.id !== moments.id);

    return `
      <section class="screen screen--tabbed runtime-screen runtime-screen--list runtime-discover-screen">
        <div class="screen-scroll runtime-scroll">
          <div class="runtime-list-content runtime-discover-content">
            <button class="runtime-moments-card" data-action="navigate" data-route="${moments.route}">
              <span class="runtime-moments-card__eyebrow">朋友圈</span>
              <strong>看看朋友最近的动态</strong>
              <span>${escapeHtml(moments.summary)}</span>
              <span class="runtime-moments-card__meta">${escapeHtml(moments.badge)} 条新动态 <b>›</b></span>
            </button>
            <section class="runtime-discover-grid" aria-label="发现功能">
              ${quickEntries.map(renderDiscoverEntryCard).join("")}
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderDiscoverEntryCard(item) {
    return `
      <button class="runtime-discover-card" data-action="navigate" data-route="${item.route}">
        <span class="runtime-discover-card__icon">${renderIcon(item.icon, "runtime-discover-card__glyph", item.title)}</span>
        <strong>${escapeHtml(item.title)}</strong>
        <span>${escapeHtml(item.badge)}</span>
      </button>
    `;
  }

  function renderDiscoverMomentsScreen() {
    return `
      <section class="screen">
        ${renderScreenHeader({
          title: "朋友圈",
          subtitle: "先用单列时间流验证内容型页面节奏",
          backPath: "/discover",
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <section class="hero-card hero-card--soft hero-card--moments">
              <span class="eyebrow">Moments Feed</span>
              <h3>朋友圈页只做内容流：作者、时间、正文、媒体与互动，不混入聊天操作。</h3>
              <div class="inline-actions inline-actions--wide">
                <button class="ghost-button" data-action="show-hint" data-message="后续这里可接发动态、图片选择与可见范围。">发一条动态</button>
                <button class="ghost-button" data-action="show-hint" data-message="后续这里可接仅朋友可见、分组可见和草稿箱。">可见范围</button>
              </div>
            </section>
            ${data.discover.moments.map(renderMomentCard).join("")}
          </div>
        </div>
      </section>
    `;
  }

  function renderMomentCard(item) {
    return `
      <article class="moment-card">
        <div class="moment-card__header">
          ${renderAvatar(item.author, item.tone, "avatar--md")}
          <div class="moment-card__meta">
            <strong>${escapeHtml(item.author)}</strong>
            <span>${escapeHtml(item.time)}</span>
          </div>
          <span class="badge">动态</span>
        </div>
        <p class="moment-card__text">${escapeHtml(item.text)}</p>
        <div class="moment-card__media">${escapeHtml(item.media)}</div>
        <div class="moment-card__stats">
          <span class="chip chip--filled">内容流</span>
          <span class="chip">${escapeHtml(item.media)}</span>
        </div>
        <div class="moment-card__footer">
          <span>赞 ${item.likes}</span>
          <span>评论 ${item.comments}</span>
          <span>查看详情 →</span>
        </div>
      </article>
    `;
  }

  function renderDiscoverScanScreen() {
    return `
      <section class="screen">
        ${renderScreenHeader({
          title: "扫一扫",
          subtitle: "扫码属于高频快捷入口，单独承载更合理",
          backPath: "/discover",
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <section class="scan-shell">
              <div class="scan-shell__header">
                <span class="eyebrow">Scan Gateway</span>
                <strong>把扫码动作单独抽出来，保证它是高频快捷入口。</strong>
              </div>
              <div class="scan-shell__frame">
                <div class="scan-shell__line"></div>
              </div>
              <p>后续可接加好友、进群、打开活动页、桌面端登录确认等二维码流程。</p>
            </section>
            <section class="quick-action-grid quick-action-grid--compact">
              ${[
                ["加好友", "扫个人二维码直接发起关系请求"],
                ["进群", "扫码加入活动群或协作群"],
                ["登录桌面端", "手机确认桌面登录动作"],
                ["活动页", "打开外部落地页或设备配网"],
              ]
                .map(
                  (item) => `
                    <button class="quick-action-card quick-action-card--mini" data-action="show-hint" data-message="${item[1]}">
                      <strong>${item[0]}</strong>
                      <span>${item[1]}</span>
                    </button>
                  `,
                )
                .join("")}
            </section>
            <section class="surface-card">
              <div class="surface-card__header">
                <div class="surface-card__header-copy">
                  <h3>扫码入口优先承载</h3>
                  <p>二维码是流程跳板，不应该被挤进其它页面做附属按钮。</p>
                </div>
                <span class="badge">Quick Action</span>
              </div>
              <ul class="bullet-list">
                <li>加好友二维码</li>
                <li>群邀请二维码</li>
                <li>桌面端登录确认</li>
                <li>活动页 / 设备配网等后续能力</li>
              </ul>
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderDiscoverNearbyScreen() {
    return `
      <section class="screen">
        ${renderScreenHeader({
          title: "附近的人",
          subtitle: "用于弱关系扩展和同城场景，不混入联系人主列表",
          backPath: "/discover",
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <section class="hero-card hero-card--soft hero-card--nearby">
              <span class="eyebrow">Nearby People</span>
              <h3>附近的人属于弱关系扩展页：看距离、场景和打招呼，不混进联系人主目录。</h3>
            </section>
            <section class="surface-card">
              <div class="surface-card__header">
                <div class="surface-card__header-copy">
                  <h3>附近在线</h3>
                  <p>先看距离和场景，再决定查看资料、发招呼或拉进同城群。</p>
                </div>
                <span class="badge">${data.discover.nearbyPeople.length}</span>
              </div>
              ${data.discover.nearbyPeople.map(renderNearbyPersonCard).join("")}
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderNearbyPersonCard(item) {
    return `
      <div class="nearby-card">
        ${renderAvatar(item.name, item.tone, "avatar--md")}
        <div class="nearby-card__body">
          <div class="nearby-card__title">
            <strong>${escapeHtml(item.name)}</strong>
            <span class="badge">${escapeHtml(item.distance)}</span>
          </div>
          <p>${escapeHtml(item.note)}</p>
          <div class="chip-row">
            <span class="chip chip--filled">附近的人</span>
            <span class="chip">${escapeHtml(item.distance)}</span>
          </div>
        </div>
        <button class="ghost-button ghost-button--small" data-action="show-hint" data-message="后续这里可接发招呼、查看资料、发起同城群。">看看</button>
      </div>
    `;
  }

  function renderDiscoverGamesScreen() {
    return `
      <section class="screen">
        ${renderScreenHeader({
          title: "游戏",
          subtitle: "这一轮先只保留统一入口，后续再接小游戏大厅",
          backPath: "/discover",
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <section class="hero-card hero-card--soft hero-card--games">
              <span class="eyebrow">Game Entry</span>
              <h3>先保留一个成熟的入口位置，不急着把小游戏本体塞进这轮 UI 重构。</h3>
              <div class="inline-actions inline-actions--wide">
                <button class="ghost-button" data-action="show-hint" data-message="后续这里可接小游戏大厅与最近玩过。">小游戏大厅</button>
                <button class="ghost-button" data-action="show-hint" data-message="后续这里可接群内发起房间与好友邀请。">组队房间</button>
              </div>
            </section>
            <section class="surface-card surface-card--games">
              <div class="surface-card__header">
                <div class="surface-card__header-copy">
                  <h3>当前入口规划</h3>
                  <p>先把入口和状态语言做对，后续再扩小游戏大厅与房间链路。</p>
                </div>
                <span class="badge">${data.discover.games.length}</span>
              </div>
              ${data.discover.games
                .map(
                  (item) => `
                    <div class="game-entry-card">
                      <div class="game-entry-card__body">
                        <strong>${escapeHtml(item.title)}</strong>
                        <span>${escapeHtml(item.summary)}</span>
                      </div>
                      <span class="badge">入口</span>
                    </div>
                  `,
                )
                .join("")}
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function discoverEntryMeta(item) {
    if (item.route === "/discover/moments") {
      return {
        label: "内容流",
        keyword: "熟人动态",
        note: "用时间流承接图文内容与互动。",
      };
    }
    if (item.route === "/discover/scan") {
      return {
        label: "快捷动作",
        keyword: "扫码跳转",
        note: "扫码后直接进入加好友、进群或登录确认。",
      };
    }
    if (item.route === "/discover/nearby") {
      return {
        label: "弱关系",
        keyword: "同城扩展",
        note: "基于距离和场景扩展新的关系。",
      };
    }
    return {
      label: "轻娱乐",
      keyword: "入口保留",
      note: "先确定入口位置，后续再扩小游戏链路。",
    };
  }

  function renderContactSection(section) {
    return `
      <section class="runtime-contact-section">
        <div class="runtime-contact-section__heading">${escapeHtml(section.tag)}</div>
        <div class="runtime-contact-list">
          ${section.items.map((contact) => renderContactRow(contact)).join("")}
        </div>
      </section>
    `;
  }

  function renderContactRow(contact) {
    return `
      <button
        class="runtime-contact-row"
        data-action="navigate"
        data-route="/contacts/profile/${contact.id}"
      >
        <span class="runtime-contact-row__avatar">
          ${renderAvatar(contact.name, contact.tone, "avatar--md")}
          <span class="runtime-contact-row__presence ${presenceClass(contact.status)}"></span>
        </span>
        <span class="runtime-contact-row__body">
          <strong>${escapeHtml(contact.name)}</strong>
          <span>${escapeHtml(contact.title)}</span>
        </span>
        ${renderRowChevron()}
      </button>
    `;
  }

  function renderFriendRequestsScreen() {
    const incoming = data.friendRequests.filter((item) => item.type === "incoming");
    const outgoing = data.friendRequests.filter((item) => item.type === "outgoing");

    return `
      <section class="screen">
        ${renderScreenHeader({
          title: "新的朋友",
          subtitle: `${incoming.length} 条收到 · ${outgoing.length} 条发出`,
          backPath: "/contacts",
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <section class="hero-card hero-card--soft hero-card--request-hub">
              <span class="eyebrow">Request Inbox</span>
              <h3>好友申请要先看方向、状态和打招呼内容，再决定通过、忽略或撤回。</h3>
              <div class="request-overview-grid">
                <span class="request-overview-card">
                  <strong>${incoming.length}</strong>
                  <span>收到申请</span>
                </span>
                <span class="request-overview-card">
                  <strong>${outgoing.length}</strong>
                  <span>发出申请</span>
                </span>
              </div>
            </section>
            ${renderRequestSection("收到的申请", "优先处理待确认的关系请求。", incoming, "incoming")}
            ${renderRequestSection("发出的申请", "跟踪自己发出的申请是否已经被处理。", outgoing, "outgoing")}
            <section class="surface-card">
              <div class="surface-card__header">
                <h3>下一步动作</h3>
                <span class="badge">Flow</span>
              </div>
              <div class="inline-actions inline-actions--wide">
                <button class="ghost-button" data-action="navigate" data-route="/contacts/add">继续搜索好友</button>
                <button class="ghost-button" data-action="navigate" data-route="/contacts">返回联系人目录</button>
              </div>
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderRequestSection(title, note, requests, type) {
    return `
      <section class="surface-card surface-card--request-section">
        <div class="surface-card__header">
          <div class="surface-card__header-copy">
            <h3>${escapeHtml(title)}</h3>
            <p>${escapeHtml(note)}</p>
          </div>
          <span class="badge">${requests.length}</span>
        </div>
        ${requests.length
          ? requests.map((request) => renderRequestCard(request)).join("")
          : renderEmptyState(
              type === "incoming" ? "暂无收到的申请" : "暂无发出的申请",
              type === "incoming"
                ? "后续这里会承接好友验证、打招呼和状态变更。"
                : "从添加好友页发起申请后，这里会同步展示。",
            )}
      </section>
    `;
  }

  function renderRequestCard(request) {
    const isIncoming = request.type === "incoming";
    const pending = request.status === "pending";

    return `
      <div class="request-card request-card--${request.type}">
        <div class="request-card__header">
          ${renderAvatar(request.name, request.tone, "avatar--md")}
          <div class="request-card__body">
            <div class="request-card__title">
              <strong>${escapeHtml(request.name)}</strong>
              <span class="request-card__status">
                <span class="chip ${isIncoming ? "chip--filled" : ""}">${requestDirectionLabel(request.type)}</span>
              </span>
            </div>
            <div class="request-card__meta">
              <span>@${escapeHtml(request.username)}</span>
              <span>${escapeHtml(request.title)}</span>
              <span>${escapeHtml(request.time)}</span>
            </div>
            <div class="request-card__title">
              <strong>${isIncoming ? "当前状态" : "申请状态"}</strong>
              <span class="badge ${request.status === "rejected" ? "badge--muted" : request.status === "accepted" ? "badge--success" : ""}">
                ${statusLabel(request.status)}
              </span>
            </div>
            <div class="request-card__message">
              <span>打招呼内容</span>
              <p>${escapeHtml(request.message)}</p>
            </div>
          </div>
        </div>
        ${
          isIncoming && pending
            ? `
              <div class="request-card__actions">
                <button class="ghost-button" data-action="update-request" data-request-id="${request.id}" data-status="rejected">忽略</button>
                <button class="primary-button primary-button--small" data-action="update-request" data-request-id="${request.id}" data-status="accepted">通过</button>
              </div>
            `
            : !isIncoming && pending
            ? `
              <div class="request-card__actions">
                <button class="ghost-button" data-action="update-request" data-request-id="${request.id}" data-status="withdrawn">撤回申请</button>
              </div>
            `
            : ""
        }
      </div>
    `;
  }

  function renderAddFriendScreen() {
    const users = filteredSearchUsers();

    return `
      <section class="screen">
        ${renderScreenHeader({
          title: "添加好友",
          subtitle: "搜索账号、写打招呼，再进入好友申请流转",
          backPath: "/contacts",
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <section class="hero-card hero-card--soft hero-card--add-friend">
              <span class="eyebrow">Search & Greeting</span>
              <h3>先搜到人，再决定是添加、处理现有关系，还是直接进入聊天。</h3>
            </section>
            <label class="search-box search-box--conversation">
              <span>搜索昵称、账号或城市</span>
              <div class="search-box__field">
                ${renderIcon("search", "search-box__icon", "搜索")}
                <input
                  id="friend-search-input"
                  class="search-box__input"
                  value="${escapeHtml(state.friendSearch)}"
                  placeholder="例如：nora、Shanghai"
                />
              </div>
            </label>
            <section class="surface-card surface-card--search-results">
              <div class="surface-card__header">
                <div class="surface-card__header-copy">
                  <h3>搜索结果</h3>
                  <p>动作按钮随关系状态变化，不让用户在“添加 / 处理 / 发消息”之间猜测。</p>
                </div>
                <span class="badge">${users.length}</span>
              </div>
              ${users.length ? users.map(renderSearchUserItem).join("") : renderEmptyState("没有匹配结果", "换个关键词，或者先从新的朋友里处理已有申请。")}
            </section>
            <section class="surface-card surface-card--friend-note">
              <div class="surface-card__header">
                <h3>打招呼内容</h3>
                <span class="badge">添加时会携带</span>
              </div>
              <div class="friend-note-card">
                <div class="friend-note-card__preview">
                  <strong>当前预览</strong>
                  <p>${escapeHtml(state.friendNote)}</p>
                </div>
                <div class="friend-note-card__meta">
                  <span class="chip chip--filled">${state.friendNote.trim().length} 字</span>
                  <span class="chip">申请消息</span>
                </div>
              </div>
              <label class="field field--textarea">
                <textarea id="friend-note-input" class="field__input field__input--textarea" rows="3">${escapeHtml(state.friendNote)}</textarea>
              </label>
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderSearchUserItem(user) {
    const action = renderSearchUserAction(user);

    return `
      <div class="list-row list-row--static list-row--search-user">
        ${renderAvatar(user.name, user.tone, "avatar--md")}
        <div class="list-row__body">
          <div class="list-row__title">
            <strong>${escapeHtml(user.name)}</strong>
            <span class="badge">${relationLabel(user.relation)}</span>
          </div>
          <div class="list-row__summary">${escapeHtml(user.username)} · ${escapeHtml(user.title)}</div>
          <div class="contact-row__chips">
            <span class="chip chip--filled">${escapeHtml(user.city)}</span>
            <span class="chip">${escapeHtml(searchUserRelationNote(user))}</span>
          </div>
        </div>
        ${action}
      </div>
    `;
  }

  function renderSearchUserAction(user) {
    if (user.relation === "pending_incoming") {
      return `<button class="ghost-button ghost-button--small" data-action="navigate" data-route="/contacts/requests">去处理</button>`;
    }
    if (user.relation === "pending_outgoing") {
      return `<button class="ghost-button ghost-button--small" type="button" disabled>已发送</button>`;
    }
    if (user.relation === "friend") {
      return `<button class="ghost-button ghost-button--small" data-action="open-direct-chat" data-contact-id="${user.id}">发消息</button>`;
    }
    return `<button class="primary-button primary-button--small" data-action="send-friend-request" data-user-id="${user.id}">添加</button>`;
  }

  function renderContactProfileScreen(contactId) {
    const contact = findContact(contactId);
    if (!contact) {
      return renderFallbackScreen("联系人不存在", "/contacts");
    }
    const relatedGroups = groupsForContact(contact.id);

    return `
      <section class="screen">
        ${renderScreenHeader({
          title: "联系人资料",
          subtitle: "单独承载联系人详情，而不是和列表并排",
          backPath: "/contacts",
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <section class="profile-hero profile-hero--contact">
              ${renderAvatar(contact.name, contact.tone, "avatar--xl")}
              <div class="profile-hero__body">
                <h3>${escapeHtml(contact.name)}</h3>
                <p>${escapeHtml(contact.title)} · ${escapeHtml(contact.status)}</p>
                <div class="chip-row">
                  <span class="chip chip--filled">${escapeHtml(contact.zone)}</span>
                  <span class="chip">@${escapeHtml(contact.username)}</span>
                  ${relatedGroups.length ? `<span class="chip">共同群 ${relatedGroups.length}</span>` : ""}
                </div>
              </div>
              <span class="badge ${contact.status === "在线" ? "badge--success" : contact.status === "离开" ? "badge--muted" : ""}">${escapeHtml(contact.status)}</span>
            </section>
            <section class="surface-card">
              <div class="inline-actions inline-actions--wide">
                <button class="primary-button" data-action="open-direct-chat" data-contact-id="${contact.id}">发送消息</button>
                <button class="ghost-button" data-action="show-hint" data-message="后续这里可承接音视频、备注、共享文件等能力。">更多动作</button>
              </div>
            </section>
            <section class="surface-card">
              <div class="surface-card__header">
                <h3>关系摘要</h3>
                <span class="badge">Profile</span>
              </div>
              <div class="profile-fact-grid">
                <span class="profile-fact">
                  <strong>@${escapeHtml(contact.username)}</strong>
                  <span>账号</span>
                </span>
                <span class="profile-fact">
                  <strong>${escapeHtml(contact.zone)}</strong>
                  <span>所在组</span>
                </span>
                <span class="profile-fact">
                  <strong>${relatedGroups.length}</strong>
                  <span>共同群聊</span>
                </span>
              </div>
            </section>
            <section class="settings-list">
              ${renderMenuRow("账号", contact.username, false)}
              ${renderMenuRow("职责", contact.title, false)}
              ${renderMenuRow("所在组", contact.zone, false)}
              ${renderMenuRow("备注", contact.note, false)}
            </section>
            ${
              relatedGroups.length
                ? `
                  <section class="surface-card">
                    <div class="surface-card__header">
                      <h3>共同群聊</h3>
                      <span class="badge">${relatedGroups.length}</span>
                    </div>
                    <div class="group-preview-list">
                      ${relatedGroups
                        .map(
                          (group) => `
                            <div class="group-preview-card">
                              <div class="group-preview-card__title">
                                <strong>${escapeHtml(group.name)}</strong>
                                <span class="badge">${group.memberCount} 人</span>
                              </div>
                              <p>${escapeHtml(group.notice)}</p>
                            </div>
                          `,
                        )
                        .join("")}
                    </div>
                  </section>
                `
                : ""
            }
          </div>
        </div>
      </section>
    `;
  }

  function renderGroupsScreen() {
    return `
      <section class="screen">
        ${renderScreenHeader({
          title: "群聊",
          subtitle: "查看已加入的群聊、公告与群设置",
          backPath: "/contacts",
          actions: [
            `<button class="ghost-button ghost-button--small" data-action="navigate" data-route="/groups/create">建群</button>`,
          ],
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <section class="surface-card">
              <div class="surface-card__header">
                <h3>已有群组</h3>
                <span class="badge">${data.groups.length}</span>
              </div>
              ${data.groups.map(renderGroupCard).join("")}
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderGroupCard(group) {
    return `
      <div class="group-card">
        <div class="group-card__header">
          ${renderAvatar(group.name, "violet", "avatar--md")}
          <div class="group-card__body">
            <div class="list-row__title">
              <strong>${escapeHtml(group.name)}</strong>
              <span class="badge">${group.memberCount} 人</span>
            </div>
            <p>${escapeHtml(group.notice)}</p>
            <div class="chip-row">
              ${group.tags.map((tag) => `<span class="chip">${escapeHtml(tag)}</span>`).join("")}
            </div>
          </div>
        </div>
        <div class="request-card__actions">
          <button class="ghost-button" data-action="navigate" data-route="/chat/${group.chatId}">进入聊天</button>
          <button class="primary-button primary-button--small" data-action="navigate" data-route="/groups/settings/${group.id}">群设置</button>
        </div>
      </div>
    `;
  }

  function renderCreateGroupScreen() {
    const contacts = filteredContacts().filter(matchesGroupMemberFilter);
    const selectedMembers = data.contacts.filter((contact) => state.createGroupMembers.has(contact.id));
    const selectedMemberNames = selectedMembers.map((contact) => escapeHtml(contact.name)).join("、");

    return `
      <section class="screen runtime-screen runtime-group-create-screen">
        ${renderScreenHeader({
          title: "创建群聊",
          backPath: "/chats",
        })}
        <form id="group-create-form" class="runtime-group-create-form" data-form="create-group-form">
          <section class="runtime-group-create__identity">
            <div class="runtime-section-heading">
              <h3>群聊名称</h3>
            </div>
            <label class="runtime-group-create__name-field">
              <input
                id="group-name-input"
                value="${escapeHtml(state.createGroupName)}"
                placeholder="输入群聊名称"
                aria-label="群聊名称"
              />
            </label>
          </section>
          <section class="runtime-group-create__picker" aria-label="邀请成员">
            <div class="runtime-group-create__picker-toolbar">
              <div class="runtime-group-create__selection" role="status" aria-live="polite">
                <span class="runtime-group-create__selection-copy">
                  <strong>已选成员</strong>
                  <span class="runtime-group-create__selection-summary">${selectedMemberNames || "从下方选择联系人"}</span>
                </span>
                <span class="runtime-group-create__member-count">${selectedMembers.length} 人</span>
              </div>
              <label class="runtime-search-field runtime-group-create__search">
                ${renderIcon("search", "runtime-search-field__icon", "筛选成员")}
                <input
                  id="group-member-filter-input"
                  value="${escapeHtml(state.groupMemberFilter)}"
                  placeholder="搜索联系人"
                  aria-label="筛选成员"
                />
              </label>
            </div>
            <div class="runtime-contact-list runtime-member-picker">
              ${contacts.length ? contacts.map(renderMemberPickerRow).join("") : renderEmptyState("未找到联系人", "调整搜索条件后重试。")}
            </div>
          </section>
        </form>
        <div class="runtime-group-create__footer">
          <button class="runtime-group-create__submit" type="submit" form="group-create-form">创建并进入群聊</button>
        </div>
      </section>
    `;
  }

  function renderMemberPickerRow(contact) {
    const checked = state.createGroupMembers.has(contact.id);
    return `
      <label class="runtime-contact-row runtime-member-picker__row">
        <span class="runtime-contact-row__avatar">
          ${renderAvatar(contact.name, contact.tone, "avatar--md")}
          <span class="runtime-contact-row__presence ${presenceClass(contact.status)}"></span>
        </span>
        <span class="runtime-contact-row__body">
          <strong>${escapeHtml(contact.name)}</strong>
          <span>${escapeHtml(contact.title)}</span>
        </span>
        <span class="runtime-member-picker__status">${escapeHtml(contact.status)}</span>
        <input
          class="runtime-member-picker__control"
          type="checkbox"
          data-kind="group-member"
          data-contact-id="${contact.id}"
          ${checked ? "checked" : ""}
        />
        <span class="runtime-member-picker__check" aria-hidden="true"></span>
      </label>
    `;
  }

  function renderGroupSettingsScreen(groupId) {
    const group = findGroup(groupId);
    if (!group) {
      return renderFallbackScreen("群组不存在", "/groups");
    }

    const members = group.members.map((memberId) => findPerson(memberId)).filter(Boolean);

    return `
      <section class="screen">
        ${renderScreenHeader({
          title: "群设置",
          subtitle: "公告、规则、加入方式和成员管理",
          backPath: `/chat/${group.chatId}`,
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <section class="profile-hero profile-hero--group">
              ${renderAvatar(group.name, "violet", "avatar--xl")}
              <div class="profile-hero__body">
                <h3>${escapeHtml(group.name)}</h3>
                <p>${group.memberCount} 位成员 · 在线 ${group.onlineCount}</p>
                <div class="chip-row">
                  ${group.tags.map((tag) => `<span class="chip chip--filled">${escapeHtml(tag)}</span>`).join("")}
                </div>
              </div>
            </section>
            <section class="surface-card">
              <div class="surface-card__header">
                <h3>群公告</h3>
                <button class="ghost-button ghost-button--small" data-action="navigate" data-route="/chat/${group.chatId}">返回会话</button>
              </div>
              <p>${escapeHtml(group.notice)}</p>
            </section>
            <section class="surface-card">
              <div class="surface-card__header">
                <h3>加入方式</h3>
                <span class="badge">${joinPolicyLabel(group.joinPolicy)}</span>
              </div>
              <div class="choice-row">
                ${renderChoiceButton("join-policy", group.id, "invite_only", joinPolicyLabel("invite_only"), group.joinPolicy)}
                ${renderChoiceButton("join-policy", group.id, "review_required", joinPolicyLabel("review_required"), group.joinPolicy)}
              </div>
            </section>
            <section class="surface-card">
              <div class="surface-card__header">
                <h3>发言策略</h3>
                <span class="badge">${muteModeLabel(group.muteMode)}</span>
              </div>
              <div class="choice-row">
                ${renderChoiceButton("mute-mode", group.id, "free", muteModeLabel("free"), group.muteMode)}
                ${renderChoiceButton("mute-mode", group.id, "admin_only", muteModeLabel("admin_only"), group.muteMode)}
              </div>
            </section>
            <section class="surface-card">
              <div class="surface-card__header">
                <h3>群规则</h3>
                <span class="badge">${group.rules.length}</span>
              </div>
              <ul class="bullet-list">
                ${group.rules.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}
              </ul>
            </section>
            <section class="surface-card">
              <div class="surface-card__header">
                <h3>成员</h3>
                <span class="badge">${members.length}</span>
              </div>
              <div class="member-stack">
                ${members
                  .map((member) => {
                    const name = member.name || member.username || "Unknown";
                    const title = member.title || member.role || "成员";
                    const tone = member.tone || member.avatarTone || "mint";
                    const status = member.status || "在线";
                    return `
                      <div class="list-row list-row--static">
                        ${renderAvatar(name, tone, "avatar--md")}
                        <div class="list-row__body">
                          <div class="list-row__title">
                            <strong>${escapeHtml(name)}</strong>
                            <span class="badge">${escapeHtml(status)}</span>
                          </div>
                          <div class="list-row__summary">${escapeHtml(title)}</div>
                        </div>
                      </div>
                    `;
                  })
                  .join("")}
              </div>
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderChoiceButton(kind, groupId, value, label, currentValue) {
    return `
      <button
        class="choice-button ${currentValue === value ? "is-active" : ""}"
        data-action="update-group-field"
        data-kind="${kind}"
        data-group-id="${groupId}"
        data-value="${value}"
      >
        ${label}
      </button>
    `;
  }

  function renderSearchScreen() {
    const results = searchResults();

    return `
      <section class="screen">
        ${renderScreenHeader({
          title: "消息搜索",
          subtitle: "独立二级页，点击结果返回对应会话上下文",
          backPath: "/chats",
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <label class="search-box">
              <span>搜索关键词</span>
              <input
                id="global-search-input"
                class="search-box__input"
                value="${escapeHtml(state.searchQuery)}"
                placeholder="例如：发布、规范、AI"
              />
            </label>
            ${
              !state.searchQuery.trim()
                ? `
                  <section class="surface-card">
                    <div class="surface-card__header">
                      <h3>推荐关键词</h3>
                      <span class="badge">Mock</span>
                    </div>
                    <div class="chip-row">
                      ${["发布", "设计", "AI", "群公告"]
                        .map(
                          (item) => `
                            <button class="chip" data-action="prefill-search" data-value="${item}">
                              ${item}
                            </button>
                          `,
                        )
                        .join("")}
                    </div>
                  </section>
                `
                : ""
            }
            <section class="surface-card">
              <div class="surface-card__header">
                <h3>${state.searchQuery.trim() ? `搜索“${escapeHtml(state.searchQuery)}”` : "最近命中的消息"}</h3>
                <span class="badge">${results.length}</span>
              </div>
              ${results.length ? results.map(renderSearchResultRow).join("") : renderEmptyState("没有匹配消息", "尝试更换关键词，或先进入聊天列表查看最近会话。")}
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderSearchResultRow(item) {
    return `
      <button
        class="search-result-row"
        data-action="open-search-result"
        data-chat-id="${item.chat.id}"
        data-message-id="${item.message.id}"
      >
        <span class="search-result-row__title">
          <strong>${escapeHtml(item.chat.name)}</strong>
          <span>${escapeHtml(item.message.time)}</span>
        </span>
        <span class="search-result-row__summary">${escapeHtml(item.message.content)}</span>
        <span class="search-result-row__note">${escapeHtml(item.message.senderName)} · ${item.chat.type === "group" ? "群聊" : "单聊"}</span>
      </button>
    `;
  }

  function renderLabOverviewScreen() {
    return `
      <section class="screen">
        ${renderScreenHeader({
          title: "扩展模块",
          subtitle: "未来能力全部拆成独立场景页，不绑在主聊天视图里",
          backPath: "/spec",
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            ${data.extensions.map(renderExtensionCard).join("")}
          </div>
        </div>
      </section>
    `;
  }

  function renderExtensionCard(item) {
    return `
      <button class="surface-card surface-card--button" data-action="navigate" data-route="${item.route}">
        <div class="surface-card__header">
          <h3>${escapeHtml(item.title)}</h3>
          <span class="badge">${escapeHtml(item.status)}</span>
        </div>
        <p>${escapeHtml(item.summary)}</p>
        <ul class="bullet-list">
          ${item.bullets.map((bullet) => `<li>${escapeHtml(bullet)}</li>`).join("")}
        </ul>
      </button>
    `;
  }

  function renderLabDetailScreen(moduleId) {
    const item = data.extensions.find((entry) => entry.id === moduleId);
    if (!item) {
      return renderFallbackScreen("扩展模块不存在", "/lab");
    }

    return `
      <section class="screen">
        ${renderScreenHeader({
          title: item.title,
          subtitle: "未来扩展方向",
          backPath: "/lab",
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <section class="hero-card hero-card--soft">
              <span class="eyebrow">Future Module</span>
              <h3>${escapeHtml(item.summary)}</h3>
              <span class="badge">${escapeHtml(item.status)}</span>
            </section>
            <section class="surface-card">
              <div class="surface-card__header">
                <h3>可扩展内容</h3>
                <span class="badge">${item.bullets.length}</span>
              </div>
              <ul class="bullet-list">
                ${item.bullets.map((bullet) => `<li>${escapeHtml(bullet)}</li>`).join("")}
              </ul>
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderMineScreen() {
    return `
      <section class="screen screen--tabbed runtime-screen runtime-screen--list runtime-mine-screen">
        <div class="screen-scroll runtime-scroll">
          <div class="runtime-list-content runtime-mine-content">
            <button class="runtime-mine-profile" data-action="navigate" data-route="/mine/profile">
              <span class="runtime-mine-profile__avatar">
                ${renderAvatar(data.currentUser.name, data.currentUser.avatarTone, "avatar--xl")}
                <span class="runtime-mine-profile__presence" aria-hidden="true"></span>
              </span>
              <span class="runtime-mine-profile__body">
                <strong>${escapeHtml(data.currentUser.name)}</strong>
                <span>${escapeHtml(data.currentUser.role)} · ${escapeHtml(data.currentUser.status)}</span>
                <span class="runtime-mine-profile__bio">${escapeHtml(data.currentUser.bio)}</span>
                <small>查看个人资料</small>
              </span>
              ${renderRowChevron()}
            </button>
            <section class="runtime-settings-group runtime-mine-group">
              ${renderMineMenuLink("账号与安全", "设备与登录管理", "profile", "/settings/account")}
              ${renderMineMenuLink("设置", "通知、隐私、聊天与存储", "settings", "/settings", true)}
            </section>
            <section class="runtime-settings-group runtime-mine-group">
              <h3>支持与关于</h3>
              ${renderMineMenuLink("隐私协议", "数据使用说明", "shield", "/settings/privacy")}
              ${renderMineMenuLink("关于 RedCode IM", "版本与反馈", "more", "/settings/about")}
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderMineMenuLink(title, description, icon, route, emphasized = false) {
    return `
      <button class="runtime-mine-menu-row ${emphasized ? "is-emphasized" : ""}" data-action="navigate" data-route="${route}">
        <span class="runtime-mine-menu-row__icon">${renderIcon(icon, "runtime-mine-menu-row__glyph")}</span>
        <span class="runtime-mine-menu-row__copy"><strong>${escapeHtml(title)}</strong><small>${escapeHtml(description)}</small></span>
        ${renderRowChevron()}
      </button>
    `;
  }

  function renderSettingsScreen() {
    return `
      <section class="screen runtime-screen runtime-screen--list runtime-settings-screen">
        ${renderScreenHeader({ title: "设置", backPath: "/mine" })}
        <div class="screen-scroll runtime-scroll">
          <div class="runtime-list-content runtime-settings-content">
            <section class="runtime-settings-group runtime-settings-group--links">
              <h3>账号与偏好</h3>
              ${renderRuntimeSettingsLink("账号与安全", "手机号、设备与登录管理", "/settings/account")}
              ${renderRuntimeSettingsLink("聊天", "聊天背景与存储", "/settings/chat")}
            </section>
            <section class="runtime-settings-group">
              <h3>消息通知</h3>
              ${renderRuntimeSwitchRow("mentions", "提及通知", data.settings.notifications.mentions, "notifications")}
              ${renderRuntimeSwitchRow("summaries", "消息摘要", data.settings.notifications.summaries, "notifications")}
              ${renderRuntimeSwitchRow("fileAlerts", "文件提醒", data.settings.notifications.fileAlerts, "notifications")}
            </section>
            <section class="runtime-settings-group">
              <h3>隐私</h3>
              ${renderRuntimeSwitchRow("readReceipt", "已读回执", data.settings.privacy.readReceipt, "privacy")}
              ${renderRuntimeSwitchRow("typingStatus", "正在输入", data.settings.privacy.typingStatus, "privacy")}
              ${renderRuntimeSwitchRow("autoDownloadMedia", "自动下载媒体", data.settings.privacy.autoDownloadMedia, "privacy")}
            </section>
            <section class="runtime-settings-group runtime-settings-group--links">
              <h3>支持</h3>
              ${renderRuntimeSettingsLink("隐私协议", "协议与数据使用说明", "/settings/privacy")}
              ${renderRuntimeSettingsLink("关于 RedCode IM", "版本与反馈", "/settings/about")}
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderSettingsDetailScreen(section) {
    const detail = settingsDetail(section);
    if (!detail) {
      return renderFallbackScreen("设置项不存在", "/settings");
    }

    return `
      <section class="screen runtime-screen runtime-screen--list">
        ${renderScreenHeader({ title: detail.title, backPath: section === "profile" ? "/mine" : "/settings" })}
        <div class="screen-scroll runtime-scroll">
          <div class="runtime-list-content runtime-settings-content">
            <section class="runtime-settings-group">
              ${detail.rows.map(renderRuntimeSettingsValueRow).join("")}
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function settingsDetail(section) {
    const enabledLabel = (enabled) => (enabled ? "已开启" : "已关闭");
    const details = {
      profile: {
        title: "个人资料",
        rows: [
          ["姓名", data.currentUser.name],
          ["身份", data.currentUser.role],
          ["手机号", data.currentUser.phone],
          ["邮箱", data.currentUser.email],
          ["个性签名", data.currentUser.bio],
        ],
      },
      account: {
        title: "账号与安全",
        rows: [
          ["手机号", data.currentUser.phone],
          ["登录设备", "当前设备已受保护"],
          ["账号状态", "正常"],
        ],
      },
      chat: {
        title: "聊天",
        rows: [
          ["聊天背景", "跟随当前主题"],
          ["自动下载媒体", enabledLabel(data.settings.privacy.autoDownloadMedia)],
          ["消息存储", "保留最近会话记录"],
        ],
      },
      privacy: {
        title: "隐私协议",
        rows: [
          ["已读回执", enabledLabel(data.settings.privacy.readReceipt)],
          ["正在输入", enabledLabel(data.settings.privacy.typingStatus)],
          ["数据使用", "仅用于提供 IM 服务"],
        ],
      },
      about: {
        title: "关于 RedCode IM",
        rows: [
          ["版本", "RedCode IM 2.0 Preview"],
          ["设计源", "im-ui-html"],
          ["反馈", "产品体验反馈"],
        ],
      },
    };
    return details[section] || null;
  }

  function renderRuntimeSettingsValueRow([label, value]) {
    return `
      <div class="runtime-setting-row runtime-setting-row--static">
        <span class="runtime-setting-row__copy"><strong>${escapeHtml(label)}</strong><small>${escapeHtml(value)}</small></span>
      </div>
    `;
  }

  function renderRuntimeSwitchRow(key, label, checked, scope) {
    return `
      <label class="runtime-setting-row runtime-setting-row--switch">
        <span>${escapeHtml(label)}</span>
        <input
          class="switch-row__input"
          type="checkbox"
          data-kind="setting-toggle"
          data-scope="${scope}"
          data-key="${key}"
          ${checked ? "checked" : ""}
        />
      </label>
    `;
  }

  function renderRuntimeSettingsLink(title, description, route) {
    return `
      <button class="runtime-setting-row runtime-setting-row--link" data-action="navigate" data-route="${route}">
        <span class="runtime-setting-row__copy"><strong>${escapeHtml(title)}</strong><small>${escapeHtml(description)}</small></span>
        ${renderRowChevron()}
      </button>
    `;
  }

  function renderSwitchRow(key, label, checked, scope) {
    return `
      <label class="switch-row">
        <span>${label}</span>
        <input
          class="switch-row__input"
          type="checkbox"
          data-kind="setting-toggle"
          data-scope="${scope}"
          data-key="${key}"
          ${checked ? "checked" : ""}
        />
      </label>
    `;
  }

  function renderMenuRow(title, description, clickable) {
    const tag = clickable ? "button" : "div";
    const attrs = clickable
      ? `class="menu-row" data-action="show-hint" data-message="${escapeHtml(description)}"`
      : `class="menu-row menu-row--static"`;

    return `
      <${tag} ${attrs}>
        <span class="menu-row__body">
          <strong>${escapeHtml(title)}</strong>
          <span>${escapeHtml(description)}</span>
        </span>
        ${clickable ? `<span class="list-arrow">→</span>` : ""}
      </${tag}>
    `;
  }

  function renderFallbackScreen(title, backPath) {
    return `
      <section class="screen">
        ${renderScreenHeader({
          title,
          subtitle: "返回上一层继续浏览原型",
          backPath,
        })}
        <div class="screen-scroll">
          ${renderEmptyState(title, "这条 mock 数据当前不存在，可以返回继续体验其他页面。")}
        </div>
      </section>
    `;
  }

  function renderEmptyState(title, description) {
    return `
      <div class="empty-state">
        <strong>${escapeHtml(title)}</strong>
        <p>${escapeHtml(description)}</p>
      </div>
    `;
  }

  function renderRouteReview(route) {
    if (route.section === "entry" || route.section === "spec") {
      return "";
    }

    const notes = reviewNotesForRoute(route);
    return `
      <section class="review-card">
        <div class="review-card__header">
          <h3>${escapeHtml(notes.title)}</h3>
          <span class="badge">${escapeHtml(notes.label)}</span>
        </div>
        <ul class="bullet-list">
          ${notes.items.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}
        </ul>
      </section>
    `;
  }

  function reviewNotesForRoute(route) {
    if (route.section === "entry") {
      return {
        title: "总入口当前验证点",
        label: "Entry",
        items: [
          "index 首页不再直接落入某个具体原型页，而是先分出规范、PC、移动端三个评审入口。",
          "入口页要体现“先系统后页面”的顺序，而不是继续把业务路由当首页。",
          "入口卡片、说明块与后续设计页必须共用同一套色系、字体和表面层级。",
        ],
      };
    }
    if (route.section === "pc-design") {
      return {
        title: "PC 设计验证点",
        label: "Desktop",
        items: [
          "桌面版是重组消息工作台，而不是把手机布局直接横向放大。",
          "消息流仍然是主层级，资料侧栏和文件上下文只能作为次级信息区。",
          "桌面端要继承移动端 token 与组件语义，但允许在版式上提升信息密度。",
        ],
      };
    }
    if (route.section === "spec") {
      return {
        title: "规范页当前验证点",
        label: "Design Source",
        items: [
          "先确认 2.0 视觉语言足够克制、细致，而不是继续沿用旧原型的花哨感。",
          "先把手机端 token、组件、页面地图定清楚，再让 Flutter 去实现。",
          "桌面端只保留方向说明，不提前把手机页拉成桌面工作台。",
        ],
      };
    }
    if (route.section === "mobile-design") {
      return {
        title: "移动端设备预览验证点",
        label: "Device",
        items: [
          "页面外只保留一个手机容器，不展示设计说明、工具条或验证卡。",
          "聊天、联系人、发现、我的与设置二级页都必须在容器内完成跳转。",
          "稳定底栏、消息输入区和容器内提示都使用同一套产品组件语言。",
        ],
      };
    }
    if (route.section === "not-found") {
      return {
        title: "无效路由验证点",
        label: "Route",
        items: [
          "非法 hash 需要显式提示，而不是静默伪装成首页成功渲染。",
          "错误路由页仍要保留回到入口、规范页和移动端入口的恢复路径。",
          "后续新增入口或页面时，应继续把非法路由作为基本 smoke 场景之一。",
        ],
      };
    }
    if (route.section === "chat-detail") {
      return {
        title: "聊天详情验证点",
        label: "Chat",
        items: [
          "输入框、占位文案和发送按钮在垂直方向保持一致节奏。",
          "表情 / 更多面板作为输入区延展，而不是打断当前上下文。",
          "消息列表只承载单列滚动，不再并排挂其他面板。",
        ],
      };
    }
    if (
      route.section === "contacts" ||
      route.section === "contact-profile" ||
      route.section === "contact-add" ||
      route.section === "contact-requests"
    ) {
      return {
        title: "联系人链路验证点",
        label: "Contact",
        items: [
          "联系人主页和资料页分层明确，避免列表 + 详情并排。",
          "好友申请、添加好友、群聊都从联系人体系自然分叉。",
          "卡片、列表项、按钮都复用同一套信息层级。",
        ],
      };
    }
    if (
      route.section === "discover" ||
      route.section === "discover-moments" ||
      route.section === "discover-scan" ||
      route.section === "discover-nearby" ||
      route.section === "discover-games"
    ) {
      return {
        title: "发现链路验证点",
        label: "Discover",
        items: [
          "发现必须成为正式一级入口，而不是继续挂在扩展页后面。",
          "朋友圈、扫一扫、附近的人、游戏要按不同场景分别落位，不混在一个大杂烩页里。",
          "游戏先只做入口位，保留后续小游戏大厅和房间扩展空间。",
        ],
      };
    }
    if (route.section === "groups" || route.section === "group-create" || route.section === "group-settings") {
      return {
        title: "群组链路验证点",
        label: "Group",
        items: [
          "建群流程应当短、清晰、适配手机单列操作。",
          "群设置承载规则、公告、策略和成员，不混进聊天主屏。",
          "创建完成后默认回到群会话，再从群设置进入细节维护。",
        ],
      };
    }
    if (route.section === "mine") {
      return {
        title: "我的页验证点",
        label: "Mine",
        items: [
          "一级页以资料、账户操作和支持入口为核心，不混入静态统计或其他根页的快捷入口。",
          "个人资料、账号安全、设置、隐私协议和关于入口都必须进入真实业务链路。",
          "设置下沉为二级页后，底栏仍只保留四个稳定入口。",
        ],
      };
    }
    if (route.section === "settings" || route.section === "settings-detail") {
      return {
        title: "设置链路验证点",
        label: "Settings",
        items: [
          "设置从我的页进入，通知、隐私与偏好不再和个人身份信息混排。",
          "开关行高、文本层级和列表结构保持统一。",
          "深链与返回都应留在移动端设备容器内。",
        ],
      };
    }
    return {
      title: "当前页面验证点",
      label: "Screen",
      items: [
        "保持移动端单列阅读和操作路径。",
        "只用必要表面层级，不回到桌面式信息堆叠。",
        "跳转、列表、按钮都要延续同一套视觉节奏。",
      ],
    };
  }

  function renderAvatar(name, tone, sizeClass) {
    const safeName = name || "R";
    const label = initials(safeName);
    const toneClass = toneClassMap[tone] || "avatar--mint";
    return `<span class="avatar ${toneClass} ${sizeClass || ""}" aria-hidden="true">${escapeHtml(label)}</span>`;
  }

  function sortedChats() {
    return data.chats.slice().sort((left, right) => {
      const pinnedDiff = Number(Boolean(right.pinned)) - Number(Boolean(left.pinned));
      if (pinnedDiff !== 0) {
        return pinnedDiff;
      }
      return (right.sortKey || 0) - (left.sortKey || 0);
    });
  }

  function matchesChatFilter(chat) {
    const keyword = state.chatFilter.trim().toLowerCase();
    if (!keyword) {
      return true;
    }
    return [chat.name, chat.lastMessage, chat.description, (chat.tags || []).join(" ")]
      .filter(Boolean)
      .join(" ")
      .toLowerCase()
      .includes(keyword);
  }

  function filteredContacts() {
    const keyword = state.contactFilter.trim().toLowerCase();
    if (!keyword) {
      return data.contacts.slice();
    }
    return data.contacts.filter((contact) =>
      [contact.name, contact.title, contact.zone, contact.note, contact.username]
        .filter(Boolean)
        .join(" ")
        .toLowerCase()
        .includes(keyword),
    );
  }

  function groupContacts(contacts) {
    const grouped = new Map();
    contacts.forEach((contact) => {
      const tag = contact.name ? contact.name.charAt(0).toUpperCase() : "#";
      if (!grouped.has(tag)) {
        grouped.set(tag, []);
      }
      grouped.get(tag).push(contact);
    });
    return Array.from(grouped.entries())
      .sort((left, right) => left[0].localeCompare(right[0]))
      .map(([tag, items]) => ({ tag, items: items.sort((left, right) => left.name.localeCompare(right.name)) }));
  }

  function filteredSearchUsers() {
    const keyword = state.friendSearch.trim().toLowerCase();
    if (!keyword) {
      return data.searchUsers.slice();
    }
    return data.searchUsers.filter((user) =>
      [user.name, user.username, user.title, user.city]
        .filter(Boolean)
        .join(" ")
        .toLowerCase()
      .includes(keyword),
    );
  }

  function presenceClass(status) {
    if (status === "在线") {
      return "is-online";
    }
    if (status === "离开") {
      return "is-away";
    }
    return "is-busy";
  }

  function groupsForContact(contactId) {
    return data.groups.filter((group) => group.members.includes(contactId));
  }

  function requestDirectionLabel(type) {
    return type === "incoming" ? "收到申请" : "发出申请";
  }

  function searchUserRelationNote(user) {
    if (user.relation === "pending_incoming") {
      return "等你处理";
    }
    if (user.relation === "pending_outgoing") {
      return "等待对方";
    }
    if (user.relation === "friend") {
      return "已是好友";
    }
    return "可发申请";
  }

  function matchesGroupMemberFilter(contact) {
    const keyword = state.groupMemberFilter.trim().toLowerCase();
    if (!keyword) {
      return true;
    }
    return [contact.name, contact.title, contact.zone]
      .filter(Boolean)
      .join(" ")
      .toLowerCase()
      .includes(keyword);
  }

  function searchResults() {
    const keyword = state.searchQuery.trim().toLowerCase();
    const results = [];

    sortedChats().forEach((chat) => {
      (chat.messages || []).forEach((message) => {
        const matchedText = [message.content, message.senderName, message.quote]
          .filter(Boolean)
          .join(" ")
          .toLowerCase();
        if (!keyword || matchedText.includes(keyword)) {
          results.push({ chat, message });
        }
      });
    });

    return results.slice(-8).reverse();
  }

  function findChat(chatId) {
    return data.chats.find((chat) => chat.id === chatId) || null;
  }

  function findContact(contactId) {
    return data.contacts.find((contact) => contact.id === contactId) || null;
  }

  function findGroup(groupId) {
    return data.groups.find((group) => group.id === groupId) || null;
  }

  function findGroupByChatId(chatId) {
    return data.groups.find((group) => group.chatId === chatId) || null;
  }

  function findPerson(personId) {
    if (personId === data.currentUser.id) {
      return data.currentUser;
    }
    const contact = findContact(personId);
    if (contact) {
      return contact;
    }
    const searchUser = data.searchUsers.find((item) => item.id === personId);
    if (searchUser) {
      return {
        id: searchUser.id,
        name: searchUser.name,
        title: searchUser.title,
        status: "在线",
        tone: searchUser.tone,
      };
    }
    return null;
  }

  function findDirectContact(chat) {
    const contactId = (chat.participants || []).find((id) => id !== data.currentUser.id);
    return contactId ? findContact(contactId) : null;
  }

  function promoteChat(chat) {
    state.orderCursor += 1;
    chat.sortKey = state.orderCursor;
  }

  function createDirectChat(contact) {
    const existing = data.chats.find(
      (chat) =>
        chat.type === "single" &&
        chat.participants.includes(data.currentUser.id) &&
        chat.participants.includes(contact.id),
    );

    if (existing) {
      promoteChat(existing);
      return existing;
    }

    const chat = {
      id: `c_room_${contact.id}`,
      type: "single",
      name: contact.name,
      remark: "",
      participants: [data.currentUser.id, contact.id],
      avatarTone: contact.tone,
      unread: 0,
      pinned: false,
      muted: false,
      tags: [contact.zone],
      lastMessage: "会话刚刚创建，准备开始新一轮沟通。",
      lastTime: "刚刚",
      description: `${contact.title} · ${contact.zone}`,
      metrics: {
        activeMembers: 2,
        todayMessages: 0,
        unreadMention: 0,
      },
      pinnedMessages: [],
      files: [],
      messages: [
        {
          id: `m_${Date.now()}`,
          senderId: data.currentUser.id,
          senderName: data.currentUser.name,
          senderTone: data.currentUser.avatarTone,
          content: "你好，先从这里开始同步新的移动端方案。",
          time: "刚刚",
          self: true,
          status: "已送达",
        },
      ],
      sortKey: 0,
    };
    promoteChat(chat);
    data.chats.unshift(chat);
    return chat;
  }

  function ensureContactForRequest(request) {
    if (findContact(request.userId)) {
      return findContact(request.userId);
    }
    const contact = {
      id: request.userId,
      name: request.name,
      username: request.username,
      title: request.title,
      status: "在线",
      tone: request.tone,
      note: "由好友申请转入联系人列表",
      zone: "新的好友",
    };
    data.contacts.push(contact);
    return contact;
  }

  function updateSearchUserRelation(userId, relation) {
    const user = data.searchUsers.find((item) => item.id === userId);
    if (user) {
      user.relation = relation;
    }
  }

  function sendFriendRequest(userId) {
    const user = data.searchUsers.find((entry) => entry.id === userId);
    if (!user) {
      return;
    }
    user.relation = "pending_outgoing";
    data.friendRequests.unshift({
      id: `fr_${Date.now()}`,
      type: "outgoing",
      userId: user.id,
      name: user.name,
      username: user.username,
      title: user.title,
      tone: user.tone,
      message: state.friendNote.trim() || "你好，想和你建立联系。",
      time: "刚刚",
      status: "pending",
    });
    showToast("申请已发送", `已向 ${user.name} 发送好友申请。`);
  }

  function updateFriendRequest(requestId, nextStatus) {
    const request = data.friendRequests.find((item) => item.id === requestId);
    if (!request) {
      return;
    }
    request.status = nextStatus;
    if (nextStatus === "accepted") {
      const contact = ensureContactForRequest(request);
      updateSearchUserRelation(request.userId, "friend");
      createDirectChat(contact);
      showToast("已通过申请", `${request.name} 已加入联系人，并生成私聊入口。`);
      return;
    }
    if (nextStatus === "withdrawn") {
      updateSearchUserRelation(request.userId, "none");
      showToast("已撤回", `已撤回发给 ${request.name} 的好友申请。`);
      return;
    }
    showToast("申请状态已更新", `${request.name} 当前状态：${statusLabel(nextStatus)}。`);
  }

  function createGroupFromForm() {
    const name = state.createGroupName.trim();
    const members = Array.from(state.createGroupMembers);

    if (!name) {
      showToast("创建失败", "请先输入群聊名称。");
      return;
    }
    if (members.length === 0) {
      showToast("创建失败", "至少选择 1 位好友。");
      return;
    }

    const timestamp = Date.now();
    const groupId = `g_${timestamp}`;
    const chatId = `c_group_${timestamp}`;
    const memberIds = [data.currentUser.id].concat(members);
    const previewContacts = members
      .map((id) => findContact(id))
      .filter(Boolean);

    data.groups.unshift({
      id: groupId,
      chatId,
      name,
      members: memberIds,
      notice: "刚创建的群聊，建议先把当前评审目标写进公告。",
      rules: ["围绕移动端体验推进结论。", "设计变更先回到规范页达成共识。"],
      joinPolicy: "invite_only",
      muteMode: "free",
      memberCount: memberIds.length,
      onlineCount: Math.max(2, memberIds.length - 1),
      tags: ["新建群聊", "移动端评审"],
    });

    const firstNames = previewContacts.map((contact) => contact.name).join("、");
    const chat = {
      id: chatId,
      type: "group",
      name,
      remark: "",
      participants: memberIds,
      avatarTone: "violet",
      unread: 0,
      pinned: false,
      muted: false,
      tags: ["群聊", "评审"],
      lastMessage: `${data.currentUser.name} 创建了群聊`,
      lastTime: "刚刚",
      description: `成员：${firstNames || "待补充"}`,
      metrics: {
        activeMembers: memberIds.length,
        todayMessages: 1,
        unreadMention: 0,
      },
      pinnedMessages: ["先对齐规范，再逐页推进视觉重构。"],
      files: [],
      messages: [
        {
          id: `m_${timestamp}`,
          senderId: data.currentUser.id,
          senderName: data.currentUser.name,
          senderTone: data.currentUser.avatarTone,
          content: `${data.currentUser.name} 创建了群聊「${name}」`,
          time: "刚刚",
          self: true,
          status: "系统消息",
        },
      ],
      sortKey: 0,
    };
    promoteChat(chat);
    data.chats.unshift(chat);

    state.activeGroupId = groupId;
    state.activeChatId = chatId;
    state.createGroupName = "移动端重构评审群";
    state.createGroupMembers = new Set(["u_alice", "u_zoe"]);
    state.groupMemberFilter = "";

    showToast("群聊已创建", `${name} 已创建完成，并进入群会话。`);
    navigate(`/chat/${chatId}`, { resetNavigationStack: true });
  }

  function sendChatMessage(chatId) {
    const chat = findChat(chatId);
    if (!chat) {
      return;
    }

    const content = (state.chatDrafts[chatId] || "").trim();
    if (!content) {
      showToast("发送失败", "请先输入一条消息。");
      return;
    }

    const message = {
      id: `m_${Date.now()}`,
      senderId: data.currentUser.id,
      senderName: data.currentUser.name,
      senderTone: data.currentUser.avatarTone,
      content,
      time: "刚刚",
      self: true,
      status: "已送达",
    };
    chat.messages.push(message);
    chat.lastMessage = content;
    chat.lastTime = "刚刚";
    chat.unread = 0;
    promoteChat(chat);
    state.chatDrafts[chatId] = "";
    state.recentMessageId = message.id;
    showToast("消息已发送", "消息已加入当前会话。");
    render();
  }

  function simulateIncomingMessage(chatId) {
    const chat = findChat(chatId);
    if (!chat) {
      return;
    }

    const sender = chat.type === "group"
      ? findContact(chat.participants.find((item) => item !== data.currentUser.id))
      : findDirectContact(chat);

    const message = {
      id: `m_${Date.now()}`,
      senderId: sender ? sender.id : "u_bot",
      senderName: sender ? sender.name : "Ops Copilot",
      senderTone: sender ? sender.tone : "violet",
      content: "收到一条新消息。",
      time: "刚刚",
      self: false,
      reactions: [{ emoji: "👀", count: 1 }],
    };
    chat.messages.push(message);
    chat.lastMessage = message.content;
    chat.lastTime = "刚刚";
    chat.unread = 0;
    promoteChat(chat);
    state.recentMessageId = message.id;
    showToast("新消息", "已收到一条新消息。");
    render();
  }

  function updateGroupField(groupId, kind, value) {
    const group = findGroup(groupId);
    if (!group) {
      return;
    }
    if (kind === "join-policy") {
      group.joinPolicy = value;
      showToast("加入方式已更新", `${group.name} 现在是 ${joinPolicyLabel(value)}。`);
    } else if (kind === "mute-mode") {
      group.muteMode = value;
      showToast("发言策略已更新", `${group.name} 现在是 ${muteModeLabel(value)}。`);
    }
    render();
  }

  function showToast(title, message) {
    state.toasts.unshift({
      id: `toast_${Date.now()}`,
      title,
      message,
    });
    state.toasts = state.toasts.slice(0, 3);
    if (toastTimerId) {
      window.clearTimeout(toastTimerId);
    }
    toastTimerId = window.setTimeout(() => {
      state.toasts.pop();
      render();
    }, 2800);
  }

  function renderToasts(options = {}) {
    if (!state.toasts.length) {
      return "";
    }
    return `
      <aside class="toast-stack ${options.embedded ? "toast-stack--embedded" : ""}" aria-live="polite">
        ${state.toasts
          .map(
            (toast) => `
              <div class="toast">
                <strong>${escapeHtml(toast.title)}</strong>
                <p>${escapeHtml(toast.message)}</p>
              </div>
            `,
          )
          .join("")}
      </aside>
    `;
  }

  function handleClick(event) {
    const target = event.target.closest("[data-action]");
    if (!target) {
      return;
    }

    const action = target.getAttribute("data-action");
    if (action === "go-back") {
      event.preventDefault();
      navigateBack(target.getAttribute("data-fallback-route"));
      return;
    }
    if (action === "navigate") {
      event.preventDefault();
      navigate(target.getAttribute("data-route"));
      return;
    }
    if (action === "set-theme") {
      state.theme = target.getAttribute("data-theme");
      data.settings.theme = state.theme;
      persistUiState();
      render();
      return;
    }
    if (action === "set-density") {
      state.density = target.getAttribute("data-density");
      data.settings.density = state.density;
      persistUiState();
      render();
      return;
    }
    if (action === "set-device-frame") {
      const deviceFrame = target.getAttribute("data-device-frame");
      if (isSupportedDeviceFrame(deviceFrame)) {
        state.deviceFrame = deviceFrame;
        persistUiState();
        render();
      }
      return;
    }
    if (action === "set-desktop-chat") {
      const chatId = target.getAttribute("data-chat-id");
      if (chatId && findChat(chatId)) {
        state.activeChatId = chatId;
        render();
      }
      return;
    }
    if (action === "set-spec-tab") {
      state.activeSpecTab = target.getAttribute("data-tab");
      render();
      return;
    }
    if (action === "toggle-composer-panel") {
      const panel = target.getAttribute("data-panel");
      state.composerPanel = state.composerPanel === panel ? null : panel;
      render();
      return;
    }
    if (action === "append-emoji") {
      const route = resolveMobilePreviewRoute(parseRoute(currentPath()));
      if (route.section === "chat-detail" && route.chatId) {
        state.chatDrafts[route.chatId] = `${state.chatDrafts[route.chatId] || ""}${target.getAttribute("data-emoji")}`;
        render();
      }
      return;
    }
    if (action === "simulate-message") {
      simulateIncomingMessage(target.getAttribute("data-chat-id"));
      return;
    }
    if (action === "show-hint") {
      showToast("提示", target.getAttribute("data-message") || "该功能暂不可用。");
      return;
    }
    if (action === "send-friend-request") {
      sendFriendRequest(target.getAttribute("data-user-id"));
      render();
      return;
    }
    if (action === "update-request") {
      updateFriendRequest(target.getAttribute("data-request-id"), target.getAttribute("data-status"));
      render();
      return;
    }
    if (action === "open-direct-chat") {
      const contact = findContact(target.getAttribute("data-contact-id"));
      if (contact) {
        const chat = createDirectChat(contact);
        state.activeChatId = chat.id;
        navigate(`/chat/${chat.id}`);
      }
      return;
    }
    if (action === "open-search-result") {
      state.activeChatId = target.getAttribute("data-chat-id");
      state.highlightMessageId = target.getAttribute("data-message-id");
      navigate(`/chat/${state.activeChatId}`, { keepHighlight: true });
      return;
    }
    if (action === "prefill-search") {
      state.searchQuery = target.getAttribute("data-value") || "";
      render();
      return;
    }
    if (action === "update-group-field") {
      updateGroupField(
        target.getAttribute("data-group-id"),
        target.getAttribute("data-kind"),
        target.getAttribute("data-value"),
      );
    }
  }

  let filterRenderTimer = 0;

  function scheduleFilterRender(target) {
    const inputId = target.id;
    const caretPosition = typeof target.selectionStart === "number"
      ? target.selectionStart
      : target.value.length;

    window.clearTimeout(filterRenderTimer);
    filterRenderTimer = window.setTimeout(() => {
      render();
      window.requestAnimationFrame(() => {
        const nextInput = document.getElementById(inputId);
        if (!(nextInput instanceof HTMLInputElement || nextInput instanceof HTMLTextAreaElement)) {
          return;
        }
        nextInput.focus({ preventScroll: true });
        const nextCaretPosition = Math.min(caretPosition, nextInput.value.length);
        nextInput.setSelectionRange(nextCaretPosition, nextCaretPosition);
      });
    }, 120);
  }

  function handleInput(event) {
    const target = event.target;

    if (target.id === "chat-filter-input") {
      state.chatFilter = target.value;
      scheduleFilterRender(target);
      return;
    }
    if (target.id === "contact-filter-input") {
      state.contactFilter = target.value;
      scheduleFilterRender(target);
      return;
    }
    if (target.id === "friend-search-input") {
      state.friendSearch = target.value;
      scheduleFilterRender(target);
      return;
    }
    if (target.id === "global-search-input") {
      state.searchQuery = target.value;
      scheduleFilterRender(target);
      return;
    }
    if (target.id === "group-member-filter-input") {
      state.groupMemberFilter = target.value;
      scheduleFilterRender(target);
      return;
    }
    if (target.id === "group-name-input") {
      state.createGroupName = target.value;
      return;
    }
    if (target.id === "friend-note-input") {
      state.friendNote = target.value;
      return;
    }
    if (target.id === "chat-draft-input") {
      const chatId = target.getAttribute("data-chat-id");
      state.chatDrafts[chatId] = target.value;
    }
  }

  function restoreGroupMemberPickerScroll(scrollTop) {
    window.requestAnimationFrame(() => {
      const picker = root.querySelector(".runtime-member-picker");
      if (!(picker instanceof HTMLElement)) {
        return;
      }
      picker.scrollTop = Math.min(scrollTop, Math.max(0, picker.scrollHeight - picker.clientHeight));
    });
  }

  function handleChange(event) {
    const target = event.target;

    if (target.getAttribute("data-kind") === "setting-toggle") {
      const scope = target.getAttribute("data-scope");
      const key = target.getAttribute("data-key");
      data.settings[scope][key] = target.checked;
      persistUiState();
      return;
    }

    if (target.getAttribute("data-kind") === "group-member") {
      const picker = root.querySelector(".runtime-member-picker");
      const scrollTop = picker instanceof HTMLElement ? picker.scrollTop : 0;
      const contactId = target.getAttribute("data-contact-id");
      if (target.checked) {
        state.createGroupMembers.add(contactId);
      } else {
        state.createGroupMembers.delete(contactId);
      }
      render();
      restoreGroupMemberPickerScroll(scrollTop);
    }
  }

  function handleSubmit(event) {
    const form = event.target;
    if (!(form instanceof HTMLFormElement)) {
      return;
    }

    const formKind = form.getAttribute("data-form");
    if (formKind === "login-form") {
      event.preventDefault();
      showToast("登录成功", "欢迎回来。");
      navigate("/chats");
      return;
    }
    if (formKind === "send-message") {
      event.preventDefault();
      sendChatMessage(form.getAttribute("data-chat-id"));
      return;
    }
    if (formKind === "create-group-form") {
      event.preventDefault();
      createGroupFromForm();
    }
  }

  function relationLabel(value) {
    if (value === "pending_incoming") {
      return "待处理";
    }
    if (value === "pending_outgoing") {
      return "已申请";
    }
    if (value === "friend") {
      return "好友";
    }
    return "可添加";
  }

  function statusLabel(value) {
    if (value === "pending") {
      return "待处理";
    }
    if (value === "accepted") {
      return "已通过";
    }
    if (value === "rejected") {
      return "已忽略";
    }
    if (value === "withdrawn") {
      return "已撤回";
    }
    if (value === "sent") {
      return "已发送";
    }
    return value;
  }

  function joinPolicyLabel(value) {
    if (value === "invite_only") {
      return "仅邀请";
    }
    if (value === "review_required") {
      return "需审核";
    }
    return value;
  }

  function muteModeLabel(value) {
    if (value === "admin_only") {
      return "仅管理员";
    }
    if (value === "free") {
      return "全员可发言";
    }
    return value;
  }

  function themeLabel(value) {
    return value === "dark" ? "深色主题" : "浅色主题";
  }

  function densityLabel(value) {
    if (value === "mid") {
      return "1.5K 密度";
    }
    if (value === "compact") {
      return "1K 密度";
    }
    return "2K 密度";
  }

  function initials(value) {
    return value
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((item) => item.charAt(0))
      .join("")
      .toUpperCase();
  }

  function escapeHtml(value) {
    return String(value == null ? "" : value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }
})();
