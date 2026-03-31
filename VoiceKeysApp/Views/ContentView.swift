import SwiftUI
import AVFoundation
import Speech

struct ContentView: View {
    @EnvironmentObject var service: BackgroundRecordingService

    var body: some View {
        ZStack {
            DarkTheme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Status icon
                Image(systemName: statusIcon)
                    .font(.system(size: 80))
                    .foregroundColor(statusColor)

                Text("VoiceKeys")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(DarkTheme.textPrimary)

                Text(statusText)
                    .font(.system(size: 16))
                    .foregroundColor(statusColor)

                Spacer()

                // Toggle session
                Button(action: toggleSession) {
                    HStack(spacing: 12) {
                        Image(systemName: service.state != .inactive ? "mic.circle.fill" : "mic.slash.circle")
                            .font(.system(size: 24))
                        Text(service.state != .inactive ? "语音服务运行中" : "启动语音服务")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(service.state != .inactive ? Color.green : DarkTheme.accent)
                    .cornerRadius(16)
                }
                .padding(.horizontal)

                // Stop recording button (shown during recording)
                if case .recording = service.state {
                    Button(action: {
                        service.stopRecordingManually()
                    }) {
                        Text("点击完成")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                if service.state != .inactive {
                    Text("服务已开启，可以最小化此 app\n回到其他 app 使用 VoiceKeys 键盘")
                        .font(.system(size: 13))
                        .foregroundColor(DarkTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Live status when recording
                if case .recording = service.state {
                    VStack(spacing: 8) {
                        Text("录音中...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                        if !service.liveTranscript.isEmpty {
                            Text(service.liveTranscript)
                                .font(.system(size: 14))
                                .foregroundColor(DarkTheme.textSecondary)
                                .lineLimit(3)
                                .padding(.horizontal)
                        }
                    }
                }

                if case .processing = service.state {
                    Text("润色中...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DarkTheme.accent)
                }

                Spacer()

                // Settings
                SettingsSection()

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            requestPermissions()
        }
    }

    private var statusIcon: String {
        switch service.state {
        case .inactive: return "mic.slash.circle"
        case .ready: return "mic.circle.fill"
        case .recording: return "waveform.circle.fill"
        case .processing: return "sparkles"
        case .done: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch service.state {
        case .inactive: return DarkTheme.textSecondary
        case .ready: return .green
        case .recording: return .red
        case .processing: return DarkTheme.accent
        case .done: return .green
        case .error: return .orange
        }
    }

    private var statusText: String {
        switch service.state {
        case .inactive: return "语音服务未启动"
        case .ready: return "就绪，等待键盘指令"
        case .recording: return "正在录音..."
        case .processing: return "润色中..."
        case .done(let text): return "✓ \(text.prefix(30))..."
        case .error(let msg): return msg
        }
    }

    private func toggleSession() {
        if service.state == .inactive {
            service.activateBackgroundSession()
        } else {
            service.deactivateSession()
        }
    }

    private func requestPermissions() {
        AVAudioApplication.requestRecordPermission { _ in }
        SFSpeechRecognizer.requestAuthorization { _ in }
    }
}

// MARK: - Settings
struct SettingsSection: View {
    @State private var selectedLocale = SharedDefaults.selectedLanguage
    @State private var apiKey = SharedDefaults.apiKey ?? ""

    var body: some View {
        VStack(spacing: 12) {
            // Language
            Picker("Language", selection: $selectedLocale) {
                ForEach(AppConstants.languages, id: \.locale) { lang in
                    Text("\(lang.flag) \(lang.name)").tag(lang.locale)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedLocale) { _, val in
                SharedDefaults.selectedLanguage = val
            }

            // API Key
            HStack {
                Text("Moonshot API")
                    .font(.system(size: 12))
                    .foregroundColor(DarkTheme.textSecondary)
                Spacer()
                Text(apiKey.isEmpty ? "未设置" : "已配置 ✓")
                    .font(.system(size: 12))
                    .foregroundColor(apiKey.isEmpty ? .orange : .green)
            }
        }
        .padding()
        .background(DarkTheme.surface)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
