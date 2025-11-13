const { test, expect } = require('@playwright/test');

test.describe('聊天记录测试', () => {
  test('查看用户消息错误重现', async ({ page }) => {
    // 1. 导航到登录页面
    await page.goto('http://localhost:8011');

    // 2. 登录
    // 填写用户名和密码（需要根据实际情况调整）
    await page.fill('input[placeholder="请输入用户名"]', 'admin');
    await page.fill('input[placeholder="请输入密码"]', 'admin123');

    // 点击登录按钮
    await page.click('button[type="submit"]');

    // 等待登录完成
    await page.waitForTimeout(1000);

    // 3. 点击展开聊天记录菜单
    await page.click('.arco-menu-inline-header:has-text("聊天记录")');

    // 等待菜单展开
    await page.waitForTimeout(500);

    // 4. 点击聊天记录列表
    await page.click('.arco-menu-item:has-text("聊天记录列表")');

    // 等待页面加载
    await page.waitForTimeout(1000);

    // 5. 点击查看用户记录按钮
    await page.click('button:has-text("查看用户记录")');

    // 等待页面跳转
    await page.waitForTimeout(1000);

    // 6. 点击用户消息标签页
    await page.click('.arco-tabs-tab:has-text("用户消息")');

    // 等待错误出现
    await page.waitForTimeout(2000);

    // 捕获控制台日志
    page.on('console', (msg) => {
      console.log('控制台日志:', msg.text());
    });

    // 捕获网络请求
    page.on('response', (response) => {
      if (response.status() >= 400) {
        console.log('错误请求:', response.url(), response.status());
      }
    });

    // 检查页面是否有错误提示
    const errorElement = await page.$(
      '.arco-message-error, .error-message, [class*="error"]'
    );
    if (errorElement) {
      const errorText = await errorElement.textContent();
      console.log('页面错误信息:', errorText);
    }

    // 等待一段时间以便观察
    await page.waitForTimeout(3000);
  });
});
