import AVFoundation
import Foundation
import Observation
import RedCodeStorage

@MainActor
@Observable
public final class VoiceRecorderController {
    public private(set) var isRecording = false
    public private(set) var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var startedAt: Date?
    private var currentURL: URL?

    public init() {}

    public func start() async throws {
        #if os(iOS)
        let granted = await requestRecordPermission()
        guard granted else {
            throw VoiceMediaError.microphonePermissionDenied
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)
        #endif

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw VoiceMediaError.recordingFailed
        }
        self.recorder = recorder
        self.currentURL = url
        self.startedAt = Date()
        self.errorMessage = nil
        self.isRecording = true
    }

    public func stop() throws -> PreparedUploadFile {
        guard let recorder, let currentURL else {
            throw VoiceMediaError.notRecording
        }
        recorder.stop()
        self.recorder = nil
        self.currentURL = nil
        self.isRecording = false

        let duration = startedAt.map { max(0, Int(Date().timeIntervalSince($0) * 1_000)) }
        startedAt = nil
        return try MediaUploadPreparer.prepareFile(
            at: currentURL,
            kind: .audio,
            fileName: currentURL.lastPathComponent,
            contentType: "audio/mp4",
            durationMilliseconds: duration
        )
    }

    public func cancel() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        startedAt = nil
        if let currentURL {
            try? FileManager.default.removeItem(at: currentURL)
        }
        currentURL = nil
    }

    #if os(iOS)
    private func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    #endif
}

@MainActor
@Observable
public final class VoicePlaybackController {
    public private(set) var isPlaying = false
    public private(set) var errorMessage: String?

    private var player: AVAudioPlayer?

    public init() {}

    public func play(url: URL) throws {
        if isPlaying {
            stop()
            return
        }
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        guard player.play() else {
            throw VoiceMediaError.playbackFailed
        }
        self.player = player
        self.errorMessage = nil
        self.isPlaying = true
    }

    public func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }
}

public enum VoiceMediaError: LocalizedError, Equatable, Sendable {
    case microphonePermissionDenied
    case recordingFailed
    case notRecording
    case playbackFailed

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            "麦克风权限未开启，可在系统设置中允许访问后重试"
        case .recordingFailed:
            "语音录制启动失败"
        case .notRecording:
            "当前没有正在录制的语音"
        case .playbackFailed:
            "语音播放失败"
        }
    }
}
