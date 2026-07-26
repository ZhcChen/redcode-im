(function bootstrapIMPrototype() {
  const source = window.RedcodeIMPrototypeData;
  const root = document.getElementById("app");
  const STORAGE_KEY = "redcode-im-ui-prototype/ui";

  if (!source || !root) {
    return;
  }

  const data = JSON.parse(JSON.stringify(source));
  const state = {
    theme: data.settings.theme || "dark",
    density: data.settings.density || "comfortable",
    activeChatId: data.chats[0] ? data.chats[0].id : null,
    activeContactId: data.contacts[0] ? data.contacts[0].id : null,
    activeGroupId: data.groups[0] ? data.groups[0].id : null,
    highlightMessageId: null,
    chatDrafts: {},
    searchQuery: "",
    chatFilter: "",
    contactFilter: "",
    friendSearch: "",
    friendNote: "你好，我想一起同步新版 IM 的界面方向。",
    createGroupName: "新设计评审群",
    createGroupMembers: new Set(["u_alice", "u_zoe"]),
    groupMemberFilter: "",
    modal: null,
    toasts: [],
  };

  const toneClassMap = {
    amber: "avatar--amber",
    mint: "avatar--mint",
    violet: "avatar--violet",
  };

  let toastTimerId = null;

  initializeSortKeys();
  hydrateUiState();
  applyBodyState();

  if (!window.location.hash) {
    window.location.hash = "#/spec";
  }

  window.addEventListener("hashchange", () => {
    const route = parseRoute(currentPath());
    syncSelectionFromRoute(route);
    render();
  });

  root.addEventListener("click", handleClick);
  root.addEventListener("change", handleChange);
  root.addEventListener("submit", handleSubmit);
  render();

  function initializeSortKeys() {
    const base = 1000;
    data.chats.forEach((chat, index) => {
      chat.sortKey = base - index;
    });
  }

  function hydrateUiState() {
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      if (!raw) return;
      const persisted = JSON.parse(raw);
      if (persisted.theme === "dark" || persisted.theme === "light") {
        state.theme = persisted.theme;
        data.settings.theme = persisted.theme;
      }
      if (persisted.density === "comfortable" || persisted.density === "compact") {
        state.density = persisted.density;
        data.settings.density = persisted.density;
      }
      if (persisted.notifications && typeof persisted.notifications === "object") {
        Object.assign(data.settings.notifications, persisted.notifications);
      }
      if (persisted.privacy && typeof persisted.privacy === "object") {
        Object.assign(data.settings.privacy, persisted.privacy);
      }
    } catch (error) {
      console.warn("Failed to hydrate prototype UI state.", error);
    }
  }

  function persistUiState() {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(data.settings));
    } catch (error) {
      console.warn("Failed to persist prototype UI state.", error);
    }
  }

  function currentPath() {
    const hash = window.location.hash.replace(/^#/, "").trim();
    return hash || "/spec";
  }

  function parseRoute(path) {
    const segments = path.split("/").filter(Boolean);
    if (segments.length === 0) {
      return { section: "spec" };
    }

    if (segments[0] === "auth") {
      return { section: "auth", subview: segments[1] || "login" };
    }

    if (segments[0] === "chat") {
      return { section: "chats", chatId: segments[1] || state.activeChatId };
    }

    if (segments[0] === "chats") {
      return { section: "chats", chatId: state.activeChatId };
    }

    if (segments[0] === "contacts") {
      if (segments[1] === "requests") {
        return { section: "contacts", subview: "requests" };
      }
      if (segments[1] === "add") {
        return { section: "contacts", subview: "add" };
      }
      if (segments[1] === "profile") {
        return { section: "contacts", subview: "profile", contactId: segments[2] };
      }
      return { section: "contacts", subview: "list", contactId: state.activeContactId };
    }

    if (segments[0] === "groups") {
      if (segments[1] === "create") {
        return { section: "groups", subview: "create" };
      }
      if (segments[1] === "settings") {
        return { section: "groups", subview: "settings", groupId: segments[2] || state.activeGroupId };
      }
      return { section: "groups", subview: "list", groupId: state.activeGroupId };
    }

    if (segments[0] === "search") {
      return { section: "search" };
    }

    if (segments[0] === "lab") {
      return {
        section: "lab",
        moduleId: segments[1] || null,
      };
    }

    if (segments[0] === "settings") {
      return { section: "settings" };
    }

    return { section: "spec" };
  }

  function syncSelectionFromRoute(route) {
    if (route.chatId) {
      state.activeChatId = route.chatId;
    }
    if (route.contactId) {
      state.activeContactId = route.contactId;
    }
    if (route.groupId) {
      state.activeGroupId = route.groupId;
    }
  }

  function navigate(path, options) {
    const merged = Object.assign({ preserveHighlight: false }, options);
    if (!merged.preserveHighlight) {
      state.highlightMessageId = null;
    }
    const nextHash = `#${path}`;
    if (window.location.hash === nextHash) {
      render();
      return;
    }
    window.location.hash = nextHash;
  }

  function render() {
    applyBodyState();
    const route = parseRoute(currentPath());
    syncSelectionFromRoute(route);

    if (route.section === "auth") {
      root.innerHTML = renderAuth(route);
      bindInputs(route);
      return;
    }

    const activeNav = resolveActiveNav(route);
    root.innerHTML = `
      <div class="shell">
        ${renderRail(activeNav)}
        <main class="content-column">
          <section class="panel">
            <header class="panel__header">
              ${renderPanelHeader(route)}
            </header>
            <div class="panel__body">
              ${renderRoute(route)}
            </div>
            ${renderFloatingNav(activeNav)}
          </section>
        </main>
      </div>
      ${renderModal()}
      ${renderToasts()}
    `;
    bindInputs(route);
  }

  function renderRail(activeNav) {
    return `
      <aside class="app-rail" aria-label="主导航">
        <div class="brand-mark">RC</div>
        <div class="rail-stack">
          ${data.navItems
            .map((item) => {
              const active = item.id === activeNav ? "active" : "";
              return `
                <button
                  class="rail-item ${active}"
                  data-action="navigate"
                  data-route="${item.route}"
                  aria-label="${escapeHtml(item.label)}"
                  title="${escapeHtml(item.label)}"
                >
                  <span class="rail-item__icon">${item.icon}</span>
                </button>
              `;
            })
            .join("")}
        </div>
        <div class="rail-user">
          ${renderAvatar(data.currentUser.name, data.currentUser.avatarTone, "")}
        </div>
      </aside>
    `;
  }

  function renderFloatingNav(activeNav) {
    const visibleItems = data.navItems.filter((item) =>
      ["spec", "chats", "contacts", "lab", "settings"].includes(item.id),
    );
    return `
      <nav class="floating-nav" aria-label="移动导航">
        <div class="floating-nav__inner">
          ${visibleItems
            .map((item) => {
              const active = item.id === activeNav ? "active" : "";
              return `
                <button
                  class="rail-item ${active}"
                  data-action="navigate"
                  data-route="${item.route}"
                  aria-label="${escapeHtml(item.label)}"
                >
                  <span class="rail-item__icon">${item.icon}</span>
                </button>
              `;
            })
            .join("")}
        </div>
      </nav>
    `;
  }

  function renderPanelHeader(route) {
    const header = headerForRoute(route);
    return `
      <div class="panel__title">
        <span class="eyebrow">${escapeHtml(header.eyebrow)}</span>
        <h1 class="title-lg">${escapeHtml(header.title)}</h1>
        <p class="body-md">${escapeHtml(header.description)}</p>
      </div>
      <div class="toolbar">
        ${header.controls}
      </div>
    `;
  }

  function headerForRoute(route) {
    if (route.section === "spec") {
      return {
        eyebrow: "Design Operating System",
        title: "RedCode IM 设计规范与交互原型",
        description: "先固定视觉语言，再把聊天、联系人、群组和未来扩展统一进同一套设计规则。",
        controls: `
          <button class="button secondary" data-action="navigate" data-route="/auth/login">登录页</button>
          <button class="button primary" data-action="navigate" data-route="/chat/${state.activeChatId}">进入主线原型</button>
        `,
      };
    }

    if (route.section === "chats") {
      const activeChat = findChat(route.chatId || state.activeChatId);
      return {
        eyebrow: activeChat && activeChat.type === "group" ? "Group Conversation" : "Conversation Workspace",
        title: activeChat ? activeChat.name : "会话总览",
        description: activeChat
          ? activeChat.description
          : "统一管理私聊、群聊、收藏、AI 助理与上下文信息面板。",
        controls: `
          <button class="button secondary" data-action="navigate" data-route="/search">消息搜索</button>
          <button class="button secondary" data-action="navigate" data-route="/groups/create">创建群聊</button>
          <button class="button primary" data-action="simulate-reply">模拟来消息</button>
        `,
      };
    }

    if (route.section === "contacts") {
      const titleMap = {
        list: "联系人",
        requests: "好友申请",
        add: "添加好友",
        profile: "联系人详情",
      };
      return {
        eyebrow: "Network Layer",
        title: titleMap[route.subview || "list"] || "联系人",
        description: "让搜索、申请、审批、备注和发起会话形成同一条轻量社交流程。",
        controls: `
          <button class="button secondary" data-action="navigate" data-route="/contacts/requests">新朋友</button>
          <button class="button primary" data-action="navigate" data-route="/contacts/add">搜索添加</button>
        `,
      };
    }

    if (route.section === "groups") {
      return {
        eyebrow: "Group Control",
        title: route.subview === "create" ? "创建群聊" : route.subview === "settings" ? "群设置" : "群组空间",
        description: "把成员、规则、公告、加入策略与权限摆进一个统一的信息架构里。",
        controls: `
          <button class="button secondary" data-action="navigate" data-route="/groups">群组概览</button>
          <button class="button primary" data-action="navigate" data-route="/groups/create">新建群聊</button>
        `,
      };
    }

    if (route.section === "search") {
      return {
        eyebrow: "Search & Trace",
        title: "消息搜索中心",
        description: "搜索结果不只是列表，要保留会话、发送者、时间和跳转上下文。",
        controls: `
          <button class="button secondary" data-action="set-message-search" data-preset="设计">搜索“设计”</button>
          <button class="button primary" data-action="set-message-search" data-preset="群">搜索“群”</button>
        `,
      };
    }

    if (route.section === "lab") {
      return {
        eyebrow: "Future Surfaces",
        title: route.moduleId ? labTitle(route.moduleId) : "未来扩展工作台",
        description: "在当前 IM 主体之外，为通话、AI、文件协作与自动化预留结构化入口。",
        controls: `
          <button class="button secondary" data-action="navigate" data-route="/lab/ai">AI 助理</button>
          <button class="button primary" data-action="navigate" data-route="/lab/files">文件协作</button>
        `,
      };
    }

    if (route.section === "settings") {
      return {
        eyebrow: "Preferences",
        title: "设置与主题控制",
        description: "主题、密度、通知、隐私和未来能力开关都回到同一套偏好体系里。",
        controls: `
          <button class="button secondary" data-action="toggle-theme">切换主题</button>
          <button class="button primary" data-action="toggle-density">切换密度</button>
        `,
      };
    }

    return {
      eyebrow: "Prototype",
      title: "RedCode IM",
      description: "统一的 UI 设计基线。",
      controls: "",
    };
  }

  function resolveActiveNav(route) {
    if (route.section === "spec") return "spec";
    if (route.section === "auth") return "auth";
    if (route.section === "chats") return "chats";
    if (route.section === "contacts") return "contacts";
    if (route.section === "groups") return "groups";
    if (route.section === "search") return "search";
    if (route.section === "lab") return "lab";
    if (route.section === "settings") return "settings";
    return "spec";
  }

  function renderRoute(route) {
    if (route.section === "spec") return renderSpecPage();
    if (route.section === "chats") return renderChatWorkspace(route.chatId || state.activeChatId);
    if (route.section === "contacts") return renderContactsRoute(route);
    if (route.section === "groups") return renderGroupsRoute(route);
    if (route.section === "search") return renderSearchRoute();
    if (route.section === "lab") return route.moduleId ? renderLabDetail(route.moduleId) : renderLabOverview();
    if (route.section === "settings") return renderSettingsRoute();
    return renderSpecPage();
  }

  function renderAuth() {
    return `
      <div class="shell">
        <main class="content-column">
          <section class="login-layout">
            <article class="auth-card">
              <section class="auth-brand stack lg">
                <span class="eyebrow">Graphite Command Lounge</span>
                <h1 class="title-xl">先统一设计规范，再重构 IM。</h1>
                <p class="body-lg">
                  这个纯 HTML 原型不依赖真实服务端，专门用来验证新的登录、导航、会话和扩展能力的视觉与交互规则。
                </p>
                <div class="metric-grid">
                  <div class="metric-card">
                    <p class="meta">原型页面</p>
                    <p class="metric-card__value">12</p>
                  </div>
                  <div class="metric-card">
                    <p class="meta">当前功能覆盖</p>
                    <p class="metric-card__value">IM 主线</p>
                  </div>
                  <div class="metric-card">
                    <p class="meta">未来扩展位</p>
                    <p class="metric-card__value">4+</p>
                  </div>
                </div>
                <ul class="kicker-list">
                  ${data.designSystem.principles
                    .map((item) => `<li>${escapeHtml(item)}</li>`)
                    .join("")}
                </ul>
              </section>
              <section class="auth-form">
                <span class="eyebrow">Prototype Login</span>
                <h2 class="title-lg">欢迎回到 RedCode IM</h2>
                <p class="body-md">
                  这个登录页原型强调品牌层级、路径选择和轻量错误提示，而不是把所有控件堆在首屏。
                </p>
                <label class="stack">
                  <span class="meta">账号</span>
                  <input class="input" value="atlas@redcode.im" readonly />
                </label>
                <label class="stack">
                  <span class="meta">密码</span>
                  <input class="input" value="••••••••" readonly />
                </label>
                <div class="button-row" style="grid-template-columns: 1fr 1fr;">
                  <button class="button secondary" type="button" data-action="navigate" data-route="/spec">查看规范</button>
                  <button class="button primary" type="button" data-action="prototype-login">进入原型</button>
                </div>
                <div class="helper-note">
                  当前只做 UI 原型，因此登录不会校验真实账号，而是直接进入应用工作区。
                </div>
              </section>
            </article>
          </section>
        </main>
      </div>
    `;
  }

  function renderSpecPage() {
    return `
      <section class="spec-layout">
        <div class="stack lg">
          <article class="hero">
            <div class="hero-grid">
              <div class="stack lg">
                <span class="pill">设计主张</span>
                <h2 class="title-xl">${escapeHtml(data.designSystem.thesis)}</h2>
                <p class="body-lg">
                  目标不是把现有 IM 页面“修顺一点”，而是重新定义一套统一、长期可扩展的界面操作系统：导航统一、层级统一、组件统一、状态统一。
                </p>
                <div class="button-row" style="grid-template-columns: repeat(3, minmax(0, max-content));">
                  ${data.quickActions
                    .map(
                      (item) => `
                        <button class="button ${item.id === "open-chat" ? "primary" : "secondary"}" data-action="navigate" data-route="${item.route}">
                          ${escapeHtml(item.title)}
                        </button>
                      `,
                    )
                    .join("")}
                </div>
              </div>
              <div class="hero-preview stack">
                <span class="eyebrow">Interaction DNA</span>
                <h3 class="title-md">统一 3 类核心动效</h3>
                <ul class="kicker-list">
                  <li>导航切换：轻位移 + 淡入，保持工作区稳定感。</li>
                  <li>消息进入：从下向上出现，适合 IM 的时间流感知。</li>
                  <li>弹层与侧栏：以滑入替代生硬弹出，减少上下文断裂。</li>
                </ul>
              </div>
            </div>
          </article>

          <div class="metric-grid">
            <article class="metric-card">
              <p class="meta">Brand Mood</p>
              <p class="metric-card__value">Calm / Sharp</p>
            </article>
            <article class="metric-card">
              <p class="meta">Primary Surface</p>
              <p class="metric-card__value">Dark Graphite</p>
            </article>
            <article class="metric-card">
              <p class="meta">Action Accent</p>
              <p class="metric-card__value">Electric Cyan</p>
            </article>
            <article class="metric-card">
              <p class="meta">Layout Bias</p>
              <p class="metric-card__value">Dense Workspace</p>
            </article>
          </div>

          <section class="spec-card stack lg">
            <div class="stack">
              <span class="eyebrow">Design Tokens</span>
              <h3 class="title-md">颜色、字体、间距、圆角必须先定死</h3>
            </div>
            <div class="token-grid">
              <article class="token-card stack">
                <h4 class="title-sm">Color System</h4>
                ${data.designSystem.tokens.colors
                  .map(
                    (entry) => `
                      <div class="row space-between">
                        <span>${escapeHtml(entry[0])}</span>
                        <span class="meta">${entry[1]}</span>
                      </div>
                    `,
                  )
                  .join("")}
              </article>
              <article class="token-card stack">
                <h4 class="title-sm">Typography</h4>
                ${data.designSystem.tokens.typography
                  .map(
                    (entry) => `
                      <div class="row space-between">
                        <span>${escapeHtml(entry[0])}</span>
                        <span class="meta">${escapeHtml(entry[1])}</span>
                      </div>
                    `,
                  )
                  .join("")}
              </article>
              <article class="token-card stack">
                <h4 class="title-sm">Spacing & Motion</h4>
                ${data.designSystem.tokens.spacing
                  .map(
                    (entry) => `
                      <div class="row space-between">
                        <span>${escapeHtml(entry[0])}</span>
                        <span class="meta">${escapeHtml(entry[1])}</span>
                      </div>
                    `,
                  )
                  .join("")}
              </article>
            </div>
          </section>

          <section class="spec-card stack lg">
            <div class="stack">
              <span class="eyebrow">Component Language</span>
              <h3 class="title-md">按钮、状态、筛选、消息气泡都遵循同一套形态规则</h3>
            </div>
            <div class="component-grid">
              <article class="component-card stack">
                <h4 class="title-sm">Button States</h4>
                <div class="button-row" style="grid-template-columns: repeat(2, minmax(0, 1fr));">
                  <button class="button primary">主操作</button>
                  <button class="button secondary">次操作</button>
                  <button class="button ghost">弱操作</button>
                  <button class="button danger">危险操作</button>
                </div>
              </article>
              <article class="component-card stack">
                <h4 class="title-sm">Filter Chips</h4>
                <div class="chip-row">
                  <span class="chip active">全部会话</span>
                  <span class="chip">群聊</span>
                  <span class="chip">收藏</span>
                  <span class="chip">机器人</span>
                </div>
              </article>
              <article class="component-card stack">
                <h4 class="title-sm">Message Bubble</h4>
                <div class="message-board">
                  <div class="message-row">
                    ${renderAvatar("Zoe", "violet", "")}
                    <div class="message-bubble">
                      这套气泡要支持文本、引用、附件、reaction 和上下文动作。
                      <div class="reaction-row">
                        <span class="reaction">🔥 4</span>
                        <span class="reaction">✅ 2</span>
                      </div>
                    </div>
                  </div>
                  <div class="message-row self">
                    <div class="message-bubble">
                      所以整个设计系统不能只盯着列表页，要从消息对象本身出发。
                    </div>
                  </div>
                </div>
              </article>
            </div>
          </section>
        </div>

        <aside class="stack lg">
          <article class="spec-card stack">
            <span class="eyebrow">Prototype Coverage</span>
            <h3 class="title-md">当前页面清单</h3>
            <div class="list">
              ${data.designSystem.pageTemplates
                .map(
                  (name) => `
                    <div class="list-item">
                      <div class="list-item__main">
                        <p class="list-item__title">${escapeHtml(name)}</p>
                        <p class="list-item__summary">已纳入统一原型导航和 mock 数据流。</p>
                      </div>
                    </div>
                  `,
                )
                .join("")}
            </div>
          </article>

          <article class="spec-card stack">
            <span class="eyebrow">Review Route</span>
            <h3 class="title-md">建议评审路径</h3>
            <ul class="kicker-list">
              <li>先看规范页，确认视觉方向和组件形态。</li>
              <li>再看聊天主线，验证会话列表 + 详情 + 右侧上下文。</li>
              <li>再看联系人、加好友、建群，确认社交流程是否顺滑。</li>
              <li>最后看扩展页，判断未来路线是否值得保留。</li>
            </ul>
          </article>

          <article class="spec-card stack">
            <span class="eyebrow">Future Hooks</span>
            <h3 class="title-md">已预留扩展位</h3>
            ${data.extensions
              .map(
                (item) => `
                  <button class="list-item" data-action="navigate" data-route="${item.route}">
                    <div class="list-item__main">
                      <div class="list-item__row">
                        <p class="list-item__title">${escapeHtml(item.title)}</p>
                        <span class="badge">${escapeHtml(item.status)}</span>
                      </div>
                      <p class="list-item__summary">${escapeHtml(item.summary)}</p>
                    </div>
                  </button>
                `,
              )
              .join("")}
          </article>
        </aside>
      </section>
    `;
  }

  function renderChatWorkspace(chatId) {
    const chatList = sortedChats();
    const filteredChatList = chatList.filter((chat) => matchesChatFilter(chat));
    const activeChat = findChat(chatId) || findChat(state.activeChatId);
    if (!activeChat) {
      return '<div class="empty-state">当前没有可展示的会话。</div>';
    }

    state.activeChatId = activeChat.id;
    const participants = contactListForChat(activeChat);
    const draft = state.chatDrafts[activeChat.id] || "";
    const chatAction = renderChatContextAction(activeChat);

    return `
      <section class="stage-layout">
        <aside class="context-card">
          <header class="context-card__header">
            <div class="stack">
              <span class="eyebrow">Inbox</span>
              <h3 class="title-md">会话列表</h3>
            </div>
            <span class="badge">${chatList.length}</span>
          </header>
          <div class="context-card__body stack">
            <input
              id="chat-filter-input"
              class="search-field"
              placeholder="搜索会话、标签或最后一条消息"
              value="${escapeHtml(state.chatFilter)}"
            />
            <div class="chip-row">
              <button class="chip active" data-action="navigate" data-route="/chats">全部</button>
              <button class="chip" data-action="navigate" data-route="/groups">群聊</button>
              <button class="chip" data-action="navigate" data-route="/lab/ai">AI</button>
            </div>
            <div class="list">
              ${
                filteredChatList.length
                  ? filteredChatList.map((chat) => renderChatListItem(chat, chat.id === activeChat.id)).join("")
                  : '<div class="empty-state compact">没有匹配的会话。</div>'
              }
            </div>
          </div>
        </aside>

        <section class="stage-card">
          <header class="stage-card__header">
            <div class="row">
              ${renderAvatar(activeChat.name, activeChat.avatarTone, "")}
              <div class="stack">
                <h3 class="title-md">${escapeHtml(activeChat.name)}</h3>
                <p class="body-sm">${escapeHtml(activeChat.description)}</p>
              </div>
            </div>
            <div class="row wrap">
              ${activeChat.tags.map((tag) => `<span class="chip">${escapeHtml(tag)}</span>`).join("")}
              ${chatAction}
            </div>
          </header>
          <div class="stage-card__body stack lg">
            <div class="message-board">
              ${activeChat.messages
                .map((message) => renderMessage(activeChat, message))
                .join("")}
            </div>
          </div>
          <footer class="message-composer">
            <div class="composer-actions">
              <button class="action-button" data-action="insert-draft-token" data-token="#设计评审">#</button>
              <button class="action-button" data-action="insert-draft-token" data-token="@all">@</button>
            </div>
            <textarea
              id="chat-draft"
              class="composer-input"
              placeholder="输入消息、需求摘要或群公告草稿..."
            >${escapeHtml(draft)}</textarea>
            <div class="composer-actions">
              <button class="action-button" data-action="insert-draft-token" data-token="✅">✓</button>
              <button class="button primary" data-action="send-message">发送</button>
            </div>
          </footer>
        </section>

        <aside class="context-card">
          <header class="context-card__header">
            <div class="stack">
              <span class="eyebrow">Context</span>
              <h3 class="title-md">上下文面板</h3>
            </div>
          </header>
          <div class="context-card__body stack lg">
            <article class="preview-card stack">
              <h4 class="title-sm">群指标</h4>
              <div class="metric-grid">
                <div class="metric-card">
                  <p class="meta">在线成员</p>
                  <p class="metric-card__value">${activeChat.metrics.activeMembers}</p>
                </div>
                <div class="metric-card">
                  <p class="meta">今日消息</p>
                  <p class="metric-card__value">${activeChat.metrics.todayMessages}</p>
                </div>
              </div>
            </article>
            <article class="preview-card stack">
              <h4 class="title-sm">Pinned Messages</h4>
              <div class="list">
                ${activeChat.pinnedMessages.length
                  ? activeChat.pinnedMessages
                      .map(
                        (item) => `
                          <div class="list-item">
                            <div class="list-item__main">
                              <p class="list-item__summary">${escapeHtml(item)}</p>
                            </div>
                          </div>
                        `,
                      )
                      .join("")
                  : '<div class="helper-note">当前会话还没有置顶消息。</div>'}
              </div>
            </article>
            <article class="preview-card stack">
              <h4 class="title-sm">Shared Files</h4>
              <div class="list">
                ${activeChat.files.length
                  ? activeChat.files
                      .map(
                        (item) => `
                          <div class="list-item">
                            <div class="list-item__main">
                              <div class="list-item__row">
                                <p class="list-item__title">${escapeHtml(item.name)}</p>
                                <span class="badge">${escapeHtml(item.type)}</span>
                              </div>
                              <p class="list-item__summary">${escapeHtml(item.size)}</p>
                            </div>
                          </div>
                        `,
                      )
                      .join("")
                  : '<div class="helper-note">暂无共享文件。</div>'}
              </div>
            </article>
            <article class="preview-card stack">
              <h4 class="title-sm">Active Participants</h4>
              <div class="list">
                ${participants
                  .map(
                    (contact) => `
                      <button
                        class="list-item"
                        data-action="navigate"
                        data-route="/contacts/profile/${contact.id}"
                      >
                        ${renderAvatar(contact.name, contact.tone, "")}
                        <div class="list-item__main">
                          <div class="list-item__row">
                            <p class="list-item__title">${escapeHtml(contact.name)}</p>
                            <span class="badge">${escapeHtml(contact.status)}</span>
                          </div>
                          <p class="list-item__summary">${escapeHtml(contact.title || contact.role || "")}</p>
                        </div>
                      </button>
                    `,
                  )
                  .join("")}
              </div>
            </article>
          </div>
        </aside>
      </section>
    `;
  }

  function renderMessage(chat, message) {
    const reactionRow = message.reactions && message.reactions.length
      ? `
        <div class="reaction-row">
          ${message.reactions
            .map(
              (reaction) => `
                <button
                  class="reaction"
                  data-action="increment-reaction"
                  data-chat-id="${chat.id}"
                  data-message-id="${message.id}"
                  data-emoji="${reaction.emoji}"
                >${reaction.emoji} ${reaction.count}</button>
              `,
            )
            .join("")}
        </div>
      `
      : "";

    const quote = message.quote
      ? `<div class="helper-note" style="margin-bottom: 12px;">${escapeHtml(message.quote)}</div>`
      : "";

    const bubbleClass = state.highlightMessageId === message.id ? "message-bubble highlight" : "message-bubble";

    return `
      <div class="message-row ${message.self ? "self" : ""}">
        ${message.self ? "" : renderAvatar(message.senderName, message.senderTone, "")}
        <div class="${bubbleClass}">
          ${message.self ? "" : `<p class="meta">${escapeHtml(message.senderName)}</p>`}
          ${quote}
          <div>${escapeHtml(message.content)}</div>
          ${reactionRow}
          <div class="message-meta">
            <span>${escapeHtml(message.time)}</span>
            <span>${escapeHtml(message.status || (message.self ? "已送达" : "可操作"))}</span>
          </div>
        </div>
      </div>
    `;
  }

  function renderContactsRoute(route) {
    if (route.subview === "requests") {
      return renderFriendRequests();
    }
    if (route.subview === "add") {
      return renderAddFriend();
    }
    return renderContactsList(route.contactId || state.activeContactId);
  }

  function renderContactsList(contactId) {
    const filtered = data.contacts.filter((contact) => {
      if (!state.contactFilter.trim()) return true;
      const keyword = state.contactFilter.trim().toLowerCase();
      return (
        contact.name.toLowerCase().includes(keyword) ||
        contact.username.toLowerCase().includes(keyword) ||
        contact.zone.toLowerCase().includes(keyword)
      );
    });

    const activeContact = findContact(contactId) || filtered[0] || data.contacts[0];
    if (activeContact) {
      state.activeContactId = activeContact.id;
    }

    return `
      <section class="contacts-layout">
        <aside class="context-card">
          <header class="context-card__header">
            <div class="stack">
              <span class="eyebrow">People Directory</span>
              <h3 class="title-md">联系人</h3>
            </div>
            <span class="badge">${filtered.length}</span>
          </header>
          <div class="context-card__body stack">
            <input
              id="contact-filter-input"
              class="search-field"
              placeholder="搜索名字、账号、组织"
              value="${escapeHtml(state.contactFilter)}"
            />
            <div class="list">
              ${filtered
                .map(
                  (contact) => `
                    <button
                      class="list-item ${activeContact && activeContact.id === contact.id ? "active" : ""}"
                      data-action="navigate"
                      data-route="/contacts/profile/${contact.id}"
                    >
                      ${renderAvatar(contact.name, contact.tone, "")}
                      <div class="list-item__main">
                        <div class="list-item__row">
                          <p class="list-item__title">${escapeHtml(contact.name)}</p>
                          <span class="badge">${escapeHtml(contact.status)}</span>
                        </div>
                        <p class="list-item__summary">${escapeHtml(contact.title)}</p>
                        <p class="list-item__note">${escapeHtml(contact.note)}</p>
                      </div>
                    </button>
                  `,
                )
                .join("")}
            </div>
          </div>
        </aside>

        <section class="stage-card">
          <header class="stage-card__header">
            <div class="row">
              ${activeContact ? renderAvatar(activeContact.name, activeContact.tone, "large") : ""}
              <div class="stack">
                <h3 class="title-md">${escapeHtml(activeContact ? activeContact.name : "暂无联系人")}</h3>
                <p class="body-sm">${escapeHtml(activeContact ? `${activeContact.title} · ${activeContact.zone}` : "")}</p>
              </div>
            </div>
            <div class="button-row" style="grid-template-columns: repeat(2, minmax(0, max-content));">
              ${
                activeContact
                  ? `<button class="button secondary" data-action="open-direct-chat" data-contact-id="${activeContact.id}">发消息</button>`
                  : ""
              }
              <button class="button primary" data-action="navigate" data-route="/contacts/add">添加好友</button>
            </div>
          </header>
          <div class="stage-card__body stack lg">
            ${
              activeContact
                ? `
                  <div class="metric-grid">
                    <article class="metric-card">
                      <p class="meta">账号</p>
                      <p class="metric-card__value">${escapeHtml(activeContact.username)}</p>
                    </article>
                    <article class="metric-card">
                      <p class="meta">状态</p>
                      <p class="metric-card__value">${escapeHtml(activeContact.status)}</p>
                    </article>
                    <article class="metric-card">
                      <p class="meta">组织</p>
                      <p class="metric-card__value">${escapeHtml(activeContact.zone)}</p>
                    </article>
                  </div>
                  <article class="settings-section stack">
                    <h4 class="title-sm">联系信息与备注</h4>
                    <p class="body-md">${escapeHtml(activeContact.note)}</p>
                    <div class="divider"></div>
                    <div class="row space-between">
                      <span>个人标签</span>
                      <span class="chip">${escapeHtml(activeContact.zone)}</span>
                    </div>
                    <div class="row space-between">
                      <span>推荐入口</span>
                      <span class="meta">聊天 / 协作文件 / 群组邀请</span>
                    </div>
                  </article>
                  <article class="settings-section stack">
                    <h4 class="title-sm">推荐下一步</h4>
                    <div class="button-row" style="grid-template-columns: repeat(3, minmax(0, 1fr));">
                      <button class="button secondary" data-action="open-direct-chat" data-contact-id="${activeContact.id}">发消息</button>
                      <button class="button secondary" data-action="preset-group-member" data-contact-id="${activeContact.id}">拉进建群</button>
                      <button class="button secondary" data-action="navigate" data-route="/groups/settings/${data.groups[0].id}">共享群设置</button>
                    </div>
                  </article>
                `
                : '<div class="empty-state">没有匹配的联系人。</div>'
            }
          </div>
        </section>
      </section>
    `;
  }

  function renderFriendRequests() {
    const incoming = data.friendRequests.filter((item) => item.type === "incoming");
    const outgoing = data.friendRequests.filter((item) => item.type === "outgoing");
    return `
      <section class="settings-layout layout-main-first">
        <section class="stage-card">
          <header class="stage-card__header">
            <div class="stack">
              <span class="eyebrow">Incoming</span>
              <h3 class="title-md">收到的好友申请</h3>
            </div>
            <span class="badge">${incoming.filter((item) => item.status === "pending").length}</span>
          </header>
          <div class="stage-card__body">
            <div class="list">
              ${
                incoming.length
                  ? incoming
                      .map(
                        (request) => `
                          <div class="list-item">
                            ${renderAvatar(request.name, request.tone, "")}
                            <div class="list-item__main">
                              <div class="list-item__row">
                                <p class="list-item__title">${escapeHtml(request.name)}</p>
                                <span class="badge ${request.status === "accepted" ? "success" : request.status === "rejected" ? "danger" : ""}">${escapeHtml(request.status)}</span>
                              </div>
                              <p class="list-item__summary">${escapeHtml(request.title)}</p>
                              <p class="list-item__note">${escapeHtml(request.message)}</p>
                              <div class="button-row" style="grid-template-columns: repeat(2, minmax(0, max-content)); margin-top: 12px;">
                                <button class="button secondary" data-action="reject-request" data-request-id="${request.id}">拒绝</button>
                                <button class="button primary" data-action="accept-request" data-request-id="${request.id}">通过</button>
                              </div>
                            </div>
                          </div>
                        `,
                      )
                      .join("")
                  : '<div class="empty-state compact">当前没有待处理的好友申请。</div>'
              }
            </div>
          </div>
        </section>
        <aside class="context-card">
          <header class="context-card__header">
            <div class="stack">
              <span class="eyebrow">Outgoing</span>
              <h3 class="title-md">我发出的申请</h3>
            </div>
          </header>
          <div class="context-card__body">
            <div class="list">
              ${
                outgoing.length
                  ? outgoing
                      .map(
                        (request) => `
                          <div class="list-item">
                            ${renderAvatar(request.name, request.tone, "")}
                            <div class="list-item__main">
                              <div class="list-item__row">
                                <p class="list-item__title">${escapeHtml(request.name)}</p>
                                <span class="badge">${escapeHtml(request.status)}</span>
                              </div>
                              <p class="list-item__summary">${escapeHtml(request.title)}</p>
                              <p class="list-item__note">${escapeHtml(request.message)}</p>
                            </div>
                          </div>
                        `,
                      )
                      .join("")
                  : '<div class="empty-state compact">你还没有发出新的好友申请。</div>'
              }
            </div>
          </div>
        </aside>
      </section>
    `;
  }

  function renderAddFriend() {
    const keyword = state.friendSearch.trim().toLowerCase();
    const filtered = data.searchUsers.filter((user) => {
      if (!keyword) return true;
      return (
        user.name.toLowerCase().includes(keyword) ||
        user.username.toLowerCase().includes(keyword) ||
        user.title.toLowerCase().includes(keyword) ||
        user.city.toLowerCase().includes(keyword)
      );
    });
    const relationSummary = {
      pendingIncoming: filtered.filter((user) => user.relation === "pending_incoming").length,
      pendingOutgoing: filtered.filter((user) => user.relation === "pending_outgoing").length,
      available: filtered.filter((user) => user.relation === "none").length,
    };
    return `
      <section class="settings-layout layout-main-first">
        <section class="stage-card">
          <header class="stage-card__header">
            <div class="stack">
              <span class="eyebrow">Search User</span>
              <h3 class="title-md">搜索并添加好友</h3>
            </div>
          </header>
          <div class="stage-card__body stack lg">
            <article class="hero">
              <div class="hero-grid">
                <div class="stack">
                  <h3 class="title-lg">把“找人 + 申请 + 状态反馈”压缩成一条顺畅路径。</h3>
                  <p class="body-md">搜索结果要足够清楚：头像、职能、城市、当前关系状态与下一步动作一屏说明白。</p>
                </div>
                <div class="stack">
                  <label class="stack">
                    <span class="meta">关键词</span>
                    <input
                      id="friend-search-input"
                      class="search-field"
                      placeholder="输入名字、账号、城市或岗位"
                      value="${escapeHtml(state.friendSearch)}"
                    />
                  </label>
                  <label class="stack">
                    <span class="meta">打招呼文案</span>
                    <textarea id="friend-note-input" class="textarea">${escapeHtml(state.friendNote)}</textarea>
                  </label>
                </div>
              </div>
            </article>

            <div class="metric-grid">
              <article class="metric-card">
                <p class="meta">候选结果</p>
                <p class="metric-card__value">${filtered.length}</p>
              </article>
              <article class="metric-card">
                <p class="meta">待我处理</p>
                <p class="metric-card__value">${relationSummary.pendingIncoming}</p>
              </article>
              <article class="metric-card">
                <p class="meta">可直接添加</p>
                <p class="metric-card__value">${relationSummary.available}</p>
              </article>
            </div>

            <div class="search-result-grid">
              ${filtered.length
                ? filtered.map((user) => renderSearchUserItem(user)).join("")
                : '<div class="empty-state">没有匹配结果，试试输入更短的关键词。</div>'}
            </div>
          </div>
        </section>

        <aside class="context-card">
          <header class="context-card__header">
            <div class="stack">
              <span class="eyebrow">Flow Tips</span>
              <h3 class="title-md">设计要求</h3>
            </div>
          </header>
          <div class="context-card__body stack">
            <div class="helper-note">结果卡片不做杂乱信息堆叠，只保留决策必须字段。</div>
            <div class="helper-note">申请动作始终明确区分：未添加、等待对方、等待我处理、已是好友。</div>
            <div class="helper-note">点击“添加好友”会弹出轻量确认层，不再让操作跳来跳去。</div>
            <article class="preview-card stack">
              <h4 class="title-sm">状态分布</h4>
              <div class="list">
                <div class="list-item">
                  <div class="list-item__main">
                    <div class="list-item__row">
                      <p class="list-item__title">待我处理</p>
                      <span class="badge">${relationSummary.pendingIncoming}</span>
                    </div>
                    <p class="list-item__summary">收到申请后可以直接通过并生成私聊入口。</p>
                  </div>
                </div>
                <div class="list-item">
                  <div class="list-item__main">
                    <div class="list-item__row">
                      <p class="list-item__title">等待对方</p>
                      <span class="badge">${relationSummary.pendingOutgoing}</span>
                    </div>
                    <p class="list-item__summary">保持静态反馈，不再把状态藏进详情页。</p>
                  </div>
                </div>
              </div>
            </article>
          </div>
        </aside>
      </section>
    `;
  }

  function renderSearchUserItem(user) {
    return `
      <article class="search-result stack">
        <div class="row space-between">
          <div class="row">
            ${renderAvatar(user.name, user.tone, "")}
            <div class="stack">
              <h4 class="title-sm">${escapeHtml(user.name)}</h4>
              <p class="body-sm">${escapeHtml(user.username)} · ${escapeHtml(user.title)}</p>
            </div>
          </div>
          <span class="badge">${escapeHtml(relationLabel(user.relation))}</span>
        </div>
        <div class="row space-between">
          <p class="meta">${escapeHtml(user.city)}</p>
          <div class="button-row" style="grid-template-columns: repeat(2, minmax(0, max-content));">
            ${
              user.relation === "none"
                ? `<button class="button primary" data-action="open-request-modal" data-user-id="${user.id}">添加好友</button>`
                : ""
            }
            ${
              user.relation === "pending_incoming"
                ? `<button class="button primary" data-action="accept-by-user-id" data-user-id="${user.id}">立即通过</button>`
                : ""
            }
            ${
              user.relation === "pending_outgoing"
                ? `<button class="button secondary" disabled>等待对方处理</button>`
                : ""
            }
            ${
              user.relation !== "none"
                ? `<button class="button secondary" data-action="navigate" data-route="/contacts/requests">查看申请</button>`
                : ""
            }
          </div>
        </div>
      </article>
    `;
  }

  function renderGroupsRoute(route) {
    if (route.subview === "create") {
      return renderCreateGroup();
    }
    if (route.subview === "settings") {
      return renderGroupSettings(route.groupId || state.activeGroupId);
    }
    return renderGroupOverview();
  }

  function renderGroupOverview() {
    const groups = data.groups;
    return `
      <section class="group-layout">
        <aside class="context-card">
          <header class="context-card__header">
            <div class="stack">
              <span class="eyebrow">Group Spaces</span>
              <h3 class="title-md">群组列表</h3>
            </div>
            <span class="badge">${groups.length}</span>
          </header>
          <div class="context-card__body">
            <div class="list">
              ${groups
                .map(
                  (group) => `
                    <button class="list-item" data-action="navigate" data-route="/groups/settings/${group.id}">
                      ${renderAvatar(group.name, "violet", "")}
                      <div class="list-item__main">
                        <div class="list-item__row">
                          <p class="list-item__title">${escapeHtml(group.name)}</p>
                          <span class="badge">${group.memberCount}</span>
                        </div>
                        <p class="list-item__summary">${escapeHtml(group.notice)}</p>
                      </div>
                    </button>
                  `,
                )
                .join("")}
            </div>
          </div>
        </aside>
        <section class="stage-card">
          <header class="stage-card__header">
            <div class="stack">
              <span class="eyebrow">Architecture</span>
              <h3 class="title-md">群组页面的重构重点</h3>
            </div>
          </header>
          <div class="stage-card__body stack lg">
            <div class="card-grid">
              <article class="extension-card stack">
                <h4 class="title-sm">信息集中</h4>
                <p class="body-sm">公告、规则、权限、入群方式、禁言模式不再散落在多个入口。</p>
              </article>
              <article class="extension-card stack">
                <h4 class="title-sm">成员可控</h4>
                <p class="body-sm">管理员、禁言、申请、操作日志全部使用同一视觉结构。</p>
              </article>
              <article class="extension-card stack">
                <h4 class="title-sm">上下文统一</h4>
                <p class="body-sm">从群详情、聊天右栏、搜索结果都能进入同一套群管理视图。</p>
              </article>
            </div>
            <button class="button primary" data-action="navigate" data-route="/groups/create">开始创建群聊</button>
          </div>
        </section>
      </section>
    `;
  }

  function renderCreateGroup() {
    const selectedIds = Array.from(state.createGroupMembers);
    const selectedContacts = data.contacts.filter((contact) => selectedIds.includes(contact.id));
    const candidateKeyword = state.groupMemberFilter.trim().toLowerCase();
    const candidateContacts = data.contacts.filter((contact) => {
      if (!candidateKeyword) return true;
      return (
        contact.name.toLowerCase().includes(candidateKeyword) ||
        contact.title.toLowerCase().includes(candidateKeyword) ||
        contact.zone.toLowerCase().includes(candidateKeyword)
      );
    });
    const onlineCount = selectedContacts.filter((contact) => contact.status !== "离开").length;
    const previewMessageAuthor = selectedContacts[0] || data.currentUser;
    return `
      <section class="group-layout">
        <section class="stage-card">
          <header class="stage-card__header">
            <div class="stack">
              <span class="eyebrow">Create Group</span>
              <h3 class="title-md">用“群目的 + 成员选择 + 规则预览”替代空白表单</h3>
            </div>
          </header>
          <div class="stage-card__body stack lg">
            <label class="stack">
              <span class="meta">群聊名称</span>
              <input id="group-name-input" class="input" value="${escapeHtml(state.createGroupName)}" />
            </label>
            <article class="settings-section stack">
              <div class="row space-between">
                <h4 class="title-sm">已选成员 (${selectedContacts.length})</h4>
                <button class="button secondary" data-action="clear-group-members">清空</button>
              </div>
              <div class="chip-row">
                ${selectedContacts.length
                  ? selectedContacts
                      .map((contact) => `<span class="chip active">${escapeHtml(contact.name)}</span>`)
                      .join("")
                  : '<span class="helper-note">至少选择 1 位好友，原型会自动创建群聊和会话。</span>'}
              </div>
            </article>
            <article class="settings-section stack">
              <h4 class="title-sm">选择好友</h4>
              <input
                id="group-member-search-input"
                class="search-field"
                placeholder="搜索名字、岗位或分组"
                value="${escapeHtml(state.groupMemberFilter)}"
              />
              <div class="list">
                ${candidateContacts.length
                  ? candidateContacts
                  .map(
                    (contact) => `
                      <label class="list-item">
                        <input
                          type="checkbox"
                          data-action="toggle-group-member"
                          data-contact-id="${contact.id}"
                          ${state.createGroupMembers.has(contact.id) ? "checked" : ""}
                        />
                        ${renderAvatar(contact.name, contact.tone, "")}
                        <div class="list-item__main">
                          <p class="list-item__title">${escapeHtml(contact.name)}</p>
                          <p class="list-item__summary">${escapeHtml(contact.title)}</p>
                        </div>
                      </label>
                    `,
                  )
                  .join("")
                  : '<div class="empty-state compact">没有匹配的好友，换个关键词再试。</div>'}
              </div>
            </article>
            <div class="button-row" style="grid-template-columns: repeat(2, minmax(0, 1fr));">
              <button class="button secondary" data-action="navigate" data-route="/groups">返回群组</button>
              <button class="button primary" data-action="create-group">创建并进入聊天</button>
            </div>
          </div>
        </section>
        <aside class="context-card">
          <header class="context-card__header">
            <div class="stack">
              <span class="eyebrow">Preview</span>
              <h3 class="title-md">群聊预览</h3>
            </div>
          </header>
          <div class="context-card__body stack lg">
            <div class="hero-preview stack">
              <h4 class="title-sm">${escapeHtml(state.createGroupName || "未命名群聊")}</h4>
              <p class="body-sm">默认会附带欢迎公告、群规则入口与上下文工作区。</p>
              <div class="chip-row">
                <span class="chip active">公告</span>
                <span class="chip">规则</span>
                <span class="chip">文件</span>
                <span class="chip">成员</span>
              </div>
            </div>
            <div class="metric-grid">
              <article class="metric-card">
                <p class="meta">预计成员</p>
                <p class="metric-card__value">${selectedContacts.length + 1}</p>
              </article>
              <article class="metric-card">
                <p class="meta">预计在线</p>
                <p class="metric-card__value">${onlineCount + 1}</p>
              </article>
            </div>
            <article class="preview-card stack">
              <div class="row space-between">
                <h4 class="title-sm">默认策略</h4>
                <span class="badge">invite_only</span>
              </div>
              <div class="helper-note">新群默认采用邀请制、开放发言、欢迎公告 + 规则入口 + 文件区的组合。</div>
              <div class="list">
                <div class="list-item">
                  <div class="list-item__main">
                    <p class="list-item__title">群入口</p>
                    <p class="list-item__summary">会话顶部 / 聊天右栏 / 搜索结果都能进入群设置。</p>
                  </div>
                </div>
                <div class="list-item">
                  <div class="list-item__main">
                    <p class="list-item__title">内容结构</p>
                    <p class="list-item__summary">公告、规则、文件、成员全部走统一组件和状态样式。</p>
                  </div>
                </div>
              </div>
            </article>
            <article class="preview-card stack">
              <h4 class="title-sm">创建后首屏预览</h4>
              <div class="message-board">
                <div class="message-row self">
                  <div class="message-bubble">
                    已创建 ${escapeHtml(state.createGroupName || "新的群聊")}，请把今天的评审重点直接放进公告。
                    <div class="message-meta">
                      <span>刚刚</span>
                      <span>系统已同步</span>
                    </div>
                  </div>
                </div>
                <div class="message-row">
                  ${renderAvatar(previewMessageAuthor.name, previewMessageAuthor.tone || previewMessageAuthor.avatarTone || "mint", "")}
                  <div class="message-bubble">
                    收到，我会先补充规范页、聊天主线和扩展入口的评审结论。
                    <div class="message-meta">
                      <span>预计首条回复</span>
                      <span>${escapeHtml(previewMessageAuthor.name)}</span>
                    </div>
                  </div>
                </div>
              </div>
            </article>
            <article class="preview-card stack">
              <h4 class="title-sm">成员快照</h4>
              <div class="list">
                ${selectedContacts.length
                  ? selectedContacts
                      .map(
                        (contact) => `
                          <div class="list-item">
                            ${renderAvatar(contact.name, contact.tone, "")}
                            <div class="list-item__main">
                              <div class="list-item__row">
                                <p class="list-item__title">${escapeHtml(contact.name)}</p>
                                <span class="badge">${escapeHtml(contact.status)}</span>
                              </div>
                              <p class="list-item__summary">${escapeHtml(contact.title)}</p>
                            </div>
                          </div>
                        `,
                      )
                      .join("")
                  : '<div class="empty-state compact">还没有选择成员。</div>'}
              </div>
            </article>
          </div>
        </aside>
      </section>
    `;
  }

  function renderGroupSettings(groupId) {
    const group = findGroup(groupId) || data.groups[0];
    if (!group) {
      return '<div class="empty-state">没有可用的群设置数据。</div>';
    }
    state.activeGroupId = group.id;

    return `
      <section class="settings-layout layout-main-first">
        <section class="stage-card">
          <header class="stage-card__header">
            <div class="row">
              ${renderAvatar(group.name, "violet", "large")}
              <div class="stack">
                <h3 class="title-md">${escapeHtml(group.name)}</h3>
                <p class="body-sm">${group.memberCount} 成员 · ${group.onlineCount} 在线</p>
              </div>
            </div>
            <button class="button secondary" data-action="navigate" data-route="/chat/${group.chatId}">返回聊天</button>
          </header>
          <div class="stage-card__body stack lg">
            <article class="settings-section stack">
              <div class="row space-between">
                <h4 class="title-sm">群公告</h4>
                <span class="badge success">同步显示在聊天右栏</span>
              </div>
              <p class="body-md">${escapeHtml(group.notice)}</p>
            </article>

            <article class="settings-section stack">
              <div class="row space-between">
                <h4 class="title-sm">群规则</h4>
                <span class="badge">${group.rules.length}</span>
              </div>
              <ul class="kicker-list">
                ${group.rules.map((rule) => `<li>${escapeHtml(rule)}</li>`).join("")}
              </ul>
            </article>

            <article class="settings-section stack">
              <div class="row space-between">
                <h4 class="title-sm">加入与发言策略</h4>
                <button class="button secondary" data-action="toggle-group-policy" data-group-id="${group.id}">
                  切换策略
                </button>
              </div>
              <div class="metric-grid">
                <div class="metric-card">
                  <p class="meta">加入方式</p>
                  <p class="metric-card__value">${escapeHtml(group.joinPolicy)}</p>
                </div>
                <div class="metric-card">
                  <p class="meta">禁言模式</p>
                  <p class="metric-card__value">${escapeHtml(group.muteMode)}</p>
                </div>
              </div>
            </article>
          </div>
        </section>

        <aside class="context-card">
          <header class="context-card__header">
            <div class="stack">
              <span class="eyebrow">Admin Surface</span>
              <h3 class="title-md">高级入口</h3>
            </div>
          </header>
          <div class="context-card__body stack">
            <button class="list-item" data-action="show-toast" data-message="管理员管理页将在正式重构中继续展开。">
              <div class="list-item__main">
                <p class="list-item__title">管理员与角色</p>
                <p class="list-item__summary">任命、移除、权限映射</p>
              </div>
            </button>
            <button class="list-item" data-action="show-toast" data-message="入群申请页将在正式重构中挂到这里。">
              <div class="list-item__main">
                <p class="list-item__title">入群申请</p>
                <p class="list-item__summary">审批流、黑名单、补充问答</p>
              </div>
            </button>
            <button class="list-item" data-action="show-toast" data-message="操作日志页将在正式重构中挂到这里。">
              <div class="list-item__main">
                <p class="list-item__title">操作日志</p>
                <p class="list-item__summary">删除、禁言、权限变更审计</p>
              </div>
            </button>
          </div>
        </aside>
      </section>
    `;
  }

  function renderSearchRoute() {
    const results = searchMessages(state.searchQuery);
    return `
      <section class="search-layout layout-main-first">
        <section class="stage-card">
          <header class="stage-card__header">
            <div class="stack">
              <span class="eyebrow">Search Results</span>
              <h3 class="title-md">${state.searchQuery ? `搜索“${escapeHtml(state.searchQuery)}”` : "输入关键词搜索消息"}</h3>
            </div>
            <span class="badge">${results.length}</span>
          </header>
          <div class="stage-card__body stack lg">
            <input
              id="message-search-input"
              class="search-field"
              placeholder="输入关键词，例如 设计、群、原型、公告"
              value="${escapeHtml(state.searchQuery)}"
            />
            <div class="list">
              ${results.length
                ? results
                    .map(
                      (item) => `
                        <button
                          class="list-item"
                          data-action="jump-to-message"
                          data-chat-id="${item.chat.id}"
                          data-message-id="${item.message.id}"
                        >
                          ${renderAvatar(item.message.senderName, item.message.senderTone || "mint", "")}
                          <div class="list-item__main">
                            <div class="list-item__row">
                              <p class="list-item__title">${escapeHtml(item.chat.name)}</p>
                              <span class="meta">${escapeHtml(item.message.time)}</span>
                            </div>
                            <p class="list-item__summary">${escapeHtml(item.message.content)}</p>
                            <p class="list-item__note">${escapeHtml(item.message.senderName)} · ${escapeHtml(item.chat.type)}</p>
                          </div>
                        </button>
                      `,
                    )
                    .join("")
                : '<div class="empty-state">还没有匹配结果，试着输入 “设计” 或 “群”。</div>'}
            </div>
          </div>
        </section>
        <aside class="context-card">
          <header class="context-card__header">
            <div class="stack">
              <span class="eyebrow">Why This Matters</span>
              <h3 class="title-md">搜索页设计目标</h3>
            </div>
          </header>
          <div class="context-card__body stack">
            <div class="helper-note">搜索页不应只给结果，而要保留会话、发送者、时间和跳转上下文。</div>
            <div class="helper-note">未来可扩展到文件、成员、公告、操作日志的统一检索。</div>
          </div>
        </aside>
      </section>
    `;
  }

  function renderLabOverview() {
    return `
      <section class="discover-layout layout-main-first">
        <section class="stage-card">
          <header class="stage-card__header">
            <div class="stack">
              <span class="eyebrow">Capability Horizon</span>
              <h3 class="title-md">从即时通讯延展到协作操作系统</h3>
            </div>
          </header>
          <div class="stage-card__body stack lg">
            <article class="hero">
              <div class="hero-grid">
                <div class="stack">
                  <h3 class="title-lg">IM 不应该只停留在发消息。</h3>
                  <p class="body-md">
                    未来扩展位统一使用同一套视觉语言和上下文结构，让“通话、AI、文件、自动化”自然嵌入当前会话体系，而不是另起一套产品。
                  </p>
                </div>
                <div class="chip-row">
                  <span class="chip active">Calls</span>
                  <span class="chip">AI</span>
                  <span class="chip">Files</span>
                  <span class="chip">Flows</span>
                </div>
              </div>
            </article>
            <article class="settings-section stack">
              <div class="row space-between">
                <h4 class="title-sm">接入路径</h4>
                <span class="badge">3 steps</span>
              </div>
              <div class="timeline">
                <div class="timeline-item">
                  <span class="meta">01</span>
                  <div class="helper-note">会话顶部动作区：先给用户“进入扩展”的直观入口。</div>
                </div>
                <div class="timeline-item">
                  <span class="meta">02</span>
                  <div class="helper-note">聊天右栏上下文：把通话、AI、文件和自动化放进当前会话对象之下。</div>
                </div>
                <div class="timeline-item">
                  <span class="meta">03</span>
                  <div class="helper-note">搜索与通知回流：扩展结果仍然能回跳到原始消息和群组空间。</div>
                </div>
              </div>
            </article>
            <div class="extension-grid">
              ${data.extensions
                .map(
                  (item) => `
                    <button class="extension-card stack" data-action="navigate" data-route="${item.route}">
                      <div class="row space-between">
                        <h4 class="title-sm">${escapeHtml(item.title)}</h4>
                        <span class="badge">${escapeHtml(item.status)}</span>
                      </div>
                      <p class="body-sm">${escapeHtml(item.summary)}</p>
                      <ul class="kicker-list">
                        ${item.bullets.map((bullet) => `<li>${escapeHtml(bullet)}</li>`).join("")}
                      </ul>
                    </button>
                  `,
                )
                .join("")}
            </div>
            <div class="card-grid">
              <article class="extension-card stack">
                <h4 class="title-sm">统一导航</h4>
                <p class="body-sm">未来扩展不再拆出独立产品壳，而是挂回统一工作台导航。</p>
              </article>
              <article class="extension-card stack">
                <h4 class="title-sm">统一 token</h4>
                <p class="body-sm">继续沿用现在的颜色、间距、动效、圆角，避免信息流断层。</p>
              </article>
              <article class="extension-card stack">
                <h4 class="title-sm">统一返回路径</h4>
                <p class="body-sm">每个模块都能回到消息、群聊、搜索或设置，不做死胡同页面。</p>
              </article>
            </div>
          </div>
        </section>
        <aside class="context-card">
          <header class="context-card__header">
            <div class="stack">
              <span class="eyebrow">Expansion Rules</span>
              <h3 class="title-md">扩展规则</h3>
            </div>
          </header>
          <div class="context-card__body stack">
            <div class="helper-note">扩展能力不新增新配色体系，继续使用主应用 token。</div>
            <div class="helper-note">所有扩展页面都应从会话上下文进入，而不是孤立应用。</div>
            <div class="helper-note">未来即使独立收费，也应该保留统一导航和返回路径。</div>
            <article class="preview-card stack">
              <h4 class="title-sm">状态分布</h4>
              <div class="list">
                ${data.extensions
                  .map(
                    (item) => `
                      <div class="list-item">
                        <div class="list-item__main">
                          <div class="list-item__row">
                            <p class="list-item__title">${escapeHtml(item.title)}</p>
                            <span class="badge">${escapeHtml(item.status)}</span>
                          </div>
                          <p class="list-item__summary">${escapeHtml(item.summary)}</p>
                        </div>
                      </div>
                    `,
                  )
                  .join("")}
              </div>
            </article>
          </div>
        </aside>
      </section>
    `;
  }

  function renderLabDetail(moduleId) {
    const module = data.extensions.find((item) => item.id === moduleId);
    if (!module) {
      return renderLabOverview();
    }
    return `
      <section class="settings-layout layout-main-first">
        <section class="stage-card">
          <header class="stage-card__header">
            <div class="stack">
              <span class="eyebrow">Future Module</span>
              <h3 class="title-md">${escapeHtml(module.title)}</h3>
            </div>
            <span class="badge">${escapeHtml(module.status)}</span>
          </header>
          <div class="stage-card__body stack lg">
            <article class="hero">
              <div class="stack">
                <h3 class="title-lg">${escapeHtml(module.summary)}</h3>
                <p class="body-md">
                  这不是一个独立外链入口，而是未来挂入聊天右栏、消息操作菜单或顶部工作区的能力模块。
                </p>
              </div>
            </article>
            <div class="card-grid">
              ${module.bullets
                .map(
                  (bullet) => `
                    <article class="extension-card stack">
                      <h4 class="title-sm">${escapeHtml(bullet)}</h4>
                      <p class="body-sm">延续主 IM 的组件和动效规则，不额外制造视觉断层。</p>
                    </article>
                  `,
                )
                .join("")}
            </div>
          </div>
        </section>
        <aside class="context-card">
          <header class="context-card__header">
            <div class="stack">
              <span class="eyebrow">Entry Points</span>
              <h3 class="title-md">建议入口</h3>
            </div>
          </header>
          <div class="context-card__body stack">
            <div class="helper-note">聊天顶部操作区</div>
            <div class="helper-note">消息长按菜单</div>
            <div class="helper-note">群组上下文面板</div>
            <button class="button primary" data-action="navigate" data-route="/lab">返回扩展总览</button>
          </div>
        </aside>
      </section>
    `;
  }

  function renderSettingsRoute() {
    const enabledNotificationCount = Object.values(data.settings.notifications).filter(Boolean).length;
    const enabledPrivacyCount = Object.values(data.settings.privacy).filter(Boolean).length;
    return `
      <section class="settings-layout layout-main-first">
        <section class="stage-card">
          <header class="stage-card__header">
            <div class="row">
              ${renderAvatar(data.currentUser.name, data.currentUser.avatarTone, "large")}
              <div class="stack">
                <h3 class="title-md">${escapeHtml(data.currentUser.name)}</h3>
                <p class="body-sm">${escapeHtml(data.currentUser.role)} · ${escapeHtml(data.currentUser.status)}</p>
              </div>
            </div>
            <button class="button secondary" data-action="navigate" data-route="/auth/login">退出到登录页</button>
          </header>
          <div class="stage-card__body stack lg">
            <div class="metric-grid">
              <article class="metric-card">
                <p class="meta">当前主题</p>
                <p class="metric-card__value">${escapeHtml(state.theme)}</p>
              </article>
              <article class="metric-card">
                <p class="meta">界面密度</p>
                <p class="metric-card__value">${escapeHtml(state.density)}</p>
              </article>
              <article class="metric-card">
                <p class="meta">通知开关</p>
                <p class="metric-card__value">${enabledNotificationCount}</p>
              </article>
              <article class="metric-card">
                <p class="meta">隐私开关</p>
                <p class="metric-card__value">${enabledPrivacyCount}</p>
              </article>
            </div>

            <div class="card-grid">
              <article class="settings-section stack">
                <div class="row space-between">
                  <h4 class="title-sm">主题</h4>
                  <button class="button primary" data-action="toggle-theme">${state.theme === "dark" ? "切到浅色" : "切到暗色"}</button>
                </div>
                <p class="body-sm">当前主题：${escapeHtml(state.theme)}</p>
              </article>
              <article class="settings-section stack">
                <div class="row space-between">
                  <h4 class="title-sm">界面密度</h4>
                  <button class="button secondary" data-action="toggle-density">${state.density === "comfortable" ? "切到紧凑" : "切到舒适"}</button>
                </div>
                <p class="body-sm">当前密度：${escapeHtml(state.density)}</p>
              </article>
            </div>

            <div class="card-grid">
              <article class="settings-section stack">
                <h4 class="title-sm">通知</h4>
                <div class="row space-between">
                  <span>提及通知</span>
                  <button class="switch ${data.settings.notifications.mentions ? "active" : ""}" data-action="toggle-setting" data-domain="notifications" data-key="mentions"></button>
                </div>
                <div class="row space-between">
                  <span>每日摘要</span>
                  <button class="switch ${data.settings.notifications.summaries ? "active" : ""}" data-action="toggle-setting" data-domain="notifications" data-key="summaries"></button>
                </div>
                <div class="row space-between">
                  <span>文件提醒</span>
                  <button class="switch ${data.settings.notifications.fileAlerts ? "active" : ""}" data-action="toggle-setting" data-domain="notifications" data-key="fileAlerts"></button>
                </div>
              </article>
              <article class="settings-section stack">
                <h4 class="title-sm">隐私</h4>
                <div class="row space-between">
                  <span>已读回执</span>
                  <button class="switch ${data.settings.privacy.readReceipt ? "active" : ""}" data-action="toggle-setting" data-domain="privacy" data-key="readReceipt"></button>
                </div>
                <div class="row space-between">
                  <span>正在输入状态</span>
                  <button class="switch ${data.settings.privacy.typingStatus ? "active" : ""}" data-action="toggle-setting" data-domain="privacy" data-key="typingStatus"></button>
                </div>
                <div class="row space-between">
                  <span>自动下载媒体</span>
                  <button class="switch ${data.settings.privacy.autoDownloadMedia ? "active" : ""}" data-action="toggle-setting" data-domain="privacy" data-key="autoDownloadMedia"></button>
                </div>
              </article>
            </div>

            <article class="settings-section stack">
              <div class="row space-between">
                <h4 class="title-sm">实时预览</h4>
                <span class="badge">${escapeHtml(state.theme)} / ${escapeHtml(state.density)}</span>
              </div>
              <div class="card-grid">
                <div class="preview-card stack">
                  <p class="meta">通知预览</p>
                  <div class="list-item">
                    ${renderAvatar("Ops Copilot", "violet", "")}
                    <div class="list-item__main">
                      <div class="list-item__row">
                        <p class="list-item__title">Ops Copilot</p>
                        <span class="badge">${data.settings.notifications.mentions ? "提醒开" : "提醒关"}</span>
                      </div>
                      <p class="list-item__summary">已根据当前主题与密度刷新通知卡片样式。</p>
                    </div>
                  </div>
                </div>
                <div class="preview-card stack">
                  <p class="meta">消息预览</p>
                  <div class="message-board">
                    <div class="message-row self">
                      <div class="message-bubble">
                        当前这页不只是设置项列表，而是整个原型的视觉开关面板。
                        <div class="message-meta">
                          <span>现在</span>
                          <span>${data.settings.privacy.readReceipt ? "已读回执开启" : "已读回执关闭"}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </article>
          </div>
        </section>
        <aside class="context-card">
          <header class="context-card__header">
            <div class="stack">
              <span class="eyebrow">Spec Hooks</span>
              <h3 class="title-md">这页的作用</h3>
            </div>
          </header>
          <div class="context-card__body stack">
            <div class="helper-note">设置页不仅是功能堆积页，也是主题、密度、通知策略的实时演示面板。</div>
            <div class="helper-note">切换主题和密度后，整个原型会同步变化，便于评审不同视觉方案。</div>
            <article class="preview-card stack">
              <h4 class="title-sm">持久化说明</h4>
              <div class="helper-note">主题、密度以及设置开关会写入 localStorage，刷新页面后仍然保留。</div>
            </article>
          </div>
        </aside>
      </section>
    `;
  }

  function renderChatListItem(chat, active) {
    const unread = chat.unread > 0 ? `<span class="badge danger">${chat.unread}</span>` : `<span class="meta">${escapeHtml(chat.lastTime)}</span>`;
    return `
      <button
        class="list-item ${active ? "active" : ""}"
        data-action="navigate"
        data-route="/chat/${chat.id}"
      >
        ${renderAvatar(chat.name, chat.avatarTone, "")}
        <div class="list-item__main">
          <div class="list-item__row">
            <p class="list-item__title">${escapeHtml(chat.name)}</p>
            ${unread}
          </div>
          <p class="list-item__summary">${escapeHtml(chat.lastMessage)}</p>
          <div class="row wrap">
            ${chat.tags.map((tag) => `<span class="chip">${escapeHtml(tag)}</span>`).join("")}
          </div>
        </div>
      </button>
    `;
  }

  function renderAvatar(name, tone, sizeClass) {
    const label = initials(name);
    const toneClass = toneClassMap[tone] || "";
    return `<span class="avatar ${toneClass} ${sizeClass || ""}" aria-hidden="true">${escapeHtml(label)}</span>`;
  }

  function renderModal() {
    if (!state.modal) {
      return '<div class="modal-root" id="modal-root" aria-hidden="true"></div>';
    }

    if (state.modal.type === "send-request") {
      const user = data.searchUsers.find((item) => item.id === state.modal.userId);
      if (!user) {
        return '<div class="modal-root" id="modal-root" aria-hidden="true"></div>';
      }
      return `
        <div class="modal-root active" id="modal-root" aria-hidden="false">
          <div class="modal-card stack lg">
            <div class="stack">
              <span class="eyebrow">Friend Request</span>
              <h3 class="title-md">发送好友申请给 ${escapeHtml(user.name)}</h3>
              <p class="body-md">原型里保留一个轻量确认层，避免把用户直接甩进另一个页面。</p>
            </div>
            <div class="helper-note">${escapeHtml(state.friendNote)}</div>
            <div class="button-row" style="grid-template-columns: repeat(2, minmax(0, 1fr));">
              <button class="button secondary" data-action="close-modal">取消</button>
              <button class="button primary" data-action="confirm-send-request" data-user-id="${user.id}">确认发送</button>
            </div>
          </div>
        </div>
      `;
    }

    return '<div class="modal-root" id="modal-root" aria-hidden="true"></div>';
  }

  function renderToasts() {
    return `
      <div class="toast-stack">
        ${state.toasts
          .map(
            (toast) => `
              <div class="toast">
                <p class="title-sm" style="margin-bottom: 6px;">${escapeHtml(toast.title)}</p>
                <p class="body-sm">${escapeHtml(toast.message)}</p>
              </div>
            `,
          )
          .join("")}
      </div>
    `;
  }

  function bindInputs(route) {
    const chatDraft = document.getElementById("chat-draft");
    if (chatDraft) {
      chatDraft.addEventListener("input", (event) => {
        state.chatDrafts[state.activeChatId] = event.target.value;
      });
    }

    const contactFilter = document.getElementById("contact-filter-input");
    if (contactFilter) {
      contactFilter.addEventListener("input", (event) => {
        state.contactFilter = event.target.value;
        render();
      });
    }

    const chatFilter = document.getElementById("chat-filter-input");
    if (chatFilter) {
      chatFilter.addEventListener("input", (event) => {
        state.chatFilter = event.target.value;
        render();
      });
    }

    const friendSearch = document.getElementById("friend-search-input");
    if (friendSearch) {
      friendSearch.addEventListener("input", (event) => {
        state.friendSearch = event.target.value;
        render();
      });
    }

    const friendNote = document.getElementById("friend-note-input");
    if (friendNote) {
      friendNote.addEventListener("input", (event) => {
        state.friendNote = event.target.value;
      });
    }

    const groupName = document.getElementById("group-name-input");
    if (groupName) {
      groupName.addEventListener("input", (event) => {
        state.createGroupName = event.target.value;
        render();
      });
    }

    const groupMemberSearch = document.getElementById("group-member-search-input");
    if (groupMemberSearch) {
      groupMemberSearch.addEventListener("input", (event) => {
        state.groupMemberFilter = event.target.value;
        render();
      });
    }

    const messageSearch = document.getElementById("message-search-input");
    if (messageSearch) {
      messageSearch.addEventListener("input", (event) => {
        state.searchQuery = event.target.value;
        render();
      });
    }

    if (route.section === "search" && !state.searchQuery) {
      state.searchQuery = "";
    }
  }

  function handleClick(event) {
    const target = event.target.closest("[data-action]");
    if (!target) return;

    const action = target.getAttribute("data-action");

    if (action === "navigate") {
      const route = target.getAttribute("data-route");
      if (route) navigate(route);
      return;
    }

    if (action === "prototype-login") {
      navigate("/chat/" + state.activeChatId);
      showToast("已进入原型", "当前登录流程为 mock，重点是演示 UI 和交互。");
      return;
    }

    if (action === "send-message") {
      sendMessage();
      return;
    }

    if (action === "simulate-reply") {
      simulateReply();
      return;
    }

    if (action === "increment-reaction") {
      incrementReaction(
        target.getAttribute("data-chat-id"),
        target.getAttribute("data-message-id"),
        target.getAttribute("data-emoji"),
      );
      return;
    }

    if (action === "open-request-modal") {
      state.modal = { type: "send-request", userId: target.getAttribute("data-user-id") };
      render();
      return;
    }

    if (action === "close-modal") {
      state.modal = null;
      render();
      return;
    }

    if (action === "confirm-send-request") {
      confirmSendRequest(target.getAttribute("data-user-id"));
      return;
    }

    if (action === "accept-request") {
      updateRequest(target.getAttribute("data-request-id"), "accepted");
      return;
    }

    if (action === "reject-request") {
      updateRequest(target.getAttribute("data-request-id"), "rejected");
      return;
    }

    if (action === "accept-by-user-id") {
      const request = data.friendRequests.find((item) => item.userId === target.getAttribute("data-user-id") && item.type === "incoming");
      if (request) {
        updateRequest(request.id, "accepted");
      }
      return;
    }

    if (action === "clear-group-members") {
      state.createGroupMembers.clear();
      render();
      return;
    }

    if (action === "create-group") {
      createGroup();
      return;
    }

    if (action === "toggle-group-policy") {
      toggleGroupPolicy(target.getAttribute("data-group-id"));
      return;
    }

    if (action === "jump-to-message") {
      const chatId = target.getAttribute("data-chat-id");
      state.highlightMessageId = target.getAttribute("data-message-id");
      if (chatId) {
        navigate("/chat/" + chatId, { preserveHighlight: true });
      }
      return;
    }

    if (action === "set-message-search") {
      state.searchQuery = target.getAttribute("data-preset") || "";
      navigate("/search");
      return;
    }

    if (action === "toggle-theme") {
      state.theme = state.theme === "dark" ? "light" : "dark";
      data.settings.theme = state.theme;
      persistUiState();
      render();
      return;
    }

    if (action === "toggle-density") {
      state.density = state.density === "comfortable" ? "compact" : "comfortable";
      data.settings.density = state.density;
      persistUiState();
      render();
      return;
    }

    if (action === "toggle-setting") {
      const domain = target.getAttribute("data-domain");
      const key = target.getAttribute("data-key");
      if (domain && key && data.settings[domain]) {
        data.settings[domain][key] = !data.settings[domain][key];
        persistUiState();
        render();
      }
      return;
    }

    if (action === "open-direct-chat") {
      const contactId = target.getAttribute("data-contact-id");
      if (contactId) {
        const chat = ensureDirectChat(contactId);
        navigate("/chat/" + chat.id);
      }
      return;
    }

    if (action === "preset-group-member") {
      const contactId = target.getAttribute("data-contact-id");
      if (contactId) {
        state.createGroupMembers.add(contactId);
        navigate("/groups/create");
      }
      return;
    }

    if (action === "insert-draft-token") {
      const token = target.getAttribute("data-token") || "";
      const existing = state.chatDrafts[state.activeChatId] || "";
      state.chatDrafts[state.activeChatId] = `${existing}${existing ? " " : ""}${token} `;
      render();
      return;
    }

    if (action === "show-toast") {
      showToast("原型说明", target.getAttribute("data-message") || "该能力将在正式重构阶段展开。");
      return;
    }
  }

  function handleChange(event) {
    const target = event.target;
    if (!target || target.getAttribute("data-action") !== "toggle-group-member") {
      return;
    }

    const contactId = target.getAttribute("data-contact-id");
    if (!contactId) return;

    if (target.checked) {
      state.createGroupMembers.add(contactId);
    } else {
      state.createGroupMembers.delete(contactId);
    }
    render();
  }

  function handleSubmit(event) {
    event.preventDefault();
  }

  function sendMessage() {
    const chat = findChat(state.activeChatId);
    if (!chat) return;
    const draft = (state.chatDrafts[chat.id] || "").trim();
    if (!draft) {
      showToast("发送失败", "先输入一条 mock 消息再发送。");
      return;
    }
    chat.messages.push({
      id: `m_${Date.now()}`,
      senderId: data.currentUser.id,
      senderName: data.currentUser.name,
      senderTone: data.currentUser.avatarTone,
      content: draft,
      time: "刚刚",
      self: true,
      status: "已送达",
      reactions: [],
    });
    chat.lastMessage = draft;
    chat.lastTime = "刚刚";
    chat.unread = 0;
    chat.sortKey = Date.now();
    state.chatDrafts[chat.id] = "";
    render();
    showToast("已发送", "消息已经写入 mock 会话流。");
  }

  function simulateReply() {
    const chat = findChat(state.activeChatId);
    if (!chat) return;
    const templates = [
      "收到，我会把这个入口在右侧上下文面板里再加强。",
      "这个信息层级可以，我建议把搜索结果的会话名再放大一点。",
      "OK，后续把文件协作页也纳入统一 token 即可。",
    ];
    const sender = contactListForChat(chat).find((item) => item.id !== data.currentUser.id) || data.contacts[0];
    chat.messages.push({
      id: `m_reply_${Date.now()}`,
      senderId: sender.id,
      senderName: sender.name,
      senderTone: sender.tone,
      content: templates[Math.floor(Math.random() * templates.length)],
      time: "刚刚",
      self: false,
      reactions: [{ emoji: "👍", count: 1 }],
    });
    chat.lastMessage = chat.messages[chat.messages.length - 1].content;
    chat.lastTime = "刚刚";
    chat.unread = 0;
    chat.sortKey = Date.now();
    render();
    showToast("模拟来消息", "新的消息从下往上进入列表，用来演示消息入场动画。");
  }

  function incrementReaction(chatId, messageId, emoji) {
    const chat = findChat(chatId);
    if (!chat) return;
    const message = chat.messages.find((item) => item.id === messageId);
    if (!message) return;
    if (!message.reactions) {
      message.reactions = [];
    }
    const reaction = message.reactions.find((item) => item.emoji === emoji);
    if (reaction) {
      reaction.count += 1;
    } else {
      message.reactions.push({ emoji: emoji || "👍", count: 1 });
    }
    render();
  }

  function confirmSendRequest(userId) {
    const user = data.searchUsers.find((item) => item.id === userId);
    if (!user) return;
    user.relation = "pending_outgoing";
    data.friendRequests.unshift({
      id: `fr_${Date.now()}`,
      type: "outgoing",
      userId: user.id,
      name: user.name,
      username: user.username,
      title: user.title,
      tone: user.tone,
      message: state.friendNote || "希望添加你为好友。",
      time: "刚刚",
      status: "sent",
    });
    state.modal = null;
    render();
    showToast("申请已发送", `已向 ${user.name} 发送好友申请。`);
  }

  function updateRequest(requestId, nextStatus) {
    const request = data.friendRequests.find((item) => item.id === requestId);
    if (!request) return;
    request.status = nextStatus;
    if (nextStatus === "accepted") {
      ensureContactFromRequest(request);
      ensureDirectChat(request.userId);
      showToast("已通过", `${request.name} 已进入联系人列表，并生成私聊入口。`);
    } else {
      showToast("已处理", `${request.name} 的申请已标记为 ${nextStatus}。`);
    }
    render();
  }

  function ensureContactFromRequest(request) {
    const existing = data.contacts.find((item) => item.id === request.userId);
    if (existing) return existing;
    const contact = {
      id: request.userId,
      name: request.name,
      username: request.username,
      title: request.title,
      status: "在线",
      tone: request.tone,
      note: "通过好友申请加入联系人列表。",
      zone: "新联系人",
    };
    data.contacts.unshift(contact);
    return contact;
  }

  function ensureDirectChat(contactId) {
    const contact = findContact(contactId) || data.searchUsers.find((item) => item.id === contactId);
    const existing = data.chats.find(
      (chat) => chat.type === "single" && chat.participants.includes(contactId),
    );
    if (existing) {
      state.activeChatId = existing.id;
      return existing;
    }
    const chat = {
      id: `c_${contactId}_${Date.now()}`,
      type: "single",
      name: contact.name,
      remark: "",
      participants: [data.currentUser.id, contact.id],
      avatarTone: contact.tone,
      unread: 0,
      pinned: false,
      muted: false,
      tags: ["新会话"],
      lastMessage: "新的私聊已创建。",
      lastTime: "刚刚",
      description: "由联系人详情或好友申请流直接创建的私聊入口。",
      metrics: {
        activeMembers: 2,
        todayMessages: 1,
        unreadMention: 0,
      },
      pinnedMessages: [],
      files: [],
      messages: [
        {
          id: `m_welcome_${Date.now()}`,
          senderId: contact.id,
          senderName: contact.name,
          senderTone: contact.tone,
          content: "你好，新的私聊已经就绪，后续可以继续走统一聊天界面。",
          time: "刚刚",
          self: false,
          reactions: [],
        },
      ],
      sortKey: Date.now(),
    };
    data.chats.unshift(chat);
    state.activeChatId = chat.id;
    return chat;
  }

  function createGroup() {
    const name = state.createGroupName.trim();
    if (!name) {
      showToast("创建失败", "请先输入群聊名称。");
      return;
    }
    if (state.createGroupMembers.size === 0) {
      showToast("创建失败", "至少选择 1 位好友。");
      return;
    }
    const groupId = `g_${Date.now()}`;
    const chatId = `c_group_${Date.now()}`;
    const group = {
      id: groupId,
      chatId,
      name,
      members: [data.currentUser.id].concat(Array.from(state.createGroupMembers)),
      notice: "欢迎来到新的设计协作群，这里会沉淀原型、讨论和任务。",
      rules: ["重要结论请固定在公告或 pinned 中。", "涉及视觉变更先回规范页确认。"],
      joinPolicy: "invite_only",
      muteMode: "free",
      memberCount: state.createGroupMembers.size + 1,
      onlineCount: state.createGroupMembers.size + 1,
      tags: ["新建群聊"],
    };
    const chat = {
      id: chatId,
      type: "group",
      name,
      remark: "",
      participants: group.members,
      avatarTone: "violet",
      unread: 0,
      pinned: false,
      muted: false,
      tags: ["新群"],
      lastMessage: "群聊已创建。",
      lastTime: "刚刚",
      description: "通过原型中的建群流程新创建的群组。",
      metrics: {
        activeMembers: group.onlineCount,
        todayMessages: 1,
        unreadMention: 0,
      },
      pinnedMessages: ["欢迎使用新的群聊信息架构。"],
      files: [],
      messages: [
        {
          id: `m_group_${Date.now()}`,
          senderId: data.currentUser.id,
          senderName: data.currentUser.name,
          senderTone: data.currentUser.avatarTone,
          content: "群聊已创建，接下来可以直接发消息、看公告和进入群设置。",
          time: "刚刚",
          self: true,
          status: "系统已同步",
          reactions: [],
        },
      ],
      sortKey: Date.now(),
    };

    data.groups.unshift(group);
    data.chats.unshift(chat);
    state.activeGroupId = groupId;
    state.activeChatId = chatId;
    state.createGroupName = "新设计评审群";
    state.createGroupMembers = new Set(["u_alice", "u_zoe"]);
    navigate("/chat/" + chatId);
    showToast("群聊已创建", `${name} 已加入群组和会话列表。`);
  }

  function toggleGroupPolicy(groupId) {
    const group = findGroup(groupId);
    if (!group) return;
    group.joinPolicy =
      group.joinPolicy === "invite_only"
        ? "review_required"
        : group.joinPolicy === "review_required"
          ? "public_with_guidelines"
          : "invite_only";
    group.muteMode =
      group.muteMode === "free"
        ? "admin_only"
        : group.muteMode === "admin_only"
          ? "owner_only"
          : "free";
    render();
    showToast("策略已切换", `${group.name} 的加入方式和禁言模式已更新。`);
  }

  function showToast(title, message) {
    state.toasts = [{ title, message }];
    render();
    window.clearTimeout(toastTimerId);
    toastTimerId = window.setTimeout(() => {
      state.toasts = [];
      render();
    }, 2200);
  }

  function applyBodyState() {
    document.body.setAttribute("data-theme", state.theme);
    document.body.setAttribute("data-density", state.density);
  }

  function sortedChats() {
    return data.chats
      .slice()
      .sort((left, right) => {
        if (left.pinned !== right.pinned) {
          return left.pinned ? -1 : 1;
        }
        return (right.sortKey || 0) - (left.sortKey || 0);
      });
  }

  function matchesChatFilter(chat) {
    if (!state.chatFilter.trim()) return true;
    const keyword = state.chatFilter.trim().toLowerCase();
    return (
      chat.name.toLowerCase().includes(keyword) ||
      chat.lastMessage.toLowerCase().includes(keyword) ||
      chat.tags.some((tag) => tag.toLowerCase().includes(keyword))
    );
  }

  function contactListForChat(chat) {
    return chat.participants
      .map((participantId) => {
        if (participantId === data.currentUser.id) {
          return {
            id: data.currentUser.id,
            name: data.currentUser.name,
            title: data.currentUser.role,
            tone: data.currentUser.avatarTone,
            status: data.currentUser.status,
          };
        }
        return findContact(participantId) || data.searchUsers.find((item) => item.id === participantId);
      })
      .filter(Boolean);
  }

  function searchMessages(query) {
    const keyword = query.trim().toLowerCase();
    if (!keyword) return [];
    const results = [];
    data.chats.forEach((chat) => {
      chat.messages.forEach((message) => {
        if (message.content.toLowerCase().includes(keyword)) {
          results.push({ chat, message });
        }
      });
    });
    return results;
  }

  function resolveGroupId(chat) {
    const group = data.groups.find((item) => item.chatId === chat.id);
    return group ? group.id : data.groups[0] ? data.groups[0].id : "";
  }

  function resolvePrimaryPeerContact(chat) {
    const peerId = chat.participants.find((participantId) => participantId !== data.currentUser.id);
    if (!peerId) return null;
    return findContact(peerId);
  }

  function renderChatContextAction(chat) {
    if (chat.type === "group") {
      return `<button class="button secondary" data-action="navigate" data-route="/groups/settings/${resolveGroupId(chat)}">群设置</button>`;
    }

    const peerContact = resolvePrimaryPeerContact(chat);
    if (!peerContact) {
      return '<span class="helper-note">当前是单聊会话。</span>';
    }

    return `<button class="button secondary" data-action="navigate" data-route="/contacts/profile/${peerContact.id}">联系人详情</button>`;
  }

  function relationLabel(relation) {
    const map = {
      none: "可添加",
      pending_incoming: "待我处理",
      pending_outgoing: "等待对方",
      friend: "已是好友",
    };
    return map[relation] || "未知状态";
  }

  function labTitle(moduleId) {
    const module = data.extensions.find((item) => item.id === moduleId);
    return module ? module.title : "未来扩展";
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

  function initials(name) {
    const value = String(name || "").trim();
    if (!value) return "RC";
    const parts = value.split(/\s+/).filter(Boolean);
    if (parts.length === 1) {
      return value.slice(0, 2).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  function escapeHtml(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }
})();
