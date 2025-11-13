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

  page.on('pageerror', (error) => {
    console.error('PAGE ERROR:', error.message);
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

    // 导航到聊天记录列表页面
    await page.goto('http://localhost:8011/chat-history/list');
    await page.waitForLoadState('networkidle');

    // 等待聊天记录列表加载
    await page.waitForSelector('table', { timeout: 10000 });

    // 获取第一行的用户ID
    // 尝试多种方式定位"查看用户记录"按钮
    const viewUserButton = page
      .locator('button')
      .filter({ hasText: '查看用户记录' })
      .first();

    // 如果找不到按钮，尝试使用更精确的选择器
    const buttonExists = await viewUserButton.isVisible().catch(() => false);

    if (!buttonExists) {
      // 尝试通过操作列定位
      const actionColumn = page
        .locator('table tr')
        .first()
        .locator('td')
        .filter({ hasText: '查看用户记录' });
      const viewUserButton2 = actionColumn.locator('button').first();

      console.log('点击"查看用户记录"按钮...');
      await viewUserButton2.click();
    } else {
      console.log('点击"查看用户记录"按钮...');
      await viewUserButton.click();
    }

    // 等待页面跳转
    await page.waitForTimeout(2000);

    // 检查当前URL
    console.log('当前URL:', page.url());

    // 检查是否有错误信息
    const hasError = await page
      .locator('.arco-alert-error, .error-message')
      .isVisible();
    console.log('页面中是否有错误信息:', hasError);

    if (hasError) {
      const errorText = await page
        .locator('.arco-alert-error, .error-message')
        .textContent();
      console.log('错误信息:', errorText);
    }

    // 检查页面是否正常加载
    const pageContent = await page.content();
    console.log('页面标题:', await page.title());

    // 检查API请求
    console.log('检查API请求...');

    // 等待一段时间以观察网络请求
    await page.waitForTimeout(3000);

    // 截图保存用户聊天记录页面
    await page.screenshot({
      path: 'user-chat-history-page.png',
      fullPage: true,
    });
  } catch (error) {
    console.error('发生错误:', error);
    // 截图保存错误状态
    await page.screenshot({
      path: 'user-chat-history-error.png',
      fullPage: true,
    });
  } finally {
    await browser.close();
  }
})();
