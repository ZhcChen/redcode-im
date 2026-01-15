const { chromium } = require('playwright');

(async () => {
  const baseUrl = process.env.ADMIN_BASE_URL || 'http://localhost:8011';
  const username = process.env.ADMIN_USERNAME || 'admin';
  const password = process.env.ADMIN_PASSWORD || 'admin123';

  // 使用本地Chrome浏览器
  const browser = await chromium.launch({
    headless: false, // 设置为false以便观察操作
    executablePath:
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  });

  const context = await browser.newContext();
  const page = await context.newPage();

  // 监听控制台消息
  const consoleMessages = [];
  page.on('console', (msg) => {
    consoleMessages.push({
      type: msg.type(),
      text: msg.text(),
      location: msg.location(),
    });
    if (msg.type() === 'error') {
      console.log(`控制台错误: ${msg.text()}`);
    }
  });

  // 监听网络请求
  const networkRequests = [];
  page.on('request', (request) => {
    networkRequests.push({
      url: request.url(),
      method: request.method(),
    });
  });

  page.on('response', (response) => {
    const req = networkRequests.find((r) => r.url === response.url());
    if (req) {
      req.status = response.status();
      req.statusText = response.statusText();
    }

    if (response.status() >= 400) {
      console.log(
        `网络请求错误: ${response.url()} - ${response.status()} ${response.statusText()}`
      );
    }
  });

  try {
    // 1. 打开登录页面
    await page.goto(baseUrl);
    console.log('已打开登录页面');

    // 等待页面加载
    await page.waitForTimeout(2000);

    // 2. 填写登录信息
    await page.fill('input[placeholder="用户名：admin"]', username);
    await page.fill('input[placeholder="密码：admin"]', password);
    console.log('已填写登录信息');

    // 3. 点击登录按钮
    await page.click('button[type="submit"]');
    console.log('已点击登录按钮');

    // 等待登录完成和页面跳转
    await page.waitForTimeout(3000);

    // 4. 检查是否登录成功
    const currentUrl = page.url();
    console.log('登录后URL:', currentUrl);

    if (!currentUrl.includes('dashboard')) {
      console.log('登录可能失败，当前URL:', currentUrl);
      await page.screenshot({ path: 'login-state.png' });
    } else {
      console.log('登录成功，开始测试聊天记录功能');

      // 5. 查找并点击"聊天记录"菜单项
      await page.click('text=聊天记录');
      console.log('已点击聊天记录菜单');

      // 等待聊天记录页面加载
      await page.waitForTimeout(5000);

      // 6. 获取页面标题和URL
      const pageTitle = await page.title();
      const pageUrl = page.url();
      console.log('聊天记录页面标题:', pageTitle);
      console.log('聊天记录页面URL:', pageUrl);

      // 7. 截图保存当前状态
      await page.screenshot({ path: 'chat-records-page.png' });

      // 8. 获取页面主要内容
      const mainContent = await page.$eval('main', (el) => el.textContent);
      console.log('页面主要内容:', mainContent.substring(0, 500));

      // 9. 查找表格或列表
      const hasTable = (await page.$('table')) !== null;
      const hasList = (await page.$('ul, ol, .list')) !== null;
      console.log('页面是否有表格:', hasTable);
      console.log('页面是否有列表:', hasList);

      // 10. 查找可能的错误信息
      const errorSelectors = [
        '.arco-alert-error',
        '.error-message',
        '[data-testid*="error"]',
        'text=错误',
        'text=Error',
        '.arco-empty',
        'text=暂无数据',
      ];

      for (const selector of errorSelectors) {
        try {
          const element = await page.$(selector);
          if (element) {
            const text = await element.textContent();
            console.log(`找到元素 ${selector}: ${text}`);
          }
        } catch (e) {
          // 继续检查下一个选择器
        }
      }

      // 11. 检查是否有加载状态
      const loadingSelectors = [
        '.arco-spin',
        '.loading',
        '[data-loading="true"]',
        'text=加载中',
      ];

      for (const selector of loadingSelectors) {
        try {
          const element = await page.$(selector);
          if (element) {
            console.log(`找到加载状态元素: ${selector}`);
          }
        } catch (e) {
          // 继续检查下一个选择器
        }
      }

      // 12. 获取所有控制台消息
      console.log('\n=== 控制台消息 ===');
      consoleMessages.forEach((msg) => {
        console.log(`[${msg.type}] ${msg.text}`);
      });

      // 13. 获取所有网络请求
      console.log('\n=== 网络请求 ===');
      networkRequests.forEach((req) => {
        console.log(
          `${req.method} ${req.url} - ${req.status || 'Pending'} ${
            req.statusText || ''
          }`
        );
      });

      // 14. 检查API请求
      const apiRequests = networkRequests.filter((req) =>
        req.url.includes('/api/')
      );
      console.log('\n=== API请求 ===');
      apiRequests.forEach((req) => {
        console.log(
          `${req.method} ${req.url} - ${req.status || 'Pending'} ${
            req.statusText || ''
          }`
        );
      });
    }

    // 等待一段时间以便观察
    await page.waitForTimeout(5000);
  } catch (error) {
    console.error('测试过程中发生错误:', error);
    await page.screenshot({ path: 'error-state.png' });
  } finally {
    await browser.close();
  }
})();
