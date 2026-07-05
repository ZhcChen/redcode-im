import { defineStore } from 'pinia';

import { appEnv } from '@/config/env';
import { authService } from '@/services/auth-service';
import { avatarCacheService } from '@/services/avatar-cache';
import { avatarUploadService, validateAvatarFile } from '@/services/avatar-upload-service';
import { settingsService } from '@/services/settings-service';
import type { AuthUser } from '@/types/auth';
import type { DocumentContent, GeneralSettings } from '@/types/settings';

import { useAuthStore } from './auth';
import { useContactsStore } from './contacts';

export const useSettingsStore = defineStore('settings', {
  state: () => ({
    user: null as AuthUser | null,
    general: null as GeneralSettings | null,
    privacyPolicy: null as DocumentContent | null,
    userAgreement: null as DocumentContent | null,
    nicknameDraft: '',
    oldPassword: '',
    newPassword: '',
    feedbackContent: '',
    feedbackContact: '',
    loading: false,
    submitting: false,
    avatarUploading: false,
    error: '',
    notice: '',
  }),
  getters: {
    displayName: (state) => state.user?.nickname || state.user?.email || state.user?.username || 'RedCode 用户',
    avatarInitial(): string {
      return this.displayName.slice(0, 1).toUpperCase();
    },
  },
  actions: {
    async initialize() {
      this.user = useAuthStore().currentUser;
      this.nicknameDraft = this.user?.nickname ?? '';
      this.loading = true;
      this.error = '';
      try {
        if (appEnv.useMockData) {
          this.general = createMockGeneralSettings();
          this.loading = false;
          return;
        }
        const [me, general] = await Promise.all([
          authService.me(),
          settingsService.fetchGeneralSettings(),
        ]);
        if (me) {
          this.user = me;
          this.nicknameDraft = me.nickname;
          useAuthStore().updateCurrentUser(me);
        }
        this.general = general;
      } catch (error) {
        this.error = error instanceof Error ? error.message : '加载设置失败';
      } finally {
        this.loading = false;
      }
    },

    async updateNickname() {
      const nickname = this.nicknameDraft.trim();
      if (!nickname || nickname === this.user?.nickname) return;
      const previous = this.user;
      this.submitting = true;
      this.error = '';
      this.notice = '';
      try {
        const updated = appEnv.useMockData
          ? { ...(previous ?? createMockUser()), nickname }
          : await authService.updateProfile({ nickname });
        this.user = updated;
        this.nicknameDraft = updated.nickname;
        useAuthStore().updateCurrentUser(updated);
        this.notice = '昵称已更新';
      } catch (error) {
        this.user = previous;
        this.nicknameDraft = previous?.nickname ?? this.nicknameDraft;
        this.error = error instanceof Error ? error.message : '更新昵称失败';
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    async uploadAvatar(file: File | null | undefined) {
      if (!file) return;
      const previous = this.user;
      const authStore = useAuthStore();
      const previousAuthUser = authStore.currentUser;
      this.avatarUploading = true;
      this.error = '';
      this.notice = '';
      try {
        validateAvatarFile(file);
        const current = previous ?? createMockUser();
        const uploaded = appEnv.useMockData
          ? {
              objectKey: `avatars/${current.id}/${Date.now()}-${file.name || 'avatar.png'}`,
              downloadUrl: null,
            }
          : await avatarUploadService.uploadUserAvatar(file);
        const updated = appEnv.useMockData
          ? { ...current, avatarObjectKey: uploaded.objectKey, avatarUrl: uploaded.downloadUrl ?? null }
          : await authService.me();
        if (!updated) throw new Error('头像上传后刷新用户失败');
        const nextUser = {
          ...updated,
          avatarUrl: updated.avatarUrl ?? uploaded.downloadUrl ?? null,
          avatarObjectKey: updated.avatarObjectKey ?? uploaded.objectKey,
        };
        this.user = nextUser;
        authStore.updateCurrentUser(nextUser);
        await avatarCacheService.loadUserAvatar({ userId: nextUser.id, objectKey: nextUser.avatarObjectKey });
        const contactsStore = useContactsStore();
        if (!appEnv.useMockData && contactsStore.initialized) {
          try {
            await contactsStore.refreshFriends();
          } catch (error) {
            console.warn('[h5-app] 头像上传后刷新联系人失败，已保留当前用户状态', error);
          }
        }
        this.notice = '头像已更新';
      } catch (error) {
        this.user = previous;
        if (previousAuthUser) {
          authStore.updateCurrentUser(previousAuthUser);
        }
        this.error = error instanceof Error ? error.message : '更新头像失败';
        throw error;
      } finally {
        this.avatarUploading = false;
      }
    },

    async changePassword() {
      if (!this.oldPassword || !this.newPassword) return;
      this.submitting = true;
      this.error = '';
      this.notice = '';
      try {
        if (!appEnv.useMockData) {
          await authService.changePassword(this.oldPassword, this.newPassword);
        }
        this.oldPassword = '';
        this.newPassword = '';
        this.notice = '密码已更新';
      } catch (error) {
        this.error = error instanceof Error ? error.message : '修改密码失败';
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    async loadDocument(kind: 'privacy' | 'agreement') {
      this.loading = true;
      this.error = '';
      try {
        const document = appEnv.useMockData
          ? createMockDocument(kind)
          : kind === 'privacy'
            ? await settingsService.fetchPrivacyPolicy()
            : await settingsService.fetchUserAgreement();
        if (kind === 'privacy') {
          this.privacyPolicy = document;
        } else {
          this.userAgreement = document;
        }
      } catch (error) {
        this.error = error instanceof Error ? error.message : '加载内容失败';
      } finally {
        this.loading = false;
      }
    },

    async submitFeedback() {
      const content = this.feedbackContent.trim();
      if (!content) return;
      this.submitting = true;
      this.error = '';
      this.notice = '';
      try {
        const message = appEnv.useMockData
          ? '反馈提交成功，感谢您的支持！'
          : await settingsService.submitFeedback({
              content,
              contact: this.feedbackContact,
            });
        this.feedbackContent = '';
        this.feedbackContact = '';
        this.notice = message;
      } catch (error) {
        this.error = error instanceof Error ? error.message : '提交反馈失败';
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    clearNotice() {
      this.notice = '';
    },
  },
});

const createMockUser = (): AuthUser => ({
  id: 'mock-current',
  username: 'h5@example.com',
  nickname: 'H5',
  email: 'h5@example.com',
});

const createMockGeneralSettings = (): GeneralSettings => ({
  appName: 'RedCode IM',
  messageRuntime: {
    serverStorageMode: 'persist',
    contentAuditMode: 'plaintext',
  },
});

const createMockDocument = (kind: 'privacy' | 'agreement'): DocumentContent => ({
  title: kind === 'privacy' ? '隐私协议' : '用户协议',
  content: kind === 'privacy'
    ? '<p>RedCode IM 尊重并保护你的隐私。</p>'
    : '<p>使用 RedCode IM 即表示你同意本用户协议。</p>',
  updatedAt: new Date().toISOString(),
});
