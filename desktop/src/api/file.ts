/**
 * 文件管理相关 API 接口
 * 包含文件上传、下载、预览等功能
 */

import { upload, post, get } from './http';
import { fileConfig } from './config';
import type { ApiResponse } from './http';

/**
 * 文件信息接口
 */
export interface FileInfo {
  id: string;
  originalName: string; // 原始文件名
  fileName: string; // 存储文件名
  filePath: string; // 文件路径
  fileUrl: string; // 文件访问URL
  fileSize: number; // 文件大小（字节）
  fileType: string; // 文件类型（MIME类型）
  fileExtension: string; // 文件扩展名
  md5: string; // 文件MD5值
  uploaderId: string; // 上传者ID
  uploaderName: string; // 上传者名称
  isPublic: boolean; // 是否公开
  downloadCount: number; // 下载次数
  status: number; // 状态：1-正常, 2-已删除
  createTime: string;
  updateTime: string;
}

/**
 * 文件上传参数
 */
export interface FileUploadParams {
  file: File;
  category?: string; // 文件分类
  isPublic?: boolean; // 是否公开
  description?: string; // 文件描述
  tags?: string[]; // 文件标签
}

/**
 * 文件上传结果
 */
export interface FileUploadResult {
  id: string;
  fileName: string;
  filePath: string;
  fileUrl: string;
  fileSize: number;
  fileType: string;
  md5: string;
}

/**
 * 文件列表查询参数
 */
export interface GetFileListParams {
  page?: number;
  size?: number;
  category?: string;
  fileType?: string;
  keyword?: string;
  uploaderId?: string;
  startDate?: string;
  endDate?: string;
}

/**
 * 图片压缩参数
 */
export interface ImageCompressParams {
  fileId: string;
  width?: number;
  height?: number;
  quality?: number; // 压缩质量 0-100
  format?: 'jpeg' | 'png' | 'webp';
}

/**
 * 文件管理 API 接口类
 */
export class FileApi {
  /**
   * 上传文件
   * @param params 上传参数 { file: 文件对象, category?: 分类, isPublic?: 是否公开, description?: 描述, tags?: 标签 }
   * @returns Promise<ApiResponse<FileUploadResult>> 上传结果
   */
  static async uploadFile(params: FileUploadParams): Promise<ApiResponse<FileUploadResult>> {
    const { file, category, ...additionalData } = params;
    
    // 根据文件分类选择合适的上传URL
    let uploadUrl = fileConfig.uploadUrl;
    if (category === 'avatar') {
      uploadUrl = fileConfig.uploadAvatarUrl;
    }
    
    return upload<FileUploadResult>(uploadUrl, file, additionalData);
  }

  /**
   * 批量上传文件
   * @param files 文件列表
   * @param additionalData 额外数据
   * @returns Promise<ApiResponse<FileUploadResult[]>> 批量上传结果
   */
  static async uploadMultipleFiles(
    files: File[],
    additionalData?: Record<string, any>
  ): Promise<ApiResponse<FileUploadResult[]>> {
    const uploadPromises = files.map(file => 
      FileApi.uploadFile({ file, ...additionalData })
    );
    
    const results = await Promise.allSettled(uploadPromises);
    const successResults: FileUploadResult[] = [];
    const errors: string[] = [];

    results.forEach((result, index) => {
      if (result.status === 'fulfilled' && result.value.success) {
        successResults.push(result.value.data);
      } else {
        errors.push(`文件 ${files[index].name} 上传失败`);
      }
    });

    return {
      code: errors.length === 0 ? 200 : 207, // 207表示部分成功
      message: errors.length === 0 ? '上传成功' : `${successResults.length}个文件上传成功，${errors.length}个文件上传失败`,
      data: successResults,
      success: successResults.length > 0
    };
  }

  /**
   * 获取文件信息
   * @param params 查询参数 { fileId: 文件ID }
   * @returns Promise<ApiResponse<FileInfo>> 文件信息
   */
  static async getFileInfo(params: { fileId: string }): Promise<ApiResponse<FileInfo>> {
    return post<FileInfo>('file/getFileInfo', params);
  }

  /**
   * 获取文件列表
   * @param params 查询参数 { page?: 页码, size?: 每页数量, category?: 分类, fileType?: 文件类型, keyword?: 搜索关键词, uploaderId?: 上传者ID, startDate?: 开始日期, endDate?: 结束日期 }
   * @returns Promise<ApiResponse<{ list: FileInfo[], total: number, page: number, size: number }>> 文件列表
   */
  static async getFileList(params: GetFileListParams = {}): Promise<ApiResponse<{
    list: FileInfo[];
    total: number;
    page: number;
    size: number;
  }>> {
    return post('file/getFileList', params);
  }

  /**
   * 删除文件
   * @param params 删除参数 { fileId: 文件ID }
   * @returns Promise<ApiResponse<any>> 删除结果
   */
  static async deleteFile(params: { fileId: string }): Promise<ApiResponse<any>> {
    return post('file/deleteFile', params);
  }

  /**
   * 批量删除文件
   * @param params 删除参数 { fileIds: 文件ID列表 }
   * @returns Promise<ApiResponse<any>> 删除结果
   */
  static async deleteMultipleFiles(params: { fileIds: string[] }): Promise<ApiResponse<any>> {
    return post('file/deleteMultipleFiles', params);
  }

  /**
   * 更新文件信息
   * @param params 更新参数 { fileId: 文件ID, originalName?: 文件名, description?: 描述, tags?: 标签, isPublic?: 是否公开 }
   * @returns Promise<ApiResponse<any>> 更新结果
   */
  static async updateFileInfo(params: {
    fileId: string;
    originalName?: string;
    description?: string;
    tags?: string[];
    isPublic?: boolean;
  }): Promise<ApiResponse<any>> {
    return post('file/updateFileInfo', params);
  }

  /**
   * 获取文件下载链接
   * @param params 查询参数 { fileId: 文件ID, expiresIn?: 过期时间（秒） }
   * @returns Promise<ApiResponse<{ downloadUrl: string, expiresIn: number }>> 下载链接
   */
  static async getDownloadUrl(params: { fileId: string; expiresIn?: number }): Promise<ApiResponse<{
    downloadUrl: string;
    expiresIn: number;
  }>> {
    return post('file/getDownloadUrl', params);
  }

  /**
   * 根据路径获取文件
   * @param filePath 文件路径
   * @returns 文件访问URL
   */
  static getFileByPath(filePath: string): string {
    return `${fileConfig.getFileByPath}${encodeURIComponent(filePath)}`;
  }

  /**
   * 智能构建图片显示URL
   * @param fileInfo 文件信息对象，可包含 fileUrl, filePath, fullPath, fileName 等字段
   * @returns 图片显示URL
   */
  static buildImageUrl(fileInfo: any): string {
    if (!fileInfo) return '';

    console.log('🔧 FileApi.buildImageUrl 输入:', fileInfo);

    // 1. 优先使用已有的完整 URL
    if (fileInfo.url && fileInfo.url.trim() !== '' && (fileInfo.url.startsWith('http://') || fileInfo.url.startsWith('https://'))) {
      console.log('✅ 使用现有的完整 URL:', fileInfo.url);
      return fileInfo.url;
    }

    // 2. 使用 fullPath 构建 URL（主要情况）
    if (fileInfo.fullPath) {
      const target = fileInfo.fileSaveTarget || fileConfig.target || 'local';
      const constructedUrl = target === 'local'
        ? `${fileConfig.showFile}${fileInfo.fullPath}`
        : fileInfo.fullPath;
      console.log('✅ 使用 fullPath 构建URL:', constructedUrl);
      return constructedUrl;
    }

    // 3. 处理历史消息：url为空但有fileName的情况
    if (fileInfo.fileName && (!fileInfo.url || fileInfo.url.trim() === '')) {
      // 根据 fileSaveTarget 决定构建方式
      const target = fileInfo.fileSaveTarget || 'local';
      if (target === 'local') {
        // 假设fileName存储在chattingFiles目录下（与数据格式一致）
        const constructedUrl = `${fileConfig.showFile}chattingFiles/${fileInfo.fileName}`;
        console.log('✅ 历史消息使用 fileName 构建URL:', constructedUrl);
        return constructedUrl;
      } else {
        console.log('✅ 非本地模式直接使用 fileName:', fileInfo.fileName);
        return fileInfo.fileName;
      }
    }

    // 4. 使用 filePath 构建 URL
    if (fileInfo.filePath) {
      const constructedUrl = `${fileConfig.showFile}${fileInfo.filePath}`;
      console.log('✅ 使用 filePath 构建URL:', constructedUrl);
      return constructedUrl;
    }

    // 5. 如果 fileUrl 存在但不是完整 URL，根据 target 类型处理
    if (fileInfo.fileUrl) {
      const target = fileInfo.fileSaveTarget || fileConfig.target || 'local';
      if (target === 'local') {
        const constructedUrl = `${fileConfig.showFile}${fileInfo.fileUrl}`;
        console.log('✅ 本地模式下使用 fileUrl 构建URL:', constructedUrl);
        return constructedUrl;
      } else {
        console.log('✅ 非本地模式直接使用 fileUrl:', fileInfo.fileUrl);
        return fileInfo.fileUrl;
      }
    }

    console.warn('❌ 无法构建图片URL，缺少必要字段:', fileInfo);
    return '';
  }

  /**
   * 获取图片显示URL
   * @param imagePath 图片路径
   * @returns 图片显示URL
   */
  static getImageUrl(imagePath: string): string {
    // 如果已经是完整的 HTTP/HTTPS URL，直接返回
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // 如果是相对路径，拼接 API 地址
    return `${fileConfig.showFile}${imagePath}`;
  }

  /**
   * 压缩图片
   * @param params 压缩参数 { fileId: 文件ID, width?: 宽度, height?: 高度, quality?: 质量, format?: 格式 }
   * @returns Promise<ApiResponse<FileUploadResult>> 压缩后的文件信息
   */
  static async compressImage(params: ImageCompressParams): Promise<ApiResponse<FileUploadResult>> {
    return post<FileUploadResult>('file/compressImage', params);
  }

  /**
   * 生成文件缩略图
   * @param params 生成参数 { fileId: 文件ID, width?: 宽度, height?: 高度 }
   * @returns Promise<ApiResponse<FileUploadResult>> 缩略图文件信息
   */
  static async generateThumbnail(params: {
    fileId: string;
    width?: number;
    height?: number;
  }): Promise<ApiResponse<FileUploadResult>> {
    return post<FileUploadResult>('file/generateThumbnail', params);
  }

  /**
   * 获取文件存储统计
   * @param params 查询参数 { uploaderId?: 上传者ID, startDate?: 开始日期, endDate?: 结束日期 }
   * @returns Promise<ApiResponse<any>> 存储统计信息
   */
  static async getStorageStatistics(params: {
    uploaderId?: string;
    startDate?: string;
    endDate?: string;
  } = {}): Promise<ApiResponse<{
    totalFiles: number;
    totalSize: number;
    totalDownloads: number;
    typeStatistics: Array<{
      fileType: string;
      count: number;
      size: number;
    }>;
    dailyStatistics: Array<{
      date: string;
      uploads: number;
      downloads: number;
      size: number;
    }>;
  }>> {
    return post('file/getStorageStatistics', params);
  }

  /**
   * 检查文件是否存在
   * @param params 检查参数 { md5: 文件MD5值 }
   * @returns Promise<ApiResponse<{ exists: boolean, fileInfo?: FileInfo }>> 检查结果
   */
  static async checkFileExists(params: { md5: string }): Promise<ApiResponse<{
    exists: boolean;
    fileInfo?: FileInfo;
  }>> {
    return post('file/checkFileExists', params);
  }

  /**
   * 秒传文件（基于MD5）
   * @param params 秒传参数 { md5: 文件MD5值, fileName: 文件名, fileSize: 文件大小 }
   * @returns Promise<ApiResponse<FileUploadResult>> 秒传结果
   */
  static async instantUpload(params: {
    md5: string;
    fileName: string;
    fileSize: number;
  }): Promise<ApiResponse<FileUploadResult>> {
    return post<FileUploadResult>('file/instantUpload', params);
  }
}

/**
 * 文件类型枚举
 */
export enum FileType {
  IMAGE = 'image',
  VIDEO = 'video',
  AUDIO = 'audio',
  DOCUMENT = 'document',
  ARCHIVE = 'archive',
  OTHER = 'other'
}

/**
 * 文件分类枚举
 */
export enum FileCategory {
  AVATAR = 'avatar', // 头像
  CHAT_IMAGE = 'chat_image', // 聊天图片
  CHAT_FILE = 'chat_file', // 聊天文件
  CIRCLE_IMAGE = 'circle_image', // 朋友圈图片
  SYSTEM = 'system', // 系统文件
  TEMP = 'temp' // 临时文件
}

/**
 * 获取文件类型图标
 * @param fileExtension 文件扩展名
 * @returns 文件类型图标类名
 */
export function getFileTypeIcon(fileExtension: string): string {
  const ext = fileExtension.toLowerCase();
  
  if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].includes(ext)) {
    return 'icon-image';
  }
  if (['mp4', 'avi', 'mov', 'wmv', 'flv', 'mkv', 'webm'].includes(ext)) {
    return 'icon-video';
  }
  if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'wma'].includes(ext)) {
    return 'icon-audio';
  }
  if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'].includes(ext)) {
    return 'icon-document';
  }
  if (['zip', 'rar', '7z', 'tar', 'gz'].includes(ext)) {
    return 'icon-archive';
  }
  
  return 'icon-file';
}

/**
 * 格式化文件大小
 * @param bytes 字节数
 * @returns 格式化后的文件大小
 */
export function formatFileSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}
