import Foundation
import AVFoundation
import Speech
import Combine

/// Maintains a live microphone session to keep the app alive in background.
/// When the keyboard sends a command, starts speech recognition on the live audio stream.
@MainActor
final class BackgroundRecordingService: ObservableObject {
    enum State: Equatable {
        case inactive
        case ready          // Mic session active, waiting
        case recording      // Speech recognition active
        case processing     // Polishing
        case done(String)
        case error(String)
    }

    @Published var state: State = .inactive
    @Published var liveTranscript = ""

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var commandPollTimer: Timer?
    private var heartbeatTimer: Timer?
    private var idleTimer: Timer?
    private var lastCommandTimestamp: String = ""
    private let idleTimeout: TimeInterval = 5 * 60 // 5 minutes

    // MARK: - Activate: start mic session to keep app alive

    func activateBackgroundSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            // Start AVAudioEngine with mic input — this keeps the app alive in background
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            guard format.sampleRate > 0 && format.channelCount > 0 else {
                state = .error("麦克风不可用")
                return
            }

            // Install a tap that does nothing — just keeps the mic active
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { _, _ in
                // Audio flows through but we don't process it yet
                // This keeps the app alive in background
            }

            engine.prepare()
            try engine.start()

            self.audioEngine = engine
            SharedDefaults.isSessionActive = true
            state = .ready
            startPollingForCommands()
            startHeartbeat()
            resetIdleTimer()

        } catch {
            state = .error("启动失败: \(error.localizedDescription)")
        }
    }

    func deactivateSession() {
        idleTimer?.invalidate()
        idleTimer = nil
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        stopPollingForCommands()
        stopRecording()
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        SharedDefaults.isSessionActive = false
        state = .inactive
    }

    // MARK: - Idle Timer (auto-shutdown after inactivity)

    private func resetIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.deactivateSession()
            }
        }
    }

    // MARK: - Heartbeat (tells keyboard the service is alive)

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        SharedDefaults.updateHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            SharedDefaults.updateHeartbeat()
        }
    }

    // MARK: - Command Polling (Timer + Darwin notification)

    private func startPollingForCommands() {
        // Darwin notification (cross-process, works in background)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = "com.domingo.voicekeys.command" as CFString
        CFNotificationCenterAddObserver(center, Unmanaged.passUnretained(self).toOpaque(), { _, observer, _, _, _ in
            guard let observer = observer else { return }
            let service = Unmanaged<BackgroundRecordingService>.fromOpaque(observer).takeUnretainedValue()
            Task { @MainActor in
                service.checkForCommand()
            }
        }, name, nil, .deliverImmediately)

        // Timer fallback
        commandPollTimer?.invalidate()
        commandPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForCommand()
            }
        }
    }

    private func stopPollingForCommands() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
        commandPollTimer?.invalidate()
        commandPollTimer = nil
    }

    private func checkForCommand() {
        // Try file-based IPC first
        var command: String?
        var timestamp: String?

        if let fileCmd = SharedDefaults.readCommandFile(), !fileCmd.command.isEmpty {
            command = fileCmd.command
            timestamp = fileCmd.timestamp
        } else {
            SharedDefaults.suite.synchronize()
            command = SharedDefaults.string(for: .command)
            timestamp = SharedDefaults.string(for: .commandTimestamp)
        }

        guard let cmd = command, !cmd.isEmpty else { return }
        let ts = timestamp ?? ""
        guard ts != lastCommandTimestamp else { return }
        lastCommandTimestamp = ts

        switch cmd {
        case "startRecording":
            startRecording()
        case "stopRecording":
            stopRecording()
        default:
            break
        }

        SharedDefaults.clearCommandFile()
        SharedDefaults.set("", for: .command)
    }

    // MARK: - Public methods (for in-app use)

    func startRecordingManually() {
        startRecording()
    }

    func stopRecordingManually() {
        stopRecording()
    }

    // MARK: - Recording (uses the already-running audio engine)

    private func startRecording() {
        guard state != .recording else { return }
        resetIdleTimer() // Reset idle timer on activity
        guard audioEngine != nil else {
            SharedDefaults.writeStatus("error", error: "音频引擎未启动")
            return
        }

        // Always recognize Chinese — language selection is for OUTPUT (translation)
        let recognitionLocale = "zh-Hans"
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: recognitionLocale)),
              recognizer.isAvailable else {
            SharedDefaults.writeStatus("error", error: "语音识别不可用")
            return
        }

        // Remove the idle tap and replace with recognition tap
        let engine = audioEngine!
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }

        do {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true

            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            engine.prepare()
            try engine.start()

            self.recognitionRequest = request
            self.liveTranscript = ""

            SharedDefaults.writeStatus("recording")
            state = .recording

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    if let result = result {
                        self?.liveTranscript = result.bestTranscription.formattedString
                        // Write live transcript to file for keyboard to read
                        SharedDefaults.set(result.bestTranscription.formattedString, for: .rawText)
                    }
                    if let error = error {
                        let nsErr = error as NSError
                        if nsErr.domain != "kAFAssistantErrorDomain" || nsErr.code != 216 {
                            // Real error
                        }
                    }
                }
            }
        } catch {
            SharedDefaults.writeStatus("error", error: "录音失败: \(error.localizedDescription)")
            state = .error(error.localizedDescription)
            // Restore idle tap
            restoreIdleTap()
        }
    }

    private func stopRecording() {
        guard state == .recording else { return }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        let rawText = liveTranscript

        // Restore the idle mic tap (keeps app alive)
        restoreIdleTap()

        guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state = .ready
            SharedDefaults.writeStatus("error", error: "没有检测到语音")
            return
        }

        // Polish
        state = .processing
        SharedDefaults.writeStatus("polishing")

        Task {
            let apiKey = SharedDefaults.apiKey ?? ""
            var finalText = rawText

            if !apiKey.isEmpty {
                SharedDefaults.suite.synchronize()
                let outputLocale = SharedDefaults.selectedLanguage
                let outputLanguage = AppConstants.languages.first { $0.locale == outputLocale }?.name ?? "中文"
                let service = PolishingService(apiKey: apiKey)
                do {
                    finalText = try await service.polish(text: rawText, outputLanguage: outputLanguage, outputLocale: outputLocale)
                } catch {
                    finalText = rawText
                }
            }
            // If polished text is same as raw (API might have failed silently), just use raw
            if finalText.isEmpty { finalText = rawText }

            SharedDefaults.writeStatus("done", result: finalText)
            state = .done(finalText)

            // Go back to ready after a moment
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            state = .ready
        }
    }

    // Restore idle mic tap (no recognition, just keeps app alive)
    private func restoreIdleTap() {
        guard let engine = audioEngine else { return }

        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }

        do {
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { _, _ in }
            engine.prepare()
            try engine.start()
        } catch {
            // Engine restart failed
        }
    }
}
