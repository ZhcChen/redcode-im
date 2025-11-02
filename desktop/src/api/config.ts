/**
 * API 配置文件
 * 包含所有环境配置和基础设置
 */

export interface ApiConfig {
  Bear_API: string;
  BASE_API: string;
  MULTIPART_API: string;
  TIO_SERVER: string;
  version: number;
}

// 应用版本号
const APP_VERSION = 103;

// 测试环境配置
const testConfig: ApiConfig = {
  Bear_API: "http://81.70.175.46/api/",
  BASE_API: "http://43.134.201.146:9090/we-chat/",
  MULTIPART_API: "http://43.134.201.146:9090/we-chat/",
  TIO_SERVER: "ws://43.134.201.146:9022?",
  version: 1
};

// 开发环境配置
const devConfig: ApiConfig = {
  Bear_API: "http://81.70.175.46/",
  BASE_API: "http://43.134.201.146:9090/we-chat/",
  MULTIPART_API: "http://43.134.201.146:9090/we-chat/",
  TIO_SERVER: "ws://43.134.201.146:9022?",
  version: 1
};

// 生产环境配置
const prodConfig: ApiConfig = {
  Bear_API: "http://129.226.121.116/",
  BASE_API: "http://129.226.121.116:9090/we-chat/",
  MULTIPART_API: "http://129.226.121.116:9090/we-chat/",
  TIO_SERVER: "ws://129.226.121.116:9022?",
  version: 1
};

// 当前使用的环境配置
const currentConfig = prodConfig;

/**
 * API 基础配置
 */
export const apiConfig = {
  Bear_API: currentConfig.Bear_API,
  BASE_API: currentConfig.BASE_API,
  MULTIPART_API: currentConfig.MULTIPART_API,
  TIO_SERVER: currentConfig.TIO_SERVER,
  FILE_SAVE_TARGET: 'local', // 文件保存目标：'local' 本地存储 | 'oss' 云存储
  version: APP_VERSION
};

/**
 * 文件上传相关配置
 */
export const fileConfig = {
  // 文件上传接口 - 基础URL
  uploadUrl: `${apiConfig.MULTIPART_API}file/upload?target=${apiConfig.FILE_SAVE_TARGET}`,
  // 头像上传接口 - 包含dir参数
  uploadAvatarUrl: `${apiConfig.MULTIPART_API}file/upload?target=${apiConfig.FILE_SAVE_TARGET}&dir=userAvatars`,
  // 文件保存目标
  target: apiConfig.FILE_SAVE_TARGET,
  // 根据路径获取文件
  getFileByPath: `${apiConfig.MULTIPART_API}file/getFileFromParam?filePath=`,
  // 图片显示路径
  showFile: `${apiConfig.MULTIPART_API}images/`
};

/**
 * 请求超时配置
 */
export const requestConfig = {
  timeout: 10000, // 请求超时时间（毫秒）
  retryTimes: 3,  // 重试次数
  retryDelay: 1000 // 重试延迟（毫秒）
};
