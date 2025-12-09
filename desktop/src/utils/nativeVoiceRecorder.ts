/**
 * 原生语音录制工具类（使用 Rust 后端）
 *
 * 相比 Web API 的 MediaRecorder：
 * - 更好的跨平台兼容性
 * - 更可靠的权限处理
 * - 支持 macOS 和 Windows 系统级权限请求
 * - 输出 WAV 格式（更通用）
 */

import { invoke } from '@tauri-apps/api/core';
import { VoiceRecording } from './voiceRecorder';

/** 权限状态 */
export type PermissionStatus = 'granted' | 'denied' | 'undetermined' | 'restricted';

/** 录音状态 */
export type RecordingStatus = 'idle' | 'recording' | 'stopped';

/** Rust 侧返回的录音结果 */
export interface NativeRecordingResult {
  /** Base64 编码的音频数据（WAV 格式） */
  data: string;
  /** 录音时长（毫秒） */
  duration_ms: number;
  /** 音频格式 */
  format: string;
  /** 采样率 */
  sample_rate: number;
  /** 声道数 */
  channels: number;
}

/**
 * 原生语音录制器
 *
 * 使用 Rust 后端进行录音，支持 macOS 和 Windows 的系统权限处理
 */
export class NativeVoiceRecorder {
  private startTime: number = 0;
  private _isRecording: boolean = false;
  private durationPollInterval: number | null = null;

  /**
   * 检查麦克风权限状态
   */
  public static async checkPermission(): Promise<PermissionStatus> {
    try {
      return await invoke<PermissionStatus>('check_microphone_permission');
    } catch (error) {
      console.error('[NativeVoiceRecorder] 检查权限失败:', error);
      return 'undetermined';
    }
  }

  /**
   * 请求麦克风权限
   * @returns 是否获得权限
   */
  public static async requestPermission(): Promise<boolean> {
    try {
      // 先检查当前权限状态
      const status = await NativeVoiceRecorder.checkPermission();

      if (status === 'granted') {
        return true;
      }

      if (status === 'denied') {
        throw new Error('麦克风权限被拒绝，请在系统设置中开启麦克风权限后重试');
      }

      if (status === 'restricted') {
        throw new Error('麦克风权限受系统策略限制，无法使用录音功能');
      }

      // 请求权限
      const granted = await invoke<boolean>('request_microphone_permission');

      if (!granted) {
        throw new Error('麦克风权限被拒绝，请在系统设置中开启麦克风权限后重试');
      }

      return granted;
    } catch (error: any) {
      console.error('[NativeVoiceRecorder] 请求权限失败:', error);
      const message = error?.message || '无法获取麦克风权限';

      // 检查是否是设备不可用的错误
      if (message.includes('未找到') || message.includes('not found')) {
        throw new Error('未检测到可用的麦克风设备，请检查设备连接');
      }

      throw new Error(message);
    }
  }

  /**
   * 获取录音状态
   */
  public async getStatus(): Promise<RecordingStatus> {
    try {
      return await invoke<RecordingStatus>('get_recording_status');
    } catch (error) {
      console.error('[NativeVoiceRecorder] 获取状态失败:', error);
      return 'idle';
    }
  }

  /**
   * 开始录音
   */
  public async startRecording(): Promise<void> {
    try {
      await invoke('start_recording');
      this.startTime = Date.now();
      this._isRecording = true;
      console.log('[NativeVoiceRecorder] 录音已开始');
    } catch (error: any) {
      this._isRecording = false;
      console.error('[NativeVoiceRecorder] 开始录音失败:', error);

      const message = error?.message || error?.toString() || '';

      if (message.includes('未找到') || message.includes('not found')) {
        throw new Error('未检测到可用的麦克风设备，请检查设备连接');
      }

      if (message.includes('已经在录音') || message.includes('already recording')) {
        throw new Error('已经在录音中');
      }

      if (message.includes('配置失败') || message.includes('config')) {
        throw new Error('麦克风配置失败，请检查设备是否正常');
      }

      throw new Error('开始录音失败，请检查麦克风权限和设备状态');
    }
  }

  /**
   * 停止录音并返回录音数据
   */
  public async stopRecording(): Promise<VoiceRecording> {
    try {
      this._isRecording = false;
      const result = await invoke<NativeRecordingResult>('stop_recording');

      console.log('[NativeVoiceRecorder] 录音已停止', {
        duration_ms: result.duration_ms,
        format: result.format,
        sample_rate: result.sample_rate,
        channels: result.channels,
        dataLength: result.data.length,
      });

      // 将 Base64 转换为 Blob
      const binaryString = atob(result.data);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }
      const blob = new Blob([bytes], { type: 'audio/wav' });

      // 创建 Object URL
      const url = URL.createObjectURL(blob);

      // 生成波形数据
      let waveform: number[] | undefined;
      try {
        waveform = await this.createWaveformFromBlob(blob, 32);
      } catch (err) {
        console.warn('[NativeVoiceRecorder] 生成波形失败:', err);
        waveform = undefined;
      }

      const recording: VoiceRecording = {
        id: Date.now().toString(),
        blob,
        url,
        duration: result.duration_ms / 1000, // 转换为秒
        timestamp: Date.now(),
        waveform,
      };

      return recording;
    } catch (error: any) {
      this._isRecording = false;
      console.error('[NativeVoiceRecorder] 停止录音失败:', error);

      const message = error?.message || error?.toString() || '';

      if (message.includes('太短') || message.includes('too short')) {
        throw new Error('录音时间太短（至少需要 0.5 秒）');
      }

      if (message.includes('没有正在进行') || message.includes('no recording')) {
        throw new Error('当前没有正在录音');
      }

      throw new Error('停止录音失败');
    }
  }

  /**
   * 取消录音
   */
  public async cancelRecording(): Promise<void> {
    try {
      this._isRecording = false;
      await invoke('cancel_recording');
      console.log('[NativeVoiceRecorder] 录音已取消');
    } catch (error) {
      this._isRecording = false;
      console.error('[NativeVoiceRecorder] 取消录音失败:', error);
    }
  }

  /**
   * 获取当前录音时长（秒）
   */
  public getRecordingDuration(): number {
    if (this.startTime === 0 || !this._isRecording) return 0;
    return (Date.now() - this.startTime) / 1000;
  }

  /**
   * 获取当前录音时长（毫秒）- 从 Rust 侧获取精确值
   */
  public async getRecordingDurationMs(): Promise<number> {
    try {
      return await invoke<number>('get_recording_duration');
    } catch (error) {
      console.error('[NativeVoiceRecorder] 获取录音时长失败:', error);
      return 0;
    }
  }

  /**
   * 检查是否正在录音
   */
  public isRecording(): boolean {
    return this._isRecording;
  }

  /**
   * 销毁录音器
   */
  public async destroy(): Promise<void> {
    if (this._isRecording) {
      await this.cancelRecording();
    }
  }

  /**
   * 从 Blob 生成波形采样数据
   */
  private async createWaveformFromBlob(blob: Blob, samples: number = 32): Promise<number[]> {
    if (typeof window === 'undefined') {
      throw new Error('Window is not available');
    }

    const AudioContextCtor = (window as any).AudioContext || (window as any).webkitAudioContext;
    if (!AudioContextCtor) {
      throw new Error('Web Audio API is not supported');
    }

    const arrayBuffer = await blob.arrayBuffer();
    const audioContext = new AudioContextCtor();

    try {
      const audioBuffer: AudioBuffer = await audioContext.decodeAudioData(arrayBuffer.slice(0));
      const channelData = audioBuffer.getChannelData(0);
      const blockSize = Math.floor(channelData.length / samples);
      const waveform: number[] = [];

      for (let i = 0; i < samples; i++) {
        const blockStart = i * blockSize;
        let sum = 0;

        for (let j = 0; j < blockSize; j++) {
          const sample = channelData[blockStart + j] || 0;
          sum += Math.abs(sample);
        }

        const avg = blockSize > 0 ? sum / blockSize : 0;
        waveform.push(Math.max(0, Math.min(1, avg * 4)));
      }

      await audioContext.close();
      return waveform;
    } catch (error) {
      await audioContext.close();
      throw error;
    }
  }
}

/**
 * 检查是否支持原生录音
 *
 * 在 Tauri 环境下返回 true
 */
export function isNativeRecordingSupported(): boolean {
  return !!(window as any).__TAURI__;
}
