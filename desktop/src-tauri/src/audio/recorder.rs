//! 音频录制器
//!
//! 使用 cpal 进行跨平台音频录制，输出 WAV 格式。
//! 使用独立线程处理录音流，避免 Send/Sync 问题。

use serde::{Deserialize, Serialize};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc, Mutex};
use std::thread::{self, JoinHandle};

/// 录音结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecordingResult {
    /// Base64 编码的音频数据（WAV 格式）
    pub data: String,
    /// 录音时长（毫秒）
    pub duration_ms: u64,
    /// 音频格式
    pub format: String,
    /// 采样率
    pub sample_rate: u32,
    /// 声道数
    pub channels: u16,
}

/// 录音状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum RecordingStatus {
    /// 空闲
    Idle,
    /// 录音中
    Recording,
    /// 已停止
    Stopped,
}

/// 录音线程命令
enum RecorderCommand {
    Stop,
    Cancel,
}

/// 录音线程结果
enum RecorderResult {
    Success(RecordingResult),
    Cancelled,
    Error(String),
}

/// 共享的录音数据
struct SharedRecordingData {
    samples: Vec<f32>,
    sample_rate: u32,
    channels: u16,
    start_time: std::time::Instant,
}

/// 音频录制器
pub struct AudioRecorder {
    /// 录音状态
    is_recording: Arc<AtomicBool>,
    /// 命令发送器
    cmd_tx: Mutex<Option<mpsc::Sender<RecorderCommand>>>,
    /// 结果接收器
    result_rx: Mutex<Option<mpsc::Receiver<RecorderResult>>>,
    /// 录音线程句柄
    thread_handle: Mutex<Option<JoinHandle<()>>>,
    /// 录音开始时间
    start_time: Mutex<Option<std::time::Instant>>,
}

impl Default for AudioRecorder {
    fn default() -> Self {
        Self::new()
    }
}

impl AudioRecorder {
    /// 创建新的录音器
    pub fn new() -> Self {
        Self {
            is_recording: Arc::new(AtomicBool::new(false)),
            cmd_tx: Mutex::new(None),
            result_rx: Mutex::new(None),
            thread_handle: Mutex::new(None),
            start_time: Mutex::new(None),
        }
    }

    /// 获取录音状态
    pub fn status(&self) -> RecordingStatus {
        if self.is_recording.load(Ordering::SeqCst) {
            RecordingStatus::Recording
        } else {
            RecordingStatus::Idle
        }
    }

    /// 检查是否正在录音
    pub fn is_recording(&self) -> bool {
        self.is_recording.load(Ordering::SeqCst)
    }

    /// 开始录音
    pub fn start(&self) -> Result<(), String> {
        // 检查是否已在录音
        if self.is_recording.load(Ordering::SeqCst) {
            return Err("已经在录音中".to_string());
        }

        // 创建通信 channel
        let (cmd_tx, cmd_rx) = mpsc::channel::<RecorderCommand>();
        let (result_tx, result_rx) = mpsc::channel::<RecorderResult>();

        // 共享录音状态
        let is_recording = Arc::clone(&self.is_recording);

        // 在独立线程中运行录音
        let handle = thread::spawn(move || {
            run_recording_thread(cmd_rx, result_tx, is_recording);
        });

        // 保存 channel 和线程句柄
        *self.cmd_tx.lock().unwrap() = Some(cmd_tx);
        *self.result_rx.lock().unwrap() = Some(result_rx);
        *self.thread_handle.lock().unwrap() = Some(handle);
        *self.start_time.lock().unwrap() = Some(std::time::Instant::now());

        // 设置录音状态
        self.is_recording.store(true, Ordering::SeqCst);

        Ok(())
    }

    /// 停止录音并返回结果
    pub fn stop(&self) -> Result<RecordingResult, String> {
        // 检查是否在录音
        if !self.is_recording.load(Ordering::SeqCst) {
            return Err("当前没有正在进行的录音".to_string());
        }

        // 发送停止命令
        if let Some(tx) = self.cmd_tx.lock().unwrap().take() {
            let _ = tx.send(RecorderCommand::Stop);
        }

        // 等待结果
        let result = if let Some(rx) = self.result_rx.lock().unwrap().take() {
            rx.recv().map_err(|e| format!("接收录音结果失败: {}", e))?
        } else {
            return Err("录音通道已关闭".to_string());
        };

        // 等待线程结束
        if let Some(handle) = self.thread_handle.lock().unwrap().take() {
            let _ = handle.join();
        }

        // 清理状态
        self.is_recording.store(false, Ordering::SeqCst);
        *self.start_time.lock().unwrap() = None;

        // 返回结果
        match result {
            RecorderResult::Success(data) => Ok(data),
            RecorderResult::Cancelled => Err("录音已取消".to_string()),
            RecorderResult::Error(e) => Err(e),
        }
    }

    /// 取消录音
    pub fn cancel(&self) -> Result<(), String> {
        // 发送取消命令
        if let Some(tx) = self.cmd_tx.lock().unwrap().take() {
            let _ = tx.send(RecorderCommand::Cancel);
        }

        // 等待线程结束
        if let Some(handle) = self.thread_handle.lock().unwrap().take() {
            let _ = handle.join();
        }

        // 清理结果接收器
        *self.result_rx.lock().unwrap() = None;

        // 清理状态
        self.is_recording.store(false, Ordering::SeqCst);
        *self.start_time.lock().unwrap() = None;

        Ok(())
    }

    /// 获取当前录音时长（毫秒）
    pub fn get_duration_ms(&self) -> u64 {
        if let Some(start) = *self.start_time.lock().unwrap() {
            if self.is_recording.load(Ordering::SeqCst) {
                return start.elapsed().as_millis() as u64;
            }
        }
        0
    }
}

/// 录音线程主函数
fn run_recording_thread(
    cmd_rx: mpsc::Receiver<RecorderCommand>,
    result_tx: mpsc::Sender<RecorderResult>,
    is_recording: Arc<AtomicBool>,
) {
    use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
    use cpal::SampleFormat;

    // 获取默认音频主机
    let host = cpal::default_host();

    // 获取默认输入设备
    let device = match host.default_input_device() {
        Some(d) => d,
        None => {
            let _ = result_tx.send(RecorderResult::Error("未找到可用的麦克风设备".to_string()));
            is_recording.store(false, Ordering::SeqCst);
            return;
        }
    };

    // 获取默认输入配置
    let config = match device.default_input_config() {
        Ok(c) => c,
        Err(e) => {
            let _ = result_tx.send(RecorderResult::Error(format!("获取麦克风配置失败: {}", e)));
            is_recording.store(false, Ordering::SeqCst);
            return;
        }
    };

    let sample_rate = config.sample_rate().0;
    let channels = config.channels();
    let sample_format = config.sample_format();

    // 共享录音数据
    let recording_data = Arc::new(Mutex::new(SharedRecordingData {
        samples: Vec::new(),
        sample_rate,
        channels,
        start_time: std::time::Instant::now(),
    }));

    let recording_data_clone = Arc::clone(&recording_data);
    let is_recording_clone = Arc::clone(&is_recording);

    // 错误回调
    let err_fn = |err: cpal::StreamError| {
        eprintln!("录音流错误: {}", err);
    };

    // 根据采样格式创建输入流
    let stream_result = match sample_format {
        SampleFormat::F32 => {
            let data = Arc::clone(&recording_data_clone);
            let is_rec = Arc::clone(&is_recording_clone);
            device.build_input_stream(
                &config.into(),
                move |samples: &[f32], _: &cpal::InputCallbackInfo| {
                    if is_rec.load(Ordering::SeqCst) {
                        if let Ok(mut rec_data) = data.lock() {
                            rec_data.samples.extend_from_slice(samples);
                        }
                    }
                },
                err_fn,
                None,
            )
        }
        SampleFormat::I16 => {
            let data = Arc::clone(&recording_data_clone);
            let is_rec = Arc::clone(&is_recording_clone);
            device.build_input_stream(
                &config.into(),
                move |samples: &[i16], _: &cpal::InputCallbackInfo| {
                    if is_rec.load(Ordering::SeqCst) {
                        if let Ok(mut rec_data) = data.lock() {
                            let converted: Vec<f32> = samples
                                .iter()
                                .map(|&s| s as f32 / i16::MAX as f32)
                                .collect();
                            rec_data.samples.extend(converted);
                        }
                    }
                },
                err_fn,
                None,
            )
        }
        SampleFormat::U16 => {
            let data = Arc::clone(&recording_data_clone);
            let is_rec = Arc::clone(&is_recording_clone);
            device.build_input_stream(
                &config.into(),
                move |samples: &[u16], _: &cpal::InputCallbackInfo| {
                    if is_rec.load(Ordering::SeqCst) {
                        if let Ok(mut rec_data) = data.lock() {
                            let converted: Vec<f32> = samples
                                .iter()
                                .map(|&s| (s as f32 / u16::MAX as f32) * 2.0 - 1.0)
                                .collect();
                            rec_data.samples.extend(converted);
                        }
                    }
                },
                err_fn,
                None,
            )
        }
        _ => {
            let _ = result_tx.send(RecorderResult::Error(format!(
                "不支持的采样格式: {:?}",
                sample_format
            )));
            is_recording.store(false, Ordering::SeqCst);
            return;
        }
    };

    let stream = match stream_result {
        Ok(s) => s,
        Err(e) => {
            let _ = result_tx.send(RecorderResult::Error(format!("创建录音流失败: {}", e)));
            is_recording.store(false, Ordering::SeqCst);
            return;
        }
    };

    // 启动录音流
    if let Err(e) = stream.play() {
        let _ = result_tx.send(RecorderResult::Error(format!("启动录音失败: {}", e)));
        is_recording.store(false, Ordering::SeqCst);
        return;
    }

    // 等待命令
    match cmd_rx.recv() {
        Ok(RecorderCommand::Stop) => {
            // 停止录音
            let _ = stream.pause();

            // 获取录音数据
            let rec_data = recording_data.lock().unwrap();
            let duration_ms = rec_data.start_time.elapsed().as_millis() as u64;

            // 如果录音太短，返回错误
            if duration_ms < 500 {
                let _ = result_tx.send(RecorderResult::Error(
                    "录音时间太短（至少需要 0.5 秒）".to_string(),
                ));
                return;
            }

            // 编码为 WAV
            match encode_wav(&rec_data.samples, rec_data.sample_rate, rec_data.channels) {
                Ok(wav_data) => {
                    let data =
                        base64::Engine::encode(&base64::engine::general_purpose::STANDARD, &wav_data);
                    let _ = result_tx.send(RecorderResult::Success(RecordingResult {
                        data,
                        duration_ms,
                        format: "wav".to_string(),
                        sample_rate: rec_data.sample_rate,
                        channels: rec_data.channels,
                    }));
                }
                Err(e) => {
                    let _ = result_tx.send(RecorderResult::Error(e));
                }
            }
        }
        Ok(RecorderCommand::Cancel) => {
            // 取消录音
            let _ = stream.pause();
            let _ = result_tx.send(RecorderResult::Cancelled);
        }
        Err(_) => {
            // 通道关闭，停止录音
            let _ = stream.pause();
        }
    }

    is_recording.store(false, Ordering::SeqCst);
}

/// 将 f32 采样数据编码为 WAV 格式
fn encode_wav(samples: &[f32], sample_rate: u32, channels: u16) -> Result<Vec<u8>, String> {
    use std::io::Cursor;

    let spec = hound::WavSpec {
        channels,
        sample_rate,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };

    let mut cursor = Cursor::new(Vec::new());

    {
        let mut writer = hound::WavWriter::new(&mut cursor, spec)
            .map_err(|e| format!("创建 WAV 写入器失败: {}", e))?;

        for &sample in samples {
            // 将 f32 (-1.0 到 1.0) 转换为 i16
            let sample_i16 = (sample.clamp(-1.0, 1.0) * i16::MAX as f32) as i16;
            writer
                .write_sample(sample_i16)
                .map_err(|e| format!("写入采样失败: {}", e))?;
        }

        writer
            .finalize()
            .map_err(|e| format!("完成 WAV 写入失败: {}", e))?;
    }

    Ok(cursor.into_inner())
}

/// 录音器状态管理（用于 Tauri State）
pub struct AudioRecorderState {
    pub recorder: Mutex<AudioRecorder>,
}

// 手动实现 Send + Sync，因为我们的设计保证了线程安全
unsafe impl Send for AudioRecorderState {}
unsafe impl Sync for AudioRecorderState {}

impl Default for AudioRecorderState {
    fn default() -> Self {
        Self {
            recorder: Mutex::new(AudioRecorder::new()),
        }
    }
}
