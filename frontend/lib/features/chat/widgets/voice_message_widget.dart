import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/voice_service.dart';

/// 语音消息播放组件
class VoiceMessageWidget extends StatefulWidget {
  const VoiceMessageWidget({
    super.key,
    required this.audioUrl,
    required this.duration,
    this.isMine = false,
  });

  final String audioUrl;
  final int duration; // 毫秒
  final bool isMine;

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  final VoiceService _voiceService = VoiceService();
  bool _isPlaying = false;
  bool _isLoading = false;
  double _progress = 0.0; // 播放进度 0.0 - 1.0
  String? _currentPlayingUrl; // 当前正在播放的 URL
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _playerStateSubscription = _voiceService.playerStateStream.listen((state) {
      if (mounted) {
        // 检查是否是当前音频在播放
        final isCurrentPlaying = _currentPlayingUrl == widget.audioUrl;

        setState(() {
          if (isCurrentPlaying) {
            _isPlaying = state.playing;
            _isLoading =
                state.processingState == ProcessingState.loading ||
                state.processingState == ProcessingState.buffering;
          } else if (!state.playing) {
            // 其他音频停止播放时，重置本组件状态
            _isPlaying = false;
            _isLoading = false;
          }
        });

        // 播放完成后重置状态
        if (state.processingState == ProcessingState.completed &&
            isCurrentPlaying) {
          setState(() {
            _isPlaying = false;
            _progress = 0.0;
            _currentPlayingUrl = null;
          });
        }
      }
    });

    // 监听播放进度
    _positionSubscription = _voiceService.positionStream.listen((position) {
      if (mounted && _isPlaying && position != null) {
        final totalDuration = widget.duration;
        if (totalDuration > 0) {
          setState(() {
            _progress = (position.inMilliseconds / totalDuration).clamp(
              0.0,
              1.0,
            );
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _voiceService.stop();
      setState(() {
        _currentPlayingUrl = null;
      });
    } else {
      try {
        setState(() {
          _currentPlayingUrl = widget.audioUrl;
          _progress = 0.0;
        });
        await _voiceService.play(widget.audioUrl);
      } catch (e) {
        setState(() {
          _currentPlayingUrl = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('播放失败')));
        }
      }
    }
  }

  String _formatDuration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final durationText = _formatDuration(widget.duration);
    final bgColor = widget.isMine ? AppColors.primary : Colors.white;
    final textColor = widget.isMine ? Colors.white : AppColors.textPrimary;
    final iconColor = widget.isMine ? Colors.white : AppColors.primary;

    // 根据时长计算宽度（最小100，最大200）
    final width = (100 + (widget.duration / 1000) * 3).clamp(100.0, 200.0);
    final isCompact = width <= 120;
    final horizontalPadding = isCompact ? 8.0 : 12.0;
    final iconSize = isCompact ? 20.0 : 24.0;
    final gap = isCompact ? 4.0 : 8.0;
    final durationFontSize = isCompact ? 11.0 : 12.0;

    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: widget.isMine
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          // 与 Expanded 子组件配合时保持 max，避免小时长/大字重场景溢出
          mainAxisSize: MainAxisSize.max,
          children: [
            // 播放/暂停按钮
            _isLoading
                ? SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: iconColor,
                    ),
                  )
                : Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: iconColor,
                    size: iconSize,
                  ),
            SizedBox(width: gap),
            // 波形进度条
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 24) {
                    return const SizedBox.shrink();
                  }

                  return _VoiceWaveformProgress(
                    isPlaying: _isPlaying,
                    progress: _progress,
                    playedColor: widget.isMine
                        ? Colors.white
                        : AppColors.primary,
                    unplayedColor: textColor.withValues(alpha: 0.3),
                  );
                },
              ),
            ),
            SizedBox(width: gap),
            // 时长
            Text(
              durationText,
              style: TextStyle(
                fontSize: durationFontSize,
                color: textColor.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// 带进度条的波形组件
class _VoiceWaveformProgress extends StatefulWidget {
  const _VoiceWaveformProgress({
    required this.isPlaying,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  final bool isPlaying;
  final double progress; // 0.0 - 1.0
  final Color playedColor;
  final Color unplayedColor;

  @override
  State<_VoiceWaveformProgress> createState() => _VoiceWaveformProgressState();
}

class _VoiceWaveformProgressState extends State<_VoiceWaveformProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // 波形条的基础高度比例
  static const List<double> _baseHeights = [
    0.4,
    0.7,
    0.5,
    0.8,
    0.6,
    0.9,
    0.5,
    0.7,
    0.4,
    0.6,
    0.8,
    0.5,
  ];
  static const int _barCount = 12;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_VoiceWaveformProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_barCount, (index) {
            final baseHeight = _baseHeights[index];
            // 播放时有动画效果
            final animatedHeight = widget.isPlaying
                ? baseHeight * (0.5 + _controller.value * 0.5)
                : baseHeight * 0.5;

            // 根据进度确定颜色
            final barProgress = (index + 1) / _barCount;
            final isPlayed = barProgress <= widget.progress;

            return Container(
              width: 2,
              height: 16 * animatedHeight,
              decoration: BoxDecoration(
                color: isPlayed ? widget.playedColor : widget.unplayedColor,
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        );
      },
    );
  }
}

/// 语音录制面板
class VoiceRecordingPanel extends StatefulWidget {
  const VoiceRecordingPanel({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  final void Function(VoiceRecording recording) onRecordingComplete;
  final VoidCallback onCancel;

  @override
  State<VoiceRecordingPanel> createState() => _VoiceRecordingPanelState();
}

class _VoiceRecordingPanelState extends State<VoiceRecordingPanel> {
  final VoiceService _voiceService = VoiceService();
  bool _isRecording = false;
  int _recordingDuration = 0;
  StreamSubscription<int>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _durationSubscription = _voiceService.recordingDurationStream.listen((
      duration,
    ) {
      if (mounted) {
        setState(() {
          _recordingDuration = duration;
        });
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    if (_isRecording) {
      _voiceService.cancelRecording();
    }
    super.dispose();
  }

  Future<void> _startRecording() async {
    final success = await _voiceService.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法开始录音，请检查麦克风权限')));
      }
    }
  }

  Future<void> _stopRecording() async {
    final recording = await _voiceService.stopRecording();
    setState(() {
      _isRecording = false;
    });
    if (recording != null) {
      widget.onRecordingComplete(recording);
    }
  }

  Future<void> _cancelRecording() async {
    await _voiceService.cancelRecording();
    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
    });
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 录制状态显示
            if (_isRecording) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 录制指示器
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '正在录音 ${VoiceService.formatDuration(_recordingDuration)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '松开发送，上滑取消',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ] else ...[
              Text(
                '按住录音',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 16),
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 取消按钮
                GestureDetector(
                  onTap: _cancelRecording,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.grey,
                      size: 28,
                    ),
                  ),
                ),
                // 录制按钮
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd: (_) => _stopRecording(),
                  onLongPressCancel: () => _cancelRecording(),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.red : AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? Colors.red : AppColors.primary)
                              .withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                // 发送按钮（录音后显示）
                GestureDetector(
                  onTap: _isRecording ? _stopRecording : null,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? AppColors.primary
                          : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send,
                      color: _isRecording ? Colors.white : Colors.grey,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
