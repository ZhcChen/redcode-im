<template>
  <div class="permission-page">
    <Breadcrumb
      :items="['menu.accessControl', 'menu.accessControl.permissions']"
    />
    <a-card class="general-card" title="权限点管理" :bordered="false">
      <div class="header-actions">
        <a-space>
          <a-input-search
            v-model="keyword"
            placeholder="搜索权限名称或代码"
            style="width: 320px"
            allow-clear
          />
          <a-button @click="fetchPermissions">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
        </a-space>
      </div>

      <a-table
        :data="filteredPermissions"
        :loading="loading"
        :pagination="false"
        row-key="id"
      >
        <template #columns>
          <a-table-column title="权限名称" data-index="name" :width="180" />
          <a-table-column title="权限代码" data-index="code" :width="220" />
          <a-table-column title="描述" :width="320">
            <template #cell="{ record }">
              {{ record.description || '-' }}
            </template>
          </a-table-column>
          <a-table-column title="更新时间" :width="180">
            <template #cell="{ record }">
              {{ formatDate(record.updatedAt) }}
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { computed, onMounted, ref } from 'vue';
  import { Message } from '@arco-design/web-vue';

  import useLoading from '@/hooks/loading';
  import { getPermissionList, type PermissionInfo } from '@/api/rbac';
  import { formatDate } from '../helpers';

  const keyword = ref('');
  const permissions = ref<PermissionInfo[]>([]);
  const { loading, setLoading } = useLoading(false);

  const filteredPermissions = computed(() => {
    const search = keyword.value.trim().toLowerCase();
    if (!search) {
      return permissions.value;
    }

    return permissions.value.filter((item) => {
      return [item.name, item.code, item.description || '']
        .join(' ')
        .toLowerCase()
        .includes(search);
    });
  });

  async function fetchPermissions() {
    setLoading(true);
    try {
      const { data } = await getPermissionList();
      permissions.value = data.permissions || [];
    } catch (error: any) {
      Message.error(error?.message || '获取权限列表失败');
    } finally {
      setLoading(false);
    }
  }

  onMounted(() => {
    fetchPermissions();
  });
</script>

<style lang="less" scoped>
  .header-actions {
    display: flex;
    justify-content: space-between;
    margin-bottom: 16px;
  }
</style>
