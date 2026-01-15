const { chromium } = require('playwright');

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

  const page = await browser.newPage();

  // 导航到登录页面
  await page.goto(baseUrl);

  // 等待页面加载
  await page.waitForTimeout(2000);

  // 填写用户名
  await page.fill('input[placeholder="用户名"]', username);

  // 填写密码
  await page.fill('input[type="password"]', password);

  // 点击登录按钮
  await page.click('button[type="submit"]');

  // 等待登录完成
  await page.waitForTimeout(3000);

  // 截图
  await page.screenshot({ path: 'after-login.png' });

  // 获取当前URL，检查是否登录成功
  const currentUrl = page.url();
  console.log('登录后URL:', currentUrl);

  // 检查是否包含登录成功的标志
  const hasLoginSuccess = await page
    .locator('text=登录成功')
    .isVisible()
    .catch(() => false);
  console.log('登录成功提示:', hasLoginSuccess);

  await browser.close();
})();
