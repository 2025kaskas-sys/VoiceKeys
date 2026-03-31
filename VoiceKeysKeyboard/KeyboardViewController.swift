import UIKit
import SwiftUI

class KeyboardViewController: UIInputViewController {
    private var pollTimer: Timer?
    private var isRecording = false

    override func viewDidLoad() {
        super.viewDidLoad()
        showKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkAndInsertResult()
    }

    // MARK: - UI

    private func showKeyboard() {
        children.forEach { $0.view.removeFromSuperview(); $0.removeFromParent() }

        let sessionActive = SharedDefaults.isSessionActive

        let keyboardView = KeyboardMainView(
            activateURL: URL(string: AppConstants.recordURL)!,
            sessionActive: sessionActive,
            isRecording: isRecording,
            onMicTap: { [weak self] in self?.handleMicTap() },
            onStopTap: { [weak self] in self?.handleStopTap() },
            onGlobeTap: { [weak self] in self?.advanceToNextInputMode() },
            onDeleteTap: { [weak self] in self?.textDocumentProxy.deleteBackward() },
            onReturnTap: { [weak self] in self?.textDocumentProxy.insertText("\n") },
            onSpaceTap: { [weak self] in self?.textDocumentProxy.insertText(" ") }
        )

        let hc = UIHostingController(rootView: keyboardView)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear

        addChild(hc)
        view.addSubview(hc.view)

        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hc.view.heightAnchor.constraint(equalToConstant: 130)
        ])

        hc.didMove(toParent: self)
    }

    // MARK: - Actions

    private func handleMicTap() {
        // Session active → send command directly, no app switch
        SharedDefaults.clear()
        SharedDefaults.sendCommand("startRecording")
        isRecording = true
        showKeyboard() // Refresh UI to show recording state
        startResultPolling()
    }

    private func handleStopTap() {
        SharedDefaults.sendCommand("stopRecording")
        isRecording = false
        showKeyboard() // Refresh UI back to normal
        startResultPolling()
    }

    // MARK: - Polling

    private func startResultPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkAndInsertResult()
        }

        // Timeout after 120s
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
            self?.pollTimer?.invalidate()
        }
    }

    private func checkAndInsertResult() {
        // Try file first
        if let fileStatus = SharedDefaults.readStatusFile(),
           fileStatus.status == "done",
           !fileStatus.result.isEmpty {
            pollTimer?.invalidate()
            textDocumentProxy.insertText(fileStatus.result)
            clearAllResults()
            isRecording = false
            showKeyboard()
            return
        }

        // Fallback: UserDefaults
        SharedDefaults.suite.synchronize()
        if let status = SharedDefaults.string(for: .status),
           status == "done",
           let text = SharedDefaults.string(for: .polishedText),
           !text.isEmpty {
            pollTimer?.invalidate()
            textDocumentProxy.insertText(text)
            clearAllResults()
            isRecording = false
            showKeyboard()
        }
    }

    private func clearAllResults() {
        SharedDefaults.clear()
        if let dir = SharedDefaults.sharedContainerURL {
            try? "".write(to: dir.appendingPathComponent("status.txt"), atomically: true, encoding: .utf8)
        }
    }
}
