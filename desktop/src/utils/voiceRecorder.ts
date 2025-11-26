/**
 * 语音录制和播放工具类
 */

export interface VoiceRecording {
  id: string;
  blob: Blob;
  url: string;
  duration: number; // 录制时长（秒）
  timestamp: number;
}

export class VoiceRecorder {
  private mediaRecorder: MediaRecorder | null = null;
  private audioChunks: Blob[] = [];
  private startTime: number = 0;
  private stream: MediaStream | null = null;

  /**
   * 检查浏览器是否支持语音录制
   */
  public static isSupported(): boolean {
    return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
  }

  /**
   * 请求麦克风权限
   */
  public static async requestPermission(): Promise<boolean> {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      stream.getTracks().forEach(track => track.stop());
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 开始录音
   */
  public async startRecording(): Promise<void> {
    if (!VoiceRecorder.isSupported()) {
      throw new Error('浏览器不支持语音录制功能');
    }

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      this.mediaRecorder = new MediaRecorder(this.stream);
      this.audioChunks = [];
      this.startTime = Date.now();

      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          this.audioChunks.push(event.data);
        }
      };

      this.mediaRecorder.onstop = () => {
        this.cleanup();
      };

      this.mediaRecorder.start();
    } catch (error) {
      this.cleanup();
      throw new Error('无法访问麦克风');
    }
  }

  /**
   * 停止录音
   */
  public async stopRecording(): Promise<VoiceRecording> {
    return new Promise((resolve, reject) => {
      if (!this.mediaRecorder || this.mediaRecorder.state !== 'recording') {
        reject(new Error('当前没有正在录音'));
        return;
      }

      this.mediaRecorder.onstop = () => {
        try {
          const audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' });
          const duration = (Date.now() - this.startTime) / 1000;
          const url = URL.createObjectURL(audioBlob);
          const recording: VoiceRecording = {
            id: Date.now().toString(),
            blob: audioBlob,
            url,
            duration,
            timestamp: Date.now(),
          };
          this.cleanup();
          resolve(recording);
        } catch (error) {
          reject(error);
        }
      };

      this.mediaRecorder.stop();
    });
  }

  /**
   * 取消录音
   */
  public cancelRecording(): void {
    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
      this.mediaRecorder.stop();
    }
    this.audioChunks = [];
    this.cleanup();
  }

  /**
   * 获取当前录音时长
   */
  public getRecordingDuration(): number {
    if (this.startTime === 0) return 0;
    return (Date.now() - this.startTime) / 1000;
  }

  /**
   * 检查是否正在录音
   */
  public isRecording(): boolean {
    return this.mediaRecorder?.state === 'recording';
  }

  /**
   * 清理资源
   */
  private cleanup(): void {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
      this.stream = null;
    }
    this.mediaRecorder = null;
  }

  /**
   * 销毁录音器
   */
  public destroy(): void {
    this.cancelRecording();
  }
}

/**
 * 语音播放器
 */
export class VoicePlayer {
  private audio: HTMLAudioElement | null = null;
  private currentUrl: string | null = null;
  private onEndedCallback: (() => void) | null = null;

  /**
   * 设置播放结束回调
   */
  public onEnded(callback: () => void): void {
    this.onEndedCallback = callback;
  }

  /**
   * 将本地路径转换为可播放的 URL
   */
  private convertToPlayableUrl(url: string): string {
    console.log('[VoicePlayer] 输入 URL:', url);

    if (!url) return '';

    // blob: URL 可以直接使用
    if (url.startsWith('blob:')) {
      console.log('[VoicePlayer] blob URL，直接使用');
      return url;
    }

    // http/https URL 直接使用
    if (url.startsWith('http://') || url.startsWith('https://')) {
      console.log('[VoicePlayer] http(s) URL，直接使用');
      return url;
    }

    // asset: 协议 URL 直接使用
    if (url.startsWith('asset:') || url.startsWith('http://asset.localhost')) {
      console.log('[VoicePlayer] asset URL，直接使用');
      return url;
    }

    // file:// URL 需要转换
    let localPath = url;
    if (url.startsWith('file://')) {
      console.log('[VoicePlayer] file:// URL，提取路径');
      localPath = decodeURIComponent(url.replace('file://', ''));
    }

    // 尝试使用 Tauri 的 convertFileSrc
    try {
      const tauri = (window as any).__TAURI__;
      console.log('[VoicePlayer] Tauri API 可用:', !!tauri?.core?.convertFileSrc);
      if (tauri?.core?.convertFileSrc) {
        const result = tauri.core.convertFileSrc(localPath);
        console.log('[VoicePlayer] 转换结果:', result);
        return result;
      }
    } catch (error) {
      console.error('[VoicePlayer] 转换失败:', error);
    }

    console.warn('[VoicePlayer] 无法转换，返回原 URL');
    return url;
  }

  /**
   * 播放语音
   */
  public async play(url: string): Promise<void> {
    if (this.audio) {
      this.audio.pause();
      this.audio.remove();
    }

    // 转换 URL 为可播放格式
    const playableUrl = this.convertToPlayableUrl(url);
    console.log('[VoicePlayer] 播放 URL:', playableUrl);

    this.audio = new Audio(playableUrl);
    this.currentUrl = playableUrl;

    return new Promise((resolve, reject) => {
      if (!this.audio) {
        reject(new Error('音频播放器创建失败'));
        return;
      }

      this.audio.onplay = () => {
        console.log('[VoicePlayer] 开始播放');
      };

      this.audio.onended = () => {
        console.log('[VoicePlayer] 播放结束');
        if (this.onEndedCallback) {
          this.onEndedCallback();
        }
        resolve();
      };

      this.audio.onerror = (error) => {
        console.error('[VoicePlayer] 播放错误:', error);
        reject(new Error('语音播放失败'));
      };

      this.audio.play().catch(reject);
    });
  }

  /**
   * 停止播放
   */
  public stop(): void {
    if (this.audio && !this.audio.paused) {
      this.audio.pause();
      this.audio.currentTime = 0;
    }
  }

  /**
   * 暂停播放
   */
  public pause(): void {
    if (this.audio && !this.audio.paused) {
      this.audio.pause();
    }
  }

  /**
   * 恢复播放
   */
  public resume(): void {
    if (this.audio && this.audio.paused) {
    }
  }

  /**
   * 检查是否正在播放
   */
  public isPlaying(): boolean {
    return this.audio ? !this.audio.paused : false;
  }

  /**
   * 获取当前播放时间
   */
  public getCurrentTime(): number {
    return this.audio ? this.audio.currentTime : 0;
  }

  /**
   * 获取总时长
   */
  public getDuration(): number {
    return this.audio ? this.audio.duration || 0 : 0;
  }

  /**
   * 跳转到指定时间
   */
  public seekTo(time: number): void {
    if (this.audio) {
      this.audio.currentTime = Math.max(0, Math.min(time, this.audio.duration || 0));
    }
  }

  /**
   * 设置音量
   */
  public setVolume(volume: number): void {
    if (this.audio) {
      this.audio.volume = Math.max(0, Math.min(1, volume));
    }
  }

  /**
   * 清理资源
   */
  private cleanup(): void {
    if (this.audio) {
      this.audio.pause();
      this.audio.remove();
      this.audio = null;
    }
    this.currentUrl = null;
  }

  /**
   * 销毁播放器
   */
  public destroy(): void {
    this.stop();
    this.cleanup();
  }
}

/**
 * 语音工具函数
 */
export class VoiceUtils {
  /**
   * 格式化时长显示
   */
  public static formatDuration(seconds: number): string {
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = Math.floor(seconds % 60);
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  }

  /**
   * 转换Blob为Base64
   */
  public static async blobToBase64(blob: Blob): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  }

  /**
   * 检查音频文件大小
   */
  public static getAudioSize(blob: Blob): string {
    const bytes = blob.size;
    if (bytes < 1024) {
      return bytes + ' B';
    } else if (bytes < 1024 * 1024) {
      return (bytes / 1024).toFixed(1) + ' KB';
    } else {
      return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    }
  }

  /**
   * 创建音频波形可视化（预留接口）
   */
  public static createWaveform(canvas: HTMLCanvasElement, audioBuffer: AudioBuffer): void {
    // TODO: 实现音频波形可视化
  }
}