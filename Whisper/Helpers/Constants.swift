import Foundation

enum LocalWhisperModel: String, CaseIterable, Codable, Identifiable {
    case base = "base"
    case small = "small"
    case largeV3Turbo = "large-v3_turbo"
    case largeV3 = "large-v3"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .base: return "Base"
        case .small: return "Small"
        case .largeV3Turbo: return "Large V3 Turbo"
        case .largeV3: return "Large V3"
        }
    }
    
    var fileName: String {
        switch self {
        case .base: return "openai_whisper-base"
        case .small: return "openai_whisper-small"
        case .largeV3Turbo: return "openai_whisper-large-v3_turbo"
        case .largeV3: return "openai_whisper-large-v3"
        }
    }
    
    var fileSize: String {
        switch self {
        case .base: return "~74 Mo"
        case .small: return "~244 Mo"
        case .largeV3Turbo: return "~954 Mo"
        case .largeV3: return "~1.5 Go"
        }
    }
    
    var fileSizeBytes: Int64 {
        switch self {
        case .base: return 77_500_000
        case .small: return 256_000_000
        case .largeV3Turbo: return 1_000_000_000
        case .largeV3: return 1_573_000_000
        }
    }
    
    var description: String {
        switch self {
        case .base: return "Ultra-rapide, précision de base"
        case .small: return "Très rapide, bonne précision"
        case .largeV3Turbo: return "Haute précision, équilibré"
        case .largeV3: return "Meilleure précision"
        }
    }
    
    var icon: String {
        switch self {
        case .base: return "hare.fill"
        case .small: return "hare"
        case .largeV3Turbo: return "tortoise.fill"
        case .largeV3: return "tortoise"
        }
    }
}

enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double, bytesDownloaded: Int64, bytesTotal: Int64)
    case downloaded
    case error(String)
    
    var isReady: Bool {
        if case .downloaded = self { return true }
        return false
    }
    
    var statusText: String {
        switch self {
        case .notDownloaded:
            return "Non téléchargé"
        case .downloading(let progress, let downloaded, let total):
            let downloadedMB = formatBytes(downloaded)
            let totalMB = formatBytes(total)
            return "\(Int(progress * 100))% (\(downloadedMB)/\(totalMB))"
        case .downloaded:
            return "Prêt"
        case .error(let message):
            return "Erreur: \(message)"
        }
    }
    
    var shortStatusText: String {
        switch self {
        case .notDownloaded:
            return "Non téléchargé"
        case .downloading(let progress, _, _):
            return "Téléchargement: \(Int(progress * 100))%"
        case .downloaded:
            return "Prêt"
        case .error(let message):
            return "Erreur: \(message)"
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_000_000
        if mb >= 1000 {
            return String(format: "%.1f Go", mb / 1000)
        }
        return String(format: "%.1f Mo", mb)
    }
}

enum Constants {
    // Keychain
    static let keychainService = "com.hyrak.whisper"
    static let keychainAPIKeyAccount = "openai-api-key"

    // OpenAI API (Cloud mode)
    static let openAITranscriptionURL = "https://api.openai.com/v1/audio/transcriptions"
    static let openAIModel = "gpt-4o-mini-transcribe"

    // WhisperKit (Local mode)
    static let whisperKitLanguage = "fr"

    // User Defaults
    static let transcriptionModeKey = "transcriptionMode"
    
    // Local Whisper Model
    static let localWhisperModelKey = "localWhisperModel"
    static let defaultLocalModel: LocalWhisperModel = .largeV3
    
    static var selectedLocalModel: LocalWhisperModel {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: localWhisperModelKey),
               let model = LocalWhisperModel(rawValue: rawValue) {
                return model
            }
            return defaultLocalModel
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: localWhisperModelKey)
        }
    }

    // Timing
    static let doubleTapInterval: TimeInterval = 0.3 // 300ms pour double-tap
}
