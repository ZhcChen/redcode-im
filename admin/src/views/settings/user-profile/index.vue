<template>
  <div class="user-profile-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.userProfile']" />
    <a-card
      class="general-card"
      :title="t('userProfile.title')"
      :bordered="false"
    >
      <a-space direction="vertical" :size="24" style="width: 100%">
        <a-card :title="t('userProfile.section.avatar')" size="small">
          <a-space :size="24" align="start">
            <div class="avatar-section">
              <a-avatar :size="100" shape="circle" class="user-avatar">
                <img v-if="avatarPreview" :src="avatarPreview" alt="avatar" />
                <icon-user v-else class="avatar-icon" />
              </a-avatar>
              <a-button
                class="upload-btn"
                type="primary"
                :loading="avatarUploading"
                @click="triggerAvatarSelect"
              >
                {{ t('userProfile.avatar.change') }}
              </a-button>
              <input
                ref="avatarInputRef"
                type="file"
                accept="image/*"
                style="display: none"
                @change="handleAvatarChange"
              />
            </div>
            <div class="avatar-tips">
              <a-typography-text type="secondary">
                {{ t('userProfile.avatar.tips') }}
              </a-typography-text>
            </div>
          </a-space>
        </a-card>

        <a-card :title="t('userProfile.section.basic')" size="small">
          <a-form
            ref="profileFormRef"
            :model="profileForm"
            :rules="profileRules"
            layout="vertical"
            @submit="handleUpdateProfile"
          >
            <a-form-item
              :label="t('userProfile.form.username')"
              field="username"
            >
              <a-input
                v-model="profileForm.username"
                :placeholder="t('userProfile.form.username.placeholder')"
                disabled
              />
              <template #extra>
                <a-typography-text type="secondary">
                  {{ t('userProfile.form.username.help') }}
                </a-typography-text>
              </template>
            </a-form-item>

            <a-form-item :label="t('userProfile.form.email')" field="email">
              <a-input
                v-model="profileForm.email"
                :placeholder="t('userProfile.form.email.placeholder')"
                disabled
              />
              <template #extra>
                <a-typography-text type="secondary">
                  {{ t('userProfile.form.email.help') }}
                </a-typography-text>
              </template>
            </a-form-item>

            <a-form-item
              :label="t('userProfile.form.nickname')"
              field="nickname"
            >
              <a-input
                v-model="profileForm.nickname"
                :placeholder="t('userProfile.form.nickname.placeholder')"
                max-length="50"
                show-word-limit
              />
            </a-form-item>

            <a-form-item>
              <a-button
                type="primary"
                html-type="submit"
                :loading="profileLoading"
              >
                {{ t('userProfile.form.save') }}
              </a-button>
            </a-form-item>
          </a-form>
        </a-card>

        <a-card :title="t('userProfile.section.password')" size="small">
          <a-form
            ref="passwordFormRef"
            :model="passwordForm"
            :rules="passwordRules"
            layout="vertical"
            @submit="handleChangePassword"
          >
            <a-form-item
              :label="t('userProfile.form.password.new')"
              field="new_password"
            >
              <a-input-password
                v-model="passwordForm.new_password"
                :placeholder="t('userProfile.form.password.new.placeholder')"
                allow-clear
              />
              <template #extra>
                <a-typography-text type="secondary">
                  {{ t('userProfile.form.password.new.help') }}
                </a-typography-text>
              </template>
            </a-form-item>

            <a-form-item
              :label="t('userProfile.form.password.confirm')"
              field="confirm_password"
            >
              <a-input-password
                v-model="passwordForm.confirm_password"
                :placeholder="
                  t('userProfile.form.password.confirm.placeholder')
                "
                allow-clear
              />
            </a-form-item>

            <a-form-item>
              <a-button
                type="primary"
                html-type="submit"
                :loading="passwordLoading"
              >
                {{ t('userProfile.form.password.submit') }}
              </a-button>
            </a-form-item>
          </a-form>
        </a-card>
      </a-space>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive, onMounted } from 'vue';
  import { useI18n } from 'vue-i18n';
  import { Message } from '@arco-design/web-vue';
  import { useUserStore } from '@/store';
  import { resolveHttpErrorMessage } from '@/utils/i18n';
  import {
    getCurrentUserInfo,
    updateCurrentUserProfile,
    changeCurrentUserPassword,
    updateUserAvatar,
    type UpdateUserProfileRequest,
    type ChangePasswordRequest,
  } from '@/api/user-profile';
  import {
    testCosUploadSignature,
    getDefaultStorageProvider,
    getCosDownloadUrl,
  } from '@/api/settings';
  import { computeFileHash } from '@/utils/fileHash';

  const { t } = useI18n();
  const userStore = useUserStore();

  const avatarInputRef = ref<HTMLInputElement | null>(null);
  const profileFormRef = ref();
  const passwordFormRef = ref();

  const profileLoading = ref(false);
  const passwordLoading = ref(false);
  const avatarUploading = ref(false);

  const avatarPreview = ref<string>('');

  const profileForm = reactive({
    username: '',
    email: '',
    nickname: '',
  });

  const passwordForm = reactive({
    new_password: '',
    confirm_password: '',
  });

  const profileRules = {
    nickname: [
      {
        required: true,
        message: t('userProfile.validation.nickname.required'),
      },
      {
        maxLength: 50,
        message: t('userProfile.validation.nickname.maxLength'),
      },
    ],
  };

  const passwordRules = {
    new_password: [
      {
        required: true,
        message: t('userProfile.validation.password.required'),
      },
      {
        minLength: 8,
        message: t('userProfile.validation.password.minLength'),
      },
      {
        pattern: /^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&^_-]{8,}$/,
        message: t('userProfile.validation.password.pattern'),
      },
    ],
    confirm_password: [
      {
        required: true,
        message: t('userProfile.validation.password.confirmRequired'),
      },
      {
        validator: (value: string, callback: any) => {
          if (value !== passwordForm.new_password) {
            callback(
              new Error(t('userProfile.validation.password.confirmMismatch'))
            );
          } else {
            callback();
          }
        },
      },
    ],
  };

  const fetchCurrentUser = async () => {
    try {
      const response = await getCurrentUserInfo();
      const userInfo = response.data;

      profileForm.username = userInfo.username;
      profileForm.email = userInfo.email;
      profileForm.nickname = userInfo.nickname || '';

      if (userInfo.avatarUrl) {
        if (userInfo.avatarUrl.startsWith('admin/')) {
          try {
            const providerResponse = await getDefaultStorageProvider();
            const provider = providerResponse.data;
            if (provider) {
              const downloadUrlResponse = await getCosDownloadUrl({
                provider_id: provider.id,
                key: userInfo.avatarUrl,
              });
              const avatarUrl = downloadUrlResponse.data.url;

              if (avatarUrl) {
                avatarPreview.value = avatarUrl;
                userStore.setInfo({ avatar: avatarUrl });
              } else {
                avatarPreview.value = '';
                userStore.setInfo({ avatar: undefined });
              }
            }
          } catch {
            avatarPreview.value = '';
          }
        } else {
          avatarPreview.value = userInfo.avatarUrl;
          userStore.setInfo({ avatar: userInfo.avatarUrl });
        }
      }
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('userProfile.fetch.error'),
        })
      );
    }
  };

  const uploadAvatarFile = async (file: File) => {
    try {
      avatarUploading.value = true;

      const providerResponse = await getDefaultStorageProvider();
      const provider = providerResponse.data;

      if (!provider) {
        Message.error(t('userProfile.avatar.provider.missing'));
        return;
      }

      if (!provider.is_active) {
        Message.error(t('userProfile.avatar.provider.inactive'));
        return;
      }

      const fileExt = file.name.split('.').pop() || 'jpg';
      const fileKey = `admin/avatars/${Date.now()}_${Math.random()
        .toString(36)
        .substring(2)}.${fileExt}`;

      let hashValue: string | undefined;
      let hashAlg: number | undefined;
      try {
        const hash = await computeFileHash(file);
        if (hash.hashValue) {
          hashValue = hash.hashValue;
          hashAlg = hash.hashAlg ?? 2;
        }
      } catch {
        hashValue = undefined;
        hashAlg = undefined;
      }

      const signatureResponse = await testCosUploadSignature({
        provider_id: provider.id,
        key: fileKey,
        content_type: file.type,
        file_size: file.size,
        hash_value: hashValue,
        hash_alg: hashAlg,
      });
      const { signature } = signatureResponse.data;

      if (signature) {
        const headers = new Headers();
        Object.entries(signature.headers || {}).forEach(([key, value]) => {
          if (key.toLowerCase() !== 'host') {
            headers.set(key, value);
          }
        });
        if (file.type && !headers.has('Content-Type')) {
          headers.set('Content-Type', file.type);
        }

        const uploadResponse = await fetch(signature.url, {
          method: signature.method || 'PUT',
          headers,
          body: file,
        });

        if (!uploadResponse.ok) {
          throw new Error(
            `${uploadResponse.status} ${uploadResponse.statusText}`.trim()
          );
        }
      }

      const downloadUrlResponse = await getCosDownloadUrl({
        provider_id: provider.id,
        key: fileKey,
      });
      const avatarUrl = downloadUrlResponse.data.url;

      const updateResponse = await updateUserAvatar(fileKey);
      if (updateResponse.data && updateResponse.data.success) {
        Message.success(t('userProfile.avatar.upload.success'));
        await fetchCurrentUser();
        userStore.setInfo({ avatar: avatarUrl || undefined });
      }
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('userProfile.avatar.upload.error'),
        })
      );
    } finally {
      avatarUploading.value = false;
    }
  };

  const triggerAvatarSelect = () => {
    avatarInputRef.value?.click();
  };

  const handleAvatarChange = async (event: Event) => {
    const inputEl = event.target as HTMLInputElement;
    const { files } = inputEl;

    if (!files || files.length === 0) {
      return;
    }

    const file = files[0];

    if (!file.type.startsWith('image/')) {
      Message.error(t('userProfile.avatar.fileType.error'));
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      Message.error(t('userProfile.avatar.fileSize.error'));
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      avatarPreview.value = e.target?.result as string;
    };
    reader.readAsDataURL(file);

    await uploadAvatarFile(file);
  };

  const handleUpdateProfile = async ({
    errors,
  }: {
    errors: Record<string, any> | undefined;
  }) => {
    if (errors) return;

    try {
      profileLoading.value = true;

      const payload: UpdateUserProfileRequest = {
        nickname: profileForm.nickname,
      };

      const response = await updateCurrentUserProfile(payload);
      if (response.data) {
        Message.success(t('userProfile.save.success'));
        await fetchCurrentUser();
      }
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('userProfile.save.error'),
        })
      );
    } finally {
      profileLoading.value = false;
    }
  };

  const handleChangePassword = async ({
    errors,
  }: {
    errors: Record<string, any> | undefined;
  }) => {
    if (errors) return;

    try {
      passwordLoading.value = true;

      const payload: ChangePasswordRequest = {
        new_password: passwordForm.new_password,
      };

      const response = await changeCurrentUserPassword(payload);
      if (response.data) {
        Message.success(t('userProfile.password.success'));
        passwordForm.new_password = '';
        passwordForm.confirm_password = '';
        passwordFormRef.value?.clearValidate();
      }
    } catch (error: any) {
      Message.error(
        resolveHttpErrorMessage(error, {
          fallbackMessage: t('userProfile.password.error'),
        })
      );
    } finally {
      passwordLoading.value = false;
    }
  };

  onMounted(() => {
    fetchCurrentUser();
  });
</script>

<style scoped>
  .user-profile-container {
    padding: 0 20px 20px;
  }

  .avatar-section {
    display: flex;
    flex-direction: column;
    gap: 16px;
    align-items: center;
  }

  .user-avatar {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 100px;
    height: 100px;
    overflow: hidden;
    background-color: var(--color-fill-2);
    border-radius: 50%;

    :deep(img) {
      width: 100%;
      height: 100%;
      object-fit: cover;
      border-radius: 50%;
    }
  }

  .avatar-icon {
    color: rgb(var(--gray-7));
    font-size: 50px;
  }

  .upload-btn {
    width: 100%;
  }

  .avatar-tips {
    flex: 1;
  }
</style>
