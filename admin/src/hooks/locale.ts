import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { Message } from '@arco-design/web-vue';
import { isAdminLocale } from '@/locale';
import { resolveLocaleChangedMessage } from '@/utils/i18n';

export default function useLocale() {
  const i18 = useI18n();
  const currentLocale = computed(() => {
    return i18.locale.value;
  });
  const changeLocale = (value: string) => {
    if (i18.locale.value === value) {
      return;
    }
    if (!isAdminLocale(value)) {
      return;
    }
    i18.locale.value = value;
    localStorage.setItem('arco-locale', value);
    Message.success(resolveLocaleChangedMessage(value));
  };
  return {
    currentLocale,
    changeLocale,
  };
}
