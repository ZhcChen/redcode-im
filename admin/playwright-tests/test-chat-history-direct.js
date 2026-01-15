const { chromium } = require('playwright');
const fs = require('fs');

(async () => {
  const baseUrl = process.env.ADMIN_BASE_URL || 'http://localhost:8011';
  const username = process.env.ADMIN_USERNAME || 'admin';
  const password = process.env.ADMIN_PASSWORD || 'admin123';

  // 使用本地安装的Chrome浏览器
  const browser = await chromium.launch({
    executablePath:
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: false,
  });

  const context = await browser.newContext();
  const page = await context.newPage();

  // 监听网络请求
  const networkRequests = [];
  const networkErrors = [];
  const consoleMessages = [];
  const pageErrors = [];

  // 监听网络请求
  page.on('request', (request) => {
    networkRequests.push({
      url: request.url(),
      method: request.method(),
      headers: request.headers(),
      timestamp: new Date().toISOString(),
    });
  });

  // 监听网络响应
  page.on('response', (response) => {
    const request = networkRequests.find((req) => req.url === response.url());
    if (request) {
      request.status = response.status();
      request.statusText = response.statusText();
      request.responseHeaders = response.headers();
    }
  });

  // 监听网络错误
  page.on('requestfailed', (request) => {
    networkErrors.push({
      url: request.url(),
      method: request.method(),
      failure: request.failure(),
      timestamp: new Date().toISOString(),
    });
  });

  // 监听控制台消息
  page.on('console', (msg) => {
    consoleMessages.push({
      type: msg.type(),
      text: msg.text(),
      location: msg.location(),
      timestamp: new Date().toISOString(),
    });
  });

  // 监听页面错误
  page.on('pageerror', (error) => {
    pageErrors.push({
      message: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString(),
    });
  });

  try {
    // 导航到登录页面
    await page.goto(baseUrl);
    await page.waitForTimeout(2000);

    // 填写用户名
    await page.fill('input[placeholder="用户名：admin"]', username);

    // 填写密码
    await page.fill('input[placeholder="密码：admin"]', password);

    // 点击登录按钮
    await page.click('button[type="submit"]');
    await page.waitForTimeout(3000);

    // 直接导航到聊天记录列表页面
    console.log('导航到聊天记录列表页面...');
    await page.goto(`${baseUrl}/chat-history/list`);
    await page.waitForTimeout(3000);

    // 截图保存聊天记录列表页面
    await page.screenshot({ path: 'chat-history-list-page.png' });

    // 点击"查看用户记录"按钮
    console.log('点击"查看用户记录"按钮...');
    await page.click('button.arco-btn-text:has-text("查看用户记录")');
    await page.waitForTimeout(3000);

    // 截图保存点击"查看用户记录"后的页面
    await page.screenshot({ path: 'user-records-page.png' });

    // 点击"用户消息"标签
    console.log('点击"用户消息"标签...');
    await page.click('div.arco-tabs-tab:has-text("用户消息")');
    await page.waitForTimeout(3000);

    // 截图保存点击"用户消息"后的页面
    await page.screenshot({ path: 'user-messages-page.png' });

    // 获取当前URL
    const currentUrl = page.url();
    console.log('最终URL:', currentUrl);
  } catch (error) {
    console.error('执行过程中发生错误:', error);
    // 截图保存错误状态
    await page.screenshot({ path: 'error-screenshot.png' });
  }

  // 保存网络请求和错误信息到文件
  const analysisData = {
    networkRequests,
    networkErrors,
    consoleMessages,
    pageErrors,
    timestamp: new Date().toISOString(),
  };

  fs.writeFileSync(
    'chat-history-network-analysis.json',
    JSON.stringify(analysisData, null, 2)
  );

  // 输出关键信息到控制台
  console.log('\n=== 网络请求分析 ===');
  console.log(`总请求数: ${networkRequests.length}`);
  console.log(`网络错误数: ${networkErrors.length}`);
  console.log(`控制台消息数: ${consoleMessages.length}`);
  console.log(`页面错误数: ${pageErrors.length}`);

  if (networkErrors.length > 0) {
    console.log('\n=== 网络错误详情 ===');
    networkErrors.forEach((error, index) => {
      console.log(`错误 ${index + 1}:`);
      console.log(`  URL: ${error.url}`);
      console.log(`  方法: ${error.method}`);
      console.log(
        `  失败原因: ${error.failure ? error.failure.errorText : '未知'}`
      );
      console.log(`  时间: ${error.timestamp}`);
    });
  }

  if (pageErrors.length > 0) {
    console.log('\n=== 页面错误详情 ===');
    pageErrors.forEach((error, index) => {
      console.log(`错误 ${index + 1}:`);
      console.log(`  消息: ${error.message}`);
      console.log(`  时间: ${error.timestamp}`);
      if (error.stack) {
        console.log(`  堆栈: ${error.stack}`);
      }
    });
  }

  // 输出控制台错误和警告
  const errorMessages = consoleMessages.filter(
    (msg) => msg.type === 'error' || msg.type === 'warning'
  );
  if (errorMessages.length > 0) {
    console.log('\n=== 控制台错误和警告 ===');
    errorMessages.forEach((msg, index) => {
      console.log(`${msg.type.toUpperCase()} ${index + 1}:`);
      console.log(`  消息: ${msg.text}`);
      console.log(`  时间: ${msg.timestamp}`);
      if (msg.location) {
        console.log(`  位置: ${msg.location.url}:${msg.location.lineNumber}`);
      }
    });
  }

  await browser.close();
})();
