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
      // 截图保存当前状态
      await page.screenshot({ path: 'login-state.png' });
    } else {
      console.log('登录成功，开始测试聊天记录功能');

      // 5. 查找并点击"聊天记录"菜单项
      // 尝试多种可能的选择器
      const chatMenuSelectors = [
        'text=聊天记录',
        '[data-menu-id*="chat"]',
        'a[href*="chat"]',
        '.arco-menu-item:has-text("聊天记录")',
        'span:has-text("聊天记录")',
      ];

      let chatMenuFound = false;
      for (const selector of chatMenuSelectors) {
        try {
          await page.waitForSelector(selector, { timeout: 2000 });
          await page.click(selector);
          console.log(`已使用选择器 ${selector} 点击聊天记录菜单`);
          chatMenuFound = true;
          break;
        } catch (e) {
          // 继续尝试下一个选择器
        }
      }

      if (!chatMenuFound) {
        console.log('未找到聊天记录菜单，尝试查找侧边栏所有菜单项');
        // 截图保存当前状态
        await page.screenshot({ path: 'dashboard-menu.png' });

        // 获取所有菜单项
        const menuItems = await page.$$eval('.arco-menu-item', (items) =>
          items.map((item) => item.textContent)
        );
        console.log('所有菜单项:', menuItems);
      } else {
        // 等待聊天记录页面加载
        await page.waitForTimeout(3000);

        // 6. 查找并点击聊天记录列表
        const chatListSelectors = [
          '.chat-list-item',
          '.message-item',
          '[data-testid*="chat"]',
          'tr:has-text("用户")',
          '.arco-table-tr',
        ];

        let chatListFound = false;
        for (const selector of chatListSelectors) {
          try {
            await page.waitForSelector(selector, { timeout: 2000 });
            await page.click(selector);
            console.log(`已使用选择器 ${selector} 点击聊天记录列表项`);
            chatListFound = true;
            break;
          } catch (e) {
            // 继续尝试下一个选择器
          }
        }

        if (!chatListFound) {
          console.log('未找到聊天记录列表项，截图保存当前状态');
          await page.screenshot({ path: 'chat-list-page.png' });

          // 获取页面内容
          const pageContent = await page.content();
          console.log('聊天记录页面HTML片段:', pageContent.substring(0, 1000));
        } else {
          // 等待页面加载
          await page.waitForTimeout(3000);

          // 7. 查找并点击"查看用户记录"按钮
          const viewUserRecordSelectors = [
            'text=查看用户记录',
            'button:has-text("查看")',
            '.view-record-btn',
            '[data-action*="view"]',
            'a:has-text("用户记录")',
          ];

          let viewRecordFound = false;
          for (const selector of viewUserRecordSelectors) {
            try {
              await page.waitForSelector(selector, { timeout: 2000 });
              await page.click(selector);
              console.log(`已使用选择器 ${selector} 点击查看用户记录`);
              viewRecordFound = true;
              break;
            } catch (e) {
              // 继续尝试下一个选择器
            }
          }

          if (!viewRecordFound) {
            console.log('未找到查看用户记录按钮，截图保存当前状态');
            await page.screenshot({ path: 'chat-detail-page.png' });
          } else {
            // 等待页面加载
            await page.waitForTimeout(3000);

            // 检查是否有错误
            const errorSelectors = [
              '.arco-alert-error',
              '.error-message',
              '[data-testid*="error"]',
              'text=错误',
              'text=Error',
            ];

            let hasError = false;
            for (const selector of errorSelectors) {
              try {
                const errorElement = await page.$(selector);
                if (errorElement) {
                  const errorText = await errorElement.textContent();
                  console.log(`发现错误信息: ${errorText}`);
                  hasError = true;
                }
              } catch (e) {
                // 继续检查下一个错误选择器
              }
            }

            // 检查控制台错误
            page.on('console', (msg) => {
              if (msg.type() === 'error') {
                console.log('控制台错误:', msg.text());
              }
            });

            // 检查网络请求错误
            page.on('response', (response) => {
              if (response.status() >= 400) {
                console.log(
                  `网络请求错误: ${response.url()} - ${response.status()}`
                );
              }
            });

            // 截图保存最终状态
            await page.screenshot({ path: 'final-user-record.png' });

            if (!hasError) {
              console.log('未发现明显错误，但可能存在其他问题');
            }
          }
        }
      }
    }

    // 等待一段时间以便观察
    await page.waitForTimeout(5000);
  } catch (error) {
    console.error('测试过程中发生错误:', error);
    // 截图保存错误状态
    await page.screenshot({ path: 'error-state.png' });
  } finally {
    await browser.close();
  }
})();
