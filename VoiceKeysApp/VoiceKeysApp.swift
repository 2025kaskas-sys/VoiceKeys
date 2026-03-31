import SwiftUI
import AVFoundation
import Speech

@main
struct VoiceKeysApp: App {
    @StateObject private var recordingService = BackgroundRecordingService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recordingService)
                .onOpenURL { url in
                    guard url.scheme == AppConstants.urlScheme else { return }

                    // Request permissions if needed
                    AVAudioApplication.requestRecordPermission { _ in }
                    SFSpeechRecognizer.requestAuthorization { _ in }

                    // Activate session if not already running
                    if recordingService.state == .inactive {
                        recordingService.activateBackgroundSession()
                    }
                    // User will see "返回 xxx" in top-left to go back
                }
        }
    }
}
