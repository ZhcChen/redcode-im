package com.redcode.im.androidapp.feature.chat

import android.media.MediaPlayer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

enum class AudioPlaybackPhase {
    Idle,
    Loading,
    Playing,
    Paused,
    Failed,
}

data class AudioPlaybackState(
    val phase: AudioPlaybackPhase = AudioPlaybackPhase.Idle,
    val localPath: String? = null,
    val message: String? = null,
) {
    val label: String =
        when (phase) {
            AudioPlaybackPhase.Idle -> "未播放"
            AudioPlaybackPhase.Loading -> "加载中"
            AudioPlaybackPhase.Playing -> "播放中"
            AudioPlaybackPhase.Paused -> message ?: "已暂停"
            AudioPlaybackPhase.Failed -> message ?: "播放失败"
        }

    val actionLabel: String =
        when (phase) {
            AudioPlaybackPhase.Playing -> "暂停"
            AudioPlaybackPhase.Loading -> "加载中"
            AudioPlaybackPhase.Paused -> "继续"
            else -> "播放"
        }
}

interface AudioPlaybackController {
    suspend fun play(localPath: String, onCompleted: () -> Unit)

    fun pause()

    fun stop()
}

object NoopAudioPlaybackController : AudioPlaybackController {
    override suspend fun play(localPath: String, onCompleted: () -> Unit) = Unit

    override fun pause() = Unit

    override fun stop() = Unit
}

class AndroidAudioPlaybackController : AudioPlaybackController {
    private var mediaPlayer: MediaPlayer? = null

    override suspend fun play(localPath: String, onCompleted: () -> Unit) {
        withContext(Dispatchers.Main) {
            mediaPlayer?.release()
            mediaPlayer = null
            val player = MediaPlayer()
            try {
                player.apply {
                    setDataSource(localPath)
                    setOnCompletionListener {
                        onCompleted()
                        releasePlayer()
                    }
                    prepare()
                    start()
                }
                mediaPlayer = player
            } catch (error: Throwable) {
                player.release()
                throw error
            }
        }
    }

    override fun pause() {
        mediaPlayer?.takeIf { it.isPlaying }?.pause()
    }

    override fun stop() {
        releasePlayer()
    }

    private fun releasePlayer() {
        mediaPlayer?.release()
        mediaPlayer = null
    }
}
