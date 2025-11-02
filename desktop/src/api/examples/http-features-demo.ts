/**
 * HTTP 客户端新功能使用示例
 * 演示拦截器和重试机制的使用方法
 */

import { 
  httpClient, 
  addRequestInterceptor, 
  addResponseInterceptor, 
  addErrorInterceptor,
  post,
  get
} from '../http';

// ============= 拦截器使用示例 =============

// 1. 添加认证拦截器
addRequestInterceptor((config) => {
  // 自动添加认证头
  const token = localStorage.getItem('auth_token');
  if (token) {
    return {
      ...config,
      headers: {
        ...config.headers,
        'Authorization': `Bearer ${token}`
      }
    };
  }
  return config;
});

// 2. 添加加载状态拦截器
addRequestInterceptor((config) => {
  // 显示加载动画
  console.log('显示加载动画...');
  return config;
});

addResponseInterceptor((response) => {
  // 隐藏加载动画
  console.log('隐藏加载动画...');
  return response;
});

// 3. 添加响应数据处理拦截器
addResponseInterceptor((response) => {
  // 统一处理时间戳格式
  if (response.data && typeof response.data === 'object') {
    // 递归处理所有时间字段
    const processTimeFields = (obj: any): any => {
      if (Array.isArray(obj)) {
        return obj.map(processTimeFields);
      }
      
      if (obj && typeof obj === 'object') {
        const processed: any = {};
        Object.keys(obj).forEach(key => {
          if (key.includes('Time') && typeof obj[key] === 'string') {
            // 转换时间格式
            processed[key] = new Date(obj[key]).toLocaleString();
          } else {
            processed[key] = processTimeFields(obj[key]);
          }
        });
        return processed;
      }
      
      return obj;
    };

    return {
      ...response,
      data: processTimeFields(response.data)
    };
  }
  
  return response;
});

// 4. 添加错误处理拦截器
addErrorInterceptor((error) => {
  // 自定义错误消息
  if (error.message.includes('HTTP 404')) {
    return new Error('请求的资源不存在');
  }
  
  if (error.message.includes('网络错误')) {
    return new Error('网络连接失败，请检查您的网络设置');
  }
  
  return error;
});

// ============= 重试机制使用示例 =============

// 示例1：使用默认重试配置
export async function loginWithRetry(username: string, password: string) {
  try {
    const result = await post('sys/login', {
      username,
      password
    });
    
    console.log('登录成功:', result);
    return result;
  } catch (error) {
    console.error('登录失败（已自动重试）:', error);
    throw error;
  }
}

// 示例2：自定义重试配置
export async function uploadFileWithCustomRetry(file: File) {
  try {
    const result = await httpClient.upload('file/upload', file, undefined);
    
    console.log('文件上传成功:', result);
    return result;
  } catch (error) {
    console.error('文件上传失败:', error);
    throw error;
  }
}

// 示例3：禁用重试的请求
export async function getRealtimeData() {
  try {
    // 实时数据请求，不需要重试
    const result = await httpClient.get('realtime/data', {
      retry: false // 禁用重试
    });
    
    return result;
  } catch (error) {
    console.error('获取实时数据失败:', error);
    throw error;
  }
}

// 示例4：高重试次数的关键请求
export async function criticalOperation(data: any) {
  try {
    const result = await httpClient.post('critical/operation', data, {
      retryTimes: 5, // 重试5次
      retryDelay: 2000 // 每次间隔2秒
    });
    
    return result;
  } catch (error) {
    console.error('关键操作失败:', error);
    throw error;
  }
}

// ============= 使用场景示例 =============

// 场景1：用户登录流程
export async function userLoginFlow() {
  try {
    // 1. 发送登录请求（自动重试 + 认证拦截器）
    const loginResult = await loginWithRetry('testuser', 'password123');
    
    // 2. 保存token（认证拦截器会自动使用）
    localStorage.setItem('auth_token', (loginResult.data as any).token);
    
    // 3. 获取用户信息（自动添加认证头）
    const userInfo = await get('user/info');
    
    console.log('用户登录完成:', userInfo);
    
  } catch (error) {
    console.error('登录流程失败:', error);
  }
}

// 场景2：文件上传进度
export async function fileUploadWithProgress(file: File) {
  // 添加上传进度拦截器
  const progressInterceptor = (config: any) => {
    console.log(`开始上传文件: ${file.name} (${file.size} bytes)`);
    return config;
  };
  
  const responseInterceptor = (response: any) => {
    if (response.success) {
      console.log(`文件上传完成: ${file.name}`);
    }
    return response;
  };
  
  // 临时添加拦截器
  addRequestInterceptor(progressInterceptor);
  addResponseInterceptor(responseInterceptor);
  
  try {
    const result = await uploadFileWithCustomRetry(file);
    return result;
  } finally {
    // 注意：实际使用中需要提供移除特定拦截器的方法
    // 这里仅为示例
  }
}

// 场景3：批量请求处理
export async function batchRequests() {
  const requests = [
    () => get('api/data1'),
    () => get('api/data2'),
    () => get('api/data3'),
  ];
  
  // 并发执行，每个请求都会自动重试
  const results = await Promise.allSettled(
    requests.map(request => request())
  );
  
  const successful = results
    .filter(result => result.status === 'fulfilled')
    .map(result => (result as any).value);
    
  const failed = results
    .filter(result => result.status === 'rejected')
    .map(result => (result as any).reason);
  
  console.log(`批量请求完成: ${successful.length} 成功, ${failed.length} 失败`);
  
  return { successful, failed };
}

export default {
  loginWithRetry,
  uploadFileWithCustomRetry,
  getRealtimeData,
  criticalOperation,
  userLoginFlow,
  fileUploadWithProgress,
  batchRequests
};
