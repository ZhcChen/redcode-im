<template>
  <div class="auth-page">
    <div class="auth-shell">
      <header class="auth-header">
        <div class="auth-brand">
          <div class="auth-brand-mark">RC</div>
          <div>
            <div class="auth-brand-name">RedCode IM Admin</div>
            <div class="auth-brand-subtitle">
              {{ $t('auth.brand.subtitle') }}
            </div>
          </div>
        </div>
      </header>

      <a-card :bordered="false" class="auth-card">
        <template v-if="bootstrapRequired === null">
          <div class="auth-loading">
            <a-spin />
            <div class="auth-loading-text">
              {{ $t('auth.status.checking') }}
            </div>
          </div>
        </template>

        <template v-else>
          <div class="auth-copy">
            <div class="auth-kicker">
              {{
                bootstrapRequired
                  ? $t('auth.status.bootstrap')
                  : $t('auth.status.login')
              }}
            </div>
            <h1 class="auth-title">
              {{
                bootstrapRequired
                  ? $t('auth.title.bootstrap')
                  : $t('auth.title.login')
              }}
            </h1>
            <p class="auth-description">
              {{
                bootstrapRequired
                  ? $t('auth.description.bootstrap')
                  : $t('auth.description.login')
              }}
            </p>
          </div>

          <div v-if="errorMessage" class="login-form-error-msg auth-alert">
            {{ errorMessage }}
          </div>

          <a-form
            :model="formModel"
            class="auth-form"
            layout="vertical"
            @submit="handleSubmit"
          >
            <a-form-item
              field="username"
              :label="$t('auth.form.username.label')"
              :rules="[
                {
                  required: true,
                  message: $t('auth.form.username.required'),
                },
              ]"
              :validate-trigger="['change', 'blur']"
            >
              <a-input
                v-model="formModel.username"
                :placeholder="$t('auth.form.username.placeholder')"
              >
                <template #prefix>
                  <icon-user />
                </template>
              </a-input>
            </a-form-item>

            <a-form-item
              v-if="bootstrapRequired"
              field="displayName"
              :label="$t('auth.form.displayName.label')"
            >
              <a-input
                v-model="formModel.displayName"
                :placeholder="$t('auth.form.displayName.placeholder')"
              >
                <template #prefix>
                  <icon-user />
                </template>
              </a-input>
            </a-form-item>

            <a-form-item
              field="password"
              :label="$t('auth.form.password.label')"
              :rules="passwordRules"
              :validate-trigger="['change', 'blur']"
            >
              <a-input-password
                v-model="formModel.password"
                :placeholder="
                  bootstrapRequired
                    ? $t('auth.form.password.placeholder.bootstrap')
                    : $t('auth.form.password.placeholder.login')
                "
                allow-clear
              >
                <template #prefix>
                  <icon-lock />
                </template>
              </a-input-password>
            </a-form-item>

            <a-button
              class="auth-submit"
              type="primary"
              html-type="submit"
              long
              :loading="submitting"
            >
              {{
                bootstrapRequired
                  ? $t('auth.action.bootstrap')
                  : $t('auth.action.login')
              }}
            </a-button>
          </a-form>
        </template>
      </a-card>
    </div>
    <Footer class="auth-footer" />
  </div>
</template>

<script lang="ts" setup>
  import { computed, onMounted, reactive, ref } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import type { ValidatedError } from '@arco-design/web-vue/es/form/interface';
  import { useI18n } from 'vue-i18n';
  import { useRouter } from 'vue-router';

  import Footer from '@/components/footer/index.vue';
  import appRoutes from '@/app/router/routes';
  import { useUserStore } from '@/store';
  import usePermission from '@/hooks/permission';
  import { bootstrapAdmin, getAdminBootstrapStatus } from '@/services/auth';
  import type { LoginRes } from '@/services/auth';

  const router = useRouter();
  const { t } = useI18n();
  const userStore = useUserStore();
  const permission = usePermission();

  const bootstrapRequired = ref<boolean | null>(null);
  const submitting = ref(false);
  const errorMessage = ref('');

  const formModel = reactive({
    username: '',
    password: '',
    displayName: '',
  });

  const passwordRules = computed(() => {
    if (bootstrapRequired.value) {
      return [
        {
          required: true,
          message: t('auth.form.password.required'),
        },
        {
          min: 8,
          message: t('auth.form.password.min'),
        },
      ];
    }

    return [
      {
        required: true,
        message: t('auth.form.password.required'),
      },
    ];
  });

  function persistAuthResult(payload: LoginRes) {
    userStore.applyAuthResult(payload);
  }

  async function resolveRedirectTarget() {
    const { redirect, ...othersQuery } = router.currentRoute.value.query;
    const fallbackRoute = permission.findFirstPermissionRoute(appRoutes) || {
      name: 'login',
    };

    await router.push({
      name: (redirect as string) || fallbackRoute.name,
      query: {
        ...othersQuery,
      },
    });
  }

  async function loadBootstrapStatus() {
    try {
      const { data } = await getAdminBootstrapStatus();
      bootstrapRequired.value = Boolean(data.bootstrap_required);
    } catch (error) {
      bootstrapRequired.value = false;
      errorMessage.value =
        (error as Error)?.message || t('auth.error.statusLoadFailed');
    }
  }

  async function handleSubmit({
    errors,
    values,
  }: {
    errors: Record<string, ValidatedError> | undefined;
    values: Record<string, any>;
  }) {
    if (submitting.value || errors) {
      return;
    }

    submitting.value = true;
    errorMessage.value = '';

    try {
      if (bootstrapRequired.value) {
        const { data } = await bootstrapAdmin({
          username: values.username,
          password: values.password,
          display_name: values.displayName?.trim() || undefined,
        });
        persistAuthResult(data);
      } else {
        await userStore.login({
          username: values.username,
          password: values.password,
        });
      }

      await resolveRedirectTarget();
      Message.success(
        bootstrapRequired.value
          ? t('auth.action.bootstrap.success')
          : t('auth.action.login.success')
      );
    } catch (error) {
      errorMessage.value = (error as Error)?.message || t('auth.error.default');
    } finally {
      submitting.value = false;
    }
  }

  onMounted(() => {
    loadBootstrapStatus();
  });
</script>

<style lang="less" scoped>
  .auth-page {
    min-height: 100vh;
    padding: 40px 24px 24px;
    background: radial-gradient(
        circle at top left,
        rgb(22 93 255 / 16%),
        transparent 36%
      ),
      radial-gradient(circle at top right, rgb(0 180 42 / 10%), transparent 30%),
      linear-gradient(180deg, #f7f9fc 0%, #eef3fb 100%);
  }

  .auth-shell {
    width: 100%;
    max-width: 460px;
    margin: 0 auto;
  }

  .auth-header {
    margin-bottom: 24px;
  }

  .auth-brand {
    display: flex;
    gap: 14px;
    align-items: center;
  }

  .auth-brand-mark {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 44px;
    height: 44px;
    color: #fff;
    font-weight: 700;
    font-size: 16px;
    background: linear-gradient(
      135deg,
      rgb(var(--arcoblue-6)) 0%,
      #00308f 100%
    );
    border-radius: 14px;
    box-shadow: 0 12px 30px rgb(22 93 255 / 22%);
  }

  .auth-brand-name {
    color: rgb(var(--gray-10));
    font-weight: 600;
    font-size: 20px;
    line-height: 28px;
  }

  .auth-brand-subtitle {
    color: rgb(var(--gray-6));
    font-size: 13px;
    line-height: 20px;
  }

  .auth-card {
    border-radius: 24px;
    box-shadow: 0 24px 60px rgb(15 23 42 / 8%);
  }

  .auth-copy {
    margin-bottom: 24px;
  }

  .auth-kicker {
    margin-bottom: 10px;
    color: rgb(var(--arcoblue-6));
    font-weight: 600;
    font-size: 12px;
    line-height: 18px;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }

  .auth-title {
    margin: 0;
    color: rgb(var(--gray-10));
    font-weight: 600;
    font-size: 30px;
    line-height: 38px;
  }

  .auth-description {
    margin: 12px 0 0;
    color: rgb(var(--gray-6));
    font-size: 14px;
    line-height: 22px;
  }

  .auth-alert {
    margin-bottom: 16px;
    padding: 10px 12px;
    color: rgb(var(--red-6));
    background: rgb(var(--red-1));
    border: 1px solid rgb(var(--red-3));
    border-radius: 12px;
  }

  .auth-form {
    :deep(.arco-form-item:last-child) {
      margin-bottom: 0;
    }
  }

  .auth-submit {
    height: 44px;
    margin-top: 8px;
    font-weight: 600;
  }

  .auth-loading {
    display: flex;
    flex-direction: column;
    gap: 16px;
    align-items: center;
    justify-content: center;
    min-height: 280px;
  }

  .auth-loading-text {
    color: rgb(var(--gray-6));
    font-size: 14px;
    line-height: 22px;
  }

  .auth-footer {
    margin-top: 24px;
  }

  @media (max-width: 640px) {
    .auth-page {
      padding: 24px 16px 16px;
    }

    .auth-title {
      font-size: 26px;
      line-height: 34px;
    }
  }
</style>
