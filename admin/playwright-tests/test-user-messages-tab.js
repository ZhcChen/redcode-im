const { chromium } = require('playwright');

async function testUserMessagesTab() {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    // 登录管理后台
    await page.goto('http://localhost:8011/login', {
      waitUntil: 'networkidle',
    });
    await page.waitForTimeout(2000); // 等待页面完全加载

    // 获取页面HTML内容以便调试
    const pageContent = await page.content();
    console.log('登录页面HTML片段:', pageContent.substring(0, 500));

    // 尝试多种选择器来找到用户名输入框
    const selectors = [
      'input[placeholder="用户名"]',
      'input[placeholder*="用户"]',
      'input[type="text"]',
      'input[name="username"]',
      'input[name="user"]',
      '.el-input__inner',
      'input',
    ];

    let usernameInputFound = false;
    for (const selector of selectors) {
      try {
        const isVisible = await page.locator(selector).isVisible();
        if (isVisible) {
          console.log(`找到用户名输入框，使用选择器: ${selector}`);
          await page.fill(selector, 'admin');
          usernameInputFound = true;
          break;
        }
      } catch (e) {
        // 继续尝试下一个选择器
      }
    }

    if (!usernameInputFound) {
      throw new Error('无法找到用户名输入框');
    }

    // 尝试多种选择器来找到密码输入框
    const passwordSelectors = [
      'input[placeholder="密码"]',
      'input[placeholder*="密"]',
      'input[type="password"]',
      'input[name="password"]',
      'input[name="pass"]',
    ];

    let passwordInputFound = false;
    for (const selector of passwordSelectors) {
      try {
        const isVisible = await page.locator(selector).isVisible();
        if (isVisible) {
          console.log(`找到密码输入框，使用选择器: ${selector}`);
          await page.fill(selector, 'admin123');
          passwordInputFound = true;
          break;
        }
      } catch (e) {
        // 继续尝试下一个选择器
      }
    }

    if (!passwordInputFound) {
      throw new Error('无法找到密码输入框');
    }

    // 尝试多种选择器来找到提交按钮
    const buttonSelectors = [
      'button[type="submit"]',
      'button:has-text("登录")',
      'button:has-text("登入")',
      'button:has-text("Login")',
      '.el-button--primary',
      'button',
    ];

    let buttonFound = false;
    for (const selector of buttonSelectors) {
      try {
        const isVisible = await page.locator(selector).isVisible();
        if (isVisible) {
          console.log(`找到登录按钮，使用选择器: ${selector}`);
          await page.click(selector);
          buttonFound = true;
          break;
        }
      } catch (e) {
        // 继续尝试下一个选择器
      }
    }

    if (!buttonFound) {
      throw new Error('无法找到登录按钮');
    }

    await page.waitForURL('**/dashboard/workplace', { timeout: 10000 });
    console.log('登录成功，当前URL:', page.url());

    // 导航到聊天记录页面
    console.log('导航到聊天记录页面...');
    await page.goto('http://localhost:8011/chat-history', {
      waitUntil: 'networkidle',
    });
    await page.waitForTimeout(2000); // 等待页面完全加载

    // 获取页面HTML内容以便调试
    const chatHistoryContent = await page.content();
    console.log('聊天记录页面HTML片段:', chatHistoryContent.substring(0, 500));

    // 尝试多种选择器来找到"查看用户记录"按钮
    const userRecordSelectors = [
      'text=查看用户记录',
      'button:has-text("查看用户记录")',
      'a:has-text("查看用户记录")',
      '[data-testid="view-user-records"]',
      '.view-user-records',
    ];

    let userRecordButtonFound = false;
    for (const selector of userRecordSelectors) {
      try {
        const isVisible = await page.locator(selector).isVisible();
        if (isVisible) {
          console.log(`找到"查看用户记录"按钮，使用选择器: ${selector}`);
          await page.click(selector);
          userRecordButtonFound = true;
          break;
        }
      } catch (e) {
        // 继续尝试下一个选择器
      }
    }

    if (!userRecordButtonFound) {
      throw new Error('无法找到"查看用户记录"按钮');
    }

    await page.waitForURL(
      'http://localhost:8011/chat-history/user/0192c3a0-0000-7000-8000-000000000001',
      { timeout: 10000 }
    );
    await page.waitForTimeout(2000); // 等待页面完全加载

    // 获取用户记录页面HTML内容以便调试
    const userRecordContent = await page.content();
    console.log('用户记录页面HTML片段:', userRecordContent.substring(0, 500));

    // 尝试多种选择器来找到标签页导航
    const tabSelectors = [
      '.arco-tabs-nav',
      '.arco-tabs-tab',
      '.tabs-nav',
      '.tab-nav',
      '[role="tablist"]',
    ];

    let tabNavFound = false;
    for (const selector of tabSelectors) {
      try {
        const isVisible = await page.locator(selector).isVisible();
        if (isVisible) {
          console.log(`找到标签页导航，使用选择器: ${selector}`);
          tabNavFound = true;
          break;
        }
      } catch (e) {
        // 继续尝试下一个选择器
      }
    }

    if (!tabNavFound) {
      console.log('未找到标签页导航，继续执行...');
    }

    // 等待用户房间列表加载完成
    await page.waitForSelector('table', { timeout: 10000 });

    // 点击"用户消息"标签页
    console.log('点击"用户消息"标签页...');
    await page.click('text=用户消息');
    await page.waitForTimeout(2000); // 等待标签页切换和数据加载

    // 检查是否有错误信息
    const hasError = await page.locator('.arco-message-error').isVisible();
    console.log('页面中是否有错误信息:', hasError);

    // 检查API请求
    page.on('response', (response) => {
      if (response.url().includes('/api/admin/chat-history')) {
        console.log('API请求:', response.url(), '状态码:', response.status());
      }
    });

    // 等待用户消息列表加载
    await page.waitForSelector('table', { timeout: 10000 }).catch(() => {
      console.log('等待用户消息列表超时');
    });

    // 获取当前URL
    const currentUrl = page.url();
    console.log('当前URL:', currentUrl);

    // 获取页面标题
    const title = await page.title();
    console.log('页面标题:', title);

    // 检查是否有消息数据
    const messageRows = await page.locator('table tbody tr').count();
    console.log('消息行数:', messageRows);

    // 截图
    await page.screenshot({ path: 'user-messages-tab.png', fullPage: true });
    console.log('截图已保存为 user-messages-tab.png');

    // 尝试使用搜索功能
    await page.fill('input[placeholder="关键词"]', 'test');
    await page.click('text=搜索');
    await page.waitForTimeout(2000);

    // 再次检查消息行数
    const searchMessageRows = await page.locator('table tbody tr').count();
    console.log('搜索后消息行数:', searchMessageRows);

    // 检查控制台错误
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        console.log('控制台错误:', msg.text());
      }
    });

    await page.waitForTimeout(3000);
  } catch (error) {
    console.error('测试过程中出错:', error);
  } finally {
    await browser.close();
  }
}

testUserMessagesTab();
