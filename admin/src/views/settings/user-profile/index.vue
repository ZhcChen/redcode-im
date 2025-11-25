<template>
  <div class="user-profile-container">
    <Breadcrumb :items="['menu.settings', 'menu.settings.userProfile']" />
    <a-card class="general-card" title="个人设置" :bordered="false">
      <a-space direction="vertical" :size="24" style="width: 100%">
        <!-- 头像设置 -->
        <a-card title="头像设置" size="small">
          <a-space :size="24" align="start">
            <div class="avatar-section">
              <a-avatar :size="100" class="user-avatar">
                <img v-if="avatarPreview" :src="avatarPreview" alt="avatar" />
                <icon-user v-else class="avatar-icon" />
              </a-avatar>
              <a-button
                class="upload-btn"
                type="primary"
                @click="triggerAvatarSelect"
              >
                更换头像
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
                支持 JPG、PNG 格式，文件大小不超过 5MB
              </a-typography-text>
            </div>
          </a-space>
        </a-card>

        <!-- 基础信息 -->
        <a-card title="基础信息" size="small">
          <a-form
            ref="profileFormRef"
            :model="profileForm"
            :rules="profileRules"
            layout="vertical"
            @submit="handleUpdateProfile"
          >
            <a-form-item label="用户名" field="username">
              <a-input
                v-model="profileForm.username"
                placeholder="请输入用户名"
                disabled
              />
              <template #extra>
                <a-typography-text type="secondary">
                  用户名不可修改
                </a-typography-text>
              </template>
            </a-form-item>

            <a-form-item label="邮箱" field="email">
              <a-input
                v-model="profileForm.email"
                placeholder="请输入邮箱"
                disabled
              />
              <template #extra>
                <a-typography-text type="secondary">
                  邮箱不可修改
                </a-typography-text>
              </template>
            </a-form-item>

            <a-form-item label="昵称" field="nickname">
              <a-input
                v-model="profileForm.nickname"
                placeholder="请输入昵称"
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
                保存修改
              </a-button>
            </a-form-item>
          </a-form>
        </a-card>

        <!-- 重置密码 -->
        <a-card title="重置密码" size="small">
          <a-form
            ref="passwordFormRef"
            :model="passwordForm"
            :rules="passwordRules"
            layout="vertical"
            @submit="handleChangePassword"
          >
            <a-form-item label="新密码" field="new_password">
              <a-input-password
                v-model="passwordForm.new_password"
                placeholder="请输入新密码"
                allow-clear
              />
              <template #extra>
                <a-typography-text type="secondary">
                  密码长度至少 8 位，包含字母和数字
                </a-typography-text>
              </template>
            </a-form-item>

            <a-form-item label="确认新密码" field="confirm_password">
              <a-input-password
                v-model="passwordForm.confirm_password"
                placeholder="请再次输入新密码"
                allow-clear
              />
            </a-form-item>

            <a-form-item>
              <a-button
                type="primary"
                html-type="submit"
                :loading="passwordLoading"
              >
                重置密码
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
  import { Message } from '@arco-design/web-vue';
  import {
    getCurrentUserInfo,
    updateCurrentUserProfile,
    changeCurrentUserPassword,
    uploadAvatar,
    type UpdateUserProfileRequest,
    type ChangePasswordRequest,
  } from '@/api/user-profile';

  const avatarInputRef = ref<HTMLInputElement | null>(null);
  const profileFormRef = ref();
  const passwordFormRef = ref();

  const profileLoading = ref(false);
  const passwordLoading = ref(false);
  const avatarUploading = ref(false);

  const currentUser = ref<any>(null);
  const selectedAvatarFile = ref<File | null>(null);
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
        message: '请输入昵称',
      },
      {
        maxLength: 50,
        message: '昵称不能超过 50 个字符',
      },
    ],
  };

  const passwordRules = {
    new_password: [
      {
        required: true,
        message: '请输入新密码',
      },
      {
        minLength: 8,
        message: '密码长度至少 8 位',
      },
      {
        pattern: /^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&^_-]{8,}$/,
        message: '密码必须包含字母和数字',
      },
    ],
    confirm_password: [
      {
        required: true,
        message: '请确认新密码',
      },
      {
        validator: (value: string, callback: any) => {
          if (value !== passwordForm.new_password) {
            callback(new Error('两次输入的密码不一致'));
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
      currentUser.value = userInfo;

      profileForm.username = userInfo.username;
      profileForm.email = userInfo.email;
      profileForm.nickname = userInfo.nickname || '';

      if (userInfo.avatar_url) {
        avatarPreview.value = userInfo.avatar_url;
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '获取用户信息失败';
      Message.error(errorMsg);
    }
  };

  const uploadAvatarFile = async (file: File) => {
    try {
      avatarUploading.value = true;
      const formData = new FormData();
      formData.append('avatar', file);

      const response = await uploadAvatar(formData);
      if (response.data.success) {
        Message.success('头像上传成功');
        // 更新用户信息
        await fetchCurrentUser();
      } else {
        Message.error(response.data.message || '头像上传失败');
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '头像上传失败';
      Message.error(errorMsg);
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

    // 验证文件类型
    if (!file.type.startsWith('image/')) {
      Message.error('请选择图片文件');
      return;
    }

    // 验证文件大小 (5MB)
    if (file.size > 5 * 1024 * 1024) {
      Message.error('图片大小不能超过 5MB');
      return;
    }

    selectedAvatarFile.value = file;

    // 预览头像
    const reader = new FileReader();
    reader.onload = (e) => {
      avatarPreview.value = e.target?.result as string;
    };
    reader.readAsDataURL(file);

    // 自动上传头像
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
        Message.success('保存成功');
        // 更新本地用户信息
        await fetchCurrentUser();
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '保存失败';
      Message.error(errorMsg);
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
        Message.success('密码重置成功');
        // 清空表单
        passwordForm.new_password = '';
        passwordForm.confirm_password = '';
        passwordFormRef.value?.clearValidate();
      }
    } catch (error: any) {
      const errorMsg =
        error?.response?.data?.message ||
        error?.response?.data?.details ||
        error?.message ||
        '密码重置失败';
      Message.error(errorMsg);
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
    background-color: var(--color-fill-2);
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
