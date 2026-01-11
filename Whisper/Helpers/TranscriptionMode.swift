import Foundation

enum TranscriptionMode: String, CaseIterable, Codable {
    case cloud = "cloud"
    case local = "local"

    var displayName: String {
        switch self {
        case .cloud:
            return "Cloud (API)"
        case .local:
            return "Local"
        }
    }

    var description: String {
        switch self {
        case .cloud:
            return "Utilise l'API OpenAI (nécessite une clé API et une connexion internet)"
        case .local:
            return "Transcription sur l'appareil avec WhisperKit (fonctionne hors ligne)"
        }
    }

    var icon: String {
        switch self {
        case .cloud:
            return "cloud"
        case .local:
            return "cpu"
        }
    }
}
