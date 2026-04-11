<template>
  <div class="role-page">
    <Breadcrumb :items="['menu.accessControl', 'menu.accessControl.roles']" />
    <a-card class="general-card" title="角色管理" :bordered="false">
      <div class="header-actions">
        <a-space>
          <a-input-search
            v-model="keyword"
            placeholder="搜索角色名称或代码"
            style="width: 320px"
            allow-clear
          />
          <a-button type="primary" @click="openCreateModal">新建角色</a-button>
          <a-button @click="fetchData">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
        </a-space>
      </div>

      <a-table
        :data="filteredRoles"
        :loading="loading"
        :pagination="false"
        row-key="id"
      >
        <template #columns>
          <a-table-column title="角色名称" data-index="name" :width="180" />
          <a-table-column title="角色代码" data-index="code" :width="180" />
          <a-table-column title="系统角色" :width="110">
            <template #cell="{ record }">
              <a-tag :color="record.isSystem ? 'red' : 'arcoblue'">
                {{ record.isSystem ? '系统' : '自定义' }}
              </a-tag>
            </template>
          </a-table-column>
          <a-table-column title="权限" :width="420">
            <template #cell="{ record }">
              <a-space wrap>
                <a-tag
                  v-for="permission in record.permissions"
                  :key="permission.id"
                >
                  {{ permission.code }}
                </a-tag>
                <span v-if="record.permissions.length === 0">-</span>
              </a-space>
            </template>
          </a-table-column>
          <a-table-column title="描述">
            <template #cell="{ record }">
              {{ record.description || '-' }}
            </template>
          </a-table-column>
          <a-table-column title="操作" :width="260" fixed="right">
            <template #cell="{ record }">
              <a-space>
                <a-button
                  type="text"
                  size="small"
                  @click="openPermissionModal(record)"
                >
                  配置权限
                </a-button>
                <a-button
                  type="text"
                  size="small"
                  @click="openEditModal(record)"
                >
                  编辑
                </a-button>
                <a-button
                  type="text"
                  size="small"
                  status="danger"
                  :disabled="record.isSystem"
                  @click="removeRole(record)"
                >
                  删除
                </a-button>
              </a-space>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>

    <RoleEditModal
      v-model:visible="editVisible"
      :editing-role="editingRole"
      :permissions="permissions"
      :submit="submitRole"
    />
    <RolePermissionModal
      v-model:visible="permissionVisible"
      :target="permissionTarget"
      :permission-ids="selectedPermissionIds"
      :permissions="permissions"
      :submit="submitPermissions"
    />
  </div>
</template>

<script lang="ts" setup>
  import { computed, onMounted, ref } from 'vue';
  import { Message, Modal } from '@arco-design/web-vue';

  import {
    createRole,
    deleteRole,
    getPermissionList,
    getRoleList,
    getRolePermissionAssignment,
    updateRole,
    updateRolePermissionAssignment,
    type PermissionInfo,
    type RoleInfo,
  } from '@/services/access-control';
  import useLoading from '@/hooks/loading';
  import RoleEditModal, {
    type RoleFormValue,
  } from '../components/role-edit-modal.vue';
  import RolePermissionModal from '../components/role-permission-modal.vue';

  const keyword = ref('');
  const roles = ref<RoleInfo[]>([]);
  const permissions = ref<PermissionInfo[]>([]);
  const editingRole = ref<RoleInfo | null>(null);
  const permissionTarget = ref<RoleInfo | null>(null);
  const editVisible = ref(false);
  const permissionVisible = ref(false);
  const selectedPermissionIds = ref<string[]>([]);
  const { loading, setLoading } = useLoading(false);

  const filteredRoles = computed(() => {
    const search = keyword.value.trim().toLowerCase();
    if (!search) {
      return roles.value;
    }

    return roles.value.filter((item) => {
      return [item.name, item.code, item.description || '']
        .join(' ')
        .toLowerCase()
        .includes(search);
    });
  });

  async function fetchData() {
    setLoading(true);
    try {
      const [{ data: roleData }, { data: permissionData }] = await Promise.all([
        getRoleList(),
        getPermissionList(),
      ]);
      roles.value = roleData.roles || [];
      permissions.value = permissionData.permissions || [];
    } catch (error: any) {
      Message.error(error?.message || '获取角色信息失败');
    } finally {
      setLoading(false);
    }
  }

  function openCreateModal() {
    editingRole.value = null;
    editVisible.value = true;
  }

  function openEditModal(role: RoleInfo) {
    editingRole.value = role;
    editVisible.value = true;
  }

  async function submitRole(payload: RoleFormValue) {
    if (!payload.name.trim() || !payload.code.trim()) {
      Message.error('角色名称和角色代码不能为空');
      return false;
    }

    try {
      if (editingRole.value) {
        await updateRole(editingRole.value.id, {
          name: payload.name.trim(),
          description: payload.description.trim() || null,
        });
      } else {
        await createRole({
          name: payload.name.trim(),
          code: payload.code.trim(),
          description: payload.description.trim() || null,
          permissionIds: [...payload.permissionIds],
        });
      }
      Message.success(editingRole.value ? '角色更新成功' : '角色创建成功');
      editingRole.value = null;
      await fetchData();
      return true;
    } catch (error: any) {
      Message.error(error?.message || '保存角色失败');
      return false;
    }
  }

  function removeRole(role: RoleInfo) {
    Modal.confirm({
      title: '确认删除角色',
      content: `确定删除角色「${role.name}」吗？`,
      okButtonProps: { status: 'danger' },
      onOk: async () => {
        try {
          await deleteRole(role.id);
          Message.success('角色删除成功');
          await fetchData();
        } catch (error: any) {
          Message.error(error?.message || '删除角色失败');
        }
      },
    });
  }

  async function openPermissionModal(role: RoleInfo) {
    try {
      const { data } = await getRolePermissionAssignment(role.id);
      permissionTarget.value = role;
      selectedPermissionIds.value = data.permissionIds || [];
      permissionVisible.value = true;
    } catch (error: any) {
      Message.error(error?.message || '获取角色权限失败');
    }
  }

  async function submitPermissions(permissionIds: string[]) {
    if (!permissionTarget.value) {
      return false;
    }

    try {
      await updateRolePermissionAssignment(
        permissionTarget.value.id,
        permissionIds
      );
      Message.success('角色权限更新成功');
      permissionTarget.value = null;
      selectedPermissionIds.value = [];
      await fetchData();
      return true;
    } catch (error: any) {
      Message.error(error?.message || '更新角色权限失败');
      return false;
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
