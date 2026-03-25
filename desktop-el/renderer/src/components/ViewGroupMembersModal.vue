<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { filterGroupMembers, type GroupMemberListItem } from "@/utils/chat-group-members";

interface GroupMemberPanelEntry extends GroupMemberListItem {
  avatarUrl: string | null;
  roleLabel: string;
  joinedAtLabel: string;
  isSelf: boolean;
}

interface GroupMemberPanelStats {
  total: number;
  ownerCount: number;
  adminCount: number;
  memberCount: number;
}

const props = defineProps<{
  visible: boolean;
  members: GroupMemberPanelEntry[];
  stats: GroupMemberPanelStats;
  isLoading: boolean;
  canManageMembers: boolean;
  canManageAdmins: boolean;
  canTransferOwner: boolean;
}>();

const emit = defineEmits<{
  (event: "update:visible", value: boolean): void;
  (event: "open-add-members"): void;
  (event: "open-remove-members"): void;
  (event: "open-manage-admins"): void;
  (event: "open-transfer-owner"): void;
}>();

const searchQuery = ref("");

const filteredMembers = computed(() =>
  filterGroupMembers(props.members, searchQuery.value),
);

const buildAvatarFallback = (displayName: string) =>
  displayName.trim().slice(0, 1).toUpperCase() || "?";

const close = () => {
  emit("update:visible", false);
};

watch(
  () => props.visible,
  (visible, previousVisible) => {
    if ((visible && !previousVisible) || (!visible && previousVisible)) {
      searchQuery.value = "";
    }
  },
);
</script>

<template>
  <Teleport to="body">
    <div v-if="props.visible" class="group-members-modal">
      <div class="group-members-modal__backdrop" @click="close" />
      <section class="group-members-modal__panel">
        <header class="group-members-modal__header">
          <div>
            <p class="group-members-modal__eyebrow">群聊</p>
            <h2>全部成员</h2>
            <small>查看当前群的完整成员列表与角色分布。</small>
          </div>
          <button
            type="button"
            class="group-members-modal__button group-members-modal__button--ghost"
            @click="close"
          >
            关闭
          </button>
        </header>

        <div class="group-members-modal__stats">
          <article class="group-members-modal__stat">
            <strong>{{ props.stats.total }}</strong>
            <span>全部成员</span>
          </article>
          <article class="group-members-modal__stat">
            <strong>{{ props.stats.ownerCount }}</strong>
            <span>群主</span>
          </article>
          <article class="group-members-modal__stat">
            <strong>{{ props.stats.adminCount }}</strong>
            <span>管理员</span>
          </article>
          <article class="group-members-modal__stat">
            <strong>{{ props.stats.memberCount }}</strong>
            <span>普通成员</span>
          </article>
        </div>

        <div class="group-members-modal__toolbar">
          <input
            v-model="searchQuery"
            class="group-members-modal__search"
            type="search"
            placeholder="搜索成员昵称、账号或角色"
            :disabled="props.isLoading"
          />
          <div class="group-members-modal__actions">
            <button
              v-if="props.canManageMembers"
              type="button"
              class="group-members-modal__button"
              @click="emit('open-add-members')"
            >
              添加成员
            </button>
            <button
              v-if="props.canManageMembers"
              type="button"
              class="group-members-modal__button group-members-modal__button--ghost"
              @click="emit('open-remove-members')"
            >
              删除成员
            </button>
            <button
              v-if="props.canManageAdmins"
              type="button"
              class="group-members-modal__button group-members-modal__button--ghost"
              @click="emit('open-manage-admins')"
            >
              管理员设置
            </button>
            <button
              v-if="props.canTransferOwner"
              type="button"
              class="group-members-modal__button group-members-modal__button--ghost"
              @click="emit('open-transfer-owner')"
            >
              转让群主
            </button>
          </div>
        </div>

        <div v-if="props.isLoading" class="group-members-modal__empty">
          <strong>加载中</strong>
          <p>正在同步完整成员列表...</p>
        </div>

        <div
          v-else-if="!filteredMembers.length"
          class="group-members-modal__empty"
        >
          <strong>{{
            props.members.length ? "暂无匹配成员" : "暂无成员数据"
          }}</strong>
          <p>
            {{
              props.members.length
                ? "换个关键词试试"
                : "当前群成员列表尚未同步完成"
            }}
          </p>
        </div>

        <div v-else class="group-members-modal__list">
          <article
            v-for="member in filteredMembers"
            :key="member.userId"
            class="group-members-modal__member"
          >
            <span class="group-members-modal__avatar">
              <img
                v-if="member.avatarUrl"
                :src="member.avatarUrl"
                :alt="member.displayName"
              />
              <span v-else>{{ buildAvatarFallback(member.displayName) }}</span>
            </span>
            <div class="group-members-modal__member-copy">
              <div class="group-members-modal__member-title">
                <strong>{{ member.displayName }}</strong>
                <span
                  v-if="member.isSelf"
                  class="group-members-modal__tag group-members-modal__tag--self"
                >
                  我
                </span>
                <span class="group-members-modal__tag">
                  {{ member.roleLabel }}
                </span>
              </div>
              <small>{{ member.username }}</small>
            </div>
            <div class="group-members-modal__member-meta">
              <span>{{ member.joinedAtLabel }}</span>
            </div>
          </article>
        </div>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.group-members-modal {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: grid;
  place-items: center;
  padding: 24px;
}

.group-members-modal__backdrop {
  position: absolute;
  inset: 0;
  background: rgba(15, 23, 42, 0.44);
  backdrop-filter: blur(10px);
}

.group-members-modal__panel {
  position: relative;
  z-index: 1;
  width: min(980px, 100%);
  max-height: min(88vh, 900px);
  overflow: auto;
  display: grid;
  gap: 18px;
  border-radius: 28px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: linear-gradient(
    180deg,
    rgba(255, 255, 255, 0.98),
    rgba(241, 245, 249, 0.96)
  );
  box-shadow: 0 30px 80px rgba(15, 23, 42, 0.24);
  padding: 28px;
}

.group-members-modal__header,
.group-members-modal__toolbar,
.group-members-modal__actions,
.group-members-modal__member,
.group-members-modal__member-title {
  display: flex;
  align-items: center;
  gap: 12px;
}

.group-members-modal__header,
.group-members-modal__toolbar,
.group-members-modal__member {
  justify-content: space-between;
}

.group-members-modal__eyebrow {
  margin: 0 0 6px;
  font-size: 12px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--primary-color-strong);
}

.group-members-modal__header h2,
.group-members-modal__stat strong,
.group-members-modal__empty strong,
.group-members-modal__member-title strong {
  margin: 0;
  color: var(--text-primary);
}

.group-members-modal__header small,
.group-members-modal__empty p,
.group-members-modal__member-copy small,
.group-members-modal__member-meta {
  color: var(--text-secondary);
}

.group-members-modal__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
}

.group-members-modal__stat {
  display: grid;
  gap: 4px;
  padding: 16px;
  border-radius: 20px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(255, 255, 255, 0.76);
}

.group-members-modal__stat span {
  color: var(--text-secondary);
  font-size: 13px;
}

.group-members-modal__search {
  flex: 1;
  min-height: 46px;
  padding: 12px 14px;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 16px;
  background: rgba(255, 255, 255, 0.92);
  color: var(--text-primary);
}

.group-members-modal__search:focus {
  outline: none;
  border-color: rgba(0, 155, 143, 0.36);
  box-shadow: 0 0 0 4px rgba(0, 194, 179, 0.12);
}

.group-members-modal__actions {
  flex-wrap: wrap;
  justify-content: flex-end;
}

.group-members-modal__button {
  height: 42px;
  padding: 0 18px;
  border: 1px solid transparent;
  border-radius: 999px;
  background: linear-gradient(135deg, #00c2b3, #009b8f);
  color: #ffffff;
  cursor: pointer;
  transition:
    transform 0.18s ease,
    border-color 0.18s ease,
    background-color 0.18s ease;
}

.group-members-modal__button--ghost {
  background: rgba(15, 23, 42, 0.06);
  color: var(--text-primary);
}

.group-members-modal__button:hover {
  transform: translateY(-1px);
}

.group-members-modal__empty {
  display: grid;
  place-items: center;
  gap: 8px;
  min-height: 240px;
  text-align: center;
  border-radius: 24px;
  border: 1px dashed rgba(15, 23, 42, 0.12);
  background: rgba(255, 255, 255, 0.56);
}

.group-members-modal__list {
  display: grid;
  gap: 12px;
}

.group-members-modal__member {
  padding: 14px 16px;
  border-radius: 20px;
  border: 1px solid rgba(15, 23, 42, 0.08);
  background: rgba(255, 255, 255, 0.78);
}

.group-members-modal__avatar {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: 14px;
  overflow: hidden;
  background: rgba(0, 155, 143, 0.12);
  color: var(--primary-color-strong);
  font-weight: 600;
}

.group-members-modal__avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.group-members-modal__member-copy {
  flex: 1;
  min-width: 0;
  display: grid;
  gap: 4px;
}

.group-members-modal__member-title {
  flex-wrap: wrap;
}

.group-members-modal__tag {
  display: inline-flex;
  align-items: center;
  min-height: 24px;
  padding: 0 10px;
  border-radius: 999px;
  background: rgba(15, 23, 42, 0.08);
  color: var(--text-secondary);
  font-size: 12px;
}

.group-members-modal__tag--self {
  background: rgba(0, 155, 143, 0.12);
  color: var(--primary-color-strong);
}

.group-members-modal__member-meta {
  font-size: 13px;
  text-align: right;
}

@media (max-width: 860px) {
  .group-members-modal__panel {
    padding: 22px;
  }

  .group-members-modal__stats {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .group-members-modal__toolbar {
    flex-direction: column;
    align-items: stretch;
  }

  .group-members-modal__actions {
    justify-content: flex-start;
  }
}

@media (max-width: 640px) {
  .group-members-modal {
    padding: 16px;
  }

  .group-members-modal__header,
  .group-members-modal__member {
    flex-direction: column;
    align-items: stretch;
  }

  .group-members-modal__member-meta {
    text-align: left;
  }
}
</style>
