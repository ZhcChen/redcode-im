const { chromium } = require('playwright');

(async () => {
  // 启动浏览器
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

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

  try {
    // 1. 导航到登录页面
    await page.goto('http://localhost:8011');

    // 等待页面加载
    await page.waitForTimeout(2000);

    // 2. 登录
    // 填写用户名和密码
    await page.fill('input[placeholder="用户名：admin"]', 'admin');
    await page.fill('input[placeholder="密码：admin"]', 'admin');

    // 点击登录按钮
    await page.click('button:has-text("登录")');

    // 等待登录完成
    await page.waitForTimeout(2000);

    // 3. 点击展开聊天记录菜单
    await page.click('.arco-menu-inline-header:has-text("聊天记录")');

    // 等待菜单展开
    await page.waitForTimeout(500);

    // 4. 点击聊天记录列表
    await page.click('.arco-menu-item:has-text("聊天记录列表")');

    // 等待页面加载
    await page.waitForTimeout(2000);

    // 5. 点击查看用户记录按钮
    await page.click('button:has-text("查看用户记录")');

    // 等待页面跳转
    await page.waitForTimeout(2000);

    // 6. 点击用户消息标签页
    await page.click('.arco-tabs-tab:has-text("用户消息")');

    // 等待错误出现
    await page.waitForTimeout(3000);

    // 检查页面是否有错误提示
    const errorElement = await page.$(
      '.arco-message-error, .error-message, [class*="error"]'
    );
    if (errorElement) {
      const errorText = await errorElement.textContent();
      console.log('页面错误信息:', errorText);
    }

    // 获取当前URL
    const currentUrl = page.url();
    console.log('当前URL:', currentUrl);

    // 等待一段时间以便观察
    await page.waitForTimeout(5000);
  } catch (error) {
    console.error('测试过程中发生错误:', error);
  } finally {
    // 关闭浏览器
    await browser.close();
  }
})();
