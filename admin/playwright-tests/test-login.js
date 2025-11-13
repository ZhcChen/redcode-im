const { chromium } = require('playwright');

(async () => {
  // 使用本地安装的Chrome浏览器
  const browser = await chromium.launch({
    executablePath:
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: false,
  });

  const page = await browser.newPage();

  // 导航到登录页面
  await page.goto('http://localhost:8011');

  // 等待页面加载
  await page.waitForTimeout(2000);

  // 截图
  await page.screenshot({ path: 'login-page.png' });

  console.log('已成功打开登录页面并截图');

  await browser.close();
})();
