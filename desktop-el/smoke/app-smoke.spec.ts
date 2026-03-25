import { expect, test } from "@playwright/test";
import { installDesktopElMock } from "./support/mock-desktop-el";

test("从登录页登录后进入 HomeShell", async ({ page }) => {
  await page.addInitScript(installDesktopElMock, {
    appName: "RedCode",
    hostVersion: "0.1.0-smoke",
    user: {
      id: "user-smoke",
      username: "13800138000",
      nickname: "Smoke User",
      email: "smoke@example.com",
    },
  });

  await page.goto("/");

  await expect(page.getByText("Hello!")).toBeVisible();
  await expect(page.getByText("欢迎来到RedCode")).toBeVisible();
  await expect(page.getByText("Go core 已就绪，当前入口开始接管旧桌面端登录 UI。")).toBeVisible();

  await page.getByLabel("账号 / 手机号").fill("13800138000");
  await page.getByLabel("密码").fill("123456");
  await page.getByRole("button", { name: "登录账号" }).click();

  await expect(page.getByText("desktop-el / Home shell")).toBeVisible();
  await expect(page.getByRole("button", { name: "聊天 会话与消息" })).toBeVisible();
  await expect(page.getByRole("button", { name: "联系人 好友与群组" })).toBeVisible();
  await expect(page.getByRole("button", { name: "设置 账号与系统" })).toBeVisible();
});
