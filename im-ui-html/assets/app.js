(function bootstrapIMPrototype() {
  const source = window.RedcodeIMPrototypeData;
  const root = document.getElementById("app");
  const STORAGE_KEY = "redcode-im-ui-prototype/design-source-v2";
  const GROUP_MEMBER_PREVIEW_LIMIT = 5;
  const DEVICE_FRAMES = {
    "iphone-12-pro": {
      label: "iPhone 12 Pro",
    },
    "iphone-16-pro-max": {
      label: "iPhone 16 Pro Max",
    },
    "pixel-8-pro": {
      label: "Pixel 8 Pro",
    },
  };
  const EMOJI_CATALOG = [
    { id: "smile", fallback: "😀", label: "开心", motion: "bounce" },
    { id: "laugh", fallback: "😂", label: "大笑", motion: "bounce" },
    { id: "handshake", fallback: "🤝", label: "握手", motion: "swing" },
    { id: "fire", fallback: "🔥", label: "火焰", motion: "pulse" },
    { id: "check", fallback: "✅", label: "完成", motion: "pulse" },
    { id: "target", fallback: "🎯", label: "目标", motion: "launch" },
    { id: "paperclip", fallback: "📎", label: "附件", motion: "swing" },
    { id: "rocket", fallback: "🚀", label: "火箭", motion: "launch" },
    { id: "eyes", fallback: "👀", label: "关注", motion: "pulse" },
    { id: "idea", fallback: "💡", label: "想法", motion: "launch" },
    { id: "clap", fallback: "👏", label: "鼓掌", motion: "bounce" },
    { id: "raise", fallback: "🙌", label: "庆祝", motion: "bounce" },
  ];
  const EMOJI_BY_FALLBACK = new Map(EMOJI_CATALOG.map((emoji) => [emoji.fallback, emoji]));
  const SHAREABLE_FAVORITES = [
    {
      id: "fav_mobile-review",
      kind: "文本",
      title: "移动端重构评审要点",
      summary: "先收敛输入区、操作面板与会话页面的层级。",
      icon: "bookmark",
    },
    {
      id: "fav_design-source",
      kind: "文件",
      title: "RedCode IM 2.0 设计源说明.pdf",
      summary: "PDF · 2.8 MB · 今天更新",
      icon: "file",
    },
    {
      id: "fav_sync-notes",
      kind: "链接",
      title: "产品评审会议纪要",
      summary: "docs.redcode.im/reviews/mobile-im",
      icon: "link",
    },
  ];
  const MOMENT_COMMENTS = {
    mom_1001: [
      { id: "mc_1001_1", author: "Zoe Wang", tone: "violet", time: "6 分钟前", text: "输入区和底部导航的节奏现在统一多了，尤其是评论较长时，正文自然换行后仍然能和头像、发布时间保持清晰的阅读顺序。" },
      { id: "mc_1001_2", author: "Ian Chen", tone: "mint", time: "3 分钟前", text: "设计图里的状态切换也可以一起补进评审，重点检查从列表点赞后进入详情、展开点赞用户，再返回列表时状态是否仍然一致。" },
      { id: "mc_1001_3", author: "Mia Sun", tone: "amber", time: "2 分钟前", text: "三图横排的信息密度现在更适合快速浏览。" },
      { id: "mc_1001_4", author: "Nora", tone: "mint", time: "1 分钟前", text: "详情页和列表页共用图片规则会更容易维护。后续接入真实图片时，只需要替换缩略图资源和加载状态，不应该重新定义每种数量的网格结构。" },
      { id: "mc_1001_5", author: "Olivia", tone: "violet", time: "刚刚", text: "点赞状态从列表带到详情的反馈也很自然。" },
      { id: "mc_1001_6", author: "Jules", tone: "amber", time: "刚刚", text: "评论区可以继续保持这种连续阅读节奏，不过还要覆盖更小的设备尺寸，确保三行以上的评论不会把右侧时间挤出内容区，也不会被底部输入栏遮住。" },
      { id: "mc_1001_7", author: "Evan", tone: "mint", time: "刚刚", text: "底部输入不会遮住最后一条评论，体验不错。" },
      { id: "mc_1001_8", author: "Lena", tone: "violet", time: "刚刚", text: "这一版的信息层级已经清楚很多。" },
    ],
    mom_1002: [
      { id: "mc_1002_1", author: "Alice Li", tone: "amber", time: "42 分钟前", text: "同城兴趣标签适合先从轻量筛选开始。" },
      { id: "mc_1002_2", author: "Mia Sun", tone: "violet", time: "18 分钟前", text: "活动群入口可以和附近的人保持同一套权限边界。" },
    ],
    mom_1003: [
      { id: "mc_1003_1", author: "Zoe Wang", tone: "violet", time: "昨天", text: "先保留统一入口，后续扩展会更稳。" },
    ],
  };
  const MOMENT_LIKER_NAMES = [
    "Zoe Wang", "Ian Chen", "Mia Sun", "Nora", "Olivia", "Jules", "Evan", "Lena", "Alice Li",
    "Leo", "Ava", "Noah", "Emma", "Liam", "Sophia", "Mason", "Isla", "Lucas", "Ella", "James",
    "Chloe", "Henry", "Grace", "Daniel", "Lily", "Oscar",
  ];

  if (!source || !root) {
    return;
  }

  const demoData = JSON.parse(JSON.stringify(source));
  const emptyData = createEmptyPreviewData(demoData);
  let data = demoData;
  const state = {
    theme: "light",
    density: "regular",
    deviceFrame: "iphone-12-pro",
    activeChatId: data.chats[0] ? data.chats[0].id : null,
    activeContactId: data.contacts[0] ? data.contacts[0].id : null,
    activeGroupId: data.groups[0] ? data.groups[0].id : null,
    activeSpecTab: "components",
    savedGroupIds: new Set(["g_launch"]),
    expandedGroupMemberIds: new Set(),
    chatFilter: "",
    contactFilter: "",
    friendSearch: "",
    friendSearchPending: false,
    friendRequestTab: "incoming",
    friendNote: "你好，我想一起评审 RedCode IM 的移动端重构方案。",
    scanTorchOn: false,
    scanStatus: "scanning",
    scanSimulationCount: 0,
    nearbyFilter: "all",
    greetedNearbyIds: new Set(),
    searchQuery: "",
    groupMemberFilter: "",
    createGroupName: "",
    createGroupMembers: new Set(["u_alice", "u_zoe"]),
    chatDrafts: {},
    composerPanel: null,
    composerPicker: null,
    likedMomentIds: new Set(),
    expandedMomentLikeIds: new Set(),
    momentCommentDrafts: {},
    momentComments: {},
    highlightMessageId: null,
    recentMessageId: null,
    messageMenu: null,
    messageEditor: null,
    replyTargets: {},
    forwardSelection: new Set(),
    forwardQuery: "",
    messageReadsTab: "read",
    chatActionsChatId: null,
    navigationStack: [],
    pendingNavigationPath: null,
    toasts: [],
    actionDialog: null,
    actionDialogReturnAction: null,
    contactActionSheetContactId: null,
    contactRemarkEditorContactId: null,
    contactRemarkDraft: "",
    settingsSheetKey: null,
    callSession: null,
    orderCursor: 1000,
  };

  function createEmptyPreviewData(sourceData) {
    const emptyPreviewData = JSON.parse(JSON.stringify(sourceData));
    emptyPreviewData.chats = [];
    emptyPreviewData.contacts = [];
    emptyPreviewData.friendRequests = [];
    emptyPreviewData.searchUsers = [];
    emptyPreviewData.groups = [];
    emptyPreviewData.discover.moments = [];
    emptyPreviewData.discover.nearbyPeople = [];
    emptyPreviewData.discover.games = [];

    const momentsEntry = emptyPreviewData.discover.entries.find((item) => item.id === "moments");
    if (momentsEntry) {
      momentsEntry.badge = "0";
      momentsEntry.summary = "还没有朋友动态。";
    }

    return emptyPreviewData;
  }

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
    reply: [
      '<path d="m9 17-5-5 5-5" />',
      '<path d="M4 12h9a5 5 0 0 1 5 5v1" />',
    ],
    chevronRight: ['<path d="m9.25 5.5 6.5 6.5-6.5 6.5" />'],
    chevronDown: ['<path d="m5.5 9.25 6.5 6.5 6.5-6.5" />'],
    chevronUp: ['<path d="m5.5 14.75 6.5-6.5 6.5 6.5" />'],
    search: [
      '<circle cx="10.7" cy="10.7" r="4.95" />',
      '<path d="M14.35 14.35 18.65 18.65" />',
    ],
    close: [
      '<path d="m7.25 7.25 9.5 9.5" />',
      '<path d="m16.75 7.25-9.5 9.5" />',
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
    heart: [
      '<path d="M12 19.3S4.7 14.95 4.7 8.85A4.05 4.05 0 0 1 12 6.4a4.05 4.05 0 0 1 7.3 2.45c0 6.1-7.3 10.45-7.3 10.45Z" />',
    ],
    comment: [
      '<path d="M5.15 17.35 4.5 20l2.85-.82A7.65 7.65 0 1 0 4.35 16Z" />',
      '<path d="M8.25 11.9h7.5M8.25 14.75h4.6" />',
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
    edit: [
      '<path d="m5.35 18.65 1.1-3.9L15.7 5.5a1.8 1.8 0 0 1 2.55 2.55l-9.25 9.25-3.65 1.35Z" />',
      '<path d="m13.9 7.3 2.8 2.8" />',
    ],
    phone: [
      '<path d="M8.15 4.95 6.7 5.7c-.72.37-1.08 1.2-.87 1.98 1.25 4.62 4.95 8.32 9.57 9.57.78.21 1.61-.15 1.98-.87l.75-1.45a1.54 1.54 0 0 0-.53-1.95l-2.05-1.38a1.54 1.54 0 0 0-1.93.18l-.95.95a10.1 10.1 0 0 1-2.44-2.44l.95-.95a1.54 1.54 0 0 0 .18-1.93L10.1 5.48a1.54 1.54 0 0 0-1.95-.53Z" />',
    ],
    video: [
      '<rect x="4.8" y="7.15" width="10.75" height="9.7" rx="2.3" />',
      '<path d="m15.55 10.15 3.65-2.05v7.8l-3.65-2.05" />',
    ],
    image: [
      '<rect x="3.5" y="4.5" width="17" height="15" rx="2.25" />',
      '<circle cx="8.5" cy="9" r="1.5" />',
      '<path d="m20.5 15-4.25-4.25L6.5 19.5" />',
    ],
    file: [
      '<path d="M6.5 3.5h7l4 4v13h-11Z" />',
      '<path d="M13.5 3.5v4h4" />',
      '<path d="M9.5 12h5M9.5 15.5h5" />',
    ],
    camera: [
      '<path d="M8.25 6.25 9.4 4.5h5.2l1.15 1.75h2.5a2.25 2.25 0 0 1 2.25 2.25v8.75a2.25 2.25 0 0 1-2.25 2.25H5.75a2.25 2.25 0 0 1-2.25-2.25V8.5a2.25 2.25 0 0 1 2.25-2.25Z" />',
      '<circle cx="12" cy="12.75" r="3.25" />',
    ],
    flashlight: [
      '<path d="M8.25 3.75h7.5l-1.15 5.1H9.4Z" />',
      '<path d="M9.4 8.85h5.2l1.15 2.4-2.15 9h-3.2l-2.15-9Z" />',
      '<path d="M10.15 12.1h3.7" />',
    ],
    mapPin: [
      '<path d="M19 10.25c0 5-7 10.25-7 10.25S5 15.25 5 10.25a7 7 0 1 1 14 0Z" />',
      '<circle cx="12" cy="10.25" r="2.25" />',
    ],
    contactCard: [
      '<rect x="3.5" y="5" width="17" height="14" rx="2.25" />',
      '<circle cx="9" cy="10" r="2" />',
      '<path d="M5.9 15c.45-1.75 1.5-2.6 3.1-2.6s2.65.85 3.1 2.6M14.5 9h3M14.5 12h3" />',
    ],
    bookmark: [
      '<path d="M6.5 4.5h11v16L12 17l-5.5 3.5Z" />',
    ],
    link: [
      '<path d="M10.2 13.8a4 4 0 0 0 5.65.02l2.45-2.45a4 4 0 0 0-5.66-5.66l-1.4 1.4" />',
      '<path d="M13.8 10.2a4 4 0 0 0-5.65-.02L5.7 12.63a4 4 0 0 0 5.66 5.66l1.4-1.4" />',
    ],
    microphone: [
      '<rect x="9" y="3.5" width="6" height="11" rx="3" />',
      '<path d="M5.75 11.5a6.25 6.25 0 0 0 12.5 0M12 17.75v3" />',
    ],
    speaker: [
      '<path d="M5 9.5h3L12.5 6v12L8 14.5H5Z" />',
      '<path d="M15.5 9a4.25 4.25 0 0 1 0 6M17.75 6.75a7.4 7.4 0 0 1 0 10.5" />',
    ],
    cameraOff: [
      '<path d="m3.5 3.5 17 17" />',
      '<path d="M10.2 7.15h-3.1A2.3 2.3 0 0 0 4.8 9.45v5.1a2.3 2.3 0 0 0 2.3 2.3h8.45v-2.3M15.55 10.15l3.65-2.05v7.8l-1.4-.8" />',
    ],
    switchCamera: [
      '<path d="M7.5 7.5A6.5 6.5 0 0 1 18 9l1.5-1.5M19.5 7.5V4.75" />',
      '<path d="M16.5 16.5A6.5 6.5 0 0 1 6 15l-1.5 1.5M4.5 16.5v2.75" />',
      '<circle cx="12" cy="12" r="2.25" />',
    ],
    phoneOff: [
      '<path d="m4 4 16 16" />',
      '<path d="M8.15 4.95 6.7 5.7c-.72.37-1.08 1.2-.87 1.98.35 1.3.9 2.52 1.62 3.62M10.23 10.29c.68.93 1.51 1.76 2.44 2.44l.95-.95a1.54 1.54 0 0 1 1.93-.18l2.05 1.38a1.54 1.54 0 0 1 .53 1.95l-.75 1.45c-.37.72-1.2 1.08-1.98.87a15.7 15.7 0 0 1-2.75-1.06" />',
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
    puzzle: [
      '<path d="M4.5 5.25h5.05a2.45 2.45 0 1 1 4.9 0h5.05v5.05a2.45 2.45 0 1 0 0 4.9v4.55h-5.05a2.45 2.45 0 1 1-4.9 0H4.5V15.2a2.45 2.45 0 1 0 0-4.9Z" />',
    ],
    music: [
      '<path d="M9.25 17.15a2.75 2.75 0 1 1-2.75-2.75h2.75Z" />',
      '<path d="M18.25 14.65a2.75 2.75 0 1 1-2.75-2.75h2.75Z" />',
      '<path d="M9.25 14.4V6.25l9-2v7.65M9.25 9.2l9-2" />',
    ],
    flag: [
      '<path d="M6.25 20.25V4.1" />',
      '<path d="M6.25 5.1c3.25-2.1 5.45 2.1 9.1 0l2.4-1.15v8.2l-2.4 1.15c-3.65 2.1-5.85-2.1-9.1 0" />',
    ],
    checkCircle: [
      '<circle cx="12" cy="12" r="8.25" />',
      '<path d="m8.4 12.2 2.35 2.35 4.9-5.1" />',
    ],
    alertTriangle: [
      '<path d="M10.25 4.8 3.9 16.05a2 2 0 0 0 1.75 2.95h12.7a2 2 0 0 0 1.75-2.95L13.75 4.8a2 2 0 0 0-3.5 0Z" />',
      '<path d="M12 9v4.25M12 16.4h.01" />',
    ],
    trash: [
      '<path d="M5.5 7.2h13M9.1 7.2V4.75h5.8V7.2M7.3 7.2l.65 12h8.1l.65-12" />',
      '<path d="M10 10.5v5.25M14 10.5v5.25" />',
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
    activatePreviewData(route);
    syncSelection(route);
    const activeRoute = resolveMobilePreviewRoute(route);
    state.settingsSheetKey = null;
    state.messageMenu = null;
    state.messageEditor = null;
    state.chatActionsChatId = null;
    if (activeRoute.section !== "chat-detail") {
      state.composerPanel = null;
      state.composerPicker = null;
    }
    if (
      state.callSession &&
      (activeRoute.section !== "chat-detail" || activeRoute.chatId !== state.callSession.chatId)
    ) {
      state.callSession = null;
    }
    render();
  });

  let resizeRenderTimer = 0;
  window.addEventListener("resize", () => {
    window.clearTimeout(resizeRenderTimer);
    resizeRenderTimer = window.setTimeout(render, 120);
  });

  root.addEventListener("click", handleClick);
  root.addEventListener("keydown", handleKeydown);
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
      if (Array.isArray(persisted.savedGroupIds)) {
        state.savedGroupIds = new Set(
          persisted.savedGroupIds.filter((groupId) => Boolean(findGroup(groupId))),
        );
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
          savedGroupIds: Array.from(state.savedGroupIds),
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

  function isEmptyPreviewDataMode(route) {
    return route.section === "mobile-design" && route.previewDataMode === "empty";
  }

  function activatePreviewData(route) {
    data = isEmptyPreviewDataMode(route) ? emptyData : demoData;
    data.settings.theme = state.theme;
    data.settings.density = state.density;
  }

  function mobilePreviewPath(previewPath, dataMode) {
    const safePath = previewPath && previewPath.startsWith("/") ? previewPath : "/chats";
    const prefix = dataMode === "empty" ? "/mobile-design/empty" : "/mobile-design";
    return `${prefix}${safePath}`;
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
      const previewDataMode = previewSegments[0] === "empty" ? "empty" : "demo";
      const previewAppSegments = previewDataMode === "empty" ? previewSegments.slice(1) : previewSegments;
      const previewPath = previewAppSegments.length ? `/${previewAppSegments.join("/")}` : "/chats";
      const nestedRoute = parseRoute(previewPath);
      const previewRoute = ["entry", "spec", "pc-design", "mobile-design", "not-found"].includes(nestedRoute.section)
        ? { section: "chats" }
        : nestedRoute;

      return {
        section: "mobile-design",
        previewDataMode,
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
      if (segments[2] === "message" && segments[4] === "reads") {
        return {
          section: "message-reads",
          chatId: segments[1] || state.activeChatId,
          messageId: segments[3] || null,
        };
      }
      if (segments[2] === "forward") {
        return {
          section: "message-forward",
          chatId: segments[1] || state.activeChatId,
          messageId: segments[3] || null,
        };
      }
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
        if (segments[3] === "report") {
          return { section: "contact-report", contactId: segments[2] || state.activeContactId };
        }
        return { section: "contact-profile", contactId: segments[2] || state.activeContactId };
      }
      return { section: "contacts" };
    }

    if (segments[0] === "discover") {
      if (segments[1] === "moments") {
        if (segments[2]) {
          return { section: "discover-moment-detail", momentId: segments[2] };
        }
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
      if (segments[1] && segments[2]) {
        const groupSections = {
          members: "group-members",
          admins: "group-admins",
          "join-requests": "group-join-requests",
          invite: "group-invite",
          rules: "group-rules",
          mutes: "group-mutes",
          "operation-logs": "group-operation-logs",
        };
        if (segments[2] === "invitations" && segments[3]) {
          return { section: "group-invitation", groupId: segments[1], invitationId: segments[3] };
        }
        if (groupSections[segments[2]]) {
          return { section: groupSections[segments[2]], groupId: segments[1] };
        }
      }
      return { section: "groups" };
    }

    if (segments[0] === "stickers") {
      if (segments[1] === "store") {
        return { section: "sticker-store" };
      }
      if (segments[1] === "packs") {
        return { section: "sticker-pack", packId: segments[2] || null };
      }
      return { section: "stickers" };
    }

    if (segments[0] === "reports" && segments[1] === "new") {
      return { section: "report-create" };
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
      const dedicatedSettingsSections = {
        feedback: "settings-feedback",
        password: "settings-password",
        deactivate: "settings-deactivate",
        version: "settings-version",
      };
      if (segments[1] === "profile" && segments[2] === "edit") {
        return { section: "settings-profile-edit" };
      }
      if (dedicatedSettingsSections[segments[1]]) {
        return { section: dedicatedSettingsSections[segments[1]] };
      }
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
      "message-reads",
      "message-forward",
      "contacts",
      "contact-requests",
      "contact-add",
      "contact-profile",
      "contact-report",
      "discover",
      "discover-moments",
      "discover-moment-detail",
      "discover-scan",
      "discover-nearby",
      "discover-games",
      "groups",
      "group-create",
      "group-settings",
      "group-members",
      "group-admins",
      "group-join-requests",
      "group-invite",
      "group-invitation",
      "group-rules",
      "group-mutes",
      "group-operation-logs",
      "stickers",
      "sticker-store",
      "sticker-pack",
      "report-create",
      "search",
      "lab",
      "mine",
      "settings",
      "settings-detail",
      "settings-feedback",
      "settings-profile-edit",
      "settings-password",
      "settings-deactivate",
      "settings-version",
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

    const previewPrefix = currentRoute.previewDataMode === "empty" ? "/mobile-design/empty" : "/mobile-design";
    return `${previewPrefix}${requestedPath}`;
  }

  function navigate(path, options = {}) {
    closeContactProfileOverlay();
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
    activatePreviewData(route);
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
    bindScrollHeaders();
    focusActionDialog();
  }

  function bindScrollHeaders() {
    root.querySelectorAll(".runtime-topbar-scroll, .runtime-directory-scroll").forEach((scrollContainer) => {
      const header = scrollContainer.previousElementSibling;
      const supportsScrollState =
        header instanceof HTMLElement &&
        (header.classList.contains("runtime-header--compact") || header.classList.contains("runtime-header--directory"));

      if (!supportsScrollState) {
        return;
      }

      const updateScrollState = () => {
        const isScrolled = scrollContainer.scrollTop > 2;
        if (header.classList.contains("is-scrolled") !== isScrolled) {
          header.classList.toggle("is-scrolled", isScrolled);
        }
      };

      scrollContainer.addEventListener("scroll", updateScrollState, { passive: true });
      updateScrollState();
    });
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
    const previewDataMode = route.previewDataMode === "empty" ? "empty" : "demo";
    const demoPreviewPath = mobilePreviewPath(route.previewPath, "demo");
    const emptyPreviewPath = mobilePreviewPath(route.previewPath, "empty");

    return `
      <section class="mobile-preview-canvas" data-preview-data-mode="${previewDataMode}" aria-label="RedCode IM 移动端预览">
        <div class="mobile-preview-control-stack">
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
          <div class="mobile-preview-data-switcher" role="group" aria-label="预览数据状态">
            <button
              class="mobile-preview-data-switcher__item ${previewDataMode === "demo" ? "is-active" : ""}"
              type="button"
              data-action="navigate"
              data-route="${demoPreviewPath}"
              aria-pressed="${previewDataMode === "demo"}"
            >
              <span class="mobile-preview-data-switcher__indicator mobile-preview-data-switcher__indicator--demo" aria-hidden="true"></span>
              <span>演示数据</span>
            </button>
            <button
              class="mobile-preview-data-switcher__item ${previewDataMode === "empty" ? "is-active" : ""}"
              type="button"
              data-action="navigate"
              data-route="${emptyPreviewPath}"
              aria-pressed="${previewDataMode === "empty"}"
            >
              <span class="mobile-preview-data-switcher__indicator mobile-preview-data-switcher__indicator--empty" aria-hidden="true"></span>
              <span>空数据</span>
            </button>
          </div>
        </div>
        ${renderPhone(previewRoute, { devicePreview: true, dataMode: previewDataMode })}
      </section>
    `;
  }

  function renderPhone(route, options = {}) {
    const previewDataMode = options.dataMode === "empty" ? "empty" : "demo";
    const screenClasses = [
      "phone-screen",
      options.runtimeMode ? "phone-screen--runtime" : "",
      options.devicePreview ? "phone-screen--preview" : "",
      options.dataMode === "empty" ? "phone-screen--empty-data" : "",
    ]
      .filter(Boolean)
      .join(" ");
    const screen = `
      <div class="${screenClasses}" data-preview-data-mode="${previewDataMode}">
        ${options.runtimeMode ? "" : `
          <div class="phone-status-bar">
            <span>9:41</span>
            <span>5G · 87%</span>
          </div>
        `}
        ${renderRoute(route)}
        ${renderTabBar(route)}
        ${options.devicePreview ? renderToasts({ embedded: true }) : ""}
        ${renderContactProfileOverlay(route)}
        ${renderActionDialog()}
      </div>
    `;

    if (options.runtimeMode) {
      return `<section class="mobile-runtime" aria-label="移动端应用预览">${screen}</section>`;
    }

    if (options.devicePreview) {
      const deviceId = isSupportedDeviceFrame(state.deviceFrame) ? state.deviceFrame : "iphone-12-pro";
      const device = DEVICE_FRAMES[deviceId];
      const dataModeLabel = previewDataMode === "empty" ? "空数据" : "演示数据";

      return `
        <section
          class="phone-frame phone-frame--mobile-preview phone-frame--${deviceId}"
          data-device-frame="${deviceId}"
          data-preview-data-mode="${previewDataMode}"
          aria-label="${escapeHtml(device.label)} ${dataModeLabel}设备预览画布"
        >
          <span class="phone-frame__side-button phone-frame__side-button--action" aria-hidden="true"></span>
          <span class="phone-frame__side-button phone-frame__side-button--volume-up" aria-hidden="true"></span>
          <span class="phone-frame__side-button phone-frame__side-button--volume-down" aria-hidden="true"></span>
          <span class="phone-frame__side-button phone-frame__side-button--power" aria-hidden="true"></span>
          <div class="phone-frame__screen-clip">
            ${screen}
            <span class="phone-frame__home-indicator" aria-hidden="true"></span>
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
    if (route.section === "message-reads") {
      const chat = findChat(route.chatId);
      const message = findMessage(chat, route.messageId);
      if (!chat || !message) {
        return renderFallbackScreen("消息不存在", chat ? `/chat/${chat.id}` : "/chats");
      }
      return renderMessageReadsScreen(chat, message);
    }
    if (route.section === "message-forward") {
      const chat = findChat(route.chatId);
      const message = findMessage(chat, route.messageId);
      if (!chat || !message) {
        return renderFallbackScreen("消息不存在", chat ? `/chat/${chat.id}` : "/chats");
      }
      return renderMessageForwardScreen(chat, message);
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
    if (route.section === "discover-moment-detail") {
      return renderDiscoverMomentDetailScreen(route.momentId);
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
    if (route.section === "contact-report") {
      if (!findContact(route.contactId)) {
        return renderFallbackScreen("联系人不存在", "/contacts");
      }
      return renderCapabilityRouteScreen("举报用户", `/contacts/profile/${route.contactId}`, "请选择举报原因");
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
    if (route.section.startsWith("group-") && route.section !== "group-create") {
      return renderGroupCapabilityRouteScreen(route);
    }
    if (["stickers", "sticker-store", "sticker-pack"].includes(route.section)) {
      if (route.section === "sticker-pack" && !route.packId) {
        return renderFallbackScreen("贴纸包不存在", "/stickers/store");
      }
      const title = route.section === "sticker-store" ? "贴纸商店" : route.section === "sticker-pack" ? "贴纸包" : "我的贴纸";
      return renderCapabilityRouteScreen(title, route.section === "sticker-pack" ? "/stickers/store" : "/settings", "暂无贴纸");
    }
    if (route.section === "report-create") {
      return renderCapabilityRouteScreen("举报", "/mine", "请选择举报对象");
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
    if (route.section.startsWith("settings-")) {
      const settingsTitles = {
        "settings-feedback": "体验反馈",
        "settings-profile-edit": "编辑资料",
        "settings-password": "修改密码",
        "settings-deactivate": "注销账号",
        "settings-version": "版本更新",
      };
      return renderCapabilityRouteScreen(settingsTitles[route.section] || "设置", "/settings", "暂无内容");
    }
    return renderSpecScreen();
  }

  function renderScreenHeader(options) {
    const compact = options.variant === "compact";
    const directory = options.variant === "directory";
    const fallbackPath = options.backPath ? resolveBackFallbackPath(options.backPath) : null;
    const backButton = fallbackPath
      ? `
        <button
          class="runtime-icon-button runtime-icon-button--quiet ${compact ? "runtime-topbar__back" : ""}"
          type="button"
          data-action="go-back"
          data-fallback-route="${escapeHtml(fallbackPath)}"
          aria-label="返回"
        >
          ${renderIcon("back", "runtime-icon-button__glyph")}
        </button>
      `
      : "";

    const actions = options.actions && options.actions.length
      ? `<div class="screen-header__actions">${options.actions.join("")}</div>`
      : "";
    const mainContent = options.mainContent || `
        <div class="screen-header__main">
          <h2>${escapeHtml(options.title)}</h2>
          ${options.subtitle ? `<p>${escapeHtml(options.subtitle)}</p>` : ""}
        </div>
      `;

    return `
      <header class="screen-header runtime-header ${options.root ? "screen-header--root" : ""} ${compact ? "runtime-header--compact" : ""} ${directory ? "runtime-header--directory" : ""}">
        ${backButton}
        ${mainContent}
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
    const emojiSamples = EMOJI_CATALOG.slice(0, 6);

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
                <div class="emoji-grid emoji-grid--glyphs">
                  ${emojiSamples
                    .map(
                      (emoji) => `
                        <span class="emoji-grid__item" data-emoji-id="${emoji.id}">
                          <span class="emoji-grid__glyph" aria-hidden="true">${escapeHtml(emoji.fallback)}</span>
                        </span>
                      `,
                    )
                    .join("")}
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
        ${renderScreenHeader({
          title: "聊天",
          root: true,
          actions: [
            `<button class="runtime-icon-button runtime-icon-button--quiet" data-action="navigate" data-route="/search" aria-label="搜索消息">${renderIcon("search", "runtime-icon-button__glyph", "搜索")}</button>`,
            `<button class="runtime-icon-button runtime-icon-button--quiet" data-action="navigate" data-route="/groups/create" aria-label="创建群聊">${renderIcon("plus", "runtime-icon-button__glyph", "创建群聊")}</button>`,
          ],
        })}
        <div class="screen-scroll runtime-scroll">
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
    const group = chat.type === "group" ? findGroupByChatId(chat.id) : null;
    const unread = chat.unread > 0 ? `<span class="runtime-unread-badge">${chat.unread}</span>` : "";
    const context = chat.pinned
      ? "置顶"
      : chat.metrics?.unreadMention
      ? `@我 ${chat.metrics.unreadMention}`
      : chat.muted
      ? "已静音"
      : chat.type === "group"
      ? group
        ? `${group.memberCount} 人`
        : "群聊"
      : "";
    const contextLabel = context ? `<span class="runtime-conversation__context">${escapeHtml(context)}</span>` : "";
    const avatar = group
      ? renderGroupAvatar(group)
      : renderAvatar(chat.name, chat.avatarTone, "avatar--md");
    const presence = group
      ? ""
      : `<span class="runtime-conversation__presence ${chat.type === "group" ? "is-group" : chat.muted ? "is-muted" : "is-online"}"></span>`;

    return `
      <button
        class="runtime-conversation"
        data-action="navigate"
        data-route="/chat/${chat.id}"
      >
        <span class="runtime-conversation__avatar">
          ${avatar}
          ${presence}
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
    if (state.callSession?.chatId === chat.id) {
      return `
        <section class="screen screen--chat-detail runtime-chat-screen runtime-chat-screen--call-active">
          ${renderCallOverlay(chat)}
        </section>
      `;
    }
    const draft = state.chatDrafts[chat.id] || "";
    const replyTarget = findMessage(chat, state.replyTargets[chat.id]);
    const activePanel = state.composerPanel;
    const groupAnnouncement = group?.notice || "";
    const pinnedMessage = chat.pinnedMessages?.[0] || "";
    const contextualNote = groupAnnouncement || pinnedMessage;
    const isGroupAnnouncement = Boolean(groupAnnouncement);
    const contextualNoteAction = isGroupAnnouncement
      ? `data-action="navigate" data-route="/groups/settings/${group.id}"`
      : `data-action="show-hint" data-message="${escapeHtml(contextualNote)}"`;
    const contextualNoteLabel = isGroupAnnouncement ? "群公告" : "置顶消息";
    const contextualNoteMarkup = contextualNote
      ? `
        <button
          class="runtime-announcement ${isGroupAnnouncement ? "runtime-announcement--group" : "runtime-announcement--pinned"}"
          type="button"
          ${contextualNoteAction}
          aria-label="查看${contextualNoteLabel}"
        >
          <span class="runtime-announcement__label">${contextualNoteLabel}</span>
          <span class="runtime-announcement__text">${escapeHtml(contextualNote)}</span>
          ${renderIcon("chevronRight", "runtime-announcement__arrow")}
        </button>
      `
      : "";
    const fixedGroupAnnouncement = isGroupAnnouncement
      ? `
        <div class="runtime-chat-context" role="region" aria-label="群公告">
          ${contextualNoteMarkup}
        </div>
      `
      : "";
    const inFlowPinnedMessage = !isGroupAnnouncement && contextualNote ? contextualNoteMarkup : "";

    return `
      <section class="screen screen--chat-detail runtime-chat-screen ${activePanel ? "runtime-chat-screen--composer-panel-open" : ""}">
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
            `<button class="runtime-icon-button runtime-icon-button--quiet" type="button" data-action="open-chat-actions" data-chat-id="${chat.id}" aria-label="会话操作">${renderIcon("more", "runtime-icon-button__glyph")}</button>`,
          ].filter(Boolean),
        })}
        ${fixedGroupAnnouncement}
        <div class="screen-scroll runtime-scroll runtime-chat-scroll">
          ${inFlowPinnedMessage}
          <div class="runtime-message-list">
            ${renderMessageTimeline(chat)}
          </div>
        </div>
        <form class="runtime-composer" data-form="send-message" data-chat-id="${chat.id}">
          ${replyTarget ? `<div class="runtime-composer-reply"><span><small>回复 ${escapeHtml(replyTarget.self ? "自己" : replyTarget.senderName)}</small><strong>${escapeHtml(replyTarget.content)}</strong></span><button type="button" data-action="cancel-message-reply" data-chat-id="${chat.id}" aria-label="取消引用">${renderIcon("close", "runtime-composer-reply__icon")}</button></div>` : ""}
          <div class="runtime-composer__inner">
            <button
              class="runtime-composer__action ${activePanel === "emoji" ? "is-active" : ""}"
              type="button"
              data-action="toggle-composer-panel"
              data-panel="emoji"
              aria-controls="runtime-composer-panel"
              aria-expanded="${activePanel === "emoji"}"
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
              aria-controls="runtime-composer-panel"
              aria-expanded="${activePanel === "more"}"
              aria-label="更多操作"
            >
              ${renderIcon("plus", "runtime-composer__glyph", "更多操作")}
            </button>
            <button class="runtime-composer__send" type="submit" aria-label="发送消息">
              ${renderIcon("send", "runtime-composer__send-icon", "发送消息")}
            </button>
          </div>
        </form>
        ${renderComposerPanel(chat)}
        ${renderComposerPicker(chat)}
        ${renderMessageActionSheet(chat)}
        ${renderMessageEditor(chat)}
        ${renderChatActionSheet(chat)}
      </section>
    `;
  }

  function renderComposerPanel(chat) {
    const activePanel = state.composerPanel;
    const isOpen = activePanel === "emoji" || activePanel === "more";
    const emojis = EMOJI_CATALOG;
    const isGroup = chat.type === "group";
    const actions = [
      { label: "图片", message: "选择图片", icon: "image" },
      { label: "拍摄", message: "打开相机", icon: "camera" },
      { label: isGroup ? "语音会议" : "语音通话", callType: "voice", icon: "phone" },
      { label: isGroup ? "视频会议" : "视频通话", callType: "video", icon: "video" },
      { label: "文件", message: "选择文件", icon: "file" },
      { label: "位置", message: "发送位置", icon: "mapPin" },
      { label: "名片", picker: "contact-card", icon: "contactCard" },
      { label: "收藏", picker: "favorite", icon: "bookmark" },
    ];

    return `
      <section
        id="runtime-composer-panel"
        class="runtime-composer-panel ${activePanel === "emoji" ? "is-open runtime-composer-panel--emoji" : activePanel === "more" ? "is-open runtime-composer-panel--actions" : ""}"
        data-panel="${isOpen ? activePanel : "none"}"
        aria-hidden="${!isOpen}"
        ${isOpen ? "" : "inert"}
      >
        <div class="runtime-composer-panel__view runtime-composer-panel__view--emoji" aria-label="表情面板">
          <div class="emoji-grid">
            ${emojis
              .map(
                (emoji) => `
                  <button
                    class="emoji-grid__item"
                    type="button"
                    data-action="append-emoji"
                    data-emoji="${emoji.fallback}"
                    data-emoji-id="${emoji.id}"
                    aria-label="${emoji.label}表情"
                  >
                    <span class="emoji-grid__glyph emoji-grid__glyph--${emoji.motion}" aria-hidden="true">${escapeHtml(emoji.fallback)}</span>
                  </button>
                `,
              )
              .join("")}
          </div>
        </div>
        <div class="runtime-composer-panel__view runtime-composer-panel__view--actions" aria-label="更多操作面板">
          <div class="runtime-composer-actions">
            ${actions
              .map(
                (item) => `
                  <button
                    class="runtime-composer-action-card"
                    type="button"
                    data-action="${item.callType ? "start-call" : item.picker ? "open-composer-picker" : "show-hint"}"
                    ${
                      item.callType
                        ? `data-call-type="${item.callType}"`
                        : item.picker
                        ? `data-picker-type="${item.picker}"`
                        : `data-message="${item.message}"`
                    }
                  >
                    <span class="runtime-composer-action-card__icon">
                      ${renderIcon(item.icon, "runtime-composer-action-card__glyph")}
                    </span>
                    <span class="runtime-composer-action-card__label">${item.label}</span>
                  </button>
                `,
              )
              .join("")}
          </div>
        </div>
      </section>
    `;
  }

  function renderComposerPicker(chat) {
    const picker = state.composerPicker;
    if (!picker || picker.chatId !== chat.id) {
      return "";
    }

    const isContactPicker = picker.type === "contact-card";
    const title = isContactPicker ? "发送名片" : "发送收藏";
    const directContact = chat.type === "single" ? findDirectContact(chat) : null;
    const query = String(picker.query || "").trim().toLowerCase();
    const contacts = data.contacts.filter(
      (contact) =>
        contact.id !== directContact?.id &&
        (!query ||
          [contact.name, contact.title, contact.username].some((value) =>
            String(value || "").toLowerCase().includes(query),
          )),
    );
    const contactSections = groupContacts(contacts);
    const favoriteFilter = ["all", "文本", "文件", "链接"].includes(picker.filter) ? picker.filter : "all";
    const favorites = SHAREABLE_FAVORITES.filter(
      (favorite) => favoriteFilter === "all" || favorite.kind === favoriteFilter,
    );
    const content = isContactPicker
      ? `
          <div class="runtime-composer-picker__toolbar" role="search" aria-label="搜索联系人名片">
            <label class="runtime-search-field">
              ${renderIcon("search", "runtime-search-field__icon", "搜索联系人")}
              <input
                id="composer-picker-search"
                value="${escapeHtml(picker.query || "")}"
                placeholder="搜索联系人"
                aria-label="搜索联系人"
                aria-controls="composer-picker-results"
                autocomplete="off"
              />
            </label>
          </div>
          <div class="screen-scroll runtime-scroll runtime-composer-picker__scroll">
            <div class="runtime-composer-picker__content" id="composer-picker-results">
              ${
                contactSections.length
                  ? contactSections
                      .map(
                        (section) => `
                          <section class="runtime-composer-picker__section">
                            <div class="runtime-composer-picker__section-heading">${escapeHtml(section.tag)}</div>
                            <div class="runtime-composer-picker__list">
                              ${section.items.map(renderComposerContactRow).join("")}
                            </div>
                          </section>
                        `,
                      )
                      .join("")
                  : renderEmptyState("没有匹配的联系人", "换个名字或职位试试。")
              }
            </div>
          </div>
        `
      : `
          <div class="runtime-composer-picker__toolbar">
            <div class="runtime-composer-picker__filters" role="tablist" aria-label="收藏类型">
              ${[
                ["all", "全部"],
                ["文本", "文本"],
                ["文件", "文件"],
                ["链接", "链接"],
              ]
                .map(
                  ([value, label]) => `
                    <button
                      class="runtime-composer-picker__filter ${favoriteFilter === value ? "is-active" : ""}"
                      type="button"
                      role="tab"
                      aria-selected="${favoriteFilter === value}"
                      data-action="set-composer-picker-filter"
                      data-filter="${value}"
                    >
                      ${label}
                    </button>
                  `,
                )
                .join("")}
            </div>
          </div>
          <div class="screen-scroll runtime-scroll runtime-composer-picker__scroll">
            <div class="runtime-composer-picker__content">
              <section class="runtime-composer-picker__section">
                <div class="runtime-composer-picker__section-heading">
                  <span>收藏内容</span>
                  <span>${favorites.length} 条</span>
                </div>
                <div class="runtime-composer-picker__list">
                  ${favorites.map(renderComposerFavoriteRow).join("")}
                </div>
              </section>
            </div>
          </div>
        `;

    return `
      <section class="runtime-composer-picker" role="dialog" aria-modal="true" aria-labelledby="composer-picker-title">
        <header class="screen-header runtime-header runtime-header--compact runtime-composer-picker__header">
          <button class="runtime-icon-button runtime-icon-button--quiet runtime-topbar__back" type="button" data-action="close-composer-picker" aria-label="返回聊天">
            ${renderIcon("back", "runtime-icon-button__glyph")}
          </button>
          <div class="screen-header__main">
            <h2 id="composer-picker-title">${title}</h2>
          </div>
          <span class="runtime-composer-picker__header-spacer" aria-hidden="true"></span>
        </header>
        ${content}
      </section>
    `;
  }

  function renderComposerContactRow(contact) {
    return `
      <button
        class="runtime-composer-picker__row runtime-composer-picker__row--contact"
        type="button"
        data-action="send-composer-picker-item"
        data-picker-type="contact-card"
        data-item-id="${escapeHtml(contact.id)}"
      >
        <span class="runtime-composer-picker__avatar">
          ${renderAvatar(contact.name, contact.tone, "avatar--md")}
          <span class="runtime-contact-row__presence ${presenceClass(contact.status)}"></span>
        </span>
        <span class="runtime-composer-picker__row-copy">
          <strong>${escapeHtml(contact.name)}</strong>
          <small>${escapeHtml(contact.title)}</small>
        </span>
        <span class="runtime-composer-picker__send-icon">
          ${renderIcon("send", "runtime-composer-picker__send-glyph")}
        </span>
      </button>
    `;
  }

  function renderComposerFavoriteRow(favorite) {
    return `
      <button
        class="runtime-composer-picker__row runtime-composer-picker__row--favorite"
        type="button"
        data-action="send-composer-picker-item"
        data-picker-type="favorite"
        data-item-id="${escapeHtml(favorite.id)}"
      >
        <span class="runtime-composer-picker__favorite-icon">
          ${renderIcon(favorite.icon, "runtime-composer-picker__favorite-glyph")}
        </span>
        <span class="runtime-composer-picker__row-copy">
          <small>${escapeHtml(favorite.kind)}收藏</small>
          <strong>${escapeHtml(favorite.title)}</strong>
          <em>${escapeHtml(favorite.summary)}</em>
        </span>
        <span class="runtime-composer-picker__send-icon">
          ${renderIcon("send", "runtime-composer-picker__send-glyph")}
        </span>
      </button>
    `;
  }

  function renderCallOverlay(chat) {
    const session = state.callSession;
    if (!session || session.chatId !== chat.id) {
      return "";
    }

    const isVideo = session.type === "video";
    const isGroup = chat.type === "group";
    const callLabel = isGroup
      ? isVideo ? "视频会议" : "语音会议"
      : isVideo ? "视频通话" : "语音通话";

    return `
      <section class="runtime-call runtime-call--${session.type}" role="dialog" aria-modal="true" aria-label="与 ${escapeHtml(chat.name)} 的${callLabel}">
        <div class="runtime-call__topbar">
          <span class="runtime-call__secure">${renderIcon("shield", "runtime-call__secure-icon")} 端到端加密</span>
          <span class="runtime-call__type">${callLabel}</span>
        </div>
        <div class="runtime-call__identity">
          <span class="runtime-call__avatar">${renderAvatar(chat.name, chat.avatarTone, "avatar--xl")}</span>
          <h2>${escapeHtml(chat.name)}</h2>
          <p>${isGroup ? `正在邀请群成员加入${callLabel}` : `正在呼叫 ${escapeHtml(chat.name)}...`}</p>
        </div>
        ${isVideo ? `<div class="runtime-call__self-preview" aria-label="本地视频预览"><span>你</span></div>` : ""}
        <div class="runtime-call__controls" role="group" aria-label="通话控制">
          <button class="runtime-call__control ${session.muted ? "is-active" : ""}" type="button" data-action="toggle-call-control" data-control="muted" aria-pressed="${session.muted}">
            <span>${renderIcon("microphone", "runtime-call__control-icon")}</span>
            <small>${session.muted ? "取消静音" : "静音"}</small>
          </button>
          ${
            isVideo
              ? `
                <button class="runtime-call__control ${session.cameraOff ? "is-active" : ""}" type="button" data-action="toggle-call-control" data-control="cameraOff" aria-pressed="${session.cameraOff}">
                  <span>${renderIcon(session.cameraOff ? "cameraOff" : "video", "runtime-call__control-icon")}</span>
                  <small>${session.cameraOff ? "开启摄像头" : "摄像头"}</small>
                </button>
                <button class="runtime-call__control" type="button" data-action="show-hint" data-message="已切换摄像头">
                  <span>${renderIcon("switchCamera", "runtime-call__control-icon")}</span>
                  <small>翻转</small>
                </button>
              `
              : `
                <button class="runtime-call__control ${session.speaker ? "is-active" : ""}" type="button" data-action="toggle-call-control" data-control="speaker" aria-pressed="${session.speaker}">
                  <span>${renderIcon("speaker", "runtime-call__control-icon")}</span>
                  <small>扬声器</small>
                </button>
              `
          }
          <button class="runtime-call__control runtime-call__control--end" type="button" data-action="end-call">
            <span>${renderIcon("phoneOff", "runtime-call__control-icon")}</span>
            <small>挂断</small>
          </button>
        </div>
      </section>
    `;
  }

  function toggleComposerPanel(panel) {
    if (!["emoji", "more"].includes(panel)) {
      return;
    }

    const nextPanel = state.composerPanel === panel ? null : panel;
    state.composerPanel = nextPanel;

    const chatScreen = root.querySelector(".runtime-chat-screen");
    const panelElement = root.querySelector(".runtime-composer-panel");
    if (!chatScreen || !panelElement) {
      render();
      return;
    }

    root.querySelectorAll('[data-action="toggle-composer-panel"]').forEach((button) => {
      const isActive = button.getAttribute("data-panel") === nextPanel;
      button.classList.toggle("is-active", isActive);
      button.setAttribute("aria-expanded", String(isActive));
    });

    if (!nextPanel) {
      chatScreen.classList.remove("runtime-chat-screen--composer-panel-open");
      panelElement.classList.remove("is-open");
      panelElement.classList.remove("is-resizing");
      panelElement.style.height = "";
      panelElement.setAttribute("aria-hidden", "true");
      panelElement.toggleAttribute("inert", true);
      return;
    }

    panelElement.setAttribute("aria-hidden", "false");
    panelElement.toggleAttribute("inert", false);

    if (panelElement.classList.contains("is-open")) {
      transitionComposerPanelHeight(panelElement, nextPanel);
      return;
    }

    setComposerPanelMode(panelElement, nextPanel);

    // Keep one shell in the DOM so initial expansion and panel switches are continuous.
    window.requestAnimationFrame(() => {
      if (state.composerPanel !== nextPanel) {
        return;
      }
      chatScreen.classList.add("runtime-chat-screen--composer-panel-open");
      panelElement.classList.add("is-open");
    });
  }

  function setComposerPanelMode(panelElement, panel) {
    panelElement.dataset.panel = panel;
    panelElement.classList.toggle("runtime-composer-panel--emoji", panel === "emoji");
    panelElement.classList.toggle("runtime-composer-panel--actions", panel === "more");
  }

  function transitionComposerPanelHeight(panelElement, nextPanel) {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setComposerPanelMode(panelElement, nextPanel);
      return;
    }

    const currentHeight = panelElement.getBoundingClientRect().height;
    panelElement.classList.remove("is-resizing");
    panelElement.style.height = `${currentHeight}px`;
    void panelElement.offsetHeight;

    setComposerPanelMode(panelElement, nextPanel);
    panelElement.style.height = "auto";
    const targetHeight = panelElement.getBoundingClientRect().height;
    panelElement.style.height = `${currentHeight}px`;
    void panelElement.offsetHeight;
    if (Math.abs(targetHeight - currentHeight) < 1) {
      panelElement.style.height = "";
      return;
    }

    const finish = (event) => {
      if (event.target !== panelElement || event.propertyName !== "height") {
        return;
      }
      panelElement.removeEventListener("transitionend", finish);
      panelElement.classList.remove("is-resizing");
      panelElement.style.height = "";
    };

    panelElement.addEventListener("transitionend", finish);
    panelElement.classList.add("is-resizing");
    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        panelElement.style.height = `${targetHeight}px`;
      });
    });
  }

  function renderMessageTimeline(chat) {
    if (!chat.messages.length) {
      return renderCapabilityState("empty", "还没有聊天记录", "发送一条消息开始对话。");
    }
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

  // Legacy mock quotes carry excerpts rather than stable source message IDs.
  function normalizeQuoteText(value) {
    return typeof value === "string" ? value.replace(/[\s\p{P}\p{S}]+/gu, "").trim() : "";
  }

  function resolveQuotedMessage(chat, message) {
    if (message.quoteMessageId) {
      return findMessage(chat, message.quoteMessageId);
    }
    const messageIndex = chat.messages.findIndex((item) => item.id === message.id);
    const quoteText = normalizeQuoteText(message.quote);
    if (!quoteText || messageIndex <= 0) {
      return null;
    }

    return chat.messages
      .slice(0, messageIndex)
      .reverse()
      .find((item) => {
        const content = normalizeQuoteText(item.content);
        return Boolean(content) && (content.includes(quoteText) || quoteText.includes(content));
      }) || null;
  }

  function renderMessageQuote(chat, message) {
    if (!message.quote) {
      return "";
    }

    const source = resolveQuotedMessage(chat, message);
    const isReplyToSelf = source?.senderId === data.currentUser.id;
    const replyLabel = source
      ? (isReplyToSelf ? "回复自己" : `回复 ${source.senderName || "成员"}`)
      : "回复消息";
    const quoteContent = `
      <span class="message-quote__meta">
        ${renderIcon("reply", "message-quote__icon")}
        <span>${escapeHtml(replyLabel)}</span>
      </span>
      <span class="message-quote__content">${escapeHtml(message.quote)}</span>
    `;

    if (!source) {
      return `<div class="message-quote message-quote--static">${quoteContent}</div>`;
    }

    const jumpLabel = isReplyToSelf
      ? "跳转至自己的原消息"
      : `跳转至 ${source.senderName || "成员"} 的原消息`;
    return `
      <button
        class="message-quote message-quote--jump"
        type="button"
        data-action="jump-to-message"
        data-message-id="${source.id}"
        aria-label="${escapeHtml(jumpLabel)}"
      >
        ${quoteContent}
      </button>
    `;
  }

  function resolveStandaloneEmojiMessage(content) {
    const glyphs = Array.from(typeof content === "string" ? content.trim() : "");
    if (!glyphs.length || glyphs.length > 3) {
      return null;
    }

    const emojis = glyphs.map((glyph) => EMOJI_BY_FALLBACK.get(glyph));
    return emojis.every(Boolean) ? emojis : null;
  }

  function renderStandaloneEmojiMessage(emojis) {
    const label = emojis.map((emoji) => emoji.label).join("、");
    const sizeClass = emojis.length === 1 ? "message-emoji--single" : "message-emoji--cluster";
    return `
      <span class="message-emoji ${sizeClass}" role="img" aria-label="${escapeHtml(label)}表情">
        ${emojis
          .map(
            (emoji, index) => `
              <span
                class="message-emoji__glyph message-emoji__glyph--${emoji.motion}"
                data-emoji-id="${emoji.id}"
                style="--emoji-index: ${index};"
                aria-hidden="true"
              >${escapeHtml(emoji.fallback)}</span>
            `,
          )
          .join("")}
      </span>
    `;
  }

  function renderSharedMessage(share) {
    if (share.type === "contact") {
      return `
        <div class="message-share message-share--contact">
          ${renderAvatar(share.name, share.tone, "avatar--md")}
          <span class="message-share__copy">
            <strong>${escapeHtml(share.name)}</strong>
            <small>${escapeHtml(share.title)} · @${escapeHtml(share.username)}</small>
          </span>
          ${renderIcon("chevronRight", "message-share__chevron")}
        </div>
      `;
    }

    return `
      <div class="message-share message-share--favorite">
        <span class="message-share__favorite-icon">${renderIcon(share.icon, "message-share__favorite-glyph")}</span>
        <span class="message-share__copy">
          <small>${escapeHtml(share.kind)}</small>
          <strong>${escapeHtml(share.title)}</strong>
          <em>${escapeHtml(share.summary)}</em>
        </span>
        ${renderIcon("chevronRight", "message-share__chevron")}
      </div>
    `;
  }

  function renderMessageBubble(chat, message) {
    const quote = renderMessageQuote(chat, message);
    const isHighlighted = state.highlightMessageId === message.id;
    const isRecent = state.recentMessageId === message.id;
    const emojis = quote || message.share ? null : resolveStandaloneEmojiMessage(message.content);
    const content = message.share
      ? renderSharedMessage(message.share)
      : emojis
      ? renderStandaloneEmojiMessage(emojis)
      : `<p class="message-bubble__text">${escapeHtml(message.content)}</p>`;
    const reactions = Array.isArray(message.reactions) && message.reactions.length
      ? `
        <div class="reaction-row">
          ${message.reactions
            .map((item) => `<button class="reaction-pill ${item.self ? "is-active" : ""}" type="button" data-action="toggle-message-reaction" data-chat-id="${chat.id}" data-message-id="${message.id}" data-emoji="${escapeHtml(item.emoji)}">${escapeHtml(item.emoji)} ${item.count}</button>`)
            .join("")}
        </div>
      `
      : "";

    return `
      <div class="message-row ${message.self ? "message-row--self" : ""}" data-message-id="${message.id}">
        ${message.self ? "" : renderAvatar(message.senderName, message.senderTone, "avatar--sm")}
        <div class="message-block ${message.self ? "message-block--self" : ""}">
          ${message.self ? "" : `<span class="message-sender">${escapeHtml(message.senderName)}</span>`}
          <div class="message-bubble ${message.self ? "message-bubble--self" : ""} ${message.share ? "message-bubble--share" : ""} ${emojis ? "message-bubble--emoji-only" : ""} ${isHighlighted ? "is-highlighted" : ""} ${isRecent ? "is-recent" : ""}">
            ${quote}
            ${content}
          </div>
          ${reactions}
          <div class="message-meta">
            <span>${escapeHtml(message.time)}</span>
            ${message.self && chat.type === "group" ? `<button class="message-meta__reads" type="button" data-action="navigate" data-route="/chat/${chat.id}/message/${message.id}/reads">${escapeHtml(message.status || "已送达")}</button>` : message.self ? `<span>${escapeHtml(message.status || "已送达")}</span>` : ""}
            ${message.edited ? "<span>已编辑</span>" : ""}
            ${message.pinned ? "<span>已置顶</span>" : ""}
            <button class="message-meta__menu" type="button" data-action="open-message-menu" data-chat-id="${chat.id}" data-message-id="${message.id}" aria-label="消息操作">${renderIcon("more", "message-meta__menu-icon")}</button>
          </div>
        </div>
      </div>
    `;
  }

  function messageActions(chat, message) {
    const relayOnly = Boolean(chat.relayOnly);
    return [
      { id: "forward", label: "转发", disabled: relayOnly },
      { id: "quote", label: "引用", disabled: relayOnly },
      { id: "edit", label: "编辑", hidden: !message.self || message.share || !message.content, disabled: relayOnly },
      { id: "delete", label: "删除", hidden: !message.self, danger: true },
      { id: "pin", label: message.pinned ? "取消置顶" : "置顶", disabled: relayOnly },
    ].filter((item) => !item.hidden);
  }

  function renderMessageActionSheet(chat) {
    const menu = state.messageMenu;
    if (!menu || menu.chatId !== chat.id) {
      return "";
    }
    const message = findMessage(chat, menu.messageId);
    if (!message) {
      return "";
    }
    return `
      <div class="runtime-sheet-layer">
        <button class="runtime-sheet-layer__scrim" type="button" data-action="close-message-menu" aria-label="关闭消息操作"></button>
        <section class="runtime-message-sheet" role="dialog" aria-modal="true" aria-label="消息操作">
          <div class="runtime-message-sheet__reactions" aria-label="添加回应">
            ${["👍", "❤️", "😂", "🎉", "😮", "😢"].map((emoji) => `<button type="button" data-action="toggle-message-reaction" data-chat-id="${chat.id}" data-message-id="${message.id}" data-emoji="${emoji}" aria-label="回应 ${emoji}">${emoji}</button>`).join("")}
          </div>
          <div class="runtime-message-sheet__actions">
            ${messageActions(chat, message).map((item) => `
              <button class="${item.danger ? "is-danger" : ""}" type="button" data-action="perform-message-action" data-message-action="${item.id}" data-chat-id="${chat.id}" data-message-id="${message.id}" ${item.disabled ? "disabled" : ""}>
                <span>${escapeHtml(item.label)}</span>
                ${item.disabled ? "<small>中继会话不可用</small>" : ""}
              </button>
            `).join("")}
          </div>
        </section>
      </div>
    `;
  }

  function renderMessageEditor(chat) {
    const editor = state.messageEditor;
    if (!editor || editor.chatId !== chat.id) {
      return "";
    }
    return `
      <div class="runtime-sheet-layer">
        <button class="runtime-sheet-layer__scrim" type="button" data-action="close-message-editor" aria-label="关闭编辑"></button>
        <form class="runtime-message-editor" data-form="edit-message" data-chat-id="${chat.id}" data-message-id="${editor.messageId}">
          <label for="message-editor-input">编辑消息</label>
          <textarea id="message-editor-input" rows="4" maxlength="2000">${escapeHtml(editor.content)}</textarea>
          <div class="runtime-message-editor__actions">
            <button type="button" data-action="close-message-editor">取消</button>
            <button class="is-primary" type="submit" ${editor.content.trim() ? "" : "disabled"}>保存</button>
          </div>
        </form>
      </div>
    `;
  }

  function renderMessageReadsScreen(chat, message) {
    const group = findGroupByChatId(chat.id);
    const memberIds = group?.members || chat.participants || [];
    const readIds = new Set((message.readBy || []).filter((id) => id !== message.senderId));
    const unreadIds = memberIds.filter((id) => id !== message.senderId && !readIds.has(id));
    const activeIds = state.messageReadsTab === "unread" ? unreadIds : Array.from(readIds);
    const title = state.messageReadsTab === "unread" ? `未读 ${unreadIds.length}` : `已读 ${readIds.size}`;
    return `
      <section class="screen runtime-screen runtime-screen--list">
        ${renderScreenHeader({ title: "已读详情", backPath: `/chat/${chat.id}`, variant: "compact" })}
        <div class="runtime-segmented" role="tablist" aria-label="阅读状态">
          <button type="button" role="tab" aria-selected="${state.messageReadsTab === "read"}" class="${state.messageReadsTab === "read" ? "is-active" : ""}" data-action="set-message-reads-tab" data-tab="read">已读 ${readIds.size}</button>
          <button type="button" role="tab" aria-selected="${state.messageReadsTab === "unread"}" class="${state.messageReadsTab === "unread" ? "is-active" : ""}" data-action="set-message-reads-tab" data-tab="unread">未读 ${unreadIds.length}</button>
        </div>
        <div class="screen-scroll runtime-scroll runtime-topbar-scroll"><div class="runtime-list-content">
          <h3 class="runtime-list-title">${title}</h3>
          ${activeIds.length ? `<div class="runtime-member-status-list">${activeIds.map((id) => renderMessageMemberRow(id)).join("")}</div>` : renderCapabilityState("empty", `没有${state.messageReadsTab === "read" ? "已读" : "未读"}成员`, "成员状态会在这里更新。")}
        </div></div>
      </section>
    `;
  }

  function renderMessageMemberRow(personId) {
    const person = findPerson(personId);
    if (!person) return "";
    return `<div class="runtime-member-status-row">${renderAvatar(person.name, person.tone || person.avatarTone, "avatar--md")}<span><strong>${escapeHtml(person.name)}</strong><small>@${escapeHtml(person.username || person.id)}</small></span>${renderIcon("checkCircle", "runtime-member-status-row__icon")}</div>`;
  }

  function renderMessageForwardScreen(sourceChat, message) {
    const query = state.forwardQuery.trim().toLowerCase();
    const targets = sortedChats().filter((chat) => chat.id !== sourceChat.id && (!query || chat.name.toLowerCase().includes(query)));
    return `
      <section class="screen runtime-screen runtime-screen--list">
        ${renderScreenHeader({ title: "转发消息", backPath: `/chat/${sourceChat.id}`, variant: "compact" })}
        <div class="runtime-forward-search"><label class="runtime-search-field">${renderIcon("search", "runtime-search-field__icon")}<input id="message-forward-search" value="${escapeHtml(state.forwardQuery)}" placeholder="搜索会话" aria-label="搜索会话"></label></div>
        <div class="screen-scroll runtime-scroll"><div class="runtime-list-content">
          <div class="runtime-forward-preview"><small>将转发</small><p>${escapeHtml(message.content)}</p></div>
          ${targets.length ? `<div class="runtime-forward-list">${targets.map((chat) => `<label class="runtime-forward-row">${renderAvatar(chat.name, chat.avatarTone, "avatar--md")}<span><strong>${escapeHtml(chat.name)}</strong><small>${chat.relayOnly ? "中继会话可能发送失败" : chatTypeLabel(chat)}</small></span><input type="checkbox" data-kind="forward-target" data-chat-id="${chat.id}" ${state.forwardSelection.has(chat.id) ? "checked" : ""}></label>`).join("")}</div>` : renderCapabilityState("empty", "没有匹配的会话", "换个关键词试试。")}
        </div></div>
        <div class="runtime-forward-footer"><button type="button" data-action="submit-message-forward" data-source-chat-id="${sourceChat.id}" data-message-id="${message.id}" ${state.forwardSelection.size ? "" : "disabled"}>转发给 ${state.forwardSelection.size || 0} 个会话</button></div>
      </section>
    `;
  }

  function renderChatActionSheet(chat) {
    if (state.chatActionsChatId !== chat.id) return "";
    const group = findGroupByChatId(chat.id);
    const canClear = !chat.relayOnly && (chat.type === "single" || group?.ownerId === data.currentUser.id);
    const reason = chat.relayOnly
      ? "中继会话不支持清空记录"
      : chat.type === "group" && !canClear
      ? "只有群主可以清空群聊记录"
      : chat.type === "single"
      ? "清空后，双方的聊天记录都会被删除"
      : "清空后，所有群成员都无法查看历史记录";
    return `
      <div class="runtime-sheet-layer">
        <button class="runtime-sheet-layer__scrim" type="button" data-action="close-chat-actions" aria-label="关闭会话操作"></button>
        <section class="runtime-chat-actions" role="dialog" aria-modal="true" aria-label="会话操作">
          <div><strong>会话操作</strong><p>${escapeHtml(reason)}</p></div>
          <button class="is-danger" type="button" data-action="clear-chat-history" data-chat-id="${chat.id}" ${canClear ? "" : "disabled"}>清空聊天记录</button>
          <button type="button" data-action="close-chat-actions">取消</button>
        </section>
      </div>
    `;
  }

  function requestClearChatHistory(chatId) {
    const chat = findChat(chatId);
    const group = findGroupByChatId(chatId);
    const canClear = chat && !chat.relayOnly && (chat.type === "single" || group?.ownerId === data.currentUser.id);
    if (!canClear) return;
    state.chatActionsChatId = null;
    openActionDialog({
      title: "清空全部聊天记录？",
      description: chat.type === "single"
        ? "此操作会删除双方的全部聊天记录，且无法恢复。"
        : "此操作会删除所有群成员可见的历史记录，且无法恢复。",
      confirmLabel: "清空记录",
      tone: "danger",
      payload: { chatId },
      onConfirm: ({ chatId: targetId }) => {
        const target = findChat(targetId);
        if (!target) throw new Error("会话不存在，无法清空记录。");
        target.messages = [];
        target.lastMessage = "暂无消息";
        target.lastTime = "刚刚";
        target.unread = 0;
      },
    });
  }

  function renderContactsScreen() {
    const sections = groupContacts(filteredContacts());
    const pendingIncoming = data.friendRequests.filter(
      (item) => item.type === "incoming" && item.status === "pending",
    ).length;
    const groupDirectorySummary = `${data.groups.length} 个群聊`;

    return `
      <section class="screen screen--tabbed runtime-screen runtime-screen--list runtime-contacts-screen">
        ${renderScreenHeader({
          root: true,
          variant: "directory",
          mainContent: `
            <div class="screen-header__main screen-header__main--search" role="search" aria-label="搜索联系人">
              <h2 class="runtime-visually-hidden">联系人</h2>
              <label class="runtime-search-field">
                ${renderIcon("search", "runtime-search-field__icon", "搜索联系人")}
                <input
                  id="contact-filter-input"
                  value="${escapeHtml(state.contactFilter)}"
                  placeholder="搜索联系人"
                  aria-label="搜索联系人"
                  aria-controls="contact-directory"
                />
              </label>
            </div>
          `,
          actions: [
            `<button class="runtime-icon-button runtime-icon-button--quiet" data-action="navigate" data-route="/contacts/add" aria-label="添加好友">${renderIcon("plus", "runtime-icon-button__glyph", "添加好友")}</button>`,
          ],
        })}
        <div class="screen-scroll runtime-scroll runtime-directory-scroll">
          <div class="runtime-list-content runtime-contacts-content">
            <div class="runtime-contact-shortcuts">
              <button class="runtime-contact-shortcut" data-action="navigate" data-route="/contacts/requests">
                <span class="runtime-contact-shortcut__icon">${renderIcon("contacts", "runtime-contact-shortcut__glyph", "新的朋友")}</span>
                <span class="runtime-contact-shortcut__copy"><strong>新的朋友</strong><span>${pendingIncoming ? `${pendingIncoming} 条待处理` : "好友申请"}</span></span>
                ${pendingIncoming ? `<span class="runtime-unread-badge">${pendingIncoming}</span>` : ""}
              </button>
              <button class="runtime-contact-shortcut" data-action="navigate" data-route="/groups">
                <span class="runtime-contact-shortcut__icon">${renderIcon("chats", "runtime-contact-shortcut__glyph", "群聊")}</span>
                <span class="runtime-contact-shortcut__copy"><strong>群聊</strong><span>${escapeHtml(groupDirectorySummary)}</span></span>
                ${renderRowChevron()}
              </button>
            </div>
            <div class="runtime-contact-directory" id="contact-directory">
              ${sections.length ? sections.map(renderContactSection).join("") : renderEmptyState("暂无联系人", "添加好友后会显示在这里。")}
            </div>
          </div>
        </div>
      </section>
    `;
  }

  function renderDiscoverScreen() {
    const discover = data.discover;
    const entries = Array.isArray(discover.entries) ? discover.entries : [];
    const moments = entries.find((item) => item.id === "moments") || entries[0] || null;
    const quickEntries = moments ? entries.filter((item) => item.id !== moments.id) : entries;
    const hasMoments = Array.isArray(discover.moments) && discover.moments.length > 0;

    return `
      <section class="screen screen--tabbed runtime-screen runtime-screen--list runtime-discover-screen">
        <div class="screen-scroll runtime-scroll">
          <div class="runtime-list-content runtime-discover-content">
            ${
              moments
                ? `
                  <button class="runtime-moments-card" data-action="navigate" data-route="${moments.route}">
                    <span class="runtime-moments-card__eyebrow">朋友圈</span>
                    <strong>${hasMoments ? "看看朋友最近的动态" : "还没有朋友动态"}</strong>
                    <span>${escapeHtml(hasMoments ? moments.summary : "添加好友后，新动态会显示在这里。")}</span>
                    <span class="runtime-moments-card__meta">${hasMoments ? `${escapeHtml(moments.badge)} 条新动态` : "暂无新动态"} <b>›</b></span>
                  </button>
                `
                : renderEmptyState("暂无发现内容", "服务入口准备完成后会显示在这里。")
            }
            ${quickEntries.length ? `
              <section class="runtime-discover-grid" aria-label="发现功能">
                ${quickEntries.map(renderDiscoverEntryCard).join("")}
              </section>
            ` : ""}
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
      </button>
    `;
  }

  function renderDiscoverMomentsScreen() {
    const moments = data.discover.moments || [];

    return `
      <section class="screen">
        ${renderScreenHeader({
          title: "朋友圈",
          backPath: "/discover",
          variant: "compact",
        })}
        <div class="screen-scroll runtime-topbar-scroll">
          <div class="screen-stack">
            <section class="hero-card hero-card--soft hero-card--moments">
              <span class="eyebrow">Moments Feed</span>
              <h3>朋友圈页只做内容流：作者、时间、正文、媒体与互动，不混入聊天操作。</h3>
              <div class="inline-actions inline-actions--wide">
                <button class="ghost-button" data-action="show-hint" data-message="后续这里可接发动态、图片选择与可见范围。">发一条动态</button>
                <button class="ghost-button" data-action="show-hint" data-message="后续这里可接仅朋友可见、分组可见和草稿箱。">可见范围</button>
              </div>
            </section>
            ${moments.length ? moments.map(renderMomentCard).join("") : renderEmptyState("暂无朋友圈动态", "添加好友后，最新动态会显示在这里。")}
          </div>
        </div>
      </section>
    `;
  }

  function renderMomentCard(item) {
    const liked = state.likedMomentIds.has(item.id);
    const submittedComments = state.momentComments[item.id] || [];
    const mediaCount = getMomentMediaCount(item);

    return `
      <article class="moment-card">
        <div class="moment-card__header">
          ${renderAvatar(item.author, item.tone, "avatar--md")}
          <div class="moment-card__meta">
            <strong>${escapeHtml(item.author)}</strong>
            <span>${escapeHtml(item.time)}</span>
          </div>
        </div>
        <p class="moment-card__text">${escapeHtml(item.text)}</p>
        ${mediaCount ? renderMomentMediaGrid(item, mediaCount, "feed") : ""}
        <div class="moment-card__footer">
          <button
            class="moment-card__like ${liked ? "is-active" : ""}"
            type="button"
            data-action="toggle-moment-like"
            data-moment-id="${escapeHtml(item.id)}"
            aria-pressed="${liked}"
            aria-label="${liked ? "取消点赞" : "点赞"}"
          >
            ${renderIcon("heart", "moment-card__like-icon")}
            <span class="moment-card__like-count">${item.likes + (liked ? 1 : 0)}</span>
          </button>
          <span>评论 ${item.comments + submittedComments.length}</span>
          <button class="moment-card__detail" type="button" data-action="navigate" data-route="/discover/moments/${escapeHtml(item.id)}">
            查看详情
            ${renderIcon("chevronRight", "moment-card__detail-icon")}
          </button>
        </div>
      </article>
    `;
  }

  function renderDiscoverMomentDetailScreen(momentId) {
    const item = findMoment(momentId);
    if (!item) {
      return renderFallbackScreen("动态不存在", "/discover/moments");
    }

    const liked = state.likedMomentIds.has(item.id);
    const submittedComments = state.momentComments[item.id] || [];
    const comments = [...submittedComments, ...(MOMENT_COMMENTS[item.id] || [])];
    const commentCount = item.comments + submittedComments.length;
    const draft = state.momentCommentDrafts[item.id] || "";
    const mediaCount = getMomentMediaCount(item);
    const likers = getMomentLikers(item, liked);
    const likersExpanded = state.expandedMomentLikeIds.has(item.id);

    return `
      <section class="screen runtime-moment-detail-screen">
        ${renderScreenHeader({
          title: "动态详情",
          backPath: "/discover/moments",
          variant: "compact",
        })}
        <div class="screen-scroll runtime-moment-detail__scroll">
          <article class="runtime-moment-detail">
            <header class="runtime-moment-detail__author">
              ${renderAvatar(item.author, item.tone, "avatar--md")}
              <span>
                <strong>${escapeHtml(item.author)}</strong>
                <small>${escapeHtml(item.time)}</small>
              </span>
            </header>
            <p class="runtime-moment-detail__text">${escapeHtml(item.text)}</p>
            ${mediaCount ? renderMomentMediaGrid(item, mediaCount, "detail") : ""}
            <div class="runtime-moment-detail__engagement" aria-label="动态互动">
              <button
                class="runtime-moment-detail__likers-toggle ${likersExpanded ? "is-expanded" : ""}"
                type="button"
                data-action="toggle-moment-likers"
                data-moment-id="${escapeHtml(item.id)}"
                aria-expanded="${likersExpanded}"
                aria-controls="moment-likers-${escapeHtml(item.id)}"
                aria-label="${likersExpanded ? "收起点赞用户" : "查看点赞用户"}"
              >
                <span class="runtime-moment-detail__liker-stack">
                  ${likers.slice(0, 4).map(renderMomentLikerAvatar).join("")}
                </span>
                ${renderIcon("chevronDown", "runtime-moment-detail__likers-chevron")}
              </button>
              <button
                class="runtime-moment-detail__like ${liked ? "is-active" : ""}"
                type="button"
                data-action="toggle-moment-like"
                data-moment-id="${escapeHtml(item.id)}"
                aria-pressed="${liked}"
                aria-label="${liked ? "取消点赞" : "点赞"}"
              >
                ${renderIcon("heart", "runtime-moment-detail__like-icon")}
                <span class="runtime-moment-detail__like-count">${item.likes + (liked ? 1 : 0)}</span>
              </button>
            </div>
            <div
              id="moment-likers-${escapeHtml(item.id)}"
              class="runtime-moment-detail__likers"
              aria-label="点赞用户"
              ${likersExpanded ? "" : "hidden"}
            >
              ${likers.map(renderMomentLikerAvatar).join("")}
            </div>
          </article>
          <section class="runtime-moment-comments" aria-labelledby="moment-comments-title">
            <div class="runtime-moment-comments__heading">
              <h3 id="moment-comments-title">评论 <span>${commentCount}</span></h3>
            </div>
            <div class="runtime-moment-comments__list">
              ${comments.map(renderMomentComment).join("")}
            </div>
          </section>
        </div>
        <form class="runtime-moment-comment-dock" data-form="moment-comment-form" data-moment-id="${escapeHtml(item.id)}">
          <label class="runtime-moment-comment-dock__field">
            <span class="runtime-visually-hidden">发表评论</span>
            <input
              id="moment-comment-input"
              value="${escapeHtml(draft)}"
              data-moment-id="${escapeHtml(item.id)}"
              placeholder="写评论"
              autocomplete="off"
            />
          </label>
          <button class="runtime-moment-comment-dock__send" type="submit" ${draft.trim() ? "" : "disabled"} aria-label="发送评论">
            ${renderIcon("send", "runtime-moment-comment-dock__send-icon")}
          </button>
        </form>
      </section>
    `;
  }

  function getMomentMediaCount(item) {
    if (!item || ["无媒体", "文字"].includes(item.media)) {
      return 0;
    }

    return Math.min(Math.max(Number.parseInt(item.media, 10) || 0, 0), 9);
  }

  function getMomentLikers(item, liked) {
    const baseLikers = MOMENT_LIKER_NAMES.slice(0, item.likes).map((name, index) => ({
      name,
      tone: ["violet", "mint", "amber"][index % 3],
    }));

    return liked ? [{ name: "Chen Atlas", tone: "mint" }, ...baseLikers] : baseLikers;
  }

  function renderMomentLikerAvatar(liker) {
    return `<span class="runtime-moment-detail__liker" title="${escapeHtml(liker.name)}" aria-label="${escapeHtml(liker.name)}">${renderAvatar(liker.name, liker.tone, "avatar--sm")}</span>`;
  }

  function renderMomentMediaGrid(item, mediaCount, variant) {
    return `
      <div
        class="moment-media-grid moment-media-grid--${variant} moment-media-grid--count-${mediaCount}"
        aria-label="${escapeHtml(item.media)}"
      >
        ${Array.from({ length: mediaCount }, (_, index) => `
          <div class="moment-media-grid__item" aria-label="第 ${index + 1} 张图片">
            ${renderIcon("image", "moment-media-grid__icon")}
          </div>
        `).join("")}
      </div>
    `;
  }

  function renderMomentComment(comment) {
    return `
      <article class="runtime-moment-comment" data-comment-id="${escapeHtml(comment.id)}">
        ${renderAvatar(comment.author, comment.tone, "avatar--sm")}
        <span class="runtime-moment-comment__body">
          <span class="runtime-moment-comment__meta">
            <strong>${escapeHtml(comment.author)}</strong>
            <time>${escapeHtml(comment.time)}</time>
          </span>
          <p>${escapeHtml(comment.text)}</p>
        </span>
      </article>
    `;
  }

  function submitMomentComment(momentId) {
    const moment = findMoment(momentId);
    const text = String(state.momentCommentDrafts[momentId] || "").trim();
    if (!moment || !text) {
      return;
    }

    const comment = {
      id: `mc_${Date.now()}`,
      author: data.currentUser.name,
      tone: data.currentUser.avatarTone,
      time: "刚刚",
      text,
    };
    state.momentComments[momentId] = [comment, ...(state.momentComments[momentId] || [])];
    state.momentCommentDrafts[momentId] = "";
    render();
    window.requestAnimationFrame(() => {
      root.querySelector(`[data-comment-id="${comment.id}"]`)?.scrollIntoView({
        behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
        block: "center",
      });
    });
  }

  function renderDiscoverScanScreen() {
    const result = state.scanStatus === "success"
      ? {
          tone: "success",
          title: "识别到群聊邀请",
          summary: "Launch War Room · 18 位成员",
        }
      : state.scanStatus === "error"
      ? {
          tone: "error",
          title: "未识别到二维码",
          summary: "请将二维码完整放入框内。",
        }
      : null;

    return `
      <section class="screen runtime-screen runtime-discover-tool-screen runtime-scan-screen">
        ${renderScreenHeader({
          title: "扫一扫",
          backPath: "/discover",
          variant: "compact",
        })}
        <div class="screen-scroll runtime-scroll runtime-discover-tool-scroll">
          <div class="runtime-scan-workspace ${state.scanTorchOn ? "is-torch-on" : ""}">
            <div class="runtime-scan-status runtime-scan-status--${state.scanStatus}" role="status">
              <span class="runtime-scan-status__dot" aria-hidden="true"></span>
              <span>${
                state.scanStatus === "success"
                  ? "识别完成"
                  : state.scanStatus === "error"
                  ? "暂未识别"
                  : state.scanTorchOn
                  ? "手电筒已开启"
                  : "正在识别二维码"
              }</span>
            </div>
            <button
              class="runtime-scan-viewport"
              type="button"
              data-action="simulate-scan"
              aria-label="模拟识别二维码"
            >
              <span class="runtime-scan-viewport__shade" aria-hidden="true"></span>
              <span class="runtime-scan-frame" aria-hidden="true">
                <span class="runtime-scan-frame__corner runtime-scan-frame__corner--tl"></span>
                <span class="runtime-scan-frame__corner runtime-scan-frame__corner--tr"></span>
                <span class="runtime-scan-frame__corner runtime-scan-frame__corner--bl"></span>
                <span class="runtime-scan-frame__corner runtime-scan-frame__corner--br"></span>
                <span class="runtime-scan-frame__line"></span>
              </span>
            </button>
            <p class="runtime-scan-guidance">将二维码放入框内，即可自动识别</p>
            <div class="runtime-scan-actions" aria-label="扫一扫操作">
              <button class="runtime-scan-action" type="button" data-action="scan-from-gallery">
                <span class="runtime-scan-action__icon">${renderIcon("image", "runtime-scan-action__glyph")}</span>
                <span>相册</span>
              </button>
              <button class="runtime-scan-action runtime-scan-action--primary" type="button" data-action="simulate-scan">
                <span class="runtime-scan-action__icon">${renderIcon("scan", "runtime-scan-action__glyph")}</span>
                <span>识别</span>
              </button>
              <button
                class="runtime-scan-action ${state.scanTorchOn ? "is-active" : ""}"
                type="button"
                data-action="toggle-scan-torch"
                aria-pressed="${state.scanTorchOn}"
              >
                <span class="runtime-scan-action__icon">${renderIcon("flashlight", "runtime-scan-action__glyph")}</span>
                <span>手电筒</span>
              </button>
            </div>
            ${
              result
                ? `
                  <section class="runtime-scan-result runtime-scan-result--${result.tone}" role="dialog" aria-modal="false" aria-labelledby="scan-result-title">
                    <span class="runtime-scan-result__icon">
                      ${renderIcon(result.tone === "success" ? "contacts" : "close", "runtime-scan-result__glyph")}
                    </span>
                    <span class="runtime-scan-result__copy">
                      <strong id="scan-result-title">${result.title}</strong>
                      <span>${result.summary}</span>
                    </span>
                    ${
                      result.tone === "success"
                        ? `<button class="runtime-scan-result__button" type="button" data-action="navigate" data-route="/groups/settings/g_launch">查看</button>`
                        : `<button class="runtime-scan-result__button" type="button" data-action="reset-scan">重试</button>`
                    }
                    <button class="runtime-scan-result__close" type="button" data-action="reset-scan" aria-label="关闭识别结果">
                      ${renderIcon("close", "runtime-scan-result__close-icon")}
                    </button>
                  </section>
                `
                : ""
            }
          </div>
        </div>
      </section>
    `;
  }

  function simulateScan(forceSuccess = false) {
    state.scanSimulationCount += 1;
    state.scanStatus = forceSuccess || state.scanSimulationCount % 2 === 1 ? "success" : "error";
    render();
  }

  function resetScan() {
    state.scanStatus = "scanning";
    render();
  }

  function renderDiscoverNearbyScreen() {
    const nearbyPeople = data.discover.nearbyPeople || [];
    const filteredPeople = nearbyPeople.filter((person) => {
      if (state.nearbyFilter === "near") {
        return person.distanceMeters <= 1000;
      }
      if (state.nearbyFilter === "online") {
        return person.status === "在线";
      }
      return true;
    });
    const filterItems = [
      { id: "all", label: "全部" },
      { id: "near", label: "1 公里内" },
      { id: "online", label: "在线" },
    ];

    return `
      <section class="screen runtime-screen runtime-screen--list runtime-nearby-screen">
        ${renderScreenHeader({
          title: "附近的人",
          backPath: "/discover",
          variant: "compact",
        })}
        <div class="screen-scroll runtime-scroll runtime-nearby-scroll">
          <div class="runtime-nearby-content">
            <section class="runtime-nearby-location" aria-label="当前位置">
              <span class="runtime-nearby-location__icon">${renderIcon("mapPin", "runtime-nearby-location__glyph")}</span>
              <span class="runtime-nearby-location__copy">
                <strong>上海 · 徐汇滨江</strong>
                <span>位置服务已开启</span>
              </span>
              <button type="button" data-action="show-hint" data-message="位置已更新为徐汇滨江。">更新</button>
            </section>
            <div class="runtime-nearby-filters" role="tablist" aria-label="附近的人筛选">
              ${filterItems
                .map(
                  (filter) => `
                    <button
                      class="runtime-nearby-filter ${state.nearbyFilter === filter.id ? "is-active" : ""}"
                      type="button"
                      role="tab"
                      data-action="set-nearby-filter"
                      data-nearby-filter="${filter.id}"
                      aria-selected="${state.nearbyFilter === filter.id}"
                    >${filter.label}</button>
                  `,
                )
                .join("")}
            </div>
            <section class="runtime-nearby-section" aria-labelledby="nearby-results-heading">
              <div class="runtime-nearby-section__heading">
                <h3 id="nearby-results-heading">发现 ${filteredPeople.length} 人</h3>
                <span>按距离排序</span>
              </div>
              ${
                filteredPeople.length
                  ? `<div class="runtime-nearby-list">${filteredPeople.map(renderNearbyPersonCard).join("")}</div>`
                  : renderEmptyState("暂无匹配的人", "调整筛选条件后再看看。")
              }
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderNearbyPersonCard(item) {
    const greeted = state.greetedNearbyIds.has(item.id);

    return `
      <article class="runtime-nearby-person">
        <button
          class="runtime-nearby-person__profile"
          type="button"
          data-action="navigate"
          data-route="/contacts/profile/${escapeHtml(item.contactId)}"
          aria-label="查看 ${escapeHtml(item.name)} 的资料"
        >
          <span class="runtime-nearby-person__avatar">
            ${renderAvatar(item.name, item.tone, "avatar--md")}
            <span class="runtime-nearby-person__presence ${presenceClass(item.status)}" aria-hidden="true"></span>
          </span>
          <span class="runtime-nearby-person__body">
            <span class="runtime-nearby-person__title">
            <strong>${escapeHtml(item.name)}</strong>
              <span>${escapeHtml(item.distance)}</span>
            </span>
            <span class="runtime-nearby-person__meta">${escapeHtml(item.title)} · ${escapeHtml(item.status)}</span>
            <span class="runtime-nearby-person__note">${escapeHtml(item.note)}</span>
          </span>
        </button>
        <button
          class="runtime-nearby-person__greet ${greeted ? "is-sent" : ""}"
          type="button"
          data-action="send-nearby-greeting"
          data-nearby-id="${escapeHtml(item.id)}"
          ${greeted ? "disabled" : ""}
        >${greeted ? "已发送" : "打招呼"}</button>
      </article>
    `;
  }

  function sendNearbyGreeting(personId) {
    const person = (data.discover.nearbyPeople || []).find((item) => item.id === personId);
    if (!person || state.greetedNearbyIds.has(personId)) {
      return;
    }
    state.greetedNearbyIds.add(personId);
    showToast("招呼已发送", `已向 ${person.name} 发送招呼。`);
    render();
  }

  function renderDiscoverGamesScreen() {
    const games = data.discover.games || [];
    const recentGame = games.find((game) => game.recent && game.status === "available") || null;

    return `
      <section class="screen runtime-screen runtime-screen--list runtime-games-screen">
        ${renderScreenHeader({
          title: "游戏",
          backPath: "/discover",
          variant: "compact",
        })}
        <div class="screen-scroll runtime-scroll runtime-games-scroll">
          <div class="runtime-games-content">
            ${
              recentGame
                ? `
                  <section class="runtime-games-section" aria-labelledby="recent-games-title">
                    <div class="runtime-games-section__heading">
                      <h3 id="recent-games-title">最近玩过</h3>
                      <span>今天</span>
                    </div>
                    <button
                      class="runtime-game-feature"
                      type="button"
                      data-action="launch-game"
                      data-game-id="${escapeHtml(recentGame.id)}"
                    >
                      ${renderGameCover(recentGame, "feature")}
                      <span class="runtime-game-feature__body">
                        <strong>${escapeHtml(recentGame.title)}</strong>
                        <span>${escapeHtml(recentGame.summary)}</span>
                        <small>${escapeHtml(recentGame.activity)}</small>
                      </span>
                      <span class="runtime-game-feature__resume">继续</span>
                    </button>
                  </section>
                `
                : ""
            }
            <section class="runtime-games-section" aria-labelledby="all-games-title">
              <div class="runtime-games-section__heading">
                <h3 id="all-games-title">全部游戏</h3>
                <span>${games.length} 款</span>
              </div>
              ${
                games.length
                  ? `<div class="runtime-game-list">${games.map(renderGameRow).join("")}</div>`
                  : renderEmptyState("暂无游戏", "新游戏上线后会显示在这里。")
              }
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderGameCover(game, variant = "row") {
    return `
      <span class="runtime-game-cover runtime-game-cover--${variant} runtime-game-cover--${escapeHtml(game.tone)}" aria-hidden="true">
        ${renderIcon(game.icon, "runtime-game-cover__glyph")}
      </span>
    `;
  }

  function renderGameRow(game) {
    const available = game.status === "available";
    return `
      <button
        class="runtime-game-row"
        type="button"
        data-action="${available ? "launch-game" : "show-hint"}"
        ${available ? `data-game-id="${escapeHtml(game.id)}"` : `data-message="${escapeHtml(game.title)}正在维护中。"`}
        aria-label="${escapeHtml(game.title)}，${available ? "进入游戏" : "维护中"}"
      >
        ${renderGameCover(game)}
        <span class="runtime-game-row__body">
          <span class="runtime-game-row__title">
            <strong>${escapeHtml(game.title)}</strong>
            <small>${escapeHtml(game.category)}</small>
          </span>
          <span>${escapeHtml(game.summary)}</span>
          <small>${escapeHtml(game.activity)}</small>
        </span>
        <span class="runtime-game-row__status ${available ? "is-available" : "is-maintenance"}">${available ? "进入" : "维护中"}</span>
      </button>
    `;
  }

  function launchGame(gameId) {
    const game = (data.discover.games || []).find((item) => item.id === gameId && item.status === "available");
    if (!game) {
      return;
    }
    showToast("正在进入游戏", `${game.title} 已准备就绪。`);
    render();
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
    const activeTab = state.friendRequestTab === "outgoing" ? "outgoing" : "incoming";
    const activeRequests = activeTab === "incoming" ? incoming : outgoing;

    return `
      <section class="screen runtime-screen runtime-friend-requests-screen">
        ${renderScreenHeader({
          title: "新的朋友",
          backPath: "/contacts",
          variant: "compact",
        })}
        ${renderFriendRequestTabs(activeTab, {
          incoming: incoming.length,
          outgoing: outgoing.length,
        })}
        <div class="screen-scroll runtime-scroll runtime-request-scroll">
          <div
            id="friend-requests-panel"
            class="runtime-request-panel"
            role="tabpanel"
            tabindex="0"
            aria-labelledby="friend-request-tab-${activeTab}"
          >
            ${renderRequestSection(activeRequests, activeTab)}
          </div>
        </div>
      </section>
    `;
  }

  function renderFriendRequestTabs(activeTab, counts) {
    const tabs = [
      { id: "incoming", label: "收到的申请", count: counts.incoming },
      { id: "outgoing", label: "发出的申请", count: counts.outgoing },
    ];

    return `
      <nav class="runtime-request-tabs" role="tablist" aria-label="好友申请">
        ${tabs
          .map(
            (tab) => `
              <button
                id="friend-request-tab-${tab.id}"
                class="runtime-request-tabs__item ${activeTab === tab.id ? "is-active" : ""}"
                type="button"
                role="tab"
                data-action="set-request-tab"
                data-request-tab="${tab.id}"
                aria-controls="friend-requests-panel"
                aria-selected="${activeTab === tab.id}"
                aria-label="${tab.label}，共 ${tab.count} 条"
                tabindex="${activeTab === tab.id ? "0" : "-1"}"
              >
                <span class="runtime-request-tabs__label">${tab.label}</span>
                <span class="runtime-request-tabs__count" aria-hidden="true">${tab.count}</span>
              </button>
            `,
          )
          .join("")}
      </nav>
    `;
  }

  function renderRequestSection(requests, type) {
    return `
      <section class="request-section request-section--${type}">
        ${requests.length
          ? `<div class="request-section__list">${requests.map((request) => renderRequestCard(request)).join("")}</div>`
          : renderEmptyState(
              type === "incoming" ? "暂无收到的申请" : "暂无发出的申请",
              type === "incoming"
                ? "新的好友申请会显示在这里。"
                : "从添加好友页发出的申请会显示在这里。",
            )}
      </section>
    `;
  }

  function renderRequestCard(request) {
    const isIncoming = request.type === "incoming";
    const pending = request.status === "pending";
    const requestStatus = !isIncoming && pending ? "已发送" : statusLabel(request.status);
    const requestStatusClass = !isIncoming && pending ? "sent" : request.status;
    const requestLabel = `${request.name}${isIncoming ? "的好友申请" : "发出的好友申请"}，${requestStatus}`;
    const showResult = (isIncoming && !pending) || (!isIncoming && request.status === "withdrawn");
    const resultLabel = request.status === "accepted"
      ? "已建立好友关系"
      : request.status === "rejected"
      ? "已忽略该申请"
      : request.status === "withdrawn"
      ? "已撤回申请"
      : requestStatus;

    return `
      <article class="request-card request-card--${request.type}" aria-label="${escapeHtml(requestLabel)}">
        <div class="request-card__header">
          ${renderAvatar(request.name, request.tone, "avatar--md")}
          <div class="request-card__body">
            <div class="request-card__identity">
              <strong>${escapeHtml(request.name)}</strong>
              <span class="request-card__status request-card__status--${requestStatusClass}">${escapeHtml(requestStatus)}</span>
            </div>
            <div class="request-card__meta">
              <span>@${escapeHtml(request.username)} · ${escapeHtml(request.title)}</span>
            </div>
          </div>
          <time class="request-card__time">${escapeHtml(request.time)}</time>
        </div>
        <p class="request-card__message">
          <span class="request-card__message-label">申请留言</span>
          <span class="request-card__message-copy">${escapeHtml(request.message)}</span>
        </p>
        ${
          isIncoming && pending
            ? `
              <div class="request-card__actions">
                <button class="request-card__action request-card__action--secondary" type="button" data-action="update-request" data-request-id="${request.id}" data-status="rejected" aria-label="忽略 ${escapeHtml(request.name)} 的好友申请">忽略</button>
                <button class="request-card__action request-card__action--primary" type="button" data-action="update-request" data-request-id="${request.id}" data-status="accepted" aria-label="通过 ${escapeHtml(request.name)} 的好友申请">通过</button>
              </div>
            `
            : !isIncoming && pending
            ? `
              <div class="request-card__actions request-card__actions--single">
                <button class="request-card__action request-card__action--secondary" type="button" data-action="update-request" data-request-id="${request.id}" data-status="withdrawn">撤回申请</button>
              </div>
            `
            : showResult
            ? `
              <div class="request-card__actions request-card__actions--single request-card__actions--resolved" role="status">
                <span class="request-card__result">${escapeHtml(resultLabel)}</span>
              </div>
            `
            : ""
        }
      </article>
    `;
  }

  function renderAddFriendScreen() {
    const users = filteredSearchUsers();
    const hasQuery = Boolean(state.friendSearch.trim());
    const resultTitle = state.friendSearchPending ? "正在搜索" : hasQuery ? "搜索结果" : "推荐联系人";
    const resultMeta = state.friendSearchPending ? "请稍候" : `${users.length} 位`;

    return `
      <section class="screen runtime-screen runtime-screen--list runtime-add-friend-screen">
        ${renderScreenHeader({
          title: "添加好友",
          backPath: "/contacts",
          variant: "compact",
        })}
        <div class="screen-scroll runtime-scroll runtime-add-friend-scroll">
          <div class="runtime-add-friend-content">
            <label class="runtime-search-field runtime-add-friend-search" role="search">
              ${renderIcon("search", "runtime-search-field__icon", "搜索好友")}
                <input
                  id="friend-search-input"
                  value="${escapeHtml(state.friendSearch)}"
                  placeholder="搜索昵称、账号或城市"
                  aria-label="搜索昵称、账号或城市"
                  aria-controls="add-friend-results"
                />
              ${
                hasQuery
                  ? `<button class="runtime-add-friend-search__clear" type="button" data-action="clear-friend-search" aria-label="清空搜索">${renderIcon("close", "runtime-add-friend-search__clear-icon")}</button>`
                  : ""
              }
            </label>
            <section class="runtime-add-friend-note" aria-labelledby="friend-note-title">
              <div class="runtime-add-friend-note__heading">
                <h3 id="friend-note-title">申请留言</h3>
                <span class="runtime-add-friend-note__count">${state.friendNote.trim().length}/80</span>
              </div>
              <label class="runtime-add-friend-note__field">
                <span class="runtime-visually-hidden">申请留言</span>
                <textarea
                  id="friend-note-input"
                  rows="3"
                  maxlength="80"
                  placeholder="简单介绍一下自己"
                >${escapeHtml(state.friendNote)}</textarea>
              </label>
            </section>
            <section
              id="add-friend-results"
              class="runtime-add-friend-results"
              aria-labelledby="add-friend-results-title"
              aria-busy="${state.friendSearchPending}"
            >
              <div class="runtime-add-friend-results__header">
                <h3 id="add-friend-results-title">${resultTitle}</h3>
                <span data-role="friend-search-status">${resultMeta}</span>
              </div>
              <div class="runtime-add-friend-results__list">
                ${
                  users.length
                    ? users.map(renderSearchUserItem).join("")
                    : renderEmptyState(
                        hasQuery ? "没有匹配结果" : "暂无推荐联系人",
                        hasQuery ? "换个昵称、账号或城市再试试。" : "搜索昵称或账号来添加新的朋友。",
                      )
                }
              </div>
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderSearchUserItem(user) {
    const action = renderSearchUserAction(user);

    return `
      <article class="runtime-add-friend-result">
        <span class="runtime-add-friend-result__avatar">${renderAvatar(user.name, user.tone, "avatar--md")}</span>
        <span class="runtime-add-friend-result__body">
          <strong>${escapeHtml(user.name)}</strong>
          <span class="runtime-add-friend-result__identity">@${escapeHtml(user.username)} · ${escapeHtml(user.title)}</span>
          <span class="runtime-add-friend-result__city">
            ${renderIcon("mapPin", "runtime-add-friend-result__city-icon")}
            ${escapeHtml(user.city)}
          </span>
        </span>
        <span class="runtime-add-friend-result__action">${action}</span>
      </article>
    `;
  }

  function renderSearchUserAction(user) {
    if (user.relation === "pending_incoming") {
      return `<button class="runtime-add-friend-result__button runtime-add-friend-result__button--secondary" type="button" data-action="navigate" data-route="/contacts/requests">去处理</button>`;
    }
    if (user.relation === "pending_outgoing") {
      return `<button class="runtime-add-friend-result__button runtime-add-friend-result__button--disabled" type="button" disabled>已发送</button>`;
    }
    if (user.relation === "friend") {
      return `<button class="runtime-add-friend-result__button runtime-add-friend-result__button--secondary" type="button" data-action="open-direct-chat" data-contact-id="${user.id}">发消息</button>`;
    }
    return `<button class="runtime-add-friend-result__button runtime-add-friend-result__button--primary" type="button" data-action="send-friend-request" data-user-id="${user.id}">添加</button>`;
  }

  function renderContactProfileScreen(contactId) {
    const contact = findContact(contactId);
    if (!contact) {
      return renderFallbackScreen("联系人不存在", "/contacts");
    }
    const relatedGroups = groupsForContact(contact.id);
    const statusTone = contact.status === "在线" ? "online" : contact.status === "忙碌中" ? "busy" : "away";
    const remark = typeof contact.remark === "string" ? contact.remark.trim() : "";

    return `
      <section class="screen runtime-contact-profile-screen">
        ${renderScreenHeader({
          title: "联系人资料",
          subtitle: "单独承载联系人详情，而不是和列表并排",
          backPath: "/contacts",
        })}
        <div class="screen-scroll runtime-contact-profile-scroll">
          <div class="runtime-contact-profile">
            <section class="runtime-contact-profile__hero" aria-label="${escapeHtml(contact.name)} 的联系人资料">
              <span class="runtime-contact-profile__portrait">
                ${renderAvatar(contact.name, contact.tone, "avatar--xl")}
              </span>
              <div class="runtime-contact-profile__identity-meta">
                <div class="runtime-contact-profile__name-line">
                  <h3>${escapeHtml(contact.name)}</h3>
                  <span class="runtime-contact-profile__presence runtime-contact-profile__presence--${statusTone}">${escapeHtml(contact.status)}</span>
                </div>
                <p class="runtime-contact-profile__role">${escapeHtml(contact.title)}</p>
                <p class="runtime-contact-profile__handle">@${escapeHtml(contact.username)}</p>
              </div>
            </section>

            <section class="runtime-contact-profile__section" aria-labelledby="contact-profile-info-title">
              <div class="runtime-contact-profile__section-heading">
                <h3 id="contact-profile-info-title">联系人信息</h3>
              </div>
              <dl class="runtime-contact-profile__fact-list">
                <div class="runtime-contact-profile__fact-row runtime-contact-profile__fact-row--remark">
                  <dt>备注名</dt>
                  <dd>
                    <button
                      class="runtime-contact-profile__remark-edit"
                      type="button"
                      data-action="edit-contact-remark"
                      data-contact-id="${escapeHtml(contact.id)}"
                      aria-label="编辑 ${escapeHtml(contact.name)} 的备注名，当前为${escapeHtml(remark || "未设置")}"
                    >
                      <span class="runtime-contact-profile__remark-value ${remark ? "" : "is-empty"}">${escapeHtml(remark || "未设置")}</span>
                      ${renderIcon("chevronRight", "runtime-contact-profile__remark-chevron")}
                    </button>
                  </dd>
                </div>
                <div class="runtime-contact-profile__fact-row">
                  <dt>账号</dt>
                  <dd>@${escapeHtml(contact.username)}</dd>
                </div>
                <div class="runtime-contact-profile__fact-row">
                  <dt>团队</dt>
                  <dd>${escapeHtml(contact.zone)}</dd>
                </div>
              </dl>
            </section>

            ${
              relatedGroups.length
                ? `
                  <section class="runtime-contact-profile__section runtime-contact-profile__section--shared" aria-labelledby="contact-profile-groups-title">
                    <div class="runtime-contact-profile__section-heading">
                      <h3 id="contact-profile-groups-title">共同群聊</h3>
                      <span>${relatedGroups.length}</span>
                    </div>
                    <div class="runtime-contact-profile__shared-list">
                      ${relatedGroups
                        .map(
                          (group) => `
                            <button
                              class="runtime-contact-profile__shared-row"
                              type="button"
                              data-action="navigate"
                              data-route="/chat/${group.chatId}"
                              aria-label="打开 ${escapeHtml(group.name)} 群聊"
                            >
                              <span class="runtime-contact-profile__shared-avatar">${renderGroupAvatar(group)}</span>
                              <span class="runtime-contact-profile__shared-copy">
                                <strong>${escapeHtml(group.name)}</strong>
                                <small>${escapeHtml(group.notice || "暂无群公告")}</small>
                              </span>
                              <span class="runtime-contact-profile__shared-meta">${group.memberCount} 人</span>
                              ${renderIcon("chevronRight", "runtime-contact-profile__shared-chevron")}
                            </button>
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
        <footer class="runtime-contact-profile__action-dock" aria-label="${escapeHtml(contact.name)} 的操作">
          <button
            class="runtime-contact-profile__more-action"
            type="button"
            data-action="open-contact-actions"
            data-contact-id="${escapeHtml(contact.id)}"
            aria-label="更多联系人操作"
            title="更多联系人操作"
          >
            ${renderIcon("more", "runtime-contact-profile__more-icon")}
          </button>
          <button class="runtime-contact-profile__message-action" type="button" data-action="open-direct-chat" data-contact-id="${contact.id}">
            ${renderIcon("send", "runtime-contact-profile__message-icon")}
            <span>发送消息</span>
          </button>
        </footer>
      </section>
    `;
  }

  function renderContactProfileOverlay(route) {
    const editorContactId = state.contactRemarkEditorContactId;
    const actionContactId = state.contactActionSheetContactId;
    const contactId = editorContactId || actionContactId;
    if (!contactId || route.section !== "contact-profile" || route.contactId !== contactId) {
      return "";
    }

    const contact = findContact(contactId);
    if (!contact) {
      return "";
    }

    if (editorContactId) {
      return `
        <div class="runtime-contact-profile__overlay">
          <button class="runtime-contact-profile__overlay-scrim" type="button" data-action="close-contact-profile-overlay" aria-label="关闭修改备注名"></button>
          <section class="runtime-contact-profile__sheet runtime-contact-profile__remark-sheet" role="dialog" aria-modal="true" aria-labelledby="contact-remark-editor-title">
            <span class="runtime-contact-profile__sheet-handle" aria-hidden="true"></span>
            <form class="runtime-contact-profile__remark-form" data-form="contact-remark-form" data-contact-id="${escapeHtml(contact.id)}">
              <div class="runtime-contact-profile__sheet-heading">
                <h3 id="contact-remark-editor-title">修改备注名</h3>
                <p>${escapeHtml(contact.name)}</p>
              </div>
              <label class="runtime-contact-profile__remark-field" for="contact-remark-input">
                <span>备注名</span>
                <input
                  id="contact-remark-input"
                  type="text"
                  value="${escapeHtml(state.contactRemarkDraft)}"
                  maxlength="24"
                  autocomplete="off"
                  autocapitalize="words"
                  aria-describedby="contact-remark-help"
                >
              </label>
              <p class="runtime-contact-profile__remark-help" id="contact-remark-help">仅自己可见</p>
              <div class="runtime-contact-profile__sheet-actions">
                <button class="runtime-contact-profile__sheet-button runtime-contact-profile__sheet-button--secondary" type="button" data-action="close-contact-profile-overlay">取消</button>
                <button class="runtime-contact-profile__sheet-button runtime-contact-profile__sheet-button--primary" type="submit">保存</button>
              </div>
            </form>
          </section>
        </div>
      `;
    }

    return `
      <div class="runtime-contact-profile__overlay">
        <button class="runtime-contact-profile__overlay-scrim" type="button" data-action="close-contact-profile-overlay" aria-label="关闭联系人操作"></button>
        <section class="runtime-contact-profile__sheet runtime-contact-profile__actions-sheet" role="dialog" aria-modal="true" aria-labelledby="contact-actions-title">
          <span class="runtime-contact-profile__sheet-handle" aria-hidden="true"></span>
          <div class="runtime-contact-profile__sheet-heading">
            <h3 id="contact-actions-title">联系人操作</h3>
            <p>${escapeHtml(contact.name)}</p>
          </div>
          <div class="runtime-contact-profile__action-list" role="group" aria-label="${escapeHtml(contact.name)} 的更多操作">
            <button type="button" data-action="edit-contact-remark" data-contact-id="${escapeHtml(contact.id)}">
              ${renderIcon("edit", "runtime-contact-profile__action-icon")}
              <span>修改备注</span>
            </button>
            <button type="button" data-action="start-contact-action" data-contact-action="voice" data-contact-id="${escapeHtml(contact.id)}">
              ${renderIcon("phone", "runtime-contact-profile__action-icon")}
              <span>语音通话</span>
            </button>
            <button type="button" data-action="start-contact-action" data-contact-action="video" data-contact-id="${escapeHtml(contact.id)}">
              ${renderIcon("video", "runtime-contact-profile__action-icon")}
              <span>视频通话</span>
            </button>
          </div>
          <button class="runtime-contact-profile__sheet-cancel" type="button" data-action="close-contact-profile-overlay">取消</button>
        </section>
      </div>
    `;
  }

  function groupDirectoryGroups() {
    const favoriteGroups = data.groups.filter((group) => state.savedGroupIds.has(group.id));
    const otherGroups = data.groups.filter((group) => !state.savedGroupIds.has(group.id));
    return { favoriteGroups, otherGroups };
  }

  function renderGroupsScreen() {
    const { favoriteGroups, otherGroups } = groupDirectoryGroups();
    const hasGroups = favoriteGroups.length || otherGroups.length;

    return `
      <section class="screen runtime-screen runtime-screen--list runtime-screen--group-list">
        <div class="screen-scroll runtime-scroll">
          ${renderScreenHeader({
            title: "群聊",
            backPath: "/contacts",
            actions: [
              `<button class="runtime-icon-button runtime-icon-button--quiet" data-action="navigate" data-route="/groups/create" aria-label="创建群聊">${renderIcon("plus", "runtime-icon-button__glyph", "创建群聊")}</button>`,
            ],
          })}
          <div class="runtime-list-content">
            ${
              hasGroups
                ? `
                  <div class="runtime-group-directory">
                    ${
                      favoriteGroups.length
                        ? `
                          <section class="runtime-group-directory__section">
                            <div class="runtime-section-heading">
                              <h3>收藏群聊</h3>
                              <span class="runtime-group-directory__count">${favoriteGroups.length}</span>
                            </div>
                            <div class="runtime-conversation-list">
                              ${favoriteGroups.map(renderGroupConversationRow).join("")}
                            </div>
                          </section>
                        `
                        : ""
                    }
                    ${
                      otherGroups.length
                        ? `
                          <div class="runtime-conversation-list">
                            ${otherGroups.map(renderGroupConversationRow).join("")}
                          </div>
                        `
                        : ""
                    }
                  </div>
                `
                : renderEmptyState("暂无群聊", "从聊天页创建一个群聊。")
            }
          </div>
        </div>
      </section>
    `;
  }

  function renderGroupConversationRow(group) {
    const chat = findChat(group.chatId);
    if (chat) {
      return renderConversationRow(chat);
    }

    return `
      <button class="runtime-conversation" data-action="navigate" data-route="/chat/${group.chatId}">
        <span class="runtime-conversation__avatar">
          ${renderGroupAvatar(group)}
        </span>
        <span class="runtime-conversation__body">
          <strong>${escapeHtml(group.name)}</strong>
          <span class="runtime-conversation__summary">
            <span class="runtime-conversation__context">${group.memberCount} 人</span>
            <span class="runtime-conversation__summary-text">暂无消息</span>
          </span>
        </span>
        <span class="runtime-conversation__meta">
          <time></time>
        </span>
      </button>
    `;
  }

  function renderGroupAvatar(group) {
    const chat = findChat(group.chatId);
    const knownMemberIds = Array.from(
      new Set([...(group.members || []), ...(chat?.participants || [])]),
    );
    const memberIds = knownMemberIds
      .filter((memberId) => memberId !== data.currentUser.id)
      .concat(knownMemberIds.includes(data.currentUser.id) ? [data.currentUser.id] : []);
    const members = memberIds.map(findPerson).filter(Boolean).slice(0, 4);
    const remainingCount = Math.max(0, Number(group.memberCount || 0) - members.length);
    const tiles = members
      .map((member) => renderAvatar(member.name, member.tone || member.avatarTone, "runtime-group-avatar__tile"))
      .join("");
    const moreTile = remainingCount > 0 && members.length < 4
      ? `<span class="runtime-group-avatar__more">+${remainingCount}</span>`
      : "";

    return `<span class="runtime-group-avatar" aria-hidden="true">${tiles}${moreTile}</span>`;
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
      <section class="screen runtime-screen runtime-screen--group-settings">
        ${renderScreenHeader({
          title: "群设置",
          backPath: `/chat/${group.chatId}`,
          variant: "compact",
        })}
        <div class="screen-scroll runtime-scroll runtime-topbar-scroll">
          <div class="runtime-list-content runtime-group-settings-content">
            <section class="runtime-group-overview" aria-label="${escapeHtml(group.name)} 群概览">
              <span class="runtime-group-overview__avatar">${renderGroupAvatar(group)}</span>
              <span class="runtime-group-overview__copy">
                <strong>${escapeHtml(group.name)}</strong>
                <span class="runtime-group-overview__meta">${group.memberCount} 位成员 · ${group.onlineCount} 位在线</span>
                <span class="runtime-group-overview__tags">
                  ${group.tags.map((tag) => `<span>${escapeHtml(tag)}</span>`).join("")}
                </span>
              </span>
            </section>
            ${renderGroupMembersSection(group, members)}
            <section class="runtime-settings-group runtime-group-settings-group">
              <h3>我的群聊</h3>
              <label class="runtime-setting-row runtime-setting-row--switch runtime-group-preference">
                <span class="runtime-setting-row__copy">
                  <strong>收藏群聊</strong>
                  <small>在联系人 > 群聊中优先显示</small>
                </span>
                <input
                  class="switch-row__input"
                  type="checkbox"
                  data-kind="group-directory-favorite"
                  data-group-id="${group.id}"
                  ${state.savedGroupIds.has(group.id) ? "checked" : ""}
                />
              </label>
            </section>
            <section class="runtime-settings-group runtime-group-settings-group">
              <h3>群信息</h3>
              <div class="runtime-group-notice">
                <strong>群公告</strong>
                <p>${escapeHtml(group.notice)}</p>
              </div>
            </section>
            <section class="runtime-settings-group runtime-group-settings-group">
              <h3>群权限</h3>
              <div class="runtime-group-policy">
                <span class="runtime-group-policy__copy">
                  <strong>加入方式</strong>
                  <small>控制新成员进入此群的方式</small>
                </span>
                <div class="choice-row runtime-group-policy__choices" role="group" aria-label="加入方式">
                  ${renderChoiceButton("join-policy", group.id, "invite_only", joinPolicyLabel("invite_only"), group.joinPolicy)}
                  ${renderChoiceButton("join-policy", group.id, "review_required", joinPolicyLabel("review_required"), group.joinPolicy)}
                </div>
              </div>
              <div class="runtime-group-policy">
                <span class="runtime-group-policy__copy">
                  <strong>发言策略</strong>
                  <small>控制群成员的发言范围</small>
                </span>
                <div class="choice-row runtime-group-policy__choices" role="group" aria-label="发言策略">
                  ${renderChoiceButton("mute-mode", group.id, "free", muteModeLabel("free"), group.muteMode)}
                  ${renderChoiceButton("mute-mode", group.id, "admin_only", muteModeLabel("admin_only"), group.muteMode)}
                </div>
              </div>
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderGroupMembersSection(group, members) {
    const isExpanded = state.expandedGroupMemberIds.has(group.id);
    const visibleMembers = isExpanded ? members : members.slice(0, GROUP_MEMBER_PREVIEW_LIMIT);
    const remainingMemberCount = Math.max(0, group.memberCount - members.length);
    const hasMoreMembers = members.length > GROUP_MEMBER_PREVIEW_LIMIT || remainingMemberCount > 0;
    const memberToggleLabel = isExpanded ? "收起成员" : `查看更多成员 · ${group.memberCount} 人`;

    return `
      <section class="runtime-settings-group runtime-group-settings-group runtime-group-members-section">
        <div class="runtime-group-member-preview ${isExpanded ? "is-expanded" : ""}">
          <div class="runtime-group-member-grid">
            ${visibleMembers.map(renderGroupSettingsMember).join("")}
            ${isExpanded && remainingMemberCount ? renderGroupMemberOverflow(remainingMemberCount) : ""}
          </div>
        </div>
        ${
          hasMoreMembers
            ? `
              <button
                class="runtime-group-member-toggle"
                type="button"
                data-action="toggle-group-members"
                data-group-id="${group.id}"
                aria-expanded="${isExpanded}"
              >
                <span class="runtime-group-member-toggle__label">${memberToggleLabel}</span>
                ${renderIcon(isExpanded ? "chevronUp" : "chevronDown", "runtime-group-member-toggle__icon", memberToggleLabel)}
              </button>
            `
            : ""
        }
      </section>
    `;
  }

  function renderGroupMemberOverflow(remainingMemberCount) {
    return `
      <span class="runtime-group-member runtime-group-member--overflow" aria-label="还有 ${remainingMemberCount} 位成员">
        <span class="runtime-group-member__count">+${remainingMemberCount}</span>
        <strong>其他成员</strong>
      </span>
    `;
  }

  function renderGroupSettingsMember(member) {
    const name = member.name || member.username || "Unknown";
    const tone = member.tone || member.avatarTone || "mint";

    return `
      <span class="runtime-group-member">
        ${renderAvatar(name, tone, "avatar--sm")}
        <strong title="${escapeHtml(name)}">${escapeHtml(name)}</strong>
      </span>
    `;
  }

  function renderChoiceButton(kind, groupId, value, label, currentValue) {
    const isActive = currentValue === value;
    return `
      <button
        class="choice-button ${isActive ? "is-active" : ""}"
        type="button"
        data-action="update-group-field"
        data-kind="${kind}"
        data-group-id="${groupId}"
        data-value="${value}"
        aria-pressed="${isActive}"
      >
        ${label}
      </button>
    `;
  }

  function renderSearchScreen() {
    const query = state.searchQuery.trim();
    const hasQuery = Boolean(query);
    const results = searchResults();
    const resultTitle = hasQuery ? "搜索结果" : "最近消息";

    return `
      <section class="screen runtime-screen runtime-message-search-screen">
        ${renderScreenHeader({
          title: "消息搜索",
          backPath: "/chats",
          variant: "compact",
        })}
        <div class="runtime-message-search__toolbar">
          <label class="runtime-message-search__field">
            ${renderIcon("search", "runtime-message-search__field-icon")}
            <input
              id="global-search-input"
              value="${escapeHtml(state.searchQuery)}"
              placeholder="搜索消息"
              aria-label="搜索消息"
              aria-controls="message-search-results"
              autocomplete="off"
              enterkeyhint="search"
              autofocus
            />
            ${
              hasQuery
                ? `
                  <button
                    class="runtime-message-search__clear"
                    type="button"
                    data-action="prefill-search"
                    data-value=""
                    aria-label="清除搜索"
                  >
                    ${renderIcon("close", "runtime-message-search__clear-icon")}
                  </button>
                `
                : ""
            }
          </label>
        </div>
        <div class="screen-scroll runtime-scroll runtime-message-search__scroll">
          <div class="runtime-message-search__content">
            ${
              !hasQuery
                ? `
                  <section class="runtime-message-search__suggestions" aria-labelledby="message-search-suggestions-title">
                    <div class="runtime-message-search__section-heading">
                      <h3 id="message-search-suggestions-title">常用关键词</h3>
                    </div>
                    <div class="runtime-message-search__chips">
                      ${["发布", "设计", "AI", "群公告"]
                        .map(
                          (item) => `
                            <button class="runtime-message-search__chip" type="button" data-action="prefill-search" data-value="${item}">
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
            <section class="runtime-message-search__results" aria-labelledby="message-search-results-title">
              <div class="runtime-message-search__section-heading">
                <h3 id="message-search-results-title">${resultTitle}</h3>
                <span class="runtime-message-search__section-count">${results.length} 条</span>
              </div>
              ${
                results.length
                  ? `<div id="message-search-results" class="runtime-message-search__result-list">${results.map(renderSearchResultRow).join("")}</div>`
                  : `
                    <div id="message-search-results" class="runtime-message-search__empty" aria-live="polite">
                      ${renderIcon("search", "runtime-message-search__empty-icon")}
                      <strong>没有相关消息</strong>
                      <span>换个关键词试试</span>
                    </div>
                  `
              }
            </section>
          </div>
        </div>
      </section>
    `;
  }

  function renderSearchResultRow(item) {
    const group = findGroupByChatId(item.chat.id);
    const isGroup = item.chat.type === "group";
    const conversationName = item.chat.name || "未知会话";
    const senderName = item.message.self ? "你" : item.message.senderName || "未知";
    const shouldShowSender = isGroup || senderName !== conversationName;
    const avatar = group
      ? renderGroupAvatar(group)
      : renderAvatar(conversationName, item.chat.avatarTone, "avatar--sm");
    const senderPrefix = shouldShowSender
      ? `<span class="runtime-message-search__sender">${renderSearchHighlight(senderName, state.searchQuery)}<span aria-hidden="true"> · </span></span>`
      : "";
    const label = `在${conversationName}中查看${senderName}于${item.message.time}发送的消息`;

    return `
      <button
        class="runtime-message-search__result"
        type="button"
        data-action="open-search-result"
        data-chat-id="${item.chat.id}"
        data-message-id="${item.message.id}"
        aria-label="${escapeHtml(label)}"
      >
        <span class="runtime-message-search__avatar">${avatar}</span>
        <span class="runtime-message-search__result-body">
          <span class="runtime-message-search__result-top">
            <span class="runtime-message-search__conversation">
              <strong>${escapeHtml(conversationName)}</strong>
              <span class="runtime-message-search__kind">${isGroup ? "群聊" : "单聊"}</span>
            </span>
            <time>${escapeHtml(item.message.time)}</time>
          </span>
          <span class="runtime-message-search__excerpt">${senderPrefix}${renderSearchHighlight(item.message.content, state.searchQuery)}</span>
        </span>
      </button>
    `;
  }

  function renderSearchHighlight(value, query) {
    const text = String(value || "");
    const keyword = String(query || "").trim();
    if (!keyword) {
      return escapeHtml(text);
    }

    const normalizedText = text.toLowerCase();
    const normalizedKeyword = keyword.toLowerCase();
    const fragments = [];
    let cursor = 0;
    let matchIndex = normalizedText.indexOf(normalizedKeyword, cursor);

    while (matchIndex !== -1) {
      fragments.push(escapeHtml(text.slice(cursor, matchIndex)));
      fragments.push(`<mark>${escapeHtml(text.slice(matchIndex, matchIndex + keyword.length))}</mark>`);
      cursor = matchIndex + keyword.length;
      matchIndex = normalizedText.indexOf(normalizedKeyword, cursor);
    }

    fragments.push(escapeHtml(text.slice(cursor)));
    return fragments.join("");
  }

  function renderLabOverviewScreen() {
    return `
      <section class="screen design-tool-screen design-tool-screen--lab">
        ${renderScreenHeader({
          title: "实验模块",
          subtitle: "设计源内部工具 · 不进入正式 App",
          backPath: "/spec",
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <aside class="design-tool-notice" role="note">
              <strong>仅用于内部评审</strong>
              <span>这里记录概念状态和模块方向，不属于移动端产品信息架构。</span>
            </aside>
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
          <span class="badge">内部 · ${escapeHtml(item.status)}</span>
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
      <section class="screen design-tool-screen design-tool-screen--lab">
        ${renderScreenHeader({
          title: item.title,
          subtitle: "设计源内部实验模块",
          backPath: "/lab",
        })}
        <div class="screen-scroll">
          <div class="screen-stack">
            <aside class="design-tool-notice" role="note">
              <strong>内部概念页</strong>
              <span>本页不映射为正式移动端或 Flutter 产品路由。</span>
            </aside>
            <section class="hero-card hero-card--soft">
              <span class="eyebrow">Internal Concept</span>
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
    const compactDetailHeader = section === "profile";

    return `
      <section class="screen runtime-screen runtime-screen--list runtime-settings-detail-screen">
        ${renderScreenHeader({
          title: detail.title,
          backPath: section === "profile" ? "/mine" : "/settings",
          variant: compactDetailHeader ? "compact" : undefined,
        })}
        <div class="screen-scroll runtime-scroll ${compactDetailHeader ? "runtime-topbar-scroll" : ""}">
          <div class="runtime-list-content runtime-settings-content runtime-settings-detail-content">
            ${detail.hero ? renderSettingsDetailHero(detail.hero) : ""}
            ${detail.groups.map(renderSettingsDetailGroup).join("")}
          </div>
        </div>
        ${renderSettingsDetailOverlay()}
      </section>
    `;
  }

  function settingsDetail(section) {
    const details = {
      profile: {
        title: "个人资料",
        groups: [
          {
            rows: [
              { type: "value", label: "姓名", description: data.currentUser.name },
              { type: "value", label: "身份", description: data.currentUser.role },
              { type: "value", label: "手机号", description: data.currentUser.phone },
              { type: "value", label: "邮箱", description: data.currentUser.email },
              { type: "value", label: "个性签名", description: data.currentUser.bio },
            ],
          },
        ],
      },
      account: {
        title: "账号与安全",
        groups: [
          {
            title: "账号信息",
            rows: [
              { type: "value", label: "手机号", description: data.currentUser.phone },
              { type: "value", label: "账号状态", description: "正常" },
            ],
          },
          {
            title: "登录安全",
            rows: [
              { type: "action", label: "登录设备", description: "当前有 2 台设备在线", value: "2 台", action: "devices" },
              { type: "action", label: "更换手机号", description: "验证当前手机号后修改", action: "phone" },
            ],
          },
        ],
      },
      chat: {
        title: "聊天",
        groups: [
          {
            title: "显示与媒体",
            rows: [
              { type: "action", label: "聊天背景", description: "跟随当前主题", value: state.theme === "dark" ? "深色" : "浅色", action: "chatBackground" },
              { type: "switch", key: "autoDownloadMedia", scope: "privacy", label: "自动下载媒体", description: "仅在当前设备生效", checked: data.settings.privacy.autoDownloadMedia },
            ],
          },
          {
            title: "消息与存储",
            rows: [
              { type: "action", label: "消息保留", description: "保留最近一年的会话记录", value: "1 年", action: "messageStorage" },
              { type: "instant", label: "清理缓存", description: "图片、视频与临时文件", value: "186 MB", action: "clearCache" },
            ],
          },
        ],
      },
      privacy: {
        title: "隐私协议",
        groups: [
          {
            title: "聊天隐私",
            rows: [
              { type: "switch", key: "readReceipt", scope: "privacy", label: "已读回执", description: "允许好友查看消息已读状态", checked: data.settings.privacy.readReceipt },
              { type: "switch", key: "typingStatus", scope: "privacy", label: "正在输入", description: "允许好友查看输入状态", checked: data.settings.privacy.typingStatus },
            ],
          },
          {
            title: "协议与数据",
            rows: [
              { type: "action", label: "隐私政策", description: "查看隐私保护与权限说明", action: "privacyPolicy" },
              { type: "action", label: "数据使用说明", description: "了解账号与消息数据用途", action: "dataUsage" },
            ],
          },
        ],
      },
      about: {
        title: "关于 RedCode IM",
        hero: {
          title: "RedCode IM",
          description: "清晰、可靠的即时沟通",
          version: "2.0 Preview",
        },
        groups: [
          {
            title: "产品信息",
            rows: [
              { type: "action", label: "版本信息", description: "RedCode IM 2.0 Preview", value: "最新", action: "version" },
              { type: "value", label: "设计源", description: "im-ui-html" },
            ],
          },
          {
            title: "支持",
            rows: [
              { type: "action", label: "隐私政策", description: "隐私保护与数据使用说明", action: "privacyPolicy" },
              { type: "action", label: "体验反馈", description: "告诉我们哪里可以做得更好", action: "feedback" },
            ],
          },
        ],
      },
    };
    return details[section] || null;
  }

  function renderSettingsDetailHero(hero) {
    return `
      <section class="runtime-settings-about-hero" aria-label="${escapeHtml(hero.title)}">
        <span class="runtime-settings-about-hero__mark" aria-hidden="true">R</span>
        <span class="runtime-settings-about-hero__copy">
          <strong>${escapeHtml(hero.title)}</strong>
          <span>${escapeHtml(hero.description)}</span>
          <small>${escapeHtml(hero.version)}</small>
        </span>
      </section>
    `;
  }

  function renderSettingsDetailGroup(group) {
    return `
      <section class="runtime-settings-group">
        ${group.title ? `<h3>${escapeHtml(group.title)}</h3>` : ""}
        ${group.rows.map(renderSettingsDetailRow).join("")}
      </section>
    `;
  }

  function renderSettingsDetailRow(row) {
    if (row.type === "switch") {
      return renderRuntimeSwitchRow(row.key, row.label, row.checked, row.scope, row.description);
    }
    if (row.type === "action" || row.type === "instant") {
      return `
        <button
          class="runtime-setting-row runtime-setting-row--link"
          type="button"
          data-action="${row.type === "instant" ? "perform-settings-action" : "open-settings-detail"}"
          data-settings-key="${escapeHtml(row.action)}"
        >
          <span class="runtime-setting-row__copy"><strong>${escapeHtml(row.label)}</strong><small>${escapeHtml(row.description)}</small></span>
          <span class="runtime-setting-row__tail">
            ${row.value ? `<span>${escapeHtml(row.value)}</span>` : ""}
            ${renderRowChevron()}
          </span>
        </button>
      `;
    }
    return renderRuntimeSettingsValueRow(row.label, row.description);
  }

  function renderRuntimeSettingsValueRow(label, value) {
    return `
      <div class="runtime-setting-row runtime-setting-row--static">
        <span class="runtime-setting-row__copy"><strong>${escapeHtml(label)}</strong><small>${escapeHtml(value)}</small></span>
      </div>
    `;
  }

  function renderRuntimeSwitchRow(key, label, checked, scope, description = "") {
    return `
      <label class="runtime-setting-row runtime-setting-row--switch">
        <span class="runtime-setting-row__copy"><strong>${escapeHtml(label)}</strong>${description ? `<small>${escapeHtml(description)}</small>` : ""}</span>
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

  function settingsSheetContent(key) {
    const sheets = {
      devices: {
        title: "登录设备",
        description: "最近使用 RedCode IM 的设备",
        items: ["iPhone 16 Pro Max · 当前设备", "MacBook Pro · 3 小时前"],
        actionLabel: "退出其他设备",
        successTitle: "其他设备已退出",
        successMessage: "当前设备保持登录状态。",
      },
      phone: {
        title: "更换手机号",
        description: "修改前需要验证当前手机号",
        items: [`当前号码 ${data.currentUser.phone}`, "验证码仅发送到当前绑定号码"],
      },
      chatBackground: {
        title: "聊天背景",
        description: "当前跟随应用主题",
        items: [state.theme === "dark" ? "深色背景" : "浅色背景", "所有会话使用相同背景"],
        actionLabel: "应用当前主题",
        successTitle: "聊天背景已更新",
        successMessage: "所有会话将跟随当前主题。",
      },
      messageStorage: {
        title: "消息保留",
        description: "管理当前设备上的消息记录",
        items: ["当前保留最近一年", "收藏与已下载文件不会自动删除"],
        actionLabel: "保持一年",
        successTitle: "保留策略已确认",
        successMessage: "消息将在当前设备保留一年。",
      },
      privacyPolicy: {
        title: "隐私政策",
        description: "我们如何保护你的信息",
        items: ["消息内容仅用于即时通信服务", "相机、麦克风与位置权限按功能单独申请", "你可以在设置中随时调整隐私偏好"],
      },
      dataUsage: {
        title: "数据使用说明",
        description: "账号与消息数据用途",
        items: ["账号信息用于身份识别与安全保护", "消息元数据用于同步、送达与已读状态", "诊断数据仅用于定位稳定性问题"],
      },
      version: {
        title: "版本信息",
        description: "RedCode IM 2.0 Preview",
        items: ["设计源：im-ui-html", "当前版本已是最新预览版本"],
      },
      feedback: {
        title: "体验反馈",
        description: "帮助我们持续改进 RedCode IM",
        items: ["页面与交互问题", "消息、通话与通知体验", "其他产品建议"],
        actionLabel: "提交反馈",
        successTitle: "反馈已提交",
        successMessage: "感谢你的产品体验反馈。",
      },
    };
    return sheets[key] || null;
  }

  function renderSettingsDetailOverlay() {
    const content = settingsSheetContent(state.settingsSheetKey);
    if (!content) {
      return "";
    }
    return `
      <div class="runtime-settings-detail-overlay">
        <button class="runtime-settings-detail-overlay__scrim" type="button" data-action="close-settings-detail" aria-label="关闭${escapeHtml(content.title)}"></button>
        <section class="runtime-settings-detail-sheet" role="dialog" aria-modal="true" aria-labelledby="settings-detail-sheet-title">
          <span class="runtime-settings-detail-sheet__handle" aria-hidden="true"></span>
          <div class="runtime-settings-detail-sheet__heading">
            <h3 id="settings-detail-sheet-title">${escapeHtml(content.title)}</h3>
            <p>${escapeHtml(content.description)}</p>
          </div>
          <div class="runtime-settings-detail-sheet__items">
            ${content.items.map((item) => `<p>${escapeHtml(item)}</p>`).join("")}
          </div>
          ${
            content.actionLabel
              ? `<button class="runtime-settings-detail-sheet__primary" type="button" data-action="perform-settings-sheet-action">${escapeHtml(content.actionLabel)}</button>`
              : ""
          }
          <button class="runtime-settings-detail-sheet__cancel" type="button" data-action="close-settings-detail">完成</button>
        </section>
      </div>
    `;
  }

  function performSettingsAction(key) {
    if (key === "clearCache") {
      showToast("缓存已清理", "已释放 186 MB 本地存储空间。");
      render();
    }
  }

  function completeSettingsSheetAction() {
    const content = settingsSheetContent(state.settingsSheetKey);
    if (!content || !content.actionLabel) {
      return;
    }
    state.settingsSheetKey = null;
    showToast(content.successTitle, content.successMessage);
    render();
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

  function renderCapabilityRouteScreen(title, backPath, emptyTitle) {
    const requestedState = new URLSearchParams(window.location.search).get("state");
    const stateKind = ["empty", "success", "error", "loading"].includes(requestedState) ? requestedState : "empty";
    const stateCopy = {
      empty: [emptyTitle, "当前没有需要处理的内容。"],
      success: ["操作已完成", "变更已经保存。"],
      error: ["暂时无法加载", "请稍后重试。"],
      loading: ["正在加载", "请稍候。"],
    };
    return `
      <section class="screen runtime-screen runtime-screen--list runtime-capability-screen">
        ${renderScreenHeader({ title, backPath, variant: "compact" })}
        <div class="screen-scroll runtime-scroll runtime-topbar-scroll">
          <div class="runtime-list-content runtime-capability-screen__content">
            ${renderCapabilityState(stateKind, stateCopy[stateKind][0], stateCopy[stateKind][1])}
          </div>
        </div>
      </section>
    `;
  }

  function renderGroupCapabilityRouteScreen(route) {
    const group = findGroup(route.groupId);
    if (!group) {
      return renderFallbackScreen("群聊不存在", "/groups");
    }
    if (route.section === "group-invitation" && !route.invitationId) {
      return renderFallbackScreen("群聊邀请不存在", `/groups/settings/${group.id}`);
    }
    const titles = {
      "group-members": "群成员",
      "group-admins": "群管理员",
      "group-join-requests": "入群申请",
      "group-invite": "邀请成员",
      "group-invitation": "群聊邀请",
      "group-rules": "群规则",
      "group-mutes": "禁言管理",
      "group-operation-logs": "操作日志",
    };
    return renderCapabilityRouteScreen(titles[route.section] || "群管理", `/groups/settings/${group.id}`, "暂无记录");
  }

  function renderCapabilityState(kind, title, description, action = null) {
    const icon = kind === "error" ? "alertTriangle" : kind === "success" ? "checkCircle" : "file";
    return `
      <section class="runtime-capability-state runtime-capability-state--${escapeHtml(kind)}" role="status">
        <span class="runtime-capability-state__icon">${renderIcon(icon, "runtime-capability-state__glyph")}</span>
        <strong>${escapeHtml(title)}</strong>
        <p>${escapeHtml(description)}</p>
        ${
          action
            ? `<button class="runtime-secondary-button" type="button" data-action="${escapeHtml(action.name)}">${escapeHtml(action.label)}</button>`
            : ""
        }
      </section>
    `;
  }

  function openActionDialog(options) {
    const activeElement = document.activeElement;
    state.actionDialogReturnAction = activeElement instanceof Element ? activeElement.getAttribute("data-action") : null;
    state.actionDialog = {
      title: options.title,
      description: options.description,
      confirmLabel: options.confirmLabel || "确认",
      cancelLabel: options.cancelLabel || "取消",
      tone: options.tone === "danger" ? "danger" : "default",
      onConfirm: typeof options.onConfirm === "function" ? options.onConfirm : null,
      payload: options.payload || null,
      pending: false,
    };
    render();
  }

  function closeActionDialog() {
    if (state.actionDialog?.pending) {
      return;
    }
    state.actionDialog = null;
    render();
    restoreActionDialogFocus();
  }

  function focusActionDialog() {
    if (!state.actionDialog) {
      return;
    }
    window.requestAnimationFrame(() => {
      const button = root.querySelector('[data-action="confirm-action-dialog"]');
      if (button instanceof HTMLButtonElement) {
        button.focus({ preventScroll: true });
      }
    });
  }

  function restoreActionDialogFocus() {
    const action = state.actionDialogReturnAction;
    state.actionDialogReturnAction = null;
    if (!action) {
      return;
    }
    window.requestAnimationFrame(() => {
      const trigger = root.querySelector(`[data-action="${CSS.escape(action)}"]`);
      if (trigger instanceof HTMLElement) {
        trigger.focus({ preventScroll: true });
      }
    });
  }

  async function confirmActionDialog() {
    const dialog = state.actionDialog;
    if (!dialog || dialog.pending) {
      return;
    }
    dialog.pending = true;
    render();
    try {
      if (dialog.onConfirm) {
        await dialog.onConfirm(dialog.payload);
      }
      if (state.actionDialog === dialog) {
        state.actionDialog = null;
        showToast("操作已完成", dialog.title);
        render();
        restoreActionDialogFocus();
      }
    } catch (error) {
      if (state.actionDialog === dialog) {
        dialog.pending = false;
        dialog.description = error instanceof Error ? error.message : "操作失败，请稍后重试。";
        render();
      }
    }
  }

  function renderActionDialog() {
    const dialog = state.actionDialog;
    if (!dialog) {
      return "";
    }
    return `
      <div class="runtime-dialog-layer">
        <button class="runtime-dialog-layer__scrim" type="button" data-action="close-action-dialog" aria-label="关闭对话框"></button>
        <section class="runtime-action-dialog" role="dialog" aria-modal="true" aria-labelledby="runtime-action-dialog-title" aria-describedby="runtime-action-dialog-description">
          <span class="runtime-action-dialog__icon runtime-action-dialog__icon--${escapeHtml(dialog.tone)}">
            ${renderIcon(dialog.tone === "danger" ? "alertTriangle" : "checkCircle", "runtime-action-dialog__glyph")}
          </span>
          <div class="runtime-action-dialog__copy">
            <h3 id="runtime-action-dialog-title">${escapeHtml(dialog.title)}</h3>
            <p id="runtime-action-dialog-description">${escapeHtml(dialog.description)}</p>
          </div>
          <div class="runtime-action-dialog__actions">
            <button class="runtime-dialog-button" type="button" data-action="close-action-dialog" ${dialog.pending ? "disabled" : ""}>${escapeHtml(dialog.cancelLabel)}</button>
            <button class="runtime-dialog-button runtime-dialog-button--${escapeHtml(dialog.tone)}" type="button" data-action="confirm-action-dialog" ${dialog.pending ? "disabled" : ""}>${escapeHtml(dialog.pending ? "处理中" : dialog.confirmLabel)}</button>
          </div>
        </section>
      </div>
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
      route.section === "discover-moment-detail" ||
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
      [contact.name, contact.title, contact.zone, contact.remark, contact.workFocus, contact.username]
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

  function findMessage(chat, messageId) {
    return chat?.messages?.find((message) => message.id === messageId) || null;
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

  function findMoment(momentId) {
    return data.discover.moments.find((moment) => moment.id === momentId) || null;
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
      remark: "",
      workFocus: "由好友申请转入联系人列表",
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
    state.friendRequestTab = "outgoing";
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
    state.createGroupName = "";
    state.createGroupMembers = new Set(["u_alice", "u_zoe"]);
    state.groupMemberFilter = "";

    showToast("群聊已创建", `${name} 已创建完成，并进入群会话。`);
    navigate(`/chat/${chatId}`, { resetNavigationStack: true });
  }

  function openComposerPicker(type) {
    const route = resolveMobilePreviewRoute(parseRoute(currentPath()));
    if (route.section !== "chat-detail" || !route.chatId || !["contact-card", "favorite"].includes(type)) {
      return;
    }

    state.composerPanel = null;
    state.composerPicker = { type, chatId: route.chatId, query: "", filter: "all" };
    render();
    window.requestAnimationFrame(() => {
      root.querySelector('[data-action="close-composer-picker"]')?.focus({ preventScroll: true });
    });
  }

  function sendComposerPickerItem(type, itemId) {
    const picker = state.composerPicker;
    const chat = picker?.chatId ? findChat(picker.chatId) : null;
    if (!chat || picker.type !== type) {
      return;
    }

    let share;
    if (type === "contact-card") {
      const contact = findContact(itemId);
      if (!contact) {
        return;
      }
      share = {
        type: "contact",
        name: contact.name,
        username: contact.username,
        title: contact.title,
        tone: contact.tone,
      };
    } else if (type === "favorite") {
      const favorite = SHAREABLE_FAVORITES.find((item) => item.id === itemId);
      if (!favorite) {
        return;
      }
      share = {
        type: "favorite",
        kind: favorite.kind,
        title: favorite.title,
        summary: favorite.summary,
        icon: favorite.icon,
      };
    } else {
      return;
    }

    const message = {
      id: `m_${Date.now()}`,
      senderId: data.currentUser.id,
      senderName: data.currentUser.name,
      senderTone: data.currentUser.avatarTone,
      content: type === "contact-card" ? `名片：${share.name}` : `收藏：${share.title}`,
      share,
      time: "刚刚",
      self: true,
      status: "已送达",
    };
    chat.messages.push(message);
    chat.lastMessage = message.content;
    chat.lastTime = "刚刚";
    chat.unread = 0;
    promoteChat(chat);
    state.composerPicker = null;
    state.recentMessageId = message.id;
    showToast(type === "contact-card" ? "名片已发送" : "收藏已发送", message.content);
    render();
    presentRecentMessage(message.id);
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
    const replyTarget = findMessage(chat, state.replyTargets[chatId]);
    if (replyTarget) {
      message.quote = replyTarget.content;
      message.quoteMessageId = replyTarget.id;
    }
    chat.messages.push(message);
    chat.lastMessage = content;
    chat.lastTime = "刚刚";
    chat.unread = 0;
    promoteChat(chat);
    state.chatDrafts[chatId] = "";
    delete state.replyTargets[chatId];
    state.recentMessageId = message.id;
    showToast("消息已发送", "消息已加入当前会话。");
    render();
    presentRecentMessage(message.id);
  }

  function presentRecentMessage(messageId) {
    window.requestAnimationFrame(() => {
      const scroll = root.querySelector(".runtime-chat-scroll");
      if (scroll instanceof HTMLElement) {
        scroll.scrollTop = scroll.scrollHeight;
      }
    });

    window.setTimeout(() => {
      if (state.recentMessageId !== messageId) {
        return;
      }
      state.recentMessageId = null;
      root
        .querySelector(`.message-row[data-message-id="${messageId}"] .message-bubble`)
        ?.classList.remove("is-recent");
    }, 960);
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
      reactions: [{ emoji: "😮", count: 1 }],
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

  function jumpToMessage(messageId) {
    if (!messageId) {
      return;
    }

    state.highlightMessageId = messageId;
    render();
    window.requestAnimationFrame(() => {
      const target = root.querySelector(`.message-row[data-message-id="${messageId}"]`);
      if (target instanceof HTMLElement) {
        target.scrollIntoView({ behavior: "smooth", block: "center" });
      }
    });
  }

  function toggleMessageReaction(chatId, messageId, emoji) {
    if (!["👍", "❤️", "😂", "🎉", "😮", "😢"].includes(emoji)) return;
    const message = findMessage(findChat(chatId), messageId);
    if (!message) return;
    message.reactions ||= [];
    const reaction = message.reactions.find((item) => item.emoji === emoji);
    if (reaction?.self) {
      reaction.count -= 1;
      reaction.self = false;
      if (reaction.count <= 0) message.reactions = message.reactions.filter((item) => item !== reaction);
    } else if (reaction) {
      reaction.count += 1;
      reaction.self = true;
    } else {
      message.reactions.push({ emoji, count: 1, self: true });
    }
    state.messageMenu = null;
    render();
  }

  function performMessageAction(chatId, messageId, action) {
    const chat = findChat(chatId);
    const message = findMessage(chat, messageId);
    if (!chat || !message) return;
    state.messageMenu = null;
    if (action === "forward") {
      state.forwardSelection = new Set();
      state.forwardQuery = "";
      navigate(`/chat/${chat.id}/forward/${message.id}`);
      return;
    }
    if (action === "quote") {
      state.replyTargets[chat.id] = message.id;
      showToast("已引用消息", "输入回复内容后发送。");
      render();
      window.requestAnimationFrame(() => document.getElementById("chat-draft-input")?.focus({ preventScroll: true }));
      return;
    }
    if (action === "edit" && message.self && !message.share) {
      state.messageEditor = { chatId, messageId, content: message.content };
      render();
      window.requestAnimationFrame(() => document.getElementById("message-editor-input")?.focus({ preventScroll: true }));
      return;
    }
    if (action === "pin") {
      message.pinned = !message.pinned;
      if (message.pinned) {
        chat.pinnedMessages = [message.content].concat((chat.pinnedMessages || []).filter((item) => item !== message.content));
      } else {
        chat.pinnedMessages = (chat.pinnedMessages || []).filter((item) => item !== message.content);
      }
      showToast(message.pinned ? "消息已置顶" : "已取消置顶", message.content);
      render();
      return;
    }
    if (action === "delete" && message.self) {
      openActionDialog({
        title: "删除这条消息？",
        description: "删除后，会话中的所有成员都无法再看到这条消息。",
        confirmLabel: "删除",
        tone: "danger",
        payload: { chatId, messageId },
        onConfirm: ({ chatId: targetChatId, messageId: targetMessageId }) => {
          const targetChat = findChat(targetChatId);
          if (!targetChat) throw new Error("会话不存在，无法删除消息。");
          targetChat.messages = targetChat.messages.filter((item) => item.id !== targetMessageId);
          const latest = targetChat.messages[targetChat.messages.length - 1];
          targetChat.lastMessage = latest?.content || "暂无消息";
        },
      });
    }
  }

  function saveMessageEdit(chatId, messageId) {
    const message = findMessage(findChat(chatId), messageId);
    const content = state.messageEditor?.content.trim();
    if (!message || !message.self || !content) return;
    message.content = content;
    message.edited = true;
    const chat = findChat(chatId);
    if (chat?.messages[chat.messages.length - 1]?.id === message.id) chat.lastMessage = content;
    state.messageEditor = null;
    showToast("消息已编辑", "修改已同步到当前会话。");
    render();
  }

  function submitMessageForward(sourceChatId, messageId) {
    const source = findChat(sourceChatId);
    const message = findMessage(source, messageId);
    if (!message || !state.forwardSelection.size) return;
    const failed = [];
    let succeeded = 0;
    state.forwardSelection.forEach((targetId) => {
      const target = findChat(targetId);
      if (!target || target.relayOnly) {
        if (target) failed.push(target.name);
        return;
      }
      const forwarded = {
        ...message,
        id: `m_${Date.now()}_${targetId}`,
        senderId: data.currentUser.id,
        senderName: data.currentUser.name,
        senderTone: data.currentUser.avatarTone,
        self: true,
        status: "已送达",
        time: "刚刚",
        forwarded: true,
        reactions: [],
      };
      target.messages.push(forwarded);
      target.lastMessage = `[转发] ${message.content}`;
      target.lastTime = "刚刚";
      promoteChat(target);
      succeeded += 1;
    });
    state.forwardSelection = new Set();
    if (failed.length) {
      showToast("部分转发失败", `已发送 ${succeeded} 个会话；${failed.join("、")} 不支持该消息。`);
      render();
      return;
    }
    showToast("转发成功", `已发送到 ${succeeded} 个会话。`);
    navigate(`/chat/${sourceChatId}`);
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

  function toggleGroupMembers(groupId) {
    if (!findGroup(groupId)) {
      return;
    }

    if (state.expandedGroupMemberIds.has(groupId)) {
      state.expandedGroupMemberIds.delete(groupId);
    } else {
      state.expandedGroupMemberIds.add(groupId);
    }
    render();
  }

  function updateGroupDirectoryFavorite(groupId, isFavorited) {
    const group = findGroup(groupId);
    if (!group) {
      return;
    }

    if (isFavorited) {
      state.savedGroupIds.add(group.id);
      showToast("已收藏群聊", `${group.name} 会优先显示在联系人群聊目录中。`);
    } else {
      state.savedGroupIds.delete(group.id);
      showToast("已取消收藏", `${group.name} 仍保留在联系人群聊目录中。`);
    }
    persistUiState();
    render();
  }

  function closeContactProfileOverlay() {
    state.contactActionSheetContactId = null;
    state.contactRemarkEditorContactId = null;
    state.contactRemarkDraft = "";
  }

  function openContactActionSheet(contactId) {
    if (!findContact(contactId)) {
      return;
    }
    state.contactRemarkEditorContactId = null;
    state.contactActionSheetContactId = contactId;
    render();
  }

  function openContactRemarkEditor(contactId) {
    const contact = findContact(contactId);
    if (!contact) {
      return;
    }
    state.contactActionSheetContactId = null;
    state.contactRemarkEditorContactId = contact.id;
    state.contactRemarkDraft = typeof contact.remark === "string" ? contact.remark : "";
    render();
    window.requestAnimationFrame(() => {
      const input = document.getElementById("contact-remark-input");
      if (input instanceof HTMLInputElement) {
        input.focus({ preventScroll: true });
        input.select();
      }
    });
  }

  function saveContactRemark(contactId) {
    const contact = findContact(contactId);
    if (!contact) {
      return;
    }
    const nextRemark = state.contactRemarkDraft.trim().slice(0, 24);
    contact.remark = nextRemark;
    closeContactProfileOverlay();
    showToast(nextRemark ? "备注已更新" : "备注已清除", nextRemark ? `${contact.name} 的备注名已更新为 ${nextRemark}。` : `${contact.name} 的备注名已恢复为未设置。`);
    render();
  }

  function startContactAction(contactId, kind) {
    const contact = findContact(contactId);
    const actionLabel = kind === "voice" ? "语音通话" : kind === "video" ? "视频通话" : "";
    if (!contact || !actionLabel) {
      return;
    }
    closeContactProfileOverlay();
    showToast(`${actionLabel}已发起`, `已向 ${contact.name} 发送${actionLabel}邀请。`);
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
      renderPreservingChatScroll();
    }, 2800);
  }

  function renderPreservingChatScroll() {
    const scroll = root.querySelector(".runtime-chat-scroll");
    const distanceFromBottom =
      scroll instanceof HTMLElement ? Math.max(0, scroll.scrollHeight - scroll.clientHeight - scroll.scrollTop) : null;
    render();

    if (distanceFromBottom === null) {
      return;
    }
    window.requestAnimationFrame(() => {
      const nextScroll = root.querySelector(".runtime-chat-scroll");
      if (nextScroll instanceof HTMLElement) {
        nextScroll.scrollTop = Math.max(0, nextScroll.scrollHeight - nextScroll.clientHeight - distanceFromBottom);
      }
    });
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

  function handleKeydown(event) {
    if (event.key === "Tab" && state.actionDialog) {
      const dialog = root.querySelector(".runtime-action-dialog");
      const focusable = dialog
        ? Array.from(dialog.querySelectorAll("button:not(:disabled)"))
        : [];
      if (focusable.length) {
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
      return;
    }

    if (
      event.key === "Escape" &&
      (state.contactActionSheetContactId || state.contactRemarkEditorContactId || state.settingsSheetKey || state.actionDialog || state.messageMenu || state.messageEditor || state.chatActionsChatId)
    ) {
      event.preventDefault();
      if (state.actionDialog) {
        closeActionDialog();
      } else if (state.messageEditor) {
        state.messageEditor = null;
      } else if (state.messageMenu) {
        state.messageMenu = null;
      } else if (state.chatActionsChatId) {
        state.chatActionsChatId = null;
      } else if (state.settingsSheetKey) {
        state.settingsSheetKey = null;
      } else {
        closeContactProfileOverlay();
      }
      render();
      return;
    }

    if (!(event.target instanceof Element)) {
      return;
    }

    const tab = event.target.closest('[data-action="set-request-tab"]');
    if (!tab || !["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) {
      return;
    }

    const tabIds = ["incoming", "outgoing"];
    const currentIndex = tabIds.indexOf(tab.getAttribute("data-request-tab"));
    let nextIndex = currentIndex;

    if (event.key === "ArrowLeft") {
      nextIndex = (currentIndex + tabIds.length - 1) % tabIds.length;
    } else if (event.key === "ArrowRight") {
      nextIndex = (currentIndex + 1) % tabIds.length;
    } else if (event.key === "Home") {
      nextIndex = 0;
    } else if (event.key === "End") {
      nextIndex = tabIds.length - 1;
    }

    event.preventDefault();
    state.friendRequestTab = tabIds[nextIndex];
    render();
    window.requestAnimationFrame(() => {
      const nextTab = document.querySelector(`[data-request-tab="${tabIds[nextIndex]}"]`);
      if (nextTab instanceof HTMLButtonElement) {
        nextTab.focus({ preventScroll: true });
      }
    });
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
    if (action === "close-action-dialog") {
      closeActionDialog();
      return;
    }
    if (action === "confirm-action-dialog") {
      void confirmActionDialog();
      return;
    }
    if (action === "open-message-menu") {
      state.messageMenu = { chatId: target.getAttribute("data-chat-id"), messageId: target.getAttribute("data-message-id") };
      render();
      return;
    }
    if (action === "close-message-menu") {
      state.messageMenu = null;
      render();
      return;
    }
    if (action === "close-message-editor") {
      state.messageEditor = null;
      render();
      return;
    }
    if (action === "perform-message-action") {
      performMessageAction(target.getAttribute("data-chat-id"), target.getAttribute("data-message-id"), target.getAttribute("data-message-action"));
      return;
    }
    if (action === "toggle-message-reaction") {
      toggleMessageReaction(target.getAttribute("data-chat-id"), target.getAttribute("data-message-id"), target.getAttribute("data-emoji"));
      return;
    }
    if (action === "set-message-reads-tab") {
      state.messageReadsTab = target.getAttribute("data-tab") === "unread" ? "unread" : "read";
      render();
      return;
    }
    if (action === "cancel-message-reply") {
      delete state.replyTargets[target.getAttribute("data-chat-id")];
      render();
      return;
    }
    if (action === "submit-message-forward") {
      submitMessageForward(target.getAttribute("data-source-chat-id"), target.getAttribute("data-message-id"));
      return;
    }
    if (action === "open-chat-actions") {
      state.chatActionsChatId = target.getAttribute("data-chat-id");
      render();
      return;
    }
    if (action === "close-chat-actions") {
      state.chatActionsChatId = null;
      render();
      return;
    }
    if (action === "clear-chat-history") {
      requestClearChatHistory(target.getAttribute("data-chat-id"));
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
    if (action === "set-request-tab") {
      const tab = target.getAttribute("data-request-tab");
      if (tab === "incoming" || tab === "outgoing") {
        state.friendRequestTab = tab;
        render();
      }
      return;
    }
    if (action === "toggle-moment-like") {
      const moment = findMoment(target.getAttribute("data-moment-id"));
      if (!moment) {
        return;
      }
      const liked = state.likedMomentIds.has(moment.id);
      if (liked) {
        state.likedMomentIds.delete(moment.id);
      } else {
        state.likedMomentIds.add(moment.id);
      }
      if (target.closest(".runtime-moment-detail")) {
        render();
        return;
      }
      target.classList.toggle("is-active", !liked);
      target.setAttribute("aria-pressed", String(!liked));
      target.setAttribute("aria-label", liked ? "点赞" : "取消点赞");
      const count = target.querySelector(".runtime-moment-detail__like-count, .moment-card__like-count");
      if (count) {
        count.textContent = String(moment.likes + (liked ? 0 : 1));
      }
      return;
    }
    if (action === "toggle-moment-likers") {
      const momentId = target.getAttribute("data-moment-id");
      const panel = document.getElementById(`moment-likers-${momentId}`);
      const expanded = state.expandedMomentLikeIds.has(momentId);
      if (expanded) {
        state.expandedMomentLikeIds.delete(momentId);
      } else {
        state.expandedMomentLikeIds.add(momentId);
      }
      target.classList.toggle("is-expanded", !expanded);
      target.setAttribute("aria-expanded", String(!expanded));
      target.setAttribute("aria-label", expanded ? "查看点赞用户" : "收起点赞用户");
      if (panel) {
        panel.hidden = expanded;
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
      toggleComposerPanel(target.getAttribute("data-panel"));
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
    if (action === "open-composer-picker") {
      openComposerPicker(target.getAttribute("data-picker-type"));
      return;
    }
    if (action === "close-composer-picker") {
      state.composerPicker = null;
      render();
      return;
    }
    if (action === "set-composer-picker-filter") {
      if (state.composerPicker?.type === "favorite") {
        state.composerPicker.filter = target.getAttribute("data-filter") || "all";
        render();
      }
      return;
    }
    if (action === "send-composer-picker-item") {
      sendComposerPickerItem(target.getAttribute("data-picker-type"), target.getAttribute("data-item-id"));
      return;
    }
    if (action === "simulate-message") {
      simulateIncomingMessage(target.getAttribute("data-chat-id"));
      return;
    }
    if (action === "start-call") {
      const route = resolveMobilePreviewRoute(parseRoute(currentPath()));
      const callType = target.getAttribute("data-call-type");
      if (route.section === "chat-detail" && route.chatId && ["voice", "video"].includes(callType)) {
        state.composerPanel = null;
        state.callSession = {
          chatId: route.chatId,
          type: callType,
          muted: false,
          speaker: callType === "video",
          cameraOff: false,
        };
        render();
      }
      return;
    }
    if (action === "toggle-call-control") {
      const control = target.getAttribute("data-control");
      if (state.callSession && ["muted", "speaker", "cameraOff"].includes(control)) {
        state.callSession[control] = !state.callSession[control];
        render();
      }
      return;
    }
    if (action === "end-call") {
      state.callSession = null;
      render();
      return;
    }
    if (action === "show-hint") {
      showToast("提示", target.getAttribute("data-message") || "该功能暂不可用。");
      render();
      return;
    }
    if (action === "toggle-scan-torch") {
      state.scanTorchOn = !state.scanTorchOn;
      render();
      return;
    }
    if (action === "simulate-scan") {
      simulateScan();
      return;
    }
    if (action === "scan-from-gallery") {
      simulateScan(true);
      return;
    }
    if (action === "reset-scan") {
      resetScan();
      return;
    }
    if (action === "set-nearby-filter") {
      const filter = target.getAttribute("data-nearby-filter");
      if (["all", "near", "online"].includes(filter)) {
        state.nearbyFilter = filter;
        render();
      }
      return;
    }
    if (action === "send-nearby-greeting") {
      sendNearbyGreeting(target.getAttribute("data-nearby-id"));
      return;
    }
    if (action === "launch-game") {
      launchGame(target.getAttribute("data-game-id"));
      return;
    }
    if (action === "clear-friend-search") {
      state.friendSearch = "";
      state.friendSearchPending = false;
      render();
      window.requestAnimationFrame(() => {
        document.getElementById("friend-search-input")?.focus({ preventScroll: true });
      });
      return;
    }
    if (action === "open-settings-detail") {
      const key = target.getAttribute("data-settings-key");
      if (settingsSheetContent(key)) {
        state.settingsSheetKey = key;
        render();
      }
      return;
    }
    if (action === "close-settings-detail") {
      state.settingsSheetKey = null;
      render();
      return;
    }
    if (action === "perform-settings-action") {
      performSettingsAction(target.getAttribute("data-settings-key"));
      return;
    }
    if (action === "perform-settings-sheet-action") {
      completeSettingsSheetAction();
      return;
    }
    if (action === "open-contact-actions") {
      openContactActionSheet(target.getAttribute("data-contact-id"));
      return;
    }
    if (action === "edit-contact-remark") {
      openContactRemarkEditor(target.getAttribute("data-contact-id"));
      return;
    }
    if (action === "close-contact-profile-overlay") {
      closeContactProfileOverlay();
      render();
      return;
    }
    if (action === "start-contact-action") {
      startContactAction(target.getAttribute("data-contact-id"), target.getAttribute("data-contact-action"));
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
    if (action === "jump-to-message") {
      jumpToMessage(target.getAttribute("data-message-id"));
      return;
    }
    if (action === "prefill-search") {
      state.searchQuery = target.getAttribute("data-value") || "";
      render();
      window.requestAnimationFrame(() => {
        const input = document.getElementById("global-search-input");
        if (input instanceof HTMLInputElement) {
          input.focus({ preventScroll: true });
        }
      });
      return;
    }
    if (action === "toggle-group-members") {
      toggleGroupMembers(target.getAttribute("data-group-id"));
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
      if (inputId === "friend-search-input") {
        state.friendSearchPending = false;
      }
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

    if (target.id === "contact-remark-input") {
      state.contactRemarkDraft = target.value;
      return;
    }
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
    if (target.id === "composer-picker-search" && state.composerPicker?.type === "contact-card") {
      state.composerPicker.query = target.value;
      scheduleFilterRender(target);
      return;
    }
    if (target.id === "friend-search-input") {
      state.friendSearch = target.value;
      state.friendSearchPending = true;
      const resultSection = document.getElementById("add-friend-results");
      resultSection?.setAttribute("aria-busy", "true");
      const status = resultSection?.querySelector('[data-role="friend-search-status"]');
      if (status) {
        status.textContent = "搜索中";
      }
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
      const count = root.querySelector(".runtime-add-friend-note__count");
      if (count) {
        count.textContent = `${target.value.trim().length}/80`;
      }
      return;
    }
    if (target.id === "moment-comment-input") {
      const momentId = target.getAttribute("data-moment-id");
      state.momentCommentDrafts[momentId] = target.value;
      const form = target.closest('[data-form="moment-comment-form"]');
      const button = form?.querySelector('button[type="submit"]');
      if (button instanceof HTMLButtonElement) {
        button.disabled = !target.value.trim();
      }
      return;
    }
    if (target.id === "chat-draft-input") {
      const chatId = target.getAttribute("data-chat-id");
      state.chatDrafts[chatId] = target.value;
      return;
    }
    if (target.id === "message-editor-input" && state.messageEditor) {
      state.messageEditor.content = target.value;
      const submit = target.closest("form")?.querySelector('button[type="submit"]');
      if (submit instanceof HTMLButtonElement) submit.disabled = !target.value.trim();
      return;
    }
    if (target.id === "message-forward-search") {
      state.forwardQuery = target.value;
      scheduleFilterRender(target);
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

    if (target.getAttribute("data-kind") === "group-directory-favorite") {
      updateGroupDirectoryFavorite(target.getAttribute("data-group-id"), target.checked);
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
      return;
    }
    if (target.getAttribute("data-kind") === "forward-target") {
      const chatId = target.getAttribute("data-chat-id");
      if (target.checked) state.forwardSelection.add(chatId);
      else state.forwardSelection.delete(chatId);
      render();
    }
  }

  function handleSubmit(event) {
    const form = event.target;
    if (!(form instanceof HTMLFormElement)) {
      return;
    }

    const formKind = form.getAttribute("data-form");
    if (formKind === "moment-comment-form") {
      event.preventDefault();
      submitMomentComment(form.getAttribute("data-moment-id"));
      return;
    }
    if (formKind === "contact-remark-form") {
      event.preventDefault();
      saveContactRemark(form.getAttribute("data-contact-id"));
      return;
    }
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
      return;
    }
    if (formKind === "edit-message") {
      event.preventDefault();
      saveMessageEdit(form.getAttribute("data-chat-id"), form.getAttribute("data-message-id"));
    }
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
