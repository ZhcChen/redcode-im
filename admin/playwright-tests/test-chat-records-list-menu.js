const { chromium } = require('playwright');

(async () => {
  // 启动浏览器
  const browser = await chromium.launch({
    headless: false,
    executablePath:
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  });

  // 创建页面
  const page = await browser.newPage();

  // 监听控制台输出
  page.on('console', (msg) => {
    console.log('PAGE LOG:', msg.text());
  });

  // 监听网络请求
  page.on('response', (response) => {
    if (response.url().includes('/api/admin')) {
      console.log('API RESPONSE:', response.url(), response.status());
    }
  });

  // 监听页面错误
  page.on('pageerror', (error) => {
    console.error('PAGE ERROR:', error.message);
  });

  try {
    // 访问登录页面
    await page.goto('http://localhost:8011/login');

    // 等待页面加载
    await page.waitForLoadState('networkidle');

    // 截图登录页面
    await page.screenshot({ path: 'login-page.png', fullPage: true });

    // 填写登录信息 - 使用正确的placeholder属性
    await page.fill('input[placeholder="用户名：admin"]', 'admin');
    await page.fill('input[placeholder="密码：admin"]', 'admin123');

    // 点击登录按钮
    await page.click('button[type="submit"]');

    // 等待登录成功并跳转
    await page.waitForNavigation();

    // 截图登录后的页面
    await page.screenshot({ path: 'after-login.png', fullPage: true });

    console.log('登录成功，当前URL:', page.url());

    // 等待侧边栏加载
    await page.waitForSelector('.arco-layout-sider', { timeout: 10000 });

    // 尝试多种方式点击聊天记录菜单
    console.log('尝试点击聊天记录菜单...');

    // 方法1: 通过文本内容查找
    const chatHistoryLink = await page.locator('text=聊天记录').first();
    if (await chatHistoryLink.isVisible()) {
      console.log('找到聊天记录菜单，点击...');
      await chatHistoryLink.click();
    } else {
      // 方法2: 通过菜单项的类名查找
      const menuItem = await page
        .locator('.arco-menu-item')
        .filter({ hasText: '聊天记录' })
        .first();
      if (await menuItem.isVisible()) {
        console.log('通过类名找到聊天记录菜单，点击...');
        await menuItem.click();
      } else {
        // 方法3: 通过更通用的选择器
        const menuLink = await page.locator('a[href*="chat-history"]').first();
        if (await menuLink.isVisible()) {
          console.log('通过链接找到聊天记录菜单，点击...');
          await menuLink.click();
        } else {
          // 方法4: 通过父级菜单项
          const parentMenuItem = await page
            .locator('.arco-menu-submenu-title')
            .filter({ hasText: '聊天记录' })
            .first();
          if (await parentMenuItem.isVisible()) {
            console.log('找到聊天记录父菜单，点击展开...');
            await parentMenuItem.click();

            // 等待子菜单展开
            await page.waitForTimeout(500);

            // 点击子菜单中的列表项
            const listMenuItem = await page
              .locator('.arco-menu-item')
              .filter({ hasText: '列表' })
              .first();
            if (await listMenuItem.isVisible()) {
              console.log('找到聊天记录列表子菜单，点击...');
              await listMenuItem.click();
            } else {
              console.log('未找到聊天记录列表子菜单');
            }
          } else {
            console.log('未找到聊天记录菜单');
          }
        }
      }
    }

    // 等待页面加载
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);

    // 截图聊天记录页面
    await page.screenshot({
      path: 'chat-records-list-page.png',
      fullPage: true,
    });

    // 检查页面内容
    const pageTitle = await page.title();
    console.log('页面标题:', pageTitle);

    // 检查是否有错误信息
    const errorElements = await page
      .locator('.arco-alert-error, .error-message, [class*="error"]')
      .count();
    if (errorElements > 0) {
      console.log('发现', errorElements, '个错误元素');
      for (let i = 0; i < errorElements; i++) {
        const errorText = await page
          .locator('.arco-alert-error, .error-message, [class*="error"]')
          .nth(i)
          .textContent();
        console.log('错误内容:', errorText);
      }
    }

    // 检查是否有表格或列表
    const tableExists =
      (await page.locator('.arco-table, .arco-list').count()) > 0;
    console.log('页面中是否有表格或列表:', tableExists);

    // 检查API请求
    console.log('检查API请求...');
  } catch (error) {
    console.error('发生错误:', error);
    await page.screenshot({ path: 'error-screenshot.png', fullPage: true });
  } finally {
    // 关闭浏览器
    await browser.close();
  }
})();
