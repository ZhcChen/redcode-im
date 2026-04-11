<template>
  <div class="admin-user-page">
    <Breadcrumb
      :items="['menu.accessControl', 'menu.accessControl.adminUsers']"
    />
    <a-card class="general-card" title="管理员账号管理" :bordered="false">
      <div class="header-actions">
        <a-space>
          <a-input-search
            v-model="keyword"
            placeholder="搜索管理员用户名"
            style="width: 320px"
            allow-clear
          />
          <a-select
            v-model="selectedStatus"
            placeholder="状态"
            allow-clear
            style="width: 140px"
          >
            <a-option value="active">正常</a-option>
            <a-option value="inactive">停用</a-option>
            <a-option value="locked">锁定</a-option>
            <a-option value="banned">封禁</a-option>
          </a-select>
          <a-button type="primary" @click="createVisible = true">
            新建管理员
          </a-button>
          <a-button @click="fetchData">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
        </a-space>
      </div>

      <a-table
        :data="filteredUsers"
        :loading="loading"
        :pagination="false"
        row-key="id"
      >
        <template #columns>
          <a-table-column title="用户名" data-index="username" :width="180" />
          <a-table-column title="昵称" data-index="nickname" :width="160" />
          <a-table-column title="邮箱" data-index="email" :width="240" />
          <a-table-column title="状态" :width="110">
            <template #cell="{ record }">
              <a-tag :color="adminStatusColor(record.status)">
                {{ adminStatusText(record.status) }}
              </a-tag>
            </template>
          </a-table-column>
          <a-table-column title="角色" :width="260">
            <template #cell="{ record }">
              <a-space wrap>
                <a-tag v-for="code in record.roleCodes" :key="code">{{
                  code
                }}</a-tag>
                <span v-if="!record.roleCodes.length">-</span>
              </a-space>
            </template>
          </a-table-column>
          <a-table-column title="最后登录" :width="180">
            <template #cell="{ record }">
              {{ formatDate(record.lastLoginAt) }}
            </template>
          </a-table-column>
          <a-table-column title="操作" :width="260" fixed="right">
            <template #cell="{ record }">
              <a-space>
                <a-button
                  type="text"
                  size="small"
                  @click="openRoleModal(record)"
                >
                  分配角色
                </a-button>
                <a-button
                  type="text"
                  size="small"
                  @click="toggleStatus(record)"
                >
                  {{ record.status === 'active' ? '停用' : '启用' }}
                </a-button>
              </a-space>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>

    <AdminUserCreateModal
      v-model:visible="createVisible"
      :submit="submitCreate"
    />
    <AdminUserRoleModal
      v-model:visible="roleVisible"
      :target="roleTarget"
      :role-ids="selectedRoleIds"
      :role-options="roleOptions"
      :submit="submitRoles"
    />
  </div>
</template>

<script lang="ts" setup>
  import { computed, onMounted, ref } from 'vue';
  import { Message } from '@arco-design/web-vue';

  import {
    createAdminUser,
    getAdminUserList,
    updateAdminUserStatus,
  } from '@/services/access-control';
  import {
    getAdminUserRoleAssignment,
    getRoleList,
    updateAdminUserRoleAssignment,
    type RoleInfo,
  } from '@/services/access-control';
  import useLoading from '@/hooks/loading';
  import { adminStatusColor, adminStatusText, formatDate } from '../helpers';
  import type { AdminUserRow } from '../types';
  import AdminUserCreateModal, {
    type AdminUserCreateFormValue,
  } from '../components/admin-user-create-modal.vue';
  import AdminUserRoleModal from '../components/admin-user-role-modal.vue';

  const keyword = ref('');
  const selectedStatus = ref('');
  const adminUsers = ref<AdminUserRow[]>([]);
  const roleOptions = ref<RoleInfo[]>([]);
  const createVisible = ref(false);
  const roleVisible = ref(false);
  const roleTarget = ref<AdminUserRow | null>(null);
  const selectedRoleIds = ref<string[]>([]);
  const { loading, setLoading } = useLoading(false);

  const filteredUsers = computed(() => {
    const search = keyword.value.trim().toLowerCase();
    return adminUsers.value.filter((item) => {
      const keywordMatched =
        !search ||
        [item.username, item.nickname || '', item.email]
          .join(' ')
          .toLowerCase()
          .includes(search);
      const statusMatched =
        !selectedStatus.value || item.status === selectedStatus.value;
      return keywordMatched && statusMatched;
    });
  });

  async function fetchData() {
    setLoading(true);
    try {
      const [{ data: adminData }, { data: roleData }] = await Promise.all([
        getAdminUserList({
          page: 1,
          pageSize: 100,
          username: keyword.value || undefined,
          status: selectedStatus.value || undefined,
        }),
        getRoleList(),
      ]);

      roleOptions.value = roleData.roles || [];
      const users = adminData.users || [];
      adminUsers.value = await Promise.all(
        users.map(async (user) => {
          try {
            const { data } = await getAdminUserRoleAssignment(user.id);
            return {
              ...user,
              roleCodes: data.roleCodes || [],
            };
          } catch {
            return {
              ...user,
              roleCodes: [],
            };
          }
        })
      );
    } catch (error: any) {
      Message.error(error?.message || '获取管理员列表失败');
    } finally {
      setLoading(false);
    }
  }

  async function submitCreate(payload: AdminUserCreateFormValue) {
    if (
      !payload.username.trim() ||
      !payload.email.trim() ||
      !payload.password.trim()
    ) {
      Message.error('用户名、邮箱、密码不能为空');
      return false;
    }

    try {
      await createAdminUser({
        username: payload.username.trim(),
        email: payload.email.trim(),
        password: payload.password,
        nickname: payload.nickname.trim() || undefined,
      });
      Message.success('管理员创建成功');
      await fetchData();
      return true;
    } catch (error: any) {
      Message.error(error?.message || '创建管理员失败');
      return false;
    }
  }

  async function openRoleModal(record: AdminUserRow) {
    try {
      const { data } = await getAdminUserRoleAssignment(record.id);
      roleTarget.value = record;
      selectedRoleIds.value = data.roleIds || [];
      roleVisible.value = true;
    } catch (error: any) {
      Message.error(error?.message || '获取管理员角色失败');
    }
  }

  async function submitRoles(roleIds: string[]) {
    if (!roleTarget.value) {
      return false;
    }

    try {
      await updateAdminUserRoleAssignment(roleTarget.value.id, roleIds);
      Message.success('管理员角色更新成功');
      selectedRoleIds.value = [];
      roleTarget.value = null;
      await fetchData();
      return true;
    } catch (error: any) {
      Message.error(error?.message || '更新管理员角色失败');
      return false;
    }
  }

  async function toggleStatus(record: AdminUserRow) {
    const nextStatus = record.status === 'active' ? 'inactive' : 'active';
    try {
      await updateAdminUserStatus(record.id, nextStatus);
      Message.success('管理员状态更新成功');
      await fetchData();
    } catch (error: any) {
      Message.error(error?.message || '更新管理员状态失败');
    }
  }

  onMounted(() => {
    fetchData();
  });
</script>

<style lang="less" scoped>
  .header-actions {
    display: flex;
    justify-content: space-between;
    margin-bottom: 16px;
  }
</style>
