import { defineStore } from 'pinia';
import {
  login as userLogin,
  logout as userLogout,
  getUserInfo,
  LoginData,
  LoginRes,
  BackendUserInfo,
} from '@/api/user';
import { setToken, setRefreshToken, clearToken } from '@/utils/auth';
import { removeRouteListener } from '@/utils/route-listener';
import { UserState } from './types';
import useAppStore from '../app';

function mapBackendUser(user: BackendUserInfo): Partial<UserState> {
  const roleCodes = user.roleCodes ?? [];
  const isSuperAdmin = user.isSuperAdmin ?? roleCodes.includes('super_admin');

  return {
    name: user.nickname || user.username,
    avatar:
      user.avatarUrl && user.avatarUrl.trim() !== ''
        ? user.avatarUrl
        : undefined,
    email: user.email,
    introduction: undefined,
    accountId: user.id,
    role: roleCodes[0] || (isSuperAdmin ? 'super_admin' : 'admin'),
    roleCodes,
    permissionKeys: user.permissionKeys ?? [],
    isSuperAdmin,
  };
}

const useUserStore = defineStore('user', {
  state: (): UserState => ({
    name: undefined,
    avatar: undefined,
    job: undefined,
    organization: undefined,
    location: undefined,
    email: undefined,
    introduction: undefined,
    personalWebsite: undefined,
    jobName: undefined,
    organizationName: undefined,
    locationName: undefined,
    phone: undefined,
    registrationDate: undefined,
    accountId: undefined,
    certification: undefined,
    role: '',
    roleCodes: [],
    permissionKeys: [],
    isSuperAdmin: false,
  }),

  getters: {
    userInfo(state: UserState): UserState {
      return { ...state };
    },
  },

  actions: {
    switchRoles() {
      return new Promise((resolve) => {
        this.isSuperAdmin = !this.isSuperAdmin;
        this.role = this.isSuperAdmin
          ? 'super_admin'
          : this.roleCodes[0] || 'admin';
        resolve(this.role);
      });
    },
    // Set user's information
    setInfo(partial: Partial<UserState>) {
      this.$patch(partial);
    },

    applyAuthResult(payload: LoginRes) {
      setToken(payload.token);
      setRefreshToken(payload.refresh_token ?? null);
      this.setInfo(mapBackendUser(payload.user));
    },

    // Reset user's information
    resetInfo() {
      this.$reset();
    },

    // Get user's information
    async info() {
      const res = await getUserInfo();
      this.setInfo(mapBackendUser(res.data));
    },

    // Login
    async login(loginForm: LoginData) {
      try {
        const res = await userLogin(loginForm);
        this.applyAuthResult(res.data);
      } catch (err) {
        clearToken();
        throw err;
      }
    },
    logoutCallBack() {
      const appStore = useAppStore();
      this.resetInfo();
      clearToken();
      removeRouteListener();
      appStore.clearServerMenu();
    },
    // Logout
    async logout() {
      try {
        await userLogout();
      } finally {
        this.logoutCallBack();
      }
    },
  },
});

export default useUserStore;
