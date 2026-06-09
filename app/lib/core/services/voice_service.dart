import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// 语音录制结果
class VoiceRecording {
  final String id;
  final String path;
  final int duration; // 毫秒
  final int timestamp;

  VoiceRecording({
    required this.id,
    required this.path,
    required this.duration,
    required this.timestamp,
  });

  /// 时长（秒）
  double get durationInSeconds => duration / 1000;
}

/// 语音服务 - 处理录制和播放
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _isRecording = false;
  DateTime? _recordingStartTime;
  String? _currentRecordingPath;
  Timer? _recordingTimer;

  // 录制状态流
  final StreamController<bool> _recordingStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get recordingStateStream => _recordingStateController.stream;

  // 录制时长流（秒）
  final StreamController<int> _recordingDurationController =
      StreamController<int>.broadcast();
  Stream<int> get recordingDurationStream => _recordingDurationController.stream;

  // 播放状态流
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  // 播放进度流
  Stream<Duration?> get positionStream => _player.positionStream;

  // 播放总时长流
  Stream<Duration?> get durationStream => _player.durationStream;

  bool get isRecording => _isRecording;
  bool get isPlaying => _player.playing;

  /// 检查麦克风权限
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// 请求麦克风权限
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// 开始录音
  Future<bool> startRecording() async {
    if (_isRecording) {
      debugPrint('VoiceService: 已在录音中');
      return false;
    }

    // 检查权限
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        debugPrint('VoiceService: 没有麦克风权限');
        return false;
      }
    }

    try {
      // 检查是否支持录音
      if (!await _recorder.hasPermission()) {
        debugPrint('VoiceService: 录音器没有权限');
        return false;
      }

      // 生成文件路径
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/voice_$timestamp.m4a';

      // 配置录音参数
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      );

      // 开始录音
      await _recorder.start(config, path: _currentRecordingPath!);

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _recordingStateController.add(true);

      // 启动计时器
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_recordingStartTime != null) {
          final duration =
              DateTime.now().difference(_recordingStartTime!).inSeconds;
          _recordingDurationController.add(duration);

          // 最大录音时长 60 秒
          if (duration >= 60) {
            stopRecording();
          }
        }
      });

      debugPrint('VoiceService: 开始录音 -> $_currentRecordingPath');
      return true;
    } catch (e) {
      debugPrint('VoiceService: 开始录音失败 - $e');
      _isRecording = false;
      _recordingStateController.add(false);
      return false;
    }
  }

  /// 停止录音
  Future<VoiceRecording?> stopRecording() async {
    if (!_isRecording) {
      debugPrint('VoiceService: 当前没有在录音');
      return null;
    }

    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      final path = await _recorder.stop();
      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;

      _isRecording = false;
      _recordingStateController.add(false);
      _recordingDurationController.add(0);

      if (path == null || path.isEmpty) {
        debugPrint('VoiceService: 录音文件路径为空');
        return null;
      }

      // 检查文件是否存在
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('VoiceService: 录音文件不存在');
        return null;
      }

      // 最小录音时长 1 秒
      if (duration < 1000) {
        debugPrint('VoiceService: 录音时间太短');
        await file.delete();
        return null;
      }

      final recording = VoiceRecording(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        path: path,
        duration: duration,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      debugPrint('VoiceService: 录音完成 - 时长: ${recording.durationInSeconds}秒');
      return recording;
    } catch (e) {
      debugPrint('VoiceService: 停止录音失败 - $e');
      _isRecording = false;
      _recordingStateController.add(false);
      return null;
    }
  }

  /// 取消录音
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      await _recorder.stop();

      // 删除临时文件
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('VoiceService: 取消录音失败 - $e');
    }

    _isRecording = false;
    _currentRecordingPath = null;
    _recordingStartTime = null;
    _recordingStateController.add(false);
    _recordingDurationController.add(0);

    debugPrint('VoiceService: 录音已取消');
  }

  /// 获取当前录音时长（秒）
  int getRecordingDuration() {
    if (_recordingStartTime == null) return 0;
    return DateTime.now().difference(_recordingStartTime!).inSeconds;
  }

  /// 播放语音
  Future<void> play(String path) async {
    try {
      // 如果正在播放其他内容，先停止
      if (_player.playing) {
        await _player.stop();
      }

      // 设置音频源
      if (path.startsWith('http://') || path.startsWith('https://')) {
        await _player.setUrl(path);
      } else {
        await _player.setFilePath(path);
      }

      // 开始播放
      await _player.play();
      debugPrint('VoiceService: 开始播放 -> $path');
    } catch (e) {
      debugPrint('VoiceService: 播放失败 - $e');
      rethrow;
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    await _player.pause();
  }

  /// 继续播放
  Future<void> resume() async {
    await _player.play();
  }

  /// 停止播放
  Future<void> stop() async {
    await _player.stop();
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// 获取当前播放位置
  Duration get position => _player.position;

  /// 获取总时长
  Duration? get duration => _player.duration;

  /// 释放资源
  Future<void> dispose() async {
    _recordingTimer?.cancel();
    await _recorder.dispose();
    await _player.dispose();
    _recordingStateController.close();
    _recordingDurationController.close();
  }

  /// 格式化时长显示
  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// 读取语音文件为字节
  Future<List<int>?> readVoiceFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      debugPrint('VoiceService: 读取语音文件失败 - $e');
      return null;
    }
  }
}
