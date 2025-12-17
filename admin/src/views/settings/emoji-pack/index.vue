<template>
  <div class="emoji-pack-settings-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.emojiPack']" />
    <a-card class="general-card" title="贴纸设置" :bordered="false">
      <div class="actions">
        <a-space>
          <a-input-search
            v-model="searchKeyword"
            placeholder="搜索贴纸名称或描述"
            style="width: 300px"
            allow-clear
            @search="handleSearch"
            @clear="handleSearchClear"
          />
          <a-button
            type="primary"
            :loading="actionLoading"
            @click="handleCreatePack"
          >
            <template #icon>
              <icon-plus />
            </template>
            新增贴纸
          </a-button>
          <a-button :loading="listLoading" @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
          </a-button>
        </a-space>
      </div>

      <a-table
        :columns="packColumns"
        :data="packs"
        :loading="listLoading"
        :pagination="false"
        :scroll="{ x: 'max-content' }"
        class="pack-table"
      >
        <template #icon_url="{ record }">
          <img
            v-if="record.icon_url && !isExpiredUrl(record.icon_url)"
            :src="record.icon_url"
            alt="贴纸图标"
            class="pack-icon"
          />
          <img
            v-else-if="record.icon_url && isExpiredUrl(record.icon_url)"
            :src="getRefreshedUrl(record.icon_url)"
            alt="贴纸图标"
            class="pack-icon"
          />
          <span v-else class="pack-icon-placeholder">无图标</span>
        </template>

        <template #pack_type="{ record }">
          <a-tag :color="record.pack_type === 1 ? 'blue' : 'gray'">
            {{ record.pack_type === 1 ? '贴纸包' : '单个' }}
          </a-tag>
        </template>

        <template #is_active="{ record }">
          <a-tag :color="record.is_active ? 'green' : 'gray'">
            {{ record.is_active ? '启用' : '禁用' }}
          </a-tag>
        </template>

        <template #operations="{ record }">
          <a-space size="mini">
            <a-button
              v-if="record.pack_type === 0"
              type="text"
              size="small"
              @click="handleManageItems(record)"
            >
              管理表情
            </a-button>
            <a-button
              v-if="record.pack_type === 1"
              type="text"
              size="small"
              @click="handleManageSuitePacks(record)"
            >
              管理贴纸
            </a-button>
            <a-button type="text" size="small" @click="handleEditPack(record)">
              编辑
            </a-button>
            <a-popconfirm
              content="确定要删除这个贴纸吗？删除后所有表情项也会被删除。"
              @ok="handleDeletePack(record.id)"
            >
              <a-button type="text" size="small" status="danger">
                删除
              </a-button>
            </a-popconfirm>
          </a-space>
        </template>
      </a-table>

      <!-- 贴纸创建/编辑对话框 -->
      <a-modal
        :visible="packModalVisible"
        :title="packModalTitle"
        :width="600"
        :confirm-loading="actionLoading"
        @update:visible="packModalVisible = $event"
        @before-ok="handlePackBeforeOk"
        @cancel="handlePackCancel"
      >
        <a-form
          ref="packFormRef"
          :model="packFormData"
          :rules="packFormRules"
          label-align="left"
          :label-col-props="{ span: 6 }"
          :wrapper-col-props="{ span: 18 }"
        >
          <a-form-item field="name" label="贴纸名称">
            <a-input v-model="packFormData.name" placeholder="请输入贴纸名称" />
          </a-form-item>

          <a-form-item field="icon_url" label="图标">
            <div class="icon-upload-wrapper">
              <div v-if="packFormData.icon_url" class="icon-preview">
                <img
                  :src="packFormData.icon_url"
                  alt="图标预览"
                  class="preview-image"
                />
                <a-button
                  type="text"
                  status="danger"
                  size="small"
                  @click="packFormData.icon_url = ''"
                >
                  删除
                </a-button>
              </div>
              <div v-else class="icon-upload-area">
                <input
                  ref="iconFileInputRef"
                  type="file"
                  accept="image/*"
                  style="display: none"
                  @change="handleIconFileChange"
                />
                <a-button
                  type="outline"
                  :loading="iconUploadLoading"
                  @click="triggerIconFileSelect"
                >
                  <template #icon>
                    <icon-upload />
                  </template>
                  上传图标
                </a-button>
                <span class="upload-hint"
                  >支持 JPG、PNG、WebP 等图片格式，建议尺寸 64x64</span
                >
              </div>
            </div>
            <template #help> 贴纸图标，用于在客户端显示贴纸标签 </template>
          </a-form-item>

          <a-form-item field="description" label="描述">
            <a-textarea
              v-model="packFormData.description"
              placeholder="请输入贴纸描述（可选）"
              :auto-size="{ minRows: 2, maxRows: 4 }"
            />
          </a-form-item>

          <a-form-item field="pack_type" label="类型">
            <a-radio-group v-model="packFormData.pack_type">
              <a-radio :value="0">单个贴纸</a-radio>
              <a-radio :value="1">贴纸包</a-radio>
            </a-radio-group>
            <template #help>
              贴纸包可以包含多个贴纸，用户添加贴纸包时会添加贴纸包下的所有贴纸
            </template>
          </a-form-item>

          <a-form-item
            v-if="packFormData.pack_type === 0"
            field="parent_id"
            label="所属贴纸包"
          >
            <a-select
              v-model="packFormData.parent_id"
              placeholder="选择所属贴纸包（可选）"
              allow-clear
            >
              <a-option
                v-for="suite in suites"
                :key="suite.id"
                :value="suite.id"
              >
                {{ suite.name }}
              </a-option>
            </a-select>
            <template #help> 如果选择贴纸包，此贴纸将归属于该贴纸包 </template>
          </a-form-item>

          <a-form-item field="is_active" label="状态">
            <a-switch v-model="packFormData.is_active" />
            <template #help> 启用后用户才能添加此贴纸 </template>
          </a-form-item>
        </a-form>
      </a-modal>

      <!-- 贴纸包贴纸管理对话框 -->
      <a-modal
        v-model:visible="suitePackModalVisible"
        title="管理贴纸包贴纸"
        :width="900"
        :footer="false"
        @cancel="handleSuitePackModalCancel"
      >
        <div v-if="currentSuite" class="suite-management">
          <div class="item-header">
            <h3>{{ currentSuite.name }}</h3>
            <a-button type="primary" @click="handleCreateSuitePack">
              <template #icon>
                <icon-plus />
              </template>
              添加贴纸
            </a-button>
          </div>

          <a-table
            :columns="suitePackColumns"
            :data="currentSuitePacks"
            :loading="suitePackLoading"
            :pagination="false"
            class="suite-pack-table"
          >
            <template #icon_url="{ record }">
              <img
                v-if="record.icon_url && !isExpiredUrl(record.icon_url)"
                :src="record.icon_url"
                alt="贴纸图标"
                class="pack-icon"
              />
              <img
                v-else-if="record.icon_url && isExpiredUrl(record.icon_url)"
                :src="getRefreshedUrl(record.icon_url)"
                alt="贴纸图标"
                class="pack-icon"
              />
              <span v-else class="pack-icon-placeholder">无图标</span>
            </template>

            <template #is_active="{ record }">
              <a-tag :color="record.is_active ? 'green' : 'gray'">
                {{ record.is_active ? '启用' : '禁用' }}
              </a-tag>
            </template>

            <template #operations="{ record }">
              <a-space size="mini">
                <a-button
                  type="text"
                  size="small"
                  @click="handleManageItems(record)"
                >
                  管理表情
                </a-button>
                <a-button
                  type="text"
                  size="small"
                  @click="handleEditPack(record)"
                >
                  编辑
                </a-button>
                <a-popconfirm
                  content="确定要从贴纸包中移除这个贴纸吗？"
                  @ok="handleRemoveFromSuite(record.id)"
                >
                  <a-button type="text" size="small" status="danger">
                    移除
                  </a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </a-table>
        </div>
      </a-modal>

      <!-- 表情项管理对话框 -->
      <a-modal
        v-model:visible="itemModalVisible"
        title="管理表情项"
        :width="900"
        :footer="false"
        @cancel="handleItemModalCancel"
      >
        <div v-if="currentPack" class="item-management">
          <div class="item-header">
            <h3>{{ currentPack.name }}</h3>
            <a-button type="primary" @click="handleCreateItem">
              <template #icon>
                <icon-plus />
              </template>
              新增表情
            </a-button>
          </div>

          <a-table
            :columns="itemColumns"
            :data="currentPackItems"
            :loading="itemLoading"
            :pagination="false"
            class="item-table"
          >
            <template #image_url="{ record }">
              <img :src="record.image_url" alt="表情" class="emoji-image" />
            </template>

            <template #operations="{ record }">
              <a-space size="mini">
                <a-button
                  type="text"
                  size="small"
                  @click="handleEditItem(record)"
                >
                  编辑
                </a-button>
                <a-popconfirm
                  content="确定要删除这个表情吗？"
                  @ok="handleDeleteItem(record.id)"
                >
                  <a-button type="text" size="small" status="danger">
                    删除
                  </a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </a-table>
        </div>

        <!-- 表情项创建/编辑对话框 -->
        <a-modal
          v-model:visible="itemFormModalVisible"
          :title="itemModalTitle"
          :width="600"
          :confirm-loading="itemActionLoading"
          @before-ok="handleItemBeforeOk"
          @cancel="handleItemFormCancel"
        >
          <a-form
            ref="itemFormRef"
            :model="itemFormData"
            :rules="itemFormRules"
            label-align="left"
            :label-col-props="{ span: 6 }"
            :wrapper-col-props="{ span: 18 }"
          >
            <a-form-item field="image_url" label="图片">
              <div class="item-image-upload-wrapper">
                <div v-if="itemFormData.image_url" class="item-image-preview">
                  <img
                    :src="itemFormData.image_url"
                    alt="表情预览"
                    class="preview-image"
                  />
                  <a-button
                    type="text"
                    status="danger"
                    size="small"
                    @click="itemFormData.image_url = ''"
                  >
                    删除
                  </a-button>
                </div>
                <div v-else class="item-image-upload-area">
                  <input
                    ref="itemImageFileInputRef"
                    type="file"
                    accept="image/*"
                    style="display: none"
                    @change="handleItemImageFileChange"
                  />
                  <a-button
                    type="outline"
                    :loading="itemImageUploadLoading"
                    @click="triggerItemImageFileSelect"
                  >
                    <template #icon>
                      <icon-upload />
                    </template>
                    上传图片
                  </a-button>
                  <span class="upload-hint"
                    >支持 JPG、PNG、WebP、GIF 等图片格式</span
                  >
                </div>
              </div>
              <template #help> 表情图片，支持静态图片和 GIF 动图 </template>
            </a-form-item>

            <a-form-item field="name" label="名称">
              <a-input
                v-model="itemFormData.name"
                placeholder="请输入表情名称（可选）"
              />
            </a-form-item>

            <a-form-item field="sort_order" label="排序">
              <a-input-number
                v-model="itemFormData.sort_order"
                :min="0"
                placeholder="数字越小越靠前"
              />
              <template #help> 排序值，数字越小越靠前显示 </template>
            </a-form-item>
          </a-form>
        </a-modal>
      </a-modal>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive, computed, onMounted, defineComponent } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import useLoading from '@/hooks/loading';
  import {
    listAllEmojiPacks,
    createEmojiPack,
    updateEmojiPack,
    deleteEmojiPack,
    getEmojiPack,
    getSuitePacks,
    createEmojiItem,
    updateEmojiItem,
    deleteEmojiItem,
    type EmojiPack,
    type EmojiItem,
  } from '@/api/emoji-pack';
  import {
    getDefaultStorageProvider,
    testCosUploadSignature,
    testCosDownloadUrl,
    type StorageProvider,
  } from '@/api/settings';
  import { uploadWithSignature } from '@/utils/direct-upload';
  import { computeFileHash } from '@/utils/fileHash';

  // 检查URL是否可能是过期的临时URL
  const isExpiredUrl = (url: string) => {
    // 简单检查：如果包含cos.域名且有查询参数，认为是临时URL
    return url.includes('cos.') && url.includes('?');
  };

  // 获取刷新的URL（如果是临时URL则尝试通过后端配置生成新的直连地址，否则直接返回原始URL）
  const getRefreshedUrl = (url: string) => {
    if (!url) return url;
    // 如果不是临时URL，直接返回
    if (!isExpiredUrl(url)) {
      return url;
    }
    // 如果后续需要严格区分「存储 key」与「访问 URL」，可以在后端返回独立的 key 字段；
    // 目前这里保守处理：直接返回原 URL，避免影响现有功能。
    return url;
  };

  const { loading: listLoading, setLoading: setListLoading } =
    useLoading(false);
  const { loading: actionLoading, setLoading: setActionLoading } =
    useLoading(false);
  const { loading: itemLoading, setLoading: setItemLoading } =
    useLoading(false);
  const { loading: itemActionLoading, setLoading: setItemActionLoading } =
    useLoading(false);

  const packs = ref<EmojiPack[]>([]);
  const searchKeyword = ref('');
  const packModalVisible = ref(false);
  const packModalTitle = ref('新增贴纸');
  const packFormRef = ref();
  const packFormData = reactive({
    name: '',
    icon_url: '',
    icon_object_key: '',
    description: '',
    is_active: true,
    pack_type: 0, // 0=单个, 1=贴纸包
    parent_id: undefined as string | undefined,
  });
  const editingPackId = ref<string | null>(null);

  const packFormRules = {
    name: [{ required: true, message: '请输入贴纸名称' }],
  };

  const suites = computed(() => {
    return packs.value.filter((p) => p.pack_type === 1 && !p.parent_id);
  });

  const packColumns = [
    {
      title: '图标',
      dataIndex: 'icon_url',
      slotName: 'icon_url',
      width: 80,
    },
    {
      title: '名称',
      dataIndex: 'name',
      width: 200,
    },
    {
      title: '类型',
      dataIndex: 'pack_type',
      slotName: 'pack_type',
      width: 100,
    },
    {
      title: '描述',
      dataIndex: 'description',
      ellipsis: true,
    },
    {
      title: '状态',
      dataIndex: 'is_active',
      slotName: 'is_active',
      width: 100,
    },
    {
      title: '创建时间',
      dataIndex: 'created_at',
      width: 180,
    },
    {
      title: '操作',
      slotName: 'operations',
      width: 280,
      fixed: 'right',
    },
  ];

  // 贴纸包管理相关
  const currentSuite = ref<EmojiPack | null>(null);
  const currentSuitePacks = ref<EmojiPack[]>([]);
  const suitePackModalVisible = ref(false);
  const suitePackLoading = ref(false);
  const suitePackColumns = [
    {
      title: '图标',
      dataIndex: 'icon_url',
      slotName: 'icon_url',
      width: 80,
    },
    {
      title: '名称',
      dataIndex: 'name',
      width: 200,
    },
    {
      title: '描述',
      dataIndex: 'description',
      ellipsis: true,
    },
    {
      title: '状态',
      dataIndex: 'is_active',
      slotName: 'is_active',
      width: 100,
    },
    {
      title: '操作',
      slotName: 'operations',
      width: 250,
      fixed: 'right',
    },
  ];

  // 表情项相关
  const currentPack = ref<EmojiPack | null>(null);
  const currentPackItems = ref<EmojiItem[]>([]);
  const itemModalVisible = ref(false);
  const itemFormModalVisible = ref(false);
  const itemModalTitle = ref('新增表情');
  const itemFormRef = ref();
  const itemFormData = reactive({
    image_url: '',
    image_object_key: '',
    name: '',
    sort_order: 0,
  });
  const editingItemId = ref<string | null>(null);

  // 图标上传相关
  const iconFileInputRef = ref<HTMLInputElement | null>(null);
  const iconUploadLoading = ref(false);
  const defaultStorageProvider = ref<StorageProvider | null>(null);

  // 表情项图片上传相关
  const itemImageFileInputRef = ref<HTMLInputElement | null>(null);
  const itemImageUploadLoading = ref(false);

  const itemFormRules = {
    image_url: [{ required: true, message: '请输入表情图片URL' }],
  };

  const itemColumns = [
    {
      title: '图片',
      dataIndex: 'image_url',
      slotName: 'image_url',
      width: 80,
    },
    {
      title: '名称',
      dataIndex: 'name',
      width: 150,
    },
    {
      title: '排序',
      dataIndex: 'sort_order',
      width: 100,
    },
    {
      title: '操作',
      slotName: 'operations',
      width: 150,
      fixed: 'right',
    },
  ];

  // 获取贴纸列表（只显示顶层的单个贴纸和贴纸包，不显示贴纸包的子贴纸）
  const fetchPacks = async (keyword?: string) => {
    try {
      setListLoading(true);
      const { data } = await listAllEmojiPacks(keyword);
      // 过滤掉有 parent_id 的贴纸（贴纸包的子贴纸）
      packs.value = data.filter((p) => !p.parent_id);
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '获取贴纸列表失败');
    } finally {
      setListLoading(false);
    }
  };

  // 搜索处理
  const handleSearch = (value: string) => {
    fetchPacks(value);
  };

  // 清除搜索
  const handleSearchClear = () => {
    searchKeyword.value = '';
    fetchPacks();
  };

  // 创建贴纸
  const handleCreatePack = () => {
    editingPackId.value = null;
    packModalTitle.value = '新增贴纸';
    packFormData.name = '';
    packFormData.icon_url = '';
    packFormData.icon_object_key = '';
    packFormData.description = '';
    packFormData.is_active = true;
    packFormData.pack_type = 0;
    packFormData.parent_id = undefined;
    packModalVisible.value = true;
  };

  // 编辑贴纸
  const handleEditPack = (pack: EmojiPack) => {
    editingPackId.value = pack.id;
    packModalTitle.value = '编辑贴纸';
    packFormData.name = pack.name;
    packFormData.icon_url = pack.icon_url || '';
    packFormData.icon_object_key = pack.icon_object_key || '';
    packFormData.description = pack.description || '';
    packFormData.is_active = pack.is_active;
    packFormData.pack_type = pack.pack_type;
    packFormData.parent_id = pack.parent_id || undefined;
    packModalVisible.value = true;
  };

  // 删除贴纸
  const handleDeletePack = async (packId: string) => {
    try {
      setActionLoading(true);
      await deleteEmojiPack(packId);
      Message.success('删除成功');
      await fetchPacks();
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '删除失败');
    } finally {
      setActionLoading(false);
    }
  };

  // 获取贴纸包下的贴纸列表
  const fetchSuitePacks = async (suiteId: string) => {
    try {
      suitePackLoading.value = true;
      const { data } = await getSuitePacks(suiteId);
      currentSuitePacks.value = data;
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '获取贴纸包贴纸列表失败');
    } finally {
      suitePackLoading.value = false;
    }
  };

  // 贴纸表单提交
  const handlePackBeforeOk = async (done: (closed: boolean) => void) => {
    if (!packFormRef.value) {
      done(false);
      return;
    }

    try {
      const errors = await packFormRef.value.validate();
      if (errors) {
        done(false);
        return;
      }
    } catch (error) {
      done(false);
      return;
    }

    try {
      setActionLoading(true);
      if (editingPackId.value) {
        await updateEmojiPack(editingPackId.value, {
          name: packFormData.name,
          icon_url: packFormData.icon_url || undefined,
          icon_object_key: packFormData.icon_object_key || undefined,
          description: packFormData.description || undefined,
          is_active: packFormData.is_active,
          pack_type: packFormData.pack_type,
          parent_id: packFormData.parent_id,
        });
        Message.success('更新成功');
      } else {
        await createEmojiPack({
          name: packFormData.name,
          icon_url: packFormData.icon_url || undefined,
          icon_object_key: packFormData.icon_object_key || undefined,
          description: packFormData.description || undefined,
          is_active: packFormData.is_active,
          pack_type: packFormData.pack_type,
          parent_id: packFormData.parent_id,
        });
        Message.success('创建成功');
      }
      await fetchPacks();
      // 如果是在贴纸包管理弹窗中添加的贴纸，需要刷新贴纸包列表
      if (
        packFormData.parent_id &&
        currentSuite.value?.id === packFormData.parent_id
      ) {
        await fetchSuitePacks(packFormData.parent_id);
      }
      packModalVisible.value = false;
      done(true);
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '操作失败';
      Message.error(errorMsg);
      done(false);
    } finally {
      setActionLoading(false);
    }
  };

  const handlePackCancel = () => {
    packFormRef.value?.resetFields();
  };

  // 获取表情项列表
  const fetchPackItems = async (packId: string) => {
    try {
      setItemLoading(true);
      const { data } = await getEmojiPack(packId);
      currentPackItems.value = data.items || [];
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '获取表情列表失败');
    } finally {
      setItemLoading(false);
    }
  };

  // 管理表情项
  const handleManageItems = async (pack: EmojiPack) => {
    currentPack.value = pack;
    itemModalVisible.value = true;
    await fetchPackItems(pack.id);
  };

  // 创建表情项
  const handleCreateItem = () => {
    editingItemId.value = null;
    itemModalTitle.value = '新增表情';
    itemFormData.image_url = '';
    itemFormData.image_object_key = '';
    itemFormData.name = '';
    itemFormData.sort_order = 0;
    itemFormModalVisible.value = true;
  };

  // 编辑表情项
  const handleEditItem = (item: EmojiItem) => {
    editingItemId.value = item.id;
    itemModalTitle.value = '编辑表情';
    itemFormData.image_url = item.image_url;
    itemFormData.image_object_key = item.image_object_key || '';
    itemFormData.name = item.name || '';
    itemFormData.sort_order = item.sort_order;
    itemFormModalVisible.value = true;
  };

  // 删除表情项
  const handleDeleteItem = async (itemId: string) => {
    try {
      setItemActionLoading(true);
      await deleteEmojiItem(itemId);
      Message.success('删除成功');
      if (currentPack.value) {
        await fetchPackItems(currentPack.value.id);
      }
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '删除失败');
    } finally {
      setItemActionLoading(false);
    }
  };

  // 表情项表单提交
  const handleItemBeforeOk = async () => {
    const valid = await itemFormRef.value?.validate();
    if (!valid) {
      return false;
    }

    if (!currentPack.value) {
      Message.error('请先选择贴纸');
      return false;
    }

    try {
      setItemActionLoading(true);
      if (editingItemId.value) {
        await updateEmojiItem(editingItemId.value, {
          image_url: itemFormData.image_url,
          image_object_key: itemFormData.image_object_key || undefined,
          name: itemFormData.name || undefined,
          sort_order: itemFormData.sort_order,
        });
        Message.success('更新成功');
      } else {
        await createEmojiItem({
          pack_id: currentPack.value.id,
          image_url: itemFormData.image_url,
          image_object_key: itemFormData.image_object_key || undefined,
          name: itemFormData.name || undefined,
          sort_order: itemFormData.sort_order,
        });
        Message.success('创建成功');
      }
      itemFormModalVisible.value = false;
      if (currentPack.value) {
        await fetchPackItems(currentPack.value.id);
      }
      return true;
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '操作失败');
      return false;
    } finally {
      setItemActionLoading(false);
    }
  };

  const handleItemFormCancel = () => {
    itemFormRef.value?.resetFields();
  };

  const handleItemModalCancel = () => {
    currentPack.value = null;
    currentPackItems.value = [];
  };

  // 管理贴纸包下的贴纸
  const handleManageSuitePacks = async (suite: EmojiPack) => {
    currentSuite.value = suite;
    suitePackModalVisible.value = true;
    await fetchSuitePacks(suite.id);
  };

  // 创建贴纸包下的贴纸
  const handleCreateSuitePack = () => {
    if (!currentSuite.value) return;
    editingPackId.value = null;
    packModalTitle.value = '添加贴纸到贴纸包';
    packFormData.name = '';
    packFormData.icon_url = '';
    packFormData.description = '';
    packFormData.is_active = true;
    packFormData.pack_type = 0;
    packFormData.parent_id = currentSuite.value.id;
    packModalVisible.value = true;
  };

  // 从贴纸包中移除贴纸
  const handleRemoveFromSuite = async (packId: string) => {
    try {
      setActionLoading(true);
      await updateEmojiPack(packId, {
        parent_id: undefined,
      });
      Message.success('移除成功');
      if (currentSuite.value) {
        await fetchSuitePacks(currentSuite.value.id);
      }
      await fetchPacks();
    } catch (error: any) {
      Message.error(error?.response?.data?.message || '移除失败');
    } finally {
      setActionLoading(false);
    }
  };

  const handleSuitePackModalCancel = () => {
    currentSuite.value = null;
    currentSuitePacks.value = [];
  };

  const handleRefresh = () => {
    fetchPacks();
  };

  // 触发图标文件选择
  const triggerIconFileSelect = () => {
    iconFileInputRef.value?.click();
  };

  // 处理图标文件选择
  const handleIconFileChange = async (event: Event) => {
    const inputEl = event.target as HTMLInputElement;
    const { files } = inputEl;
    const file = files && files.length > 0 ? files[0] : null;
    if (!file) {
      return;
    }

    // 验证文件类型
    if (!file.type.startsWith('image/')) {
      Message.error('请选择图片文件');
      inputEl.value = '';
      return;
    }

    // 验证文件大小（最大 2MB）
    const maxSize = 2 * 1024 * 1024;
    if (file.size > maxSize) {
      Message.error('图片大小不能超过 2MB');
      inputEl.value = '';
      return;
    }

    iconUploadLoading.value = true;
    try {
      // 获取默认存储提供商
      if (!defaultStorageProvider.value) {
        const { data } = await getDefaultStorageProvider();
        defaultStorageProvider.value = data;
      }

      if (!defaultStorageProvider.value) {
        throw new Error('未配置存储提供商，请先在存储提供商设置中配置');
      }

      // 生成文件key
      const timestamp = Date.now();
      const fileExt = file.name.split('.').pop() || 'jpg';
      const key = `emoji-packs/icons/${timestamp}.${fileExt}`;

      // 计算文件哈希
      let hashValue: string | undefined;
      let hashAlg: number | undefined;
      try {
        const hash = await computeFileHash(file);
        if (hash.hashValue) {
          hashValue = hash.hashValue;
          hashAlg = hash.hashAlg ?? 2;
        }
      } catch (error) {
        console.warn('[EmojiPack] 计算图标哈希失败，将跳过哈希上报', error);
      }

      // 获取上传签名
      const { data: signatureData } = await testCosUploadSignature({
        provider_id: defaultStorageProvider.value.id,
        key,
        content_type: file.type,
        file_size: file.size,
        hash_value: hashValue,
        hash_alg: hashAlg,
      });

      if (!signatureData.success) {
        throw new Error(signatureData.message || '获取上传签名失败');
      }

      // 命中哈希去重：无需上传
      if (!signatureData.signature) {
        Message.success(
          signatureData.message || '复用已上传的图标，无需重新上传'
        );
      } else {
        // 上传文件
        const response = await uploadWithSignature(
          file,
          signatureData.signature
        );
        if (!response.ok) {
          const text = await response.text();
          throw new Error(text || '上传失败');
        }
      }

      // 获取下载URL
      const { data: urlData } = await testCosDownloadUrl({
        provider_id: defaultStorageProvider.value.id,
        key,
        expires_in_seconds: 31536000, // 1年
      });

      if (!urlData.success || !urlData.url) {
        throw new Error(urlData.message || '获取下载URL失败');
      }

      // 保存URL到表单
      packFormData.icon_url = urlData.url;
      // 同步保存对象键，供前端通过 object_key 获取临时下载地址
      packFormData.icon_object_key = key;
      Message.success('图标上传成功');
    } catch (error: any) {
      const errorMsg =
        error?.message || error?.response?.data?.message || '上传失败';
      Message.error(errorMsg);
    } finally {
      iconUploadLoading.value = false;
      if (inputEl) {
        inputEl.value = '';
      }
    }
  };

  // 触发表情项图片文件选择
  const triggerItemImageFileSelect = () => {
    itemImageFileInputRef.value?.click();
  };

  // 处理表情项图片文件选择
  const handleItemImageFileChange = async (event: Event) => {
    const inputEl = event.target as HTMLInputElement;
    const { files } = inputEl;
    const file = files && files.length > 0 ? files[0] : null;
    if (!file) {
      return;
    }

    // 验证文件类型
    if (!file.type.startsWith('image/')) {
      Message.error('请选择图片文件');
      inputEl.value = '';
      return;
    }

    // 验证文件大小（最大 5MB，GIF 可能较大）
    const maxSize = 5 * 1024 * 1024;
    if (file.size > maxSize) {
      Message.error('图片大小不能超过 5MB');
      inputEl.value = '';
      return;
    }

    itemImageUploadLoading.value = true;
    try {
      // 获取默认存储提供商
      if (!defaultStorageProvider.value) {
        const { data } = await getDefaultStorageProvider();
        defaultStorageProvider.value = data;
      }

      if (!defaultStorageProvider.value) {
        throw new Error('未配置存储提供商，请先在存储提供商设置中配置');
      }

      // 生成文件key
      const timestamp = Date.now();
      const fileExt = file.name.split('.').pop() || 'jpg';
      const key = `emoji-items/${timestamp}.${fileExt}`;

      // 计算文件哈希
      let hashValue: string | undefined;
      let hashAlg: number | undefined;
      try {
        const hash = await computeFileHash(file);
        if (hash.hashValue) {
          hashValue = hash.hashValue;
          hashAlg = hash.hashAlg ?? 2;
        }
      } catch (error) {
        console.warn(
          '[EmojiPack] 计算表情项图片哈希失败，将跳过哈希上报',
          error
        );
      }

      // 获取上传签名
      const { data: signatureData } = await testCosUploadSignature({
        provider_id: defaultStorageProvider.value.id,
        key,
        content_type: file.type,
        file_size: file.size,
        hash_value: hashValue,
        hash_alg: hashAlg,
      });

      if (!signatureData.success) {
        throw new Error(signatureData.message || '获取上传签名失败');
      }

      // 命中哈希去重：无需上传
      if (!signatureData.signature) {
        Message.success(
          signatureData.message || '复用已上传的图片，无需重新上传'
        );
      } else {
        // 上传文件
        const response = await uploadWithSignature(
          file,
          signatureData.signature
        );
        if (!response.ok) {
          const text = await response.text();
          throw new Error(text || '上传失败');
        }
      }

      // 获取下载URL
      const { data: urlData } = await testCosDownloadUrl({
        provider_id: defaultStorageProvider.value.id,
        key,
        expires_in_seconds: 31536000, // 1年
      });

      if (!urlData.success || !urlData.url) {
        throw new Error(urlData.message || '获取下载URL失败');
      }

      // 保存URL到表单
      itemFormData.image_url = urlData.url;
      // 同步保存对象键
      itemFormData.image_object_key = key;
      Message.success('图片上传成功');
    } catch (error: any) {
      const errorMsg =
        error?.message || error?.response?.data?.message || '上传失败';
      Message.error(errorMsg);
    } finally {
      itemImageUploadLoading.value = false;
      if (inputEl) {
        inputEl.value = '';
      }
    }
  };

  onMounted(async () => {
    fetchPacks();
    // 预加载默认存储提供商
    try {
      const { data } = await getDefaultStorageProvider();
      defaultStorageProvider.value = data;
    } catch (error) {
      // 忽略错误，上传时会再次尝试获取
    }
  });
</script>

<style lang="less" scoped>
  .emoji-pack-settings-container {
    padding: 0 20px 20px;
  }

  .actions {
    margin-bottom: 16px;
  }

  .pack-icon {
    width: 40px;
    height: 40px;
    object-fit: contain;
    border-radius: 4px;
  }

  .pack-icon-placeholder {
    display: inline-block;
    width: 40px;
    height: 40px;
    color: #999;
    font-size: 12px;
    line-height: 40px;
    text-align: center;
    background: #f5f5f5;
    border-radius: 4px;
  }

  .item-management {
    .item-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 16px;

      h3 {
        margin: 0;
      }
    }
  }

  .suite-management {
    .item-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-top: 0;
      margin-bottom: 16px;

      h3 {
        margin: 0;
        font-weight: 500;
        font-size: 16px;
      }
    }

    .suite-pack-table {
      margin-top: 16px;
    }
  }

  .emoji-image {
    width: 40px;
    height: 40px;
    object-fit: contain;
    border-radius: 4px;
  }

  .icon-upload-wrapper {
    width: 100%;
  }

  .icon-preview {
    display: flex;
    gap: 12px;
    align-items: center;
    padding: 12px;
    background: #fafafa;
    border: 1px solid #e5e5e5;
    border-radius: 6px;
  }

  .preview-image {
    width: 64px;
    height: 64px;
    object-fit: cover;
    border: 1px solid #e5e5e5;
    border-radius: 4px;
  }

  .icon-upload-area {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .upload-hint {
    color: #86909c;
    font-size: 12px;
  }

  .item-image-upload-wrapper {
    width: 100%;
  }

  .item-image-preview {
    display: flex;
    gap: 12px;
    align-items: center;
    padding: 12px;
    background: #fafafa;
    border: 1px solid #e5e5e5;
    border-radius: 6px;
  }

  .item-image-upload-area {
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
</style>
