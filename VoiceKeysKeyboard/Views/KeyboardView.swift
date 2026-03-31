import SwiftUI

struct KeyboardMainView: View {
    let activateURL: URL
    let sessionActive: Bool
    let isRecording: Bool
    let onMicTap: () -> Void
    let onStopTap: () -> Void
    let onGlobeTap: () -> Void
    let onDeleteTap: () -> Void
    let onReturnTap: () -> Void
    let onSpaceTap: () -> Void

    @State private var currentLanguage: String = SharedDefaults.selectedLanguage
    @State private var rawText: String = ""
    private let textTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var languageLabel: String {
        AppConstants.languages.first { $0.locale == currentLanguage }?.flag ?? "🇨🇳"
    }

    var body: some View {
        ZStack {
            DarkTheme.background

            if isRecording {
                // Recording mode
                recordingView
            } else {
                // Normal keyboard mode
                normalView
            }
        }
        .frame(height: 130)
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 4) {
            HStack {
                if rawText.isEmpty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("正在录音...")
                            .font(.system(size: 13))
                            .foregroundColor(DarkTheme.textSecondary)
                    }
                } else {
                    Text(rawText)
                        .font(.system(size: 13))
                        .foregroundColor(DarkTheme.textPrimary)
                        .lineLimit(2)
                        .truncationMode(.head)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer(minLength: 0)

            Button(action: onStopTap) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                    Text("完成")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: 120, height: 40)
                .background(DarkTheme.micActive)
                .cornerRadius(20)
            }
            .padding(.bottom, 10)
        }
        .onReceive(textTimer) { _ in
            SharedDefaults.suite.synchronize()
            rawText = SharedDefaults.string(for: .rawText) ?? ""
        }
    }

    // MARK: - Normal View

    private var normalView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("VoiceKeys")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DarkTheme.textSecondary)
                Spacer(minLength: 0)
                if sessionActive {
                    Text("点击麦克风说话")
                        .font(.system(size: 11))
                        .foregroundColor(DarkTheme.textSecondary.opacity(0.7))
                } else {
                    Text("请先打开 VoiceKeys app")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 6)

            HStack(spacing: 0) {
                // Left: globe + language
                HStack(spacing: 2) {
                    Button(action: onGlobeTap) {
                        Image(systemName: "globe")
                            .font(.system(size: 20))
                            .foregroundColor(DarkTheme.textSecondary)
                            .frame(width: 34, height: 34)
                    }
                    Button(action: cycleLanguage) {
                        Text(languageLabel)
                            .font(.system(size: 20))
                            .frame(width: 34, height: 34)
                    }
                }

                Spacer(minLength: 0)

                // Center: Mic
                if sessionActive {
                    // Session active → Button (no app switch!)
                    Button(action: onMicTap) {
                        micContent(active: true)
                    }
                } else {
                    // Session not active → Link to open main app
                    Link(destination: activateURL) {
                        micContent(active: false)
                    }
                }

                Spacer(minLength: 0)

                // Right: space + delete + return
                HStack(spacing: 2) {
                    Button(action: onSpaceTap) {
                        Text("空格")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DarkTheme.textSecondary)
                            .frame(width: 40, height: 32)
                            .background(DarkTheme.surface)
                            .cornerRadius(5)
                    }
                    Button(action: onDeleteTap) {
                        Image(systemName: "delete.left")
                            .font(.system(size: 18))
                            .foregroundColor(DarkTheme.textSecondary)
                            .frame(width: 34, height: 34)
                    }
                    Button(action: onReturnTap) {
                        Image(systemName: "return")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 32)
                            .background(DarkTheme.surface)
                            .cornerRadius(5)
                    }
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }

    private func micContent(active: Bool) -> some View {
        ZStack {
            Circle()
                .fill(active ? DarkTheme.accent : DarkTheme.surface)
                .frame(width: 52, height: 52)
            Image(systemName: "mic.fill")
                .font(.system(size: 22))
                .foregroundColor(active ? .white : DarkTheme.textSecondary)
        }
    }

    private func cycleLanguage() {
        let locales = AppConstants.languages.map(\.locale)
        guard let idx = locales.firstIndex(of: currentLanguage) else { return }
        let next = locales[(idx + 1) % locales.count]
        currentLanguage = next
        SharedDefaults.selectedLanguage = next
    }
}
