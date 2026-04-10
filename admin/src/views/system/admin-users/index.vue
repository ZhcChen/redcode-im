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
          <a-button type="primary" @click="openCreateModal"
            >新建管理员</a-button
          >
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
              <a-tag :color="statusColor(record.status)">
                {{ statusText(record.status) }}
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

    <a-modal
      v-model:visible="createVisible"
      title="新建管理员"
      :on-before-ok="submitCreate"
      @cancel="resetCreateForm"
    >
      <a-form :model="createForm" layout="vertical">
        <a-form-item label="用户名" required>
          <a-input
            v-model="createForm.username"
            placeholder="请输入管理员用户名"
          />
        </a-form-item>
        <a-form-item label="邮箱" required>
          <a-input v-model="createForm.email" placeholder="请输入管理员邮箱" />
        </a-form-item>
        <a-form-item label="密码" required>
          <a-input-password
            v-model="createForm.password"
            placeholder="请输入管理员密码"
          />
        </a-form-item>
        <a-form-item label="昵称">
          <a-input
            v-model="createForm.nickname"
            placeholder="请输入管理员昵称"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <a-modal
      v-model:visible="roleVisible"
      title="分配管理员角色"
      :on-before-ok="submitRoles"
      @cancel="resetRoleForm"
    >
      <a-form :model="roleForm" layout="vertical">
        <a-form-item label="管理员账号">
          <a-input :model-value="roleTarget?.username || ''" disabled />
        </a-form-item>
        <a-form-item label="角色列表">
          <a-select
            v-model="roleForm.roleIds"
            multiple
            allow-clear
            placeholder="请选择角色"
          >
            <a-option
              v-for="role in roleOptions"
              :key="role.id"
              :value="role.id"
            >
              {{ role.code }} - {{ role.name }}
            </a-option>
          </a-select>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import { computed, onMounted, reactive, ref } from 'vue';
  import dayjs from 'dayjs';
  import { Message } from '@arco-design/web-vue';
  import {
    getAdminUserList,
    createAdminUser,
    updateAdminUserStatus,
    type AdminUserInfo,
  } from '@/api/user';
  import {
    getRoleList,
    getAdminUserRoleAssignment,
    updateAdminUserRoleAssignment,
    type RoleInfo,
  } from '@/api/rbac';
  import useLoading from '@/hooks/loading';

  type AdminUserRow = AdminUserInfo & { roleCodes: string[] };

  const keyword = ref('');
  const selectedStatus = ref('');
  const adminUsers = ref<AdminUserRow[]>([]);
  const roleOptions = ref<RoleInfo[]>([]);
  const createVisible = ref(false);
  const roleVisible = ref(false);
  const roleTarget = ref<AdminUserRow | null>(null);
  const { loading, setLoading } = useLoading(false);

  const createForm = reactive({
    username: '',
    email: '',
    password: '',
    nickname: '',
  });

  const roleForm = reactive({
    roleIds: [] as string[],
  });

  const fetchData = async () => {
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
      const users = (adminData.users || []) as AdminUserInfo[];
      const withRoles = await Promise.all(
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
      adminUsers.value = withRoles;
    } catch (error: any) {
      Message.error(error?.message || '获取管理员列表失败');
    } finally {
      setLoading(false);
    }
  };

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

  const resetCreateForm = () => {
    createForm.username = '';
    createForm.email = '';
    createForm.password = '';
    createForm.nickname = '';
  };

  const openCreateModal = () => {
    resetCreateForm();
    createVisible.value = true;
  };

  const submitCreate = async () => {
    if (
      !createForm.username.trim() ||
      !createForm.email.trim() ||
      !createForm.password.trim()
    ) {
      Message.error('用户名、邮箱、密码不能为空');
      return false;
    }

    try {
      await createAdminUser({
        username: createForm.username.trim(),
        email: createForm.email.trim(),
        password: createForm.password,
        nickname: createForm.nickname.trim() || undefined,
      });
      Message.success('管理员创建成功');
      createVisible.value = false;
      resetCreateForm();
      await fetchData();
      return true;
    } catch (error: any) {
      Message.error(error?.message || '创建管理员失败');
      return false;
    }
  };

  const resetRoleForm = () => {
    roleTarget.value = null;
    roleForm.roleIds = [];
  };

  const openRoleModal = async (record: AdminUserRow) => {
    try {
      const { data } = await getAdminUserRoleAssignment(record.id);
      roleTarget.value = record;
      roleForm.roleIds = data.roleIds || [];
      roleVisible.value = true;
    } catch (error: any) {
      Message.error(error?.message || '获取管理员角色失败');
    }
  };

  const submitRoles = async () => {
    if (!roleTarget.value) {
      return false;
    }

    try {
      await updateAdminUserRoleAssignment(
        roleTarget.value.id,
        roleForm.roleIds
      );
      Message.success('管理员角色更新成功');
      roleVisible.value = false;
      resetRoleForm();
      await fetchData();
      return true;
    } catch (error: any) {
      Message.error(error?.message || '更新管理员角色失败');
      return false;
    }
  };

  const toggleStatus = async (record: AdminUserRow) => {
    const nextStatus = record.status === 'active' ? 'inactive' : 'active';
    try {
      await updateAdminUserStatus(record.id, nextStatus);
      Message.success('管理员状态更新成功');
      await fetchData();
    } catch (error: any) {
      Message.error(error?.message || '更新管理员状态失败');
    }
  };

  const statusColor = (status: string) => {
    switch (status) {
      case 'active':
        return 'green';
      case 'inactive':
        return 'orange';
      case 'banned':
        return 'red';
      case 'locked':
        return 'purple';
      default:
        return 'gray';
    }
  };

  const statusText = (status: string) => {
    switch (status) {
      case 'active':
        return '正常';
      case 'inactive':
        return '停用';
      case 'banned':
        return '封禁';
      case 'locked':
        return '锁定';
      default:
        return status;
    }
  };

  const formatDate = (value?: string | null) => {
    if (!value) return '-';
    return dayjs(value).format('YYYY-MM-DD HH:mm');
  };

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
