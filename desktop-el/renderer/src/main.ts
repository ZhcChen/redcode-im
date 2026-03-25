import { createApp } from "vue";
import App from "./App.vue";
import "./styles/global.css";
import { disableNavigationShortcuts } from "./utils/navigation-shortcuts";

createApp(App).mount("#app");

disableNavigationShortcuts();
