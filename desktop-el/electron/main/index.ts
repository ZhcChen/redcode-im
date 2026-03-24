import { createDesktopLifecycle } from "./lifecycle.js";

const lifecycle = createDesktopLifecycle();

void lifecycle.start().catch((error) => {
  console.error("[desktop-el] failed to start lifecycle", error);
  process.exitCode = 1;
});
