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

    // 检查页面上的所有输入框
    const inputs = await page.$$('input');
    console.log(`找到 ${inputs.length} 个输入框`);

    for (let i = 0; i < inputs.length; i++) {
      const input = inputs[i];
      const placeholder = await input.getAttribute('placeholder');
      const type = await input.getAttribute('type');
      const id = await input.getAttribute('id');
      console.log(
        `输入框 ${i}: placeholder="${placeholder}", type="${type}", id="${id}"`
      );
    }

    // 检查所有按钮
    const buttons = await page.$$('button');
    console.log(`找到 ${buttons.length} 个按钮`);

    for (let i = 0; i < buttons.length; i++) {
      const button = buttons[i];
      const text = await button.textContent();
      const type = await button.getAttribute('type');
      console.log(`按钮 ${i}: text="${text}", type="${type}"`);
    }

    // 等待一段时间以便观察
    await page.waitForTimeout(5000);
  } catch (error) {
    console.error('测试过程中发生错误:', error);
  } finally {
    // 关闭浏览器
    await browser.close();
  }
})();
