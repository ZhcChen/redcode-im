/**
 * 头像上传自动化测试
 * 目的：验证头像上传后是否正确更新到 store 和后端
 */

import { store } from '../store';
import { FileApi } from '../api/file';
import { RustUserApi } from '../api/rust-user';

interface TestResult {
  step: string;
  success: boolean;
  data?: any;
  error?: string;
}

const testResults: TestResult[] = [];

/**
 * 记录测试步骤
 */
function logStep(step: string, success: boolean, data?: any, error?: string) {
  const result: TestResult = { step, success, data, error };
  testResults.push(result);

  const icon = success ? '✅' : '❌';
  console.log(`${icon} [测试] ${step}`);
  if (data) console.log('   数据:', JSON.stringify(data, null, 2));
  if (error) console.error('   错误:', error);
}

/**
 * 创建测试用的图片文件
 */
function createTestImageFile(): File {
  // 创建一个 1x1 的红色像素的 PNG 图片
  const canvas = document.createElement('canvas');
  canvas.width = 1;
  canvas.height = 1;
  const ctx = canvas.getContext('2d');
  if (ctx) {
    ctx.fillStyle = 'red';
    ctx.fillRect(0, 0, 1, 1);
  }

  // 将 canvas 转换为 Blob
  return new Promise<File>((resolve) => {
    canvas.toBlob((blob) => {
      if (blob) {
        const file = new File([blob], 'test-avatar.png', { type: 'image/png' });
        resolve(file);
      }
    }, 'image/png');
  }) as any;
}

/**
 * 步骤 1: 获取当前用户头像信息
 */
async function step1_getCurrentAvatar() {
  try {
    const currentUser = store.getters.currentUser;
    const avatarData = {
      avatar: currentUser.avatar,
      avatarObjectKey: currentUser.avatarObjectKey,
      avatarLocalPath: currentUser.avatarLocalPath,
      userId: currentUser.id,
      username: currentUser.username
    };

    logStep('获取当前用户头像信息', true, avatarData);
    return avatarData;
  } catch (error: any) {
    logStep('获取当前用户头像信息', false, undefined, error.message);
    throw error;
  }
}

/**
 * 步骤 2: 上传新头像
 */
async function step2_uploadNewAvatar(file: File) {
  try {
    console.log('[测试] 📤 开始上传头像文件:', {
      name: file.name,
      size: file.size,
      type: file.type
    });

    const uploadResult = await FileApi.uploadFile({
      file,
      category: 'avatar',
      isPublic: true,
      description: '测试头像'
    });

    logStep('上传新头像', uploadResult.code === 200, {
      code: uploadResult.code,
      message: uploadResult.message,
      fileUrl: uploadResult.data?.fileUrl,
      objectKey: uploadResult.data?.objectKey,
      localPath: uploadResult.data?.localPath
    });

    return uploadResult;
  } catch (error: any) {
    logStep('上传新头像', false, undefined, error.message);
    throw error;
  }
}

/**
 * 步骤 3: 检查 store 是否更新
 */
async function step3_checkStoreUpdate(uploadResult: any) {
  try {
    // 等待一下，确保 store 有时间更新
    await new Promise(resolve => setTimeout(resolve, 100));

    const currentUser = store.getters.currentUser;
    const storeData = {
      avatar: currentUser.avatar,
      avatarObjectKey: currentUser.avatarObjectKey,
      avatarLocalPath: currentUser.avatarLocalPath
    };

    const isUpdated =
      currentUser.avatar === uploadResult.data?.fileUrl &&
      currentUser.avatarObjectKey === uploadResult.data?.objectKey &&
      currentUser.avatarLocalPath === uploadResult.data?.localPath;

    logStep('检查 store 是否更新', isUpdated, {
      expected: {
        avatar: uploadResult.data?.fileUrl,
        avatarObjectKey: uploadResult.data?.objectKey,
        avatarLocalPath: uploadResult.data?.localPath
      },
      actual: storeData,
      matched: isUpdated
    });

    return { storeData, isUpdated };
  } catch (error: any) {
    logStep('检查 store 是否更新', false, undefined, error.message);
    throw error;
  }
}

/**
 * 步骤 4: 检查后端用户信息是否更新
 */
async function step4_checkBackendUpdate(uploadResult: any) {
  try {
    console.log('[测试] 🔍 检查后端用户信息...');

    // 重新获取用户信息
    const userInfoResponse = await RustUserApi.getUserAccountInfo();

    if (!userInfoResponse.success || !userInfoResponse.data) {
      throw new Error('获取用户信息失败: ' + userInfoResponse.message);
    }

    const backendData = {
      avatar: userInfoResponse.data.avatar,
      avatarObjectKey: userInfoResponse.data.avatarObjectKey,
      avatarLocalPath: userInfoResponse.data.avatarLocalPath
    };

    const isUpdated =
      userInfoResponse.data.avatar === uploadResult.data?.fileUrl;

    logStep('检查后端用户信息是否更新', isUpdated, {
      expected: {
        avatar: uploadResult.data?.fileUrl,
        avatarObjectKey: uploadResult.data?.objectKey,
        localPath: uploadResult.data?.localPath
      },
      actual: backendData,
      matched: isUpdated
    });

    return { backendData, isUpdated };
  } catch (error: any) {
    logStep('检查后端用户信息是否更新', false, undefined, error.message);
    throw error;
  }
}

/**
 * 步骤 5: 模拟重启应用（重新登录）
 */
async function step5_simulateRestart(originalAvatar: any) {
  try {
    console.log('[测试] 🔄 模拟重启应用（重新获取用户信息）...');

    // 模拟登录流程：重新获取用户信息
    const userInfoResponse = await RustUserApi.getUserAccountInfo();

    if (!userInfoResponse.success || !userInfoResponse.data) {
      throw new Error('重新获取用户信息失败: ' + userInfoResponse.message);
    }

    const afterRestartData = {
      avatar: userInfoResponse.data.avatar,
      avatarObjectKey: userInfoResponse.data.avatarObjectKey,
      avatarLocalPath: userInfoResponse.data.avatarLocalPath
    };

    // 检查是否恢复成原来的头像
    const isReverted =
      userInfoResponse.data.avatar === originalAvatar.avatar;

    logStep('模拟重启应用', true, {
      original: originalAvatar,
      afterRestart: afterRestartData,
      isReverted,
      问题: isReverted ? '❌ 头像恢复成旧的了！' : '✅ 头像保持为新的'
    });

    return { afterRestartData, isReverted };
  } catch (error: any) {
    logStep('模拟重启应用', false, undefined, error.message);
    throw error;
  }
}

/**
 * 主测试流程
 */
export async function runAvatarUploadTest() {
  console.log('\n=================================');
  console.log('🧪 开始头像上传自动化测试');
  console.log('=================================\n');

  try {
    // 步骤 1: 获取当前头像
    console.log('\n📋 步骤 1: 获取当前用户头像信息');
    const originalAvatar = await step1_getCurrentAvatar();

    // 步骤 2: 上传新头像
    console.log('\n📋 步骤 2: 上传新头像');
    const testFile = createTestImageFile();
    const uploadResult = await step2_uploadNewAvatar(testFile);

    // 步骤 3: 检查 store 是否更新
    console.log('\n📋 步骤 3: 检查 Vuex store 是否更新');
    const { isUpdated: storeUpdated } = await step3_checkStoreUpdate(uploadResult);

    // 步骤 4: 检查后端是否更新
    console.log('\n📋 步骤 4: 检查后端用户信息是否更新');
    const { isUpdated: backendUpdated } = await step4_checkBackendUpdate(uploadResult);

    // 步骤 5: 模拟重启
    console.log('\n📋 步骤 5: 模拟重启应用（重新获取用户信息）');
    const { isReverted } = await step5_simulateRestart(originalAvatar);

    // 生成测试报告
    console.log('\n=================================');
    console.log('📊 测试结果汇总');
    console.log('=================================\n');

    console.log('测试步骤执行情况:');
    testResults.forEach((result, index) => {
      const icon = result.success ? '✅' : '❌';
      console.log(`${index + 1}. ${icon} ${result.step}`);
    });

    console.log('\n问题分析:');
    if (!storeUpdated) {
      console.error('❌ 问题 1: Settings.vue 上传后没有更新 Vuex store');
      console.error('   原因: 缺少 store.commit("UPDATE_USER_INFO") 调用');
      console.error('   位置: src/views/Settings.vue:298 左右');
    } else {
      console.log('✅ Vuex store 更新正常');
    }

    if (!backendUpdated) {
      console.error('❌ 问题 2: 后端用户信息没有更新');
      console.error('   原因: RustUserApi.uploadAvatar() 只上传文件，不更新用户资料表');
      console.error('   建议: 需要在上传后调用 RustUserApi.updateUserInfo() 更新用户头像字段');
    } else {
      console.log('✅ 后端用户信息更新正常');
    }

    if (isReverted) {
      console.error('❌ 问题 3: 重启应用后头像恢复成旧的');
      console.error('   原因: 后端用户资料表没有更新，重新登录时获取的还是旧头像');
      console.error('   影响: 每次重启都会丢失头像更新');
    } else {
      console.log('✅ 重启应用后头像保持正常');
    }

    console.log('\n推荐修复方案:');
    if (!storeUpdated || !backendUpdated) {
      console.log('1. 在 Settings.vue 中，上传成功后添加:');
      console.log('   store.commit("UPDATE_USER_INFO", {');
      console.log('     avatar: uploadResult.data.fileUrl,');
      console.log('     avatarObjectKey: uploadResult.data.objectKey || null,');
      console.log('     avatarLocalPath: uploadResult.data.localPath || null');
      console.log('   })');
      console.log('');
      console.log('2. 检查 RustUserApi.uploadAvatar() 是否同时更新用户资料表');
      console.log('   如果没有，需要在 Rust 后端添加用户资料更新逻辑');
    }

    console.log('\n=================================\n');

    return {
      success: storeUpdated && backendUpdated && !isReverted,
      storeUpdated,
      backendUpdated,
      isReverted,
      testResults
    };

  } catch (error: any) {
    console.error('\n❌ 测试过程中发生错误:', error);
    console.error('错误堆栈:', error.stack);

    console.log('\n测试步骤执行情况:');
    testResults.forEach((result, index) => {
      const icon = result.success ? '✅' : '❌';
      console.log(`${index + 1}. ${icon} ${result.step}`);
    });

    return {
      success: false,
      error: error.message,
      testResults
    };
  }
}

// 导出测试函数到全局，方便在控制台调用
if (typeof window !== 'undefined') {
  (window as any).runAvatarUploadTest = runAvatarUploadTest;
  console.log('✅ 头像上传测试已加载');
  console.log('💡 在控制台运行: window.runAvatarUploadTest()');
}
