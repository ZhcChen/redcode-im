import { defineStore } from 'pinia';

import { appEnv } from '@/config/env';
import { authService } from '@/services/auth-service';
import { settingsService } from '@/services/settings-service';
import type { AuthUser } from '@/types/auth';
import type { DocumentContent, GeneralSettings } from '@/types/settings';

import { useAuthStore } from './auth';

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
