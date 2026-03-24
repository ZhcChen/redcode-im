<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { FriendApi, type FriendInfo, type FriendRequestInfo } from "@/api/friend";

type ContactMode = "contacts" | "requests";

const emit = defineEmits<{
  (event: "open-chat", payload: { friendUserId: string; displayName: string }): void;
}>();

const searchQuery = ref("");
const mode = ref<ContactMode>("contacts");
const contacts = ref<FriendInfo[]>([]);
const requests = ref<FriendRequestInfo[]>([]);
const selectedContactId = ref<string | null>(null);
const selectedRequestId = ref<string | null>(null);
const isLoading = ref(true);
const isHandlingRequest = ref(false);
const notice = ref("联系人页已接到 Go core，当前先恢复好友列表与好友申请查看。");

const displayName = (user: FriendInfo["user"] | FriendRequestInfo["requester"]) =>
  user.nickname || user.username || "未知用户";

const filteredContacts = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase();
  if (!keyword) {
    return contacts.value;
  }
  return contacts.value.filter((friend) => {
    const nickname = friend.user.nickname?.toLowerCase() ?? "";
    const username = friend.user.username.toLowerCase();
    const email = friend.user.email?.toLowerCase() ?? "";
    const remark = friend.friendRemark?.toLowerCase() ?? "";
    return (
      nickname.includes(keyword) ||
      username.includes(keyword) ||
      email.includes(keyword) ||
      remark.includes(keyword)
    );
  });
});

const groupedContacts = computed(() => {
  const groups = new Map<string, FriendInfo[]>();
  filteredContacts.value.forEach((friend) => {
    const base = displayName(friend.user).trim();
    const initial = base ? base[0].toUpperCase() : "#";
    const letter = /[A-Z]/.test(initial) ? initial : "#";
    if (!groups.has(letter)) {
      groups.set(letter, []);
    }
    groups.get(letter)!.push(friend);
  });

  return Array.from(groups.entries())
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([letter, items]) => ({
      letter,
      items: items.sort((a, b) => displayName(a.user).localeCompare(displayName(b.user)))
    }));
});

const incomingRequests = computed(() => requests.value.filter((request) => request.isIncoming));
const selectedContact = computed(() =>
  filteredContacts.value.find((friend) => friend.id === selectedContactId.value) ||
  filteredContacts.value[0] ||
  null
);
const selectedRequest = computed(() =>
  incomingRequests.value.find((request) => request.id === selectedRequestId.value) ||
  incomingRequests.value[0] ||
  null
);

const formatDate = (value: Date | null) => {
  if (!value) {
    return "暂无";
  }
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit"
  }).format(value);
};

const loadData = async (options: { preferredFriendUserId?: string; preferredRequestId?: string } = {}) => {
  isLoading.value = true;
  try {
    const [friendsResponse, requestResponse] = await Promise.all([
      FriendApi.getMyFriendList(),
      FriendApi.getFriendRequests({ direction: "incoming", status: "pending" })
    ]);

    if (friendsResponse.success && friendsResponse.data) {
      contacts.value = friendsResponse.data;
      selectedContactId.value =
        friendsResponse.data.find((friend) => friend.user.id === options.preferredFriendUserId)?.id ||
        friendsResponse.data[0]?.id ||
        null;
    }

    if (requestResponse.success && requestResponse.data) {
      requests.value = requestResponse.data;
      selectedRequestId.value =
        requestResponse.data.find((request) => request.id === options.preferredRequestId)?.id ||
        requestResponse.data[0]?.id ||
        null;
    }
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "联系人数据加载失败";
  } finally {
    isLoading.value = false;
  }
};

const switchMode = (nextMode: ContactMode) => {
  mode.value = nextMode;
  if (nextMode === "contacts" && !selectedContactId.value) {
    selectedContactId.value = filteredContacts.value[0]?.id ?? null;
  }
  if (nextMode === "requests" && !selectedRequestId.value) {
    selectedRequestId.value = incomingRequests.value[0]?.id ?? null;
  }
};

const handleRespondRequest = async (action: "accept" | "decline") => {
  if (!selectedRequest.value || isHandlingRequest.value) {
    return;
  }

  isHandlingRequest.value = true;
  try {
    const response = await FriendApi.handleFriendRequest({
      requestId: selectedRequest.value.id,
      action
    });
    if (!response.success || !response.data) {
      notice.value = response.message || "处理好友申请失败";
      return;
    }

    if (action === "accept") {
      notice.value = `已通过 ${displayName(response.data.requester)} 的好友申请`;
      mode.value = "contacts";
      await loadData({ preferredFriendUserId: response.data.requester.id });
      return;
    }

    notice.value = `已拒绝 ${displayName(response.data.requester)} 的好友申请`;
    await loadData();
    mode.value = "requests";
  } catch (error) {
    notice.value = error instanceof Error ? error.message : "处理好友申请失败";
  } finally {
    isHandlingRequest.value = false;
  }
};

const handleOpenChat = () => {
  if (!selectedContact.value) {
    return;
  }

  const targetName = displayName(selectedContact.value.user);
  notice.value = `准备打开与 ${targetName} 的聊天...`;
  emit("open-chat", {
    friendUserId: selectedContact.value.user.id,
    displayName: targetName
  });
};

onMounted(() => {
  void loadData();
});
</script>

<template>
  <section class="contact-panel">
    <div class="contact-panel__notice">
      <span>{{ notice }}</span>
      <small>{{ incomingRequests.length }} 条待处理申请</small>
    </div>

    <div class="contact-panel__layout">
      <aside class="contact-panel__sidebar">
        <div class="contact-panel__header">
          <h2>联系人</h2>
          <input v-model="searchQuery" class="contact-panel__search" placeholder="搜索联系人..." />
        </div>

        <div class="contact-shortcuts">
          <button
            type="button"
            class="contact-shortcut"
            :class="{ 'contact-shortcut--active': mode === 'requests' }"
            @click="switchMode('requests')"
          >
            <strong>新的朋友</strong>
            <small>{{ incomingRequests.length }} 条待处理申请</small>
          </button>
          <button
            type="button"
            class="contact-shortcut"
            :class="{ 'contact-shortcut--active': mode === 'contacts' }"
            @click="switchMode('contacts')"
          >
            <strong>联系人</strong>
            <small>{{ contacts.length }} 位好友</small>
          </button>
        </div>

        <div v-if="isLoading" class="contact-empty">
          <strong>加载中</strong>
          <p>正在从 Go core 同步联系人与好友申请。</p>
        </div>

        <div v-else-if="mode === 'contacts'" class="contact-list">
          <div v-if="!groupedContacts.length" class="contact-empty">
            <strong>暂无联系人</strong>
            <p>当前账号还没有好友，后续会继续补“添加联系人”与群组入口。</p>
          </div>
          <template v-else>
            <div v-for="group in groupedContacts" :key="group.letter" class="contact-group">
              <div class="contact-group__title">{{ group.letter }}</div>
              <button
                v-for="friend in group.items"
                :key="friend.id"
                type="button"
                class="contact-row"
                :class="{ 'contact-row--active': selectedContact?.id === friend.id }"
                @click="selectedContactId = friend.id"
              >
                <span class="contact-row__avatar">{{ displayName(friend.user).slice(0, 1).toUpperCase() }}</span>
                <span class="contact-row__copy">
                  <strong>{{ displayName(friend.user) }}</strong>
                  <small>{{ friend.friendRemark || friend.user.username }}</small>
                </span>
              </button>
            </div>
          </template>
        </div>

        <div v-else class="contact-list">
          <div v-if="!incomingRequests.length" class="contact-empty">
            <strong>暂无好友申请</strong>
            <p>当前没有待处理的好友请求。</p>
          </div>
          <button
            v-for="request in incomingRequests"
            :key="request.id"
            type="button"
            class="contact-row"
            :class="{ 'contact-row--active': selectedRequest?.id === request.id }"
            @click="selectedRequestId = request.id"
          >
            <span class="contact-row__avatar">{{ displayName(request.requester).slice(0, 1).toUpperCase() }}</span>
            <span class="contact-row__copy">
              <strong>{{ displayName(request.requester) }}</strong>
              <small>{{ request.message || "请求添加你为好友" }}</small>
            </span>
          </button>
        </div>
      </aside>

      <article class="contact-panel__detail">
        <template v-if="mode === 'contacts' && selectedContact">
          <div class="contact-hero">
            <span class="contact-hero__avatar">{{ displayName(selectedContact.user).slice(0, 1).toUpperCase() }}</span>
            <div>
              <h3>{{ displayName(selectedContact.user) }}</h3>
              <p>{{ selectedContact.friendRemark || "暂无备注" }}</p>
            </div>
          </div>

          <dl class="contact-detail-list">
            <div>
              <dt>账号</dt>
              <dd>{{ selectedContact.user.username }}</dd>
            </div>
            <div>
              <dt>邮箱</dt>
              <dd>{{ selectedContact.user.email || "未设置" }}</dd>
            </div>
            <div>
              <dt>状态</dt>
              <dd>{{ selectedContact.user.status || "unknown" }}</dd>
            </div>
            <div>
              <dt>成为好友时间</dt>
              <dd>{{ formatDate(selectedContact.createdAt) }}</dd>
            </div>
          </dl>

          <div class="contact-placeholder">
            <strong>联系人详情区已接回主壳</strong>
            <p>现在可以直接从联系人详情发起聊天，后续继续补备注编辑与更多联系人操作。</p>
          </div>

          <div class="detail-actions">
            <button type="button" class="detail-actions__button detail-actions__button--primary" @click="handleOpenChat">
              发消息
            </button>
          </div>
        </template>

        <template v-else-if="mode === 'requests' && selectedRequest">
          <div class="contact-hero">
            <span class="contact-hero__avatar">{{ displayName(selectedRequest.requester).slice(0, 1).toUpperCase() }}</span>
            <div>
              <h3>{{ displayName(selectedRequest.requester) }}</h3>
              <p>{{ selectedRequest.message || "请求添加你为好友" }}</p>
            </div>
          </div>

          <dl class="contact-detail-list">
            <div>
              <dt>请求人账号</dt>
              <dd>{{ selectedRequest.requester.username }}</dd>
            </div>
            <div>
              <dt>请求状态</dt>
              <dd>{{ selectedRequest.status }}</dd>
            </div>
            <div>
              <dt>申请时间</dt>
              <dd>{{ formatDate(selectedRequest.createdAt) }}</dd>
            </div>
            <div>
              <dt>邮箱</dt>
              <dd>{{ selectedRequest.requester.email || "未设置" }}</dd>
            </div>
          </dl>

          <div class="contact-placeholder">
            <strong>好友申请操作已接回 Go core</strong>
            <p>现在可以直接通过或拒绝申请，下一批继续接“发起聊天”和“好友备注”。</p>
          </div>

          <div class="request-actions">
            <button
              type="button"
              class="request-actions__button request-actions__button--ghost"
              :disabled="isHandlingRequest"
              @click="handleRespondRequest('decline')"
            >
              {{ isHandlingRequest ? "处理中..." : "拒绝" }}
            </button>
            <button
              type="button"
              class="request-actions__button request-actions__button--primary"
              :disabled="isHandlingRequest"
              @click="handleRespondRequest('accept')"
            >
              {{ isHandlingRequest ? "处理中..." : "通过验证" }}
            </button>
          </div>
        </template>

        <div v-else class="contact-empty contact-empty--detail">
          <strong>暂无可展示内容</strong>
          <p>等待联系人或好友申请数据。</p>
        </div>
      </article>
    </div>
  </section>
</template>

<style scoped>
.contact-panel {
  display: grid;
  gap: 18px;
}

.contact-panel__notice {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  align-items: center;
  padding: 14px 16px;
  border-radius: 18px;
  background: rgba(0, 194, 179, 0.08);
  color: #0f766e;
  font-size: 13px;
  line-height: 1.6;
}

.contact-panel__notice small {
  flex-shrink: 0;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.contact-panel__layout {
  display: grid;
  grid-template-columns: minmax(300px, 380px) minmax(0, 1fr);
  gap: 18px;
}

.contact-panel__sidebar,
.contact-panel__detail {
  padding: 22px;
  border: 1px solid var(--panel-border);
  border-radius: 28px;
  background: rgba(255, 255, 255, 0.88);
  box-shadow: var(--panel-shadow);
}

.contact-panel__header {
  display: grid;
  gap: 12px;
  margin-bottom: 16px;
}

.contact-panel__header h2 {
  margin: 0;
  font-size: 22px;
}

.contact-panel__search {
  height: 42px;
  border: 1px solid rgba(0, 155, 143, 0.16);
  border-radius: 16px;
  padding: 0 14px;
  background: #f8fffe;
  outline: none;
}

.contact-panel__search:focus {
  border-color: rgba(0, 155, 143, 0.34);
  box-shadow: 0 0 0 4px rgba(0, 194, 179, 0.08);
}

.contact-shortcuts {
  display: grid;
  gap: 10px;
  margin-bottom: 18px;
}

.contact-shortcut {
  display: grid;
  gap: 4px;
  padding: 14px 16px;
  border-radius: 20px;
  background: rgba(15, 23, 42, 0.04);
  text-align: left;
  cursor: pointer;
}

.contact-shortcut--active {
  background: rgba(0, 194, 179, 0.12);
}

.contact-shortcut strong {
  color: var(--text-primary);
}

.contact-shortcut small {
  color: var(--text-secondary);
}

.contact-list {
  display: grid;
  gap: 14px;
}

.contact-group {
  display: grid;
  gap: 8px;
}

.contact-group__title {
  font-size: 12px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-secondary);
}

.contact-row {
  display: grid;
  grid-template-columns: 42px minmax(0, 1fr);
  gap: 12px;
  align-items: center;
  padding: 12px;
  border-radius: 18px;
  background: rgba(15, 23, 42, 0.04);
  text-align: left;
  cursor: pointer;
}

.contact-row--active {
  background: rgba(0, 194, 179, 0.12);
}

.contact-row__avatar,
.contact-hero__avatar {
  display: grid;
  place-items: center;
  border-radius: 16px;
  background: linear-gradient(135deg, #00c2b3, #009b8f);
  color: #ffffff;
  font-weight: 700;
}

.contact-row__avatar {
  width: 42px;
  height: 42px;
}

.contact-row__copy {
  display: grid;
  gap: 4px;
}

.contact-row__copy strong {
  color: var(--text-primary);
  font-size: 14px;
}

.contact-row__copy small {
  color: var(--text-secondary);
}

.contact-hero {
  display: grid;
  grid-template-columns: 88px minmax(0, 1fr);
  gap: 16px;
  align-items: center;
  padding: 18px 20px;
  border-radius: 24px;
  background:
    radial-gradient(circle at top right, rgba(0, 194, 179, 0.14), transparent 26%),
    rgba(15, 23, 42, 0.03);
  margin-bottom: 18px;
}

.contact-hero__avatar {
  width: 88px;
  height: 88px;
  font-size: 30px;
  border-radius: 24px;
}

.contact-hero h3 {
  margin: 0;
  font-size: 28px;
}

.contact-hero p {
  margin: 8px 0 0;
  color: var(--text-secondary);
}

.contact-detail-list {
  display: grid;
  gap: 14px;
  margin: 0 0 18px;
}

.contact-detail-list div {
  display: grid;
  gap: 4px;
}

.contact-detail-list dt {
  font-size: 12px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-secondary);
}

.contact-detail-list dd {
  margin: 0;
  color: var(--text-primary);
  word-break: break-all;
}

.contact-placeholder,
.contact-empty {
  display: grid;
  gap: 8px;
  padding: 18px;
  border-radius: 22px;
  background: rgba(15, 23, 42, 0.04);
}

.contact-empty--detail {
  height: 100%;
  align-content: center;
}

.contact-placeholder strong,
.contact-empty strong {
  color: var(--text-primary);
}

.contact-placeholder p,
.contact-empty p {
  margin: 0;
  color: var(--text-secondary);
  line-height: 1.7;
}

.request-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

.detail-actions {
  display: flex;
  justify-content: flex-end;
}

.detail-actions__button {
  height: 42px;
  padding: 0 18px;
  border-radius: 999px;
  cursor: pointer;
}

.detail-actions__button--primary {
  background: rgba(0, 194, 179, 0.14);
  color: var(--primary-color-strong);
}

.request-actions__button {
  height: 40px;
  padding: 0 18px;
  border-radius: 999px;
  cursor: pointer;
}

.request-actions__button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.request-actions__button--ghost {
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-primary);
}

.request-actions__button--primary {
  background: rgba(0, 194, 179, 0.14);
  color: var(--primary-color-strong);
}

@media (max-width: 980px) {
  .contact-panel__layout {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 720px) {
  .contact-panel__notice {
    flex-direction: column;
    align-items: flex-start;
  }

  .contact-hero {
    grid-template-columns: 1fr;
  }
}
</style>
