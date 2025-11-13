const { chromium } = require('playwright');

/**
 * 测试用户消息标签页功能
 * 流程：
 * 1. 登录管理后台
 * 2. 展开聊天记录菜单
 * 3. 点击聊天记录列表菜单
 * 4. 在列表页面点击"查看用户记录"按钮
 * 5. 在用户记录页面点击"用户消息"标签页
 * 6. 检查是否有报错
 */
async function testUserMessagesTab() {
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  // 监听控制台输出
  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      console.log('控制台错误:', msg.text());
    }
  });

  // 监听网络请求
  page.on('response', (response) => {
    if (response.url().includes('/api/admin/chat-history')) {
      console.log(
        '聊天记录API响应:',
        response.url(),
        '状态码:',
        response.status()
      );
    }
  });

  try {
    // 1. 登录管理后台
    console.log('步骤1: 登录管理后台');
    await page.goto('http://localhost:8011/login');
    await page.waitForLoadState('networkidle');

    // 使用正确的选择器填写登录信息
    await page.fill('input[placeholder*="用户"]', 'admin');
    await page.fill('input[placeholder*="密码"]', 'admin123');
    await page.click('button[type="submit"]');

    // 等待登录成功
    await page.waitForURL('**/dashboard/workplace');
    console.log('登录成功，当前URL:', page.url());

    // 2. 点击聊天记录菜单
    console.log('步骤2: 点击聊天记录菜单');
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
            // 打印页面内容以便调试
            const pageContent = await page.content();
            console.log('页面内容片段:', pageContent.substring(0, 1000));
            throw new Error('未找到聊天记录菜单');
          }
        }
      }
    }

    // 3. 等待页面加载
    console.log('步骤3: 等待页面加载');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(3000); // 增加等待时间

    // 截图当前页面
    await page.screenshot({ path: 'chat-records-page.png', fullPage: true });

    // 检查页面内容
    const pageTitle = await page.title();
    console.log('页面标题:', pageTitle);
    console.log('当前URL:', page.url());

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

    // 4. 查找"查看用户记录"按钮
    console.log('步骤4: 查找"查看用户记录"按钮');

    // 尝试多种选择器查找"查看用户记录"按钮
    const viewUserRecordSelectors = [
      'button:has-text("查看用户记录")',
      'button:has-text("用户记录")',
      'a:has-text("查看用户记录")',
      'a:has-text("用户记录")',
      'button:has-text("查看用户")',
      'a:has-text("查看用户")',
      'button:has-text("用户消息")',
      'a:has-text("用户消息")',
      'button[title*="查看用户记录"]',
      'a[title*="查看用户记录"]',
      '.arco-btn:has-text("查看用户记录")',
      '.arco-btn:has-text("用户记录")',
    ];

    let viewUserRecordButton = null;
    for (const selector of viewUserRecordSelectors) {
      try {
        const element = await page.locator(selector).first();
        if (await element.isVisible({ timeout: 2000 })) {
          viewUserRecordButton = element;
          console.log(`找到"查看用户记录"按钮，使用选择器: ${selector}`);
          break;
        }
      } catch (e) {
        // 继续尝试下一个选择器
      }
    }

    if (!viewUserRecordButton) {
      // 打印页面内容以便调试
      const pageContent = await page.content();
      console.log('页面内容片段:', pageContent.substring(0, 1000));

      // 输出页面中所有按钮的文本
      const allButtons = await page
        .locator('button, a[role="button"], .arco-btn')
        .all();
      console.log('页面中的按钮数量:', allButtons.length);
      for (let i = 0; i < Math.min(allButtons.length, 10); i++) {
        try {
          const buttonText = await allButtons[i].textContent();
          console.log(`按钮 ${i + 1}: "${buttonText}"`);
        } catch (e) {
          console.log(`按钮 ${i + 1}: 无法获取文本`);
        }
      }

      throw new Error('未找到"查看用户记录"按钮');
    }

    // 点击"查看用户记录"按钮
    await viewUserRecordButton.click();
    await page.waitForTimeout(2000); // 增加等待时间

    // 5. 在用户记录页面点击"用户消息"标签页
    console.log('步骤5: 点击"用户消息"标签页');

    // 等待标签页导航加载
    await page.waitForSelector('.arco-tabs-nav', { timeout: 10000 });

    // 查找"用户消息"标签页
    const userMessagesTab = await page
      .locator('.arco-tabs-tab')
      .filter({ hasText: '用户消息' })
      .first();
    if (await userMessagesTab.isVisible()) {
      console.log('找到"用户消息"标签页，点击...');
      await userMessagesTab.click();
      await page.waitForTimeout(2000); // 等待标签页切换和数据加载
    } else {
      throw new Error('未找到"用户消息"标签页');
    }

    // 6. 检查是否有报错
    console.log('步骤6: 检查页面是否有报错');

    // 检查是否有错误信息
    const hasError = await page
      .locator('.arco-message-error, .arco-alert-error, .error-message')
      .isVisible();
    console.log('页面中是否有错误信息:', hasError);

    if (hasError) {
      const errorText = await page
        .locator('.arco-message-error, .arco-alert-error, .error-message')
        .textContent();
      console.log('错误信息:', errorText);
    }

    // 检查是否有消息数据
    const messageRows = await page.locator('table tbody tr').count();
    console.log('消息行数:', messageRows);

    // 截图保存
    await page.screenshot({
      path: 'user-messages-tab-result.png',
      fullPage: true,
    });
    console.log('截图已保存为 user-messages-tab-result.png');

    // 等待一段时间以观察网络请求
    await page.waitForTimeout(3000);
  } catch (error) {
    console.error('测试过程中出错:', error);
    await page.screenshot({
      path: 'user-messages-tab-error.png',
      fullPage: true,
    });
    console.log('错误截图已保存为 user-messages-tab-error.png');
  } finally {
    await browser.close();
  }
}

testUserMessagesTab();
