import Foundation

enum AppConstants {
    static let appGroupID = "group.com.domingo.voicekeys"
    static let urlScheme = "voicekeys"
    static let recordURL = "voicekeys://record"

    // Supported languages
    static let languages: [(name: String, locale: String, flag: String)] = [
        ("中文", "zh-Hans", "🇨🇳"),
        ("English", "en-US", "🇺🇸"),
        ("Español", "es-ES", "🇪🇸")
    ]
}
