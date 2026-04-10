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

    <a-modal
      v-model:visible="editVisible"
      :title="editingRole ? '编辑角色' : '新建角色'"
      :on-before-ok="submitRole"
      @cancel="resetEditForm"
    >
      <a-form :model="editForm" layout="vertical">
        <a-form-item label="角色名称" required>
          <a-input v-model="editForm.name" placeholder="请输入角色名称" />
        </a-form-item>
        <a-form-item label="角色代码" required>
          <a-input
            v-model="editForm.code"
            placeholder="请输入角色代码"
            :disabled="Boolean(editingRole)"
          />
        </a-form-item>
        <a-form-item label="描述">
          <a-textarea v-model="editForm.description" placeholder="请输入描述" />
        </a-form-item>
        <a-form-item v-if="!editingRole" label="初始权限">
          <a-select
            v-model="editForm.permissionIds"
            multiple
            allow-clear
            placeholder="请选择权限"
          >
            <a-option
              v-for="permission in permissions"
              :key="permission.id"
              :value="permission.id"
            >
              {{ permission.code }} - {{ permission.name }}
            </a-option>
          </a-select>
        </a-form-item>
      </a-form>
    </a-modal>

    <a-modal
      v-model:visible="permissionVisible"
      title="配置角色权限"
      :on-before-ok="submitPermissions"
      @cancel="resetPermissionForm"
    >
      <a-form :model="permissionForm" layout="vertical">
        <a-form-item label="角色">
          <a-input :model-value="permissionTarget?.name || ''" disabled />
        </a-form-item>
        <a-form-item label="权限列表">
          <a-select
            v-model="permissionForm.permissionIds"
            multiple
            allow-clear
            placeholder="请选择权限"
          >
            <a-option
              v-for="permission in permissions"
              :key="permission.id"
              :value="permission.id"
            >
              {{ permission.code }} - {{ permission.name }}
            </a-option>
          </a-select>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import { computed, onMounted, reactive, ref } from 'vue';
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
  } from '@/api/rbac';
  import useLoading from '@/hooks/loading';

  const keyword = ref('');
  const roles = ref<RoleInfo[]>([]);
  const permissions = ref<PermissionInfo[]>([]);
  const editingRole = ref<RoleInfo | null>(null);
  const permissionTarget = ref<RoleInfo | null>(null);
  const editVisible = ref(false);
  const permissionVisible = ref(false);
  const { loading, setLoading } = useLoading(false);

  const editForm = reactive({
    name: '',
    code: '',
    description: '',
    permissionIds: [] as string[],
  });

  const permissionForm = reactive({
    permissionIds: [] as string[],
  });

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

  const fetchData = async () => {
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
  };

  const resetEditForm = () => {
    editingRole.value = null;
    editForm.name = '';
    editForm.code = '';
    editForm.description = '';
    editForm.permissionIds = [];
  };

  const openCreateModal = () => {
    resetEditForm();
    editVisible.value = true;
  };

  const openEditModal = (role: RoleInfo) => {
    editingRole.value = role;
    editForm.name = role.name;
    editForm.code = role.code;
    editForm.description = role.description || '';
    editForm.permissionIds = role.permissions.map((item) => item.id);
    editVisible.value = true;
  };

  const submitRole = async () => {
    if (!editForm.name.trim() || !editForm.code.trim()) {
      Message.error('角色名称和角色代码不能为空');
      return false;
    }

    try {
      if (editingRole.value) {
        await updateRole(editingRole.value.id, {
          name: editForm.name.trim(),
          description: editForm.description.trim() || null,
        });
      } else {
        await createRole({
          name: editForm.name.trim(),
          code: editForm.code.trim(),
          description: editForm.description.trim() || null,
          permissionIds: [...editForm.permissionIds],
        });
      }
      Message.success(editingRole.value ? '角色更新成功' : '角色创建成功');
      editVisible.value = false;
      resetEditForm();
      await fetchData();
      return true;
    } catch (error: any) {
      Message.error(error?.message || '保存角色失败');
      return false;
    }
  };

  const removeRole = (role: RoleInfo) => {
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
  };

  const resetPermissionForm = () => {
    permissionTarget.value = null;
    permissionForm.permissionIds = [];
  };

  const openPermissionModal = async (role: RoleInfo) => {
    try {
      const { data } = await getRolePermissionAssignment(role.id);
      permissionTarget.value = role;
      permissionForm.permissionIds = data.permissionIds || [];
      permissionVisible.value = true;
    } catch (error: any) {
      Message.error(error?.message || '获取角色权限失败');
    }
  };

  const submitPermissions = async () => {
    if (!permissionTarget.value) {
      return false;
    }

    try {
      await updateRolePermissionAssignment(
        permissionTarget.value.id,
        permissionForm.permissionIds
      );
      Message.success('角色权限更新成功');
      permissionVisible.value = false;
      resetPermissionForm();
      await fetchData();
      return true;
    } catch (error: any) {
      Message.error(error?.message || '更新角色权限失败');
      return false;
    }
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
