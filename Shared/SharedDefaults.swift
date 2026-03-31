import Foundation

enum SharedKey: String {
    case polishedText
    case rawText
    case status           // idle | recording | recognizing | polishing | done | error
    case errorMessage
    case selectedLanguage
    case apiKey
    case command          // keyboard → app: "startRecording" | "stopRecording" | ""
    case commandTimestamp // when the command was issued
    case sessionActive    // "true" if background session is alive
}

final class SharedDefaults {
    static let suite = UserDefaults(suiteName: AppConstants.appGroupID)!

    static func set(_ value: String, for key: SharedKey) {
        suite.set(value, forKey: key.rawValue)
        suite.synchronize()
    }

    static func string(for key: SharedKey) -> String? {
        suite.string(forKey: key.rawValue)
    }

    static func clear() {
        // Only clear result fields, NOT command fields
        [SharedKey.polishedText, .rawText, .status, .errorMessage].forEach {
            suite.removeObject(forKey: $0.rawValue)
        }
        suite.synchronize()
    }

    static var selectedLanguage: String {
        get { string(for: .selectedLanguage) ?? "zh-Hans" }
        set { set(newValue, for: .selectedLanguage) }
    }

    static let defaultAPIKey = "sk-9N66iM4UbmgZbJQzpoD7HtfPclAuKXhf1OhWCp6wUyNBHoYH"

    static var apiKey: String? {
        get { string(for: .apiKey) ?? defaultAPIKey }
        set {
            if let newValue = newValue {
                set(newValue, for: .apiKey)
            } else {
                suite.removeObject(forKey: SharedKey.apiKey.rawValue)
                suite.synchronize()
            }
        }
    }

    static var isSessionActive: Bool {
        get {
            // Check heartbeat — if main app hasn't updated in 5 seconds, it's dead
            suite.synchronize()
            guard let tsStr = suite.string(forKey: "heartbeat"),
                  let ts = Double(tsStr) else { return false }
            return Date().timeIntervalSince1970 - ts < 5.0
        }
        set {
            if newValue {
                updateHeartbeat()
            } else {
                suite.removeObject(forKey: "heartbeat")
                suite.synchronize()
            }
        }
    }

    static func updateHeartbeat() {
        suite.set(String(Date().timeIntervalSince1970), forKey: "heartbeat")
        suite.synchronize()
    }

    // MARK: - File-based IPC (more reliable than UserDefaults cross-process)

    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID)
    }

    static func sendCommand(_ cmd: String) {
        // Write to UserDefaults
        set(cmd, for: .command)
        set(String(Date().timeIntervalSince1970), for: .commandTimestamp)

        // Also write to file (more reliable cross-process)
        if let dir = sharedContainerURL {
            let cmdFile = dir.appendingPathComponent("command.txt")
            try? "\(cmd)|\(Date().timeIntervalSince1970)".write(to: cmdFile, atomically: true, encoding: .utf8)
        }

        // Post Darwin notification to wake up main app
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName("com.domingo.voicekeys.command" as CFString), nil, nil, true)
    }

    static func readCommandFile() -> (command: String, timestamp: String)? {
        guard let dir = sharedContainerURL else { return nil }
        let cmdFile = dir.appendingPathComponent("command.txt")
        guard let content = try? String(contentsOf: cmdFile, encoding: .utf8) else { return nil }
        let parts = content.split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (command: String(parts[0]), timestamp: String(parts[1]))
    }

    static func clearCommandFile() {
        guard let dir = sharedContainerURL else { return }
        let cmdFile = dir.appendingPathComponent("command.txt")
        try? "".write(to: cmdFile, atomically: true, encoding: .utf8)
    }

    static func writeStatus(_ status: String, result: String = "", error: String = "") {
        // Write to UserDefaults
        set(status, for: .status)
        if !result.isEmpty { set(result, for: .polishedText) }
        if !error.isEmpty { set(error, for: .errorMessage) }

        // Also write to file
        if let dir = sharedContainerURL {
            let statusFile = dir.appendingPathComponent("status.txt")
            try? "\(status)|\(result)|\(error)".write(to: statusFile, atomically: true, encoding: .utf8)
        }
    }

    static func readStatusFile() -> (status: String, result: String, error: String)? {
        guard let dir = sharedContainerURL else { return nil }
        let statusFile = dir.appendingPathComponent("status.txt")
        guard let content = try? String(contentsOf: statusFile, encoding: .utf8), !content.isEmpty else { return nil }
        let parts = content.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 1 else { return nil }
        return (status: parts[0], result: parts.count > 1 ? parts[1] : "", error: parts.count > 2 ? parts[2] : "")
    }
}
