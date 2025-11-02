/**
 * 音乐相关 API 接口
 * 包含音乐搜索、播放、下载等功能
 */

import { post } from './http';
import type { ApiResponse } from './http';

/**
 * 音乐信息接口
 */
export interface MusicInfo {
  id: string;
  name: string; // 歌曲名称
  artist: string; // 艺术家
  album: string; // 专辑名称
  albumCover: string; // 专辑封面URL
  duration: number; // 歌曲时长（秒）
  size: number; // 文件大小（字节）
  bitrate: number; // 比特率
  format: string; // 音频格式（mp3, flac等）
  playUrl?: string; // 播放URL
  downloadUrl?: string; // 下载URL
  lrcUrl?: string; // 歌词URL
  quality: 'low' | 'standard' | 'high' | 'lossless'; // 音质
  source: string; // 音乐来源平台
  sourceId: string; // 来源平台的歌曲ID
  isVip: boolean; // 是否需要VIP
  canPlay: boolean; // 是否可以播放
  canDownload: boolean; // 是否可以下载
  createTime: string;
}

/**
 * 歌词信息接口
 */
export interface LyricInfo {
  id: string;
  musicId: string;
  content: string; // 歌词内容
  format: 'lrc' | 'txt'; // 歌词格式
  language: string; // 歌词语言
  isTranslated: boolean; // 是否有翻译
  translatedContent?: string; // 翻译内容
  createTime: string;
}

/**
 * 音乐搜索参数
 */
export interface SearchMusicParams {
  keyword: string; // 搜索关键词
  page?: number; // 页码
  size?: number; // 每页数量
  type?: 'song' | 'artist' | 'album' | 'playlist'; // 搜索类型
  source?: string; // 指定音乐平台
  quality?: 'low' | 'standard' | 'high' | 'lossless'; // 音质要求
}

/**
 * 音乐播放列表接口
 */
export interface MusicPlaylist {
  id: string;
  name: string;
  description: string;
  cover: string;
  userId: string;
  userName: string;
  musicCount: number;
  playCount: number;
  isPublic: boolean;
  tags: string[];
  createTime: string;
  updateTime: string;
}

/**
 * 音乐下载任务接口
 */
export interface DownloadTask {
  id: string;
  musicId: string;
  musicName: string;
  artist: string;
  quality: string;
  status: 'pending' | 'downloading' | 'completed' | 'failed'; // 下载状态
  progress: number; // 下载进度（0-100）
  filePath?: string; // 本地文件路径
  fileSize: number; // 文件大小
  downloadedSize: number; // 已下载大小
  speed: number; // 下载速度（字节/秒）
  createTime: string;
  completeTime?: string;
}

/**
 * 音乐 API 接口类
 */
export class MusicApi {
  /**
   * 搜索音乐列表
   * @param params 搜索参数 { keyword: 搜索关键词, page?: 页码, size?: 每页数量, type?: 搜索类型, source?: 音乐平台, quality?: 音质 }
   * @returns Promise<ApiResponse<{ list: MusicInfo[], total: number, page: number, size: number }>> 搜索结果
   */
  static async searchMusicList(params: SearchMusicParams): Promise<ApiResponse<{
    list: MusicInfo[];
    total: number;
    page: number;
    size: number;
    hasMore: boolean;
  }>> {
    return post('/freeMusic/searchMusicList', params);
  }

  /**
   * 获取歌曲信息和歌词
   * @param params 查询参数 { musicId: 音乐ID, source?: 音乐来源, needLyric?: 是否需要歌词 }
   * @returns Promise<ApiResponse<{ music: MusicInfo, lyric?: LyricInfo }>> 歌曲信息和歌词
   */
  static async getSongInfoAndLrc(params: {
    musicId: string;
    source?: string;
    needLyric?: boolean;
  }): Promise<ApiResponse<{
    music: MusicInfo;
    lyric?: LyricInfo;
  }>> {
    return post('/freeMusic/getSongInfoAndLrc', params);
  }

  /**
   * 获取歌曲播放地址
   * @param params 查询参数 { musicId: 音乐ID, quality?: 音质, source?: 音乐来源 }
   * @returns Promise<ApiResponse<{ playUrl: string, quality: string, bitrate: number, format: string, expiresIn: number }>> 播放地址信息
   */
  static async getSongSrc(params: {
    musicId: string;
    quality?: 'low' | 'standard' | 'high' | 'lossless';
    source?: string;
  }): Promise<ApiResponse<{
    playUrl: string;
    quality: string;
    bitrate: number;
    format: string;
    expiresIn: number; // 链接过期时间（秒）
  }>> {
    return post('/freeMusic/getSongSrc', params);
  }

  /**
   * 下载歌曲
   * @param params 下载参数 { musicId: 音乐ID, quality?: 音质, source?: 音乐来源, savePath?: 保存路径 }
   * @returns Promise<ApiResponse<{ taskId: string, downloadUrl: string }>> 下载任务信息
   */
  static async downLoadSong(params: {
    musicId: string;
    quality?: 'low' | 'standard' | 'high' | 'lossless';
    source?: string;
    savePath?: string;
  }): Promise<ApiResponse<{
    taskId: string;
    downloadUrl: string;
  }>> {
    return post('/freeMusic/downLoadSong', params);
  }

  /**
   * 获取热门音乐
   * @param params 查询参数 { category?: 分类, page?: 页码, size?: 每页数量 }
   * @returns Promise<ApiResponse<MusicInfo[]>> 热门音乐列表
   */
  static async getHotMusicList(params: {
    category?: string;
    page?: number;
    size?: number;
  } = {}): Promise<ApiResponse<MusicInfo[]>> {
    return post('/freeMusic/getHotMusicList', params);
  }

  /**
   * 获取推荐音乐
   * @param params 查询参数 { userId?: 用户ID, count?: 推荐数量 }
   * @returns Promise<ApiResponse<MusicInfo[]>> 推荐音乐列表
   */
  static async getRecommendMusicList(params: {
    userId?: string;
    count?: number;
  } = {}): Promise<ApiResponse<MusicInfo[]>> {
    return post('/freeMusic/getRecommendMusicList', params);
  }

  /**
   * 获取音乐分类列表
   * @param params 查询参数
   * @returns Promise<ApiResponse<any[]>> 分类列表
   */
  static async getMusicCategories(params: Record<string, any> = {}): Promise<ApiResponse<Array<{
    id: string;
    name: string;
    description: string;
    cover: string;
    musicCount: number;
  }>>> {
    return post('/freeMusic/getMusicCategories', params);
  }

  /**
   * 获取下载任务列表
   * @param params 查询参数 { status?: 下载状态, page?: 页码, size?: 每页数量 }
   * @returns Promise<ApiResponse<DownloadTask[]>> 下载任务列表
   */
  static async getDownloadTasks(params: {
    status?: 'pending' | 'downloading' | 'completed' | 'failed';
    page?: number;
    size?: number;
  } = {}): Promise<ApiResponse<DownloadTask[]>> {
    return post('/freeMusic/getDownloadTasks', params);
  }

  /**
   * 获取下载任务状态
   * @param params 查询参数 { taskId: 任务ID }
   * @returns Promise<ApiResponse<DownloadTask>> 下载任务状态
   */
  static async getDownloadTaskStatus(params: { taskId: string }): Promise<ApiResponse<DownloadTask>> {
    return post('/freeMusic/getDownloadTaskStatus', params);
  }

  /**
   * 取消下载任务
   * @param params 取消参数 { taskId: 任务ID }
   * @returns Promise<ApiResponse<any>> 取消结果
   */
  static async cancelDownloadTask(params: { taskId: string }): Promise<ApiResponse<any>> {
    return post('/freeMusic/cancelDownloadTask', params);
  }

  /**
   * 删除下载任务
   * @param params 删除参数 { taskId: 任务ID, deleteFile?: 是否删除文件 }
   * @returns Promise<ApiResponse<any>> 删除结果
   */
  static async deleteDownloadTask(params: { taskId: string; deleteFile?: boolean }): Promise<ApiResponse<any>> {
    return post('/freeMusic/deleteDownloadTask', params);
  }

  /**
   * 重新下载
   * @param params 重新下载参数 { taskId: 任务ID }
   * @returns Promise<ApiResponse<any>> 重新下载结果
   */
  static async retryDownload(params: { taskId: string }): Promise<ApiResponse<any>> {
    return post('/freeMusic/retryDownload', params);
  }
}

/**
 * 音乐质量枚举
 */
export enum MusicQuality {
  LOW = 'low', // 低音质 (128kbps)
  STANDARD = 'standard', // 标准音质 (320kbps)
  HIGH = 'high', // 高音质 (FLAC)
  LOSSLESS = 'lossless' // 无损音质
}

/**
 * 音乐来源平台枚举
 */
export enum MusicSource {
  NETEASE = 'netease', // 网易云音乐
  QQ = 'qq', // QQ音乐
  KUGOU = 'kugou', // 酷狗音乐
  KUWO = 'kuwo', // 酷我音乐
  MIGU = 'migu', // 咪咕音乐
  XIAMI = 'xiami' // 虾米音乐
}

/**
 * 获取音质显示名称
 * @param quality 音质
 * @returns 音质显示名称
 */
export function getQualityDisplayName(quality: string): string {
  const qualityNames: Record<string, string> = {
    [MusicQuality.LOW]: '标准音质',
    [MusicQuality.STANDARD]: '高音质',
    [MusicQuality.HIGH]: 'HQ高音质',
    [MusicQuality.LOSSLESS]: '无损音质'
  };
  return qualityNames[quality] || quality;
}

/**
 * 获取音乐平台显示名称
 * @param source 音乐平台
 * @returns 平台显示名称
 */
export function getSourceDisplayName(source: string): string {
  const sourceNames: Record<string, string> = {
    [MusicSource.NETEASE]: '网易云音乐',
    [MusicSource.QQ]: 'QQ音乐',
    [MusicSource.KUGOU]: '酷狗音乐',
    [MusicSource.KUWO]: '酷我音乐',
    [MusicSource.MIGU]: '咪咕音乐',
    [MusicSource.XIAMI]: '虾米音乐'
  };
  return sourceNames[source] || source;
}
