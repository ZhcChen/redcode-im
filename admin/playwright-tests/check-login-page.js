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

  // 获取页面HTML内容
  const htmlContent = await page.content();
  console.log('页面HTML内容:', htmlContent.substring(0, 1000));

  // 获取所有输入框
  const inputs = await page.$$('input');
  console.log('找到的输入框数量:', inputs.length);

  // 获取每个输入框的属性
  for (let i = 0; i < inputs.length; i++) {
    const input = inputs[i];
    const placeholder = await input.getAttribute('placeholder');
    const type = await input.getAttribute('type');
    console.log(`输入框 ${i}: type=${type}, placeholder=${placeholder}`);
  }

  await browser.close();
})();
