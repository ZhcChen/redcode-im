import { createApp, watch } from 'vue';
import { createPinia } from 'pinia';

import App from './App.vue';
import { router } from './router';
import { useAuthStore } from './stores/auth';

import './styles/tokens.css';
import './styles/global.css';
import './views/contacts/contact-page.css';

const app = createApp(App);
const pinia = createPinia();

app.use(pinia);
app.use(router);

const authStore = useAuthStore(pinia);
authStore.startSessionSync();
watch(() => authStore.isAuthenticated, (isAuthenticated) => {
  if (!isAuthenticated && router.currentRoute.value.meta.requiresAuth) {
    void router.replace({ name: 'login' });
  }
});

app.mount('#app');
