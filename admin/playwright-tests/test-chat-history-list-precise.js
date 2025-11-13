const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  // 监听控制台输出
  page.on('console', (msg) => {
    console.log('PAGE LOG:', msg.text());
  });

  // 监听网络请求
  page.on('request', (request) => {
    console.log('REQUEST:', request.method(), request.url());
  });

  page.on('response', (response) => {
    console.log('RESPONSE:', response.status(), response.url());
  });

  try {
    // 访问登录页面
    await page.goto('http://localhost:8011/login');

    // 等待页面加载完成
    await page.waitForLoadState('networkidle');

    // 填写登录信息 - 使用正确的placeholder属性
    await page.fill('input[placeholder="用户名：admin"]', 'admin');
    await page.fill('input[placeholder="密码：admin"]', 'admin123');

    // 点击登录按钮
    await page.click('button[type="submit"]');

    // 等待登录成功后跳转到工作台
    await page.waitForURL('http://localhost:8011/dashboard/workplace');
    console.log('登录成功，当前URL:', page.url());

    // 等待页面加载完成
    await page.waitForLoadState('networkidle');

    // 截图保存登录后的页面
    await page.screenshot({ path: 'after-login.png', fullPage: true });

    // 尝试点击聊天记录菜单
    console.log('尝试点击聊天记录菜单...');

    // 方法1: 通过文本内容查找聊天记录菜单项
    const chatHistoryMenuItem = await page.locator('text=聊天记录').first();
    if (await chatHistoryMenuItem.isVisible()) {
      console.log('找到聊天记录菜单，点击...');
      await chatHistoryMenuItem.click();

      // 等待子菜单展开
      await page.waitForTimeout(1000);

      // 查找并点击"聊天记录列表"子菜单项
      const chatHistoryListMenuItem = await page
        .locator('text=聊天记录列表')
        .first();
      if (await chatHistoryListMenuItem.isVisible()) {
        console.log('找到聊天记录列表菜单，点击...');
        await chatHistoryListMenuItem.click();

        // 等待页面跳转
        await page.waitForTimeout(2000);

        // 截图保存聊天记录列表页面
        await page.screenshot({
          path: 'chat-history-list-page.png',
          fullPage: true,
        });

        // 检查页面内容
        const pageTitle = await page.title();
        console.log('页面标题:', pageTitle);

        // 检查是否有表格或列表
        const hasTable = await page.locator('table').isVisible();
        const hasList = await page.locator('.arco-table').isVisible();
        console.log('页面中是否有表格或列表:', hasTable || hasList);

        // 检查是否有错误信息
        const errorMessage = await page
          .locator('.arco-alert-error, .error-message')
          .isVisible();
        console.log('页面中是否有错误信息:', errorMessage);

        // 获取页面内容
        const pageContent = await page.content();
        console.log('页面URL:', page.url());

        // 检查API请求
        console.log('检查API请求...');

        // 等待一段时间以观察网络请求
        await page.waitForTimeout(3000);
      } else {
        console.log('未找到聊天记录列表菜单');
        // 截图保存当前状态
        await page.screenshot({
          path: 'no-chat-history-list-menu.png',
          fullPage: true,
        });
      }
    } else {
      console.log('未找到聊天记录菜单');
      // 截图保存当前状态
      await page.screenshot({
        path: 'no-chat-history-menu.png',
        fullPage: true,
      });
    }
  } catch (error) {
    console.error('发生错误:', error);
    // 截图保存错误状态
    await page.screenshot({ path: 'error-screenshot.png', fullPage: true });
  } finally {
    await browser.close();
  }
})();
