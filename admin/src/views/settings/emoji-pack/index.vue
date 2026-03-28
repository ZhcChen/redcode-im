<template>
  <div class="emoji-pack-settings-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.emojiPack']" />
    <a-card
      class="general-card"
      :title="t('emojiPack.title')"
      :bordered="false"
    >
      <div class="actions">
        <a-space>
          <a-input-search
            v-model="searchKeyword"
            :placeholder="t('emojiPack.search.placeholder')"
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
            {{ t('emojiPack.action.createPack') }}
          </a-button>
          <a-button :loading="listLoading" @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
            {{ t('emojiPack.action.refresh') }}
          </a-button>
        </a-space>
      </div>

      <a-table
        :columns="packColumns"
        :data="packs"
        :loading="listLoading"
        :pagination="false"
        :scroll="{ x: 'max-content' }"
        :row-key="'id'"
        class="pack-table"
      >
        <template #icon_url="{ record }">
          <CosImage
            :object-key="record.icon_object_key"
            :initial-url="record.icon_url"
            :provider-id="defaultStorageProvider?.id"
            :alt="t('emojiPack.imageAlt.packIcon')"
            class="pack-icon"
          >
            <template #fallback>
              <span class="pack-icon-placeholder">
                {{ t('emojiPack.empty.noIcon') }}
              </span>
            </template>
          </CosImage>
        </template>

        <template #pack_type="{ record }">
          <a-tag
            :color="record.pack_type === PACK_TYPE_SUITE ? 'blue' : 'gray'"
          >
            {{ getPackTypeLabel(record.pack_type) }}
          </a-tag>
        </template>

        <template #is_active="{ record }">
          <a-tag :color="record.is_active ? 'green' : 'gray'">
            {{ getStatusLabel(record.is_active) }}
          </a-tag>
        </template>

        <template #operations="{ record }">
          <a-space size="mini">
            <a-button
              v-if="record.pack_type === PACK_TYPE_SINGLE"
              type="text"
              size="small"
              @click="handleManageItems(record)"
            >
              {{ t('emojiPack.action.manageItems') }}
            </a-button>
            <a-button
              v-if="record.pack_type === PACK_TYPE_SUITE"
              type="text"
              size="small"
              @click="handleManageSuitePacks(record)"
            >
              {{ t('emojiPack.action.manageSuitePacks') }}
            </a-button>
            <a-button type="text" size="small" @click="handleEditPack(record)">
              {{ t('emojiPack.action.edit') }}
            </a-button>
            <a-popconfirm
              :content="t('emojiPack.confirm.deletePack')"
              @ok="handleDeletePack(record.id)"
            >
              <a-button type="text" size="small" status="danger">
                {{ t('emojiPack.action.delete') }}
              </a-button>
            </a-popconfirm>
          </a-space>
        </template>
      </a-table>

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
          <a-form-item
            field="name"
            :label="t('emojiPack.form.pack.name.label')"
          >
            <a-input
              v-model="packFormData.name"
              :placeholder="t('emojiPack.form.pack.name.placeholder')"
            />
          </a-form-item>

          <a-form-item
            field="icon_url"
            :label="t('emojiPack.form.pack.icon.label')"
          >
            <div class="icon-upload-wrapper">
              <div v-if="packFormData.icon_url" class="icon-preview">
                <CosImage
                  :object-key="packFormData.icon_object_key"
                  :initial-url="packFormData.icon_url"
                  :provider-id="defaultStorageProvider?.id"
                  :alt="t('emojiPack.imageAlt.iconPreview')"
                  class="preview-image"
                />
                <a-button
                  type="text"
                  status="danger"
                  size="small"
                  @click="
                    packFormData.icon_url = '';
                    packFormData.icon_object_key = '';
                  "
                >
                  {{ t('emojiPack.action.delete') }}
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
                  {{ t('emojiPack.action.uploadIcon') }}
                </a-button>
                <span class="upload-hint">
                  {{ t('emojiPack.form.pack.icon.uploadHint') }}
                </span>
              </div>
            </div>
            <template #help>
              {{ t('emojiPack.form.pack.icon.help') }}
            </template>
          </a-form-item>

          <a-form-item
            field="description"
            :label="t('emojiPack.form.pack.description.label')"
          >
            <a-textarea
              v-model="packFormData.description"
              :placeholder="t('emojiPack.form.pack.description.placeholder')"
              :auto-size="{ minRows: 2, maxRows: 4 }"
            />
          </a-form-item>

          <a-form-item
            field="pack_type"
            :label="t('emojiPack.form.pack.type.label')"
          >
            <a-radio-group v-model="packFormData.pack_type">
              <a-radio :value="PACK_TYPE_SINGLE">
                {{ t('emojiPack.packType.single') }}
              </a-radio>
              <a-radio :value="PACK_TYPE_SUITE">
                {{ t('emojiPack.packType.suite') }}
              </a-radio>
            </a-radio-group>
            <template #help>
              {{ t('emojiPack.form.pack.type.help') }}
            </template>
          </a-form-item>

          <a-form-item
            v-if="packFormData.pack_type === PACK_TYPE_SINGLE"
            field="parent_id"
            :label="t('emojiPack.form.pack.parent.label')"
          >
            <a-select
              v-model="packFormData.parent_id"
              :placeholder="t('emojiPack.form.pack.parent.placeholder')"
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
            <template #help>
              {{ t('emojiPack.form.pack.parent.help') }}
            </template>
          </a-form-item>

          <a-form-item
            field="is_active"
            :label="t('emojiPack.form.pack.isActive.label')"
          >
            <a-switch v-model="packFormData.is_active" />
            <template #help>
              {{ t('emojiPack.form.pack.isActive.help') }}
            </template>
          </a-form-item>
        </a-form>
      </a-modal>

      <a-modal
        v-model:visible="suitePackModalVisible"
        :title="t('emojiPack.modal.manageSuitePacks')"
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
              {{ t('emojiPack.action.createSuitePack') }}
            </a-button>
          </div>

          <a-table
            :columns="suitePackColumns"
            :data="currentSuitePacks"
            :loading="suitePackLoading"
            :pagination="false"
            :row-key="'id'"
            class="suite-pack-table"
          >
            <template #icon_url="{ record }">
              <CosImage
                :object-key="record.icon_object_key"
                :initial-url="record.icon_url"
                :provider-id="defaultStorageProvider?.id"
                :alt="t('emojiPack.imageAlt.packIcon')"
                class="pack-icon"
              >
                <template #fallback>
                  <span class="pack-icon-placeholder">
                    {{ t('emojiPack.empty.noIcon') }}
                  </span>
                </template>
              </CosImage>
            </template>

            <template #is_active="{ record }">
              <a-tag :color="record.is_active ? 'green' : 'gray'">
                {{ getStatusLabel(record.is_active) }}
              </a-tag>
            </template>

            <template #operations="{ record }">
              <a-space size="mini">
                <a-button
                  type="text"
                  size="small"
                  @click="handleManageItems(record)"
                >
                  {{ t('emojiPack.action.manageItems') }}
                </a-button>
                <a-button
                  type="text"
                  size="small"
                  @click="handleEditPack(record)"
                >
                  {{ t('emojiPack.action.edit') }}
                </a-button>
                <a-popconfirm
                  :content="t('emojiPack.confirm.removeFromSuite')"
                  @ok="handleRemoveFromSuite(record.id)"
                >
                  <a-button type="text" size="small" status="danger">
                    {{ t('emojiPack.action.remove') }}
                  </a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </a-table>
        </div>
      </a-modal>

      <a-modal
        v-model:visible="itemModalVisible"
        :title="t('emojiPack.modal.manageItems')"
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
              {{ t('emojiPack.action.createItem') }}
            </a-button>
          </div>

          <a-table
            :columns="itemColumns"
            :data="currentPackItems"
            :loading="itemLoading"
            :pagination="false"
            :row-key="'id'"
            class="item-table"
          >
            <template #image_url="{ record }">
              <CosImage
                :object-key="record.image_object_key"
                :initial-url="record.image_url"
                :provider-id="defaultStorageProvider?.id"
                :alt="t('emojiPack.imageAlt.itemImage')"
                class="emoji-image"
              />
            </template>

            <template #operations="{ record }">
              <a-space size="mini">
                <a-button
                  type="text"
                  size="small"
                  @click="handleEditItem(record)"
                >
                  {{ t('emojiPack.action.edit') }}
                </a-button>
                <a-popconfirm
                  :content="t('emojiPack.confirm.deleteItem')"
                  @ok="handleDeleteItem(record.id)"
                >
                  <a-button type="text" size="small" status="danger">
                    {{ t('emojiPack.action.delete') }}
                  </a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </a-table>
        </div>

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
            <a-form-item
              field="image_url"
              :label="t('emojiPack.form.item.image.label')"
            >
              <div class="item-image-upload-wrapper">
                <div v-if="itemFormData.image_url" class="item-image-preview">
                  <CosImage
                    :object-key="itemFormData.image_object_key"
                    :initial-url="itemFormData.image_url"
                    :provider-id="defaultStorageProvider?.id"
                    :alt="t('emojiPack.imageAlt.itemPreview')"
                    class="preview-image"
                  />
                  <a-button
                    type="text"
                    status="danger"
                    size="small"
                    @click="
                      itemFormData.image_url = '';
                      itemFormData.image_object_key = '';
                    "
                  >
                    {{ t('emojiPack.action.delete') }}
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
                    {{ t('emojiPack.action.uploadImage') }}
                  </a-button>
                  <span class="upload-hint">
                    {{ t('emojiPack.form.item.image.uploadHint') }}
                  </span>
                </div>
              </div>
              <template #help>
                {{ t('emojiPack.form.item.image.help') }}
              </template>
            </a-form-item>

            <a-form-item
              field="name"
              :label="t('emojiPack.form.item.name.label')"
            >
              <a-input
                v-model="itemFormData.name"
                :placeholder="t('emojiPack.form.item.name.placeholder')"
              />
            </a-form-item>

            <a-form-item
              field="sort_order"
              :label="t('emojiPack.form.item.sortOrder.label')"
            >
              <a-input-number
                v-model="itemFormData.sort_order"
                :min="0"
                :placeholder="t('emojiPack.form.item.sortOrder.placeholder')"
              />
              <template #help>
                {{ t('emojiPack.form.item.sortOrder.help') }}
              </template>
            </a-form-item>
          </a-form>
        </a-modal>
      </a-modal>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { computed, onMounted, reactive, ref } from 'vue';
  import { Message, type FormInstance } from '@arco-design/web-vue';
  import { useI18n } from 'vue-i18n';
  import CosImage from '@/components/cos-image/index.vue';
  import useLoading from '@/hooks/loading';
  import {
    createEmojiItem,
    createEmojiPack,
    deleteEmojiItem,
    deleteEmojiPack,
    getEmojiPack,
    getSuitePacks,
    listAllEmojiPacks,
    updateEmojiItem,
    updateEmojiPack,
    type EmojiItem,
    type EmojiPack,
  } from '@/api/emoji-pack';
  import {
    getDefaultStorageProvider,
    testCosDownloadUrl,
    testCosUploadSignature,
    type StorageProvider,
  } from '@/api/settings';
  import { uploadWithSignature } from '@/utils/direct-upload';
  import { computeFileHash } from '@/utils/fileHash';
  import { resolveHttpErrorMessage } from '@/utils/i18n';

  const { t } = useI18n();

  const PACK_TYPE_SINGLE = 0;
  const PACK_TYPE_SUITE = 1;
  const MAX_ICON_SIZE = 2 * 1024 * 1024;
  const MAX_ITEM_IMAGE_SIZE = 5 * 1024 * 1024;

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
  const packModalMode = ref<'create' | 'edit' | 'addToSuite'>('create');
  const packFormRef = ref<FormInstance>();
  const packFormData = reactive({
    name: '',
    icon_url: '',
    icon_object_key: '',
    description: '',
    is_active: true,
    pack_type: PACK_TYPE_SINGLE,
    parent_id: undefined as string | undefined,
  });
  const editingPackId = ref<string | null>(null);

  const currentSuite = ref<EmojiPack | null>(null);
  const currentSuitePacks = ref<EmojiPack[]>([]);
  const suitePackModalVisible = ref(false);
  const suitePackLoading = ref(false);

  const currentPack = ref<EmojiPack | null>(null);
  const currentPackItems = ref<EmojiItem[]>([]);
  const itemModalVisible = ref(false);
  const itemFormModalVisible = ref(false);
  const itemModalMode = ref<'create' | 'edit'>('create');
  const itemFormRef = ref<FormInstance>();
  const itemFormData = reactive({
    image_url: '',
    image_object_key: '',
    name: '',
    sort_order: 0,
  });
  const editingItemId = ref<string | null>(null);

  const iconFileInputRef = ref<HTMLInputElement | null>(null);
  const iconUploadLoading = ref(false);
  const defaultStorageProvider = ref<StorageProvider | null>(null);

  const itemImageFileInputRef = ref<HTMLInputElement | null>(null);
  const itemImageUploadLoading = ref(false);

  const suites = computed(() =>
    packs.value.filter(
      (pack) => pack.pack_type === PACK_TYPE_SUITE && !pack.parent_id,
    ),
  );

  const packModalTitle = computed(() => {
    if (packModalMode.value === 'edit') {
      return t('emojiPack.modal.packEdit');
    }

    if (packModalMode.value === 'addToSuite') {
      return t('emojiPack.modal.packCreateInSuite');
    }

    return t('emojiPack.modal.packCreate');
  });

  const packFormRules = computed(() => ({
    name: [
      {
        required: true,
        message: t('emojiPack.validation.packName.required'),
      },
    ],
  }));

  const packColumns = computed(() => [
    {
      title: t('emojiPack.table.pack.icon'),
      dataIndex: 'icon_url',
      slotName: 'icon_url',
      width: 80,
    },
    {
      title: t('emojiPack.table.pack.name'),
      dataIndex: 'name',
      width: 200,
    },
    {
      title: t('emojiPack.table.pack.type'),
      dataIndex: 'pack_type',
      slotName: 'pack_type',
      width: 100,
    },
    {
      title: t('emojiPack.table.pack.description'),
      dataIndex: 'description',
      ellipsis: true,
    },
    {
      title: t('emojiPack.table.pack.status'),
      dataIndex: 'is_active',
      slotName: 'is_active',
      width: 100,
    },
    {
      title: t('emojiPack.table.pack.createdAt'),
      dataIndex: 'created_at',
      width: 180,
    },
    {
      title: t('emojiPack.table.pack.actions'),
      slotName: 'operations',
      width: 280,
      fixed: 'right' as const,
    },
  ]);

  const suitePackColumns = computed(() => [
    {
      title: t('emojiPack.table.suite.icon'),
      dataIndex: 'icon_url',
      slotName: 'icon_url',
      width: 80,
    },
    {
      title: t('emojiPack.table.suite.name'),
      dataIndex: 'name',
      width: 200,
    },
    {
      title: t('emojiPack.table.suite.description'),
      dataIndex: 'description',
      ellipsis: true,
    },
    {
      title: t('emojiPack.table.suite.status'),
      dataIndex: 'is_active',
      slotName: 'is_active',
      width: 100,
    },
    {
      title: t('emojiPack.table.suite.actions'),
      slotName: 'operations',
      width: 250,
      fixed: 'right' as const,
    },
  ]);

  const itemModalTitle = computed(() =>
    itemModalMode.value === 'edit'
      ? t('emojiPack.modal.itemEdit')
      : t('emojiPack.modal.itemCreate'),
  );

  const itemFormRules = computed(() => ({
    image_url: [
      {
        required: true,
        message: t('emojiPack.validation.itemImage.required'),
      },
    ],
  }));

  const itemColumns = computed(() => [
    {
      title: t('emojiPack.table.item.image'),
      dataIndex: 'image_url',
      slotName: 'image_url',
      width: 80,
    },
    {
      title: t('emojiPack.table.item.name'),
      dataIndex: 'name',
      width: 150,
    },
    {
      title: t('emojiPack.table.item.sortOrder'),
      dataIndex: 'sort_order',
      width: 100,
    },
    {
      title: t('emojiPack.table.item.actions'),
      slotName: 'operations',
      width: 150,
      fixed: 'right' as const,
    },
  ]);

  const getPackTypeLabel = (packType: number) =>
    packType === PACK_TYPE_SUITE
      ? t('emojiPack.packType.suite')
      : t('emojiPack.packType.single');

  const getStatusLabel = (isActive: boolean) =>
    isActive ? t('emojiPack.status.active') : t('emojiPack.status.inactive');

  const resolveLocalizableError = (error: any, fallbackKey: string) => {
    if (!error?.response) {
      const directMessage =
        typeof error?.message === 'string' ? error.message.trim() : '';
      if (directMessage) {
        return directMessage;
      }
    }

    return resolveHttpErrorMessage(error, {
      fallbackKey,
      fallbackMessage: t(fallbackKey),
    });
  };

  const fetchPacks = async (keyword?: string) => {
    try {
      setListLoading(true);
      const { data } = await listAllEmojiPacks(keyword);
      packs.value = data.filter((pack) => !pack.parent_id);
    } catch (error: any) {
      Message.error(
        resolveLocalizableError(error, 'emojiPack.error.fetchPacks'),
      );
    } finally {
      setListLoading(false);
    }
  };

  const handleSearch = (value: string) => {
    fetchPacks(value);
  };

  const handleSearchClear = () => {
    searchKeyword.value = '';
    fetchPacks();
  };

  const resetPackForm = () => {
    packFormData.name = '';
    packFormData.icon_url = '';
    packFormData.icon_object_key = '';
    packFormData.description = '';
    packFormData.is_active = true;
    packFormData.pack_type = PACK_TYPE_SINGLE;
    packFormData.parent_id = undefined;
  };

  const handleCreatePack = () => {
    editingPackId.value = null;
    packModalMode.value = 'create';
    resetPackForm();
    packModalVisible.value = true;
  };

  const handleEditPack = (pack: EmojiPack) => {
    editingPackId.value = pack.id;
    packModalMode.value = 'edit';
    packFormData.name = pack.name;
    packFormData.icon_url = pack.icon_url || '';
    packFormData.icon_object_key = pack.icon_object_key || '';
    packFormData.description = pack.description || '';
    packFormData.is_active = pack.is_active;
    packFormData.pack_type = pack.pack_type;
    packFormData.parent_id = pack.parent_id || undefined;
    packModalVisible.value = true;
  };

  const handleDeletePack = async (packId: string) => {
    try {
      setActionLoading(true);
      await deleteEmojiPack(packId);
      Message.success(t('emojiPack.success.packDelete'));
      await fetchPacks();
    } catch (error: any) {
      Message.error(
        resolveLocalizableError(error, 'emojiPack.error.deletePack'),
      );
    } finally {
      setActionLoading(false);
    }
  };

  const fetchSuitePacks = async (suiteId: string) => {
    try {
      suitePackLoading.value = true;
      const { data } = await getSuitePacks(suiteId);
      currentSuitePacks.value = data;
    } catch (error: any) {
      Message.error(
        resolveLocalizableError(error, 'emojiPack.error.fetchSuitePacks'),
      );
    } finally {
      suitePackLoading.value = false;
    }
  };

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
    } catch {
      done(false);
      return;
    }

    try {
      setActionLoading(true);
      const payload = {
        name: packFormData.name,
        icon_url: packFormData.icon_url || undefined,
        icon_object_key: packFormData.icon_object_key || undefined,
        description: packFormData.description || undefined,
        is_active: packFormData.is_active,
        pack_type: packFormData.pack_type,
        parent_id: packFormData.parent_id,
      };

      if (editingPackId.value) {
        await updateEmojiPack(editingPackId.value, payload);
        Message.success(t('emojiPack.success.packUpdate'));
      } else {
        await createEmojiPack(payload);
        Message.success(t('emojiPack.success.packCreate'));
      }

      await fetchPacks();
      if (
        packFormData.parent_id &&
        currentSuite.value?.id === packFormData.parent_id
      ) {
        await fetchSuitePacks(packFormData.parent_id);
      }

      packModalVisible.value = false;
      done(true);
    } catch (error: any) {
      Message.error(
        resolveLocalizableError(error, 'emojiPack.error.packSubmit'),
      );
      done(false);
    } finally {
      setActionLoading(false);
    }
  };

  const handlePackCancel = () => {
    packFormRef.value?.resetFields();
  };

  const fetchPackItems = async (packId: string) => {
    try {
      setItemLoading(true);
      const { data } = await getEmojiPack(packId);
      currentPackItems.value = data.items || [];
    } catch (error: any) {
      Message.error(
        resolveLocalizableError(error, 'emojiPack.error.fetchItems'),
      );
    } finally {
      setItemLoading(false);
    }
  };

  const handleManageItems = async (pack: EmojiPack) => {
    currentPack.value = pack;
    itemModalVisible.value = true;
    await fetchPackItems(pack.id);
  };

  const handleCreateItem = () => {
    editingItemId.value = null;
    itemModalMode.value = 'create';
    itemFormData.image_url = '';
    itemFormData.image_object_key = '';
    itemFormData.name = '';
    itemFormData.sort_order = 0;
    itemFormModalVisible.value = true;
  };

  const handleEditItem = (item: EmojiItem) => {
    editingItemId.value = item.id;
    itemModalMode.value = 'edit';
    itemFormData.image_url = item.image_url;
    itemFormData.image_object_key = item.image_object_key || '';
    itemFormData.name = item.name || '';
    itemFormData.sort_order = item.sort_order;
    itemFormModalVisible.value = true;
  };

  const handleDeleteItem = async (itemId: string) => {
    try {
      setItemActionLoading(true);
      await deleteEmojiItem(itemId);
      Message.success(t('emojiPack.success.itemDelete'));
      if (currentPack.value) {
        await fetchPackItems(currentPack.value.id);
      }
    } catch (error: any) {
      Message.error(
        resolveLocalizableError(error, 'emojiPack.error.deleteItem'),
      );
    } finally {
      setItemActionLoading(false);
    }
  };

  const handleItemBeforeOk = async () => {
    const valid = await itemFormRef.value?.validate();
    if (!valid) {
      return false;
    }

    if (!currentPack.value) {
      Message.error(t('emojiPack.error.selectPackFirst'));
      return false;
    }

    try {
      setItemActionLoading(true);
      const payload = {
        image_url: itemFormData.image_url,
        image_object_key: itemFormData.image_object_key || undefined,
        name: itemFormData.name || undefined,
        sort_order: itemFormData.sort_order,
      };

      if (editingItemId.value) {
        await updateEmojiItem(editingItemId.value, payload);
        Message.success(t('emojiPack.success.itemUpdate'));
      } else {
        await createEmojiItem({
          pack_id: currentPack.value.id,
          ...payload,
        });
        Message.success(t('emojiPack.success.itemCreate'));
      }

      itemFormModalVisible.value = false;
      await fetchPackItems(currentPack.value.id);
      return true;
    } catch (error: any) {
      Message.error(
        resolveLocalizableError(error, 'emojiPack.error.itemSubmit'),
      );
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

  const handleManageSuitePacks = async (suite: EmojiPack) => {
    currentSuite.value = suite;
    suitePackModalVisible.value = true;
    await fetchSuitePacks(suite.id);
  };

  const handleCreateSuitePack = () => {
    if (!currentSuite.value) {
      return;
    }

    editingPackId.value = null;
    packModalMode.value = 'addToSuite';
    resetPackForm();
    packFormData.parent_id = currentSuite.value.id;
    packModalVisible.value = true;
  };

  const handleRemoveFromSuite = async (packId: string) => {
    try {
      setActionLoading(true);
      await updateEmojiPack(packId, { parent_id: undefined });
      Message.success(t('emojiPack.success.removeFromSuite'));
      if (currentSuite.value) {
        await fetchSuitePacks(currentSuite.value.id);
      }
      await fetchPacks();
    } catch (error: any) {
      Message.error(
        resolveLocalizableError(error, 'emojiPack.error.removeFromSuite'),
      );
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

  const triggerIconFileSelect = () => {
    iconFileInputRef.value?.click();
  };

  const handleIconFileChange = async (event: Event) => {
    const inputEl = event.target as HTMLInputElement;
    const file =
      inputEl.files && inputEl.files.length > 0 ? inputEl.files[0] : null;
    if (!file) {
      return;
    }

    if (!file.type.startsWith('image/')) {
      Message.error(t('emojiPack.error.invalidImageFile'));
      inputEl.value = '';
      return;
    }

    if (file.size > MAX_ICON_SIZE) {
      Message.error(t('emojiPack.error.iconTooLarge'));
      inputEl.value = '';
      return;
    }

    iconUploadLoading.value = true;
    try {
      if (!defaultStorageProvider.value) {
        const { data } = await getDefaultStorageProvider();
        defaultStorageProvider.value = data;
      }

      if (!defaultStorageProvider.value) {
        throw new Error(t('emojiPack.error.storageProviderRequired'));
      }

      const timestamp = Date.now();
      const fileExt = file.name.split('.').pop() || 'jpg';
      const key = `emoji-packs/icons/${timestamp}.${fileExt}`;

      let hashValue: string | undefined;
      let hashAlg: number | undefined;
      try {
        const hash = await computeFileHash(file);
        if (hash.hashValue) {
          hashValue = hash.hashValue;
          hashAlg = hash.hashAlg ?? 2;
        }
      } catch (error) {
        console.warn('[EmojiPack] Icon hash reporting skipped', error);
      }

      const { data: signatureData } = await testCosUploadSignature({
        provider_id: defaultStorageProvider.value.id,
        key,
        content_type: file.type,
        file_size: file.size,
        hash_value: hashValue,
        hash_alg: hashAlg,
      });

      if (!signatureData.success) {
        throw new Error(
          signatureData.message || t('emojiPack.error.uploadSignature'),
        );
      }

      if (!signatureData.signature) {
        Message.success(
          signatureData.message || t('emojiPack.success.iconUploadReused'),
        );
      } else {
        const response = await uploadWithSignature(
          file,
          signatureData.signature,
        );
        if (!response.ok) {
          const text = await response.text();
          throw new Error(text || t('emojiPack.error.upload'));
        }
      }

      const { data: urlData } = await testCosDownloadUrl({
        provider_id: defaultStorageProvider.value.id,
        key,
        expires_in_seconds: 31536000,
      });

      if (!urlData.success || !urlData.url) {
        throw new Error(urlData.message || t('emojiPack.error.downloadUrl'));
      }

      packFormData.icon_url = urlData.url;
      packFormData.icon_object_key = key;
      Message.success(t('emojiPack.success.iconUpload'));
    } catch (error: any) {
      Message.error(resolveLocalizableError(error, 'emojiPack.error.upload'));
    } finally {
      iconUploadLoading.value = false;
      inputEl.value = '';
    }
  };

  const triggerItemImageFileSelect = () => {
    itemImageFileInputRef.value?.click();
  };

  const handleItemImageFileChange = async (event: Event) => {
    const inputEl = event.target as HTMLInputElement;
    const file =
      inputEl.files && inputEl.files.length > 0 ? inputEl.files[0] : null;
    if (!file) {
      return;
    }

    if (!file.type.startsWith('image/')) {
      Message.error(t('emojiPack.error.invalidImageFile'));
      inputEl.value = '';
      return;
    }

    if (file.size > MAX_ITEM_IMAGE_SIZE) {
      Message.error(t('emojiPack.error.itemImageTooLarge'));
      inputEl.value = '';
      return;
    }

    itemImageUploadLoading.value = true;
    try {
      if (!defaultStorageProvider.value) {
        const { data } = await getDefaultStorageProvider();
        defaultStorageProvider.value = data;
      }

      if (!defaultStorageProvider.value) {
        throw new Error(t('emojiPack.error.storageProviderRequired'));
      }

      const timestamp = Date.now();
      const fileExt = file.name.split('.').pop() || 'jpg';
      const key = `emoji-items/${timestamp}.${fileExt}`;

      let hashValue: string | undefined;
      let hashAlg: number | undefined;
      try {
        const hash = await computeFileHash(file);
        if (hash.hashValue) {
          hashValue = hash.hashValue;
          hashAlg = hash.hashAlg ?? 2;
        }
      } catch (error) {
        console.warn('[EmojiPack] Item image hash reporting skipped', error);
      }

      const { data: signatureData } = await testCosUploadSignature({
        provider_id: defaultStorageProvider.value.id,
        key,
        content_type: file.type,
        file_size: file.size,
        hash_value: hashValue,
        hash_alg: hashAlg,
      });

      if (!signatureData.success) {
        throw new Error(
          signatureData.message || t('emojiPack.error.uploadSignature'),
        );
      }

      if (!signatureData.signature) {
        Message.success(
          signatureData.message || t('emojiPack.success.itemUploadReused'),
        );
      } else {
        const response = await uploadWithSignature(
          file,
          signatureData.signature,
        );
        if (!response.ok) {
          const text = await response.text();
          throw new Error(text || t('emojiPack.error.upload'));
        }
      }

      const { data: urlData } = await testCosDownloadUrl({
        provider_id: defaultStorageProvider.value.id,
        key,
        expires_in_seconds: 31536000,
      });

      if (!urlData.success || !urlData.url) {
        throw new Error(urlData.message || t('emojiPack.error.downloadUrl'));
      }

      itemFormData.image_url = urlData.url;
      itemFormData.image_object_key = key;
      Message.success(t('emojiPack.success.itemUpload'));
    } catch (error: any) {
      Message.error(resolveLocalizableError(error, 'emojiPack.error.upload'));
    } finally {
      itemImageUploadLoading.value = false;
      inputEl.value = '';
    }
  };

  onMounted(async () => {
    fetchPacks();

    try {
      const { data } = await getDefaultStorageProvider();
      defaultStorageProvider.value = data;
    } catch {
      // Ignore here and retry on upload.
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
