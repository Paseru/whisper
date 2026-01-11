import Foundation

final class CloudTranscriptionProvider: TranscriptionProvider {
    static let shared = CloudTranscriptionProvider()

    private init() {}

    struct TranscriptionResponse: Codable {
        let text: String
    }

    struct ErrorResponse: Codable {
        let error: ErrorDetail
    }

    struct ErrorDetail: Codable {
        let message: String
        let type: String?
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard let apiKey = KeychainHelper.shared.getAPIKey() else {
            throw CloudTranscriptionError.noAPIKey
        }

        guard let url = URL(string: Constants.openAITranscriptionURL) else {
            throw CloudTranscriptionError.invalidURL
        }

        let audioData = try Data(contentsOf: audioURL)
        let boundary = UUID().uuidString

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Ajouter le fichier audio
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Ajouter le modèle
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(Constants.openAIModel)\r\n".data(using: .utf8)!)

        // Ajouter la langue (français)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("fr\r\n".data(using: .utf8)!)

        // Ajouter le prompt avec des mots-clés techniques pour améliorer la reconnaissance
        let prompt = "API, SDK, GitHub, TypeScript, JavaScript, React, Node.js, Python, Claude, GPT, LLM, MCP, STT, TTS, Whisper, OpenAI, Anthropic, Convex, Vercel, Next.js, SwiftUI, Xcode, iOS, macOS"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(prompt)\r\n".data(using: .utf8)!)

        // Terminer le body
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudTranscriptionError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            return transcriptionResponse.text
        } else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw CloudTranscriptionError.apiError(errorResponse.error.message)
            }
            throw CloudTranscriptionError.httpError(httpResponse.statusCode)
        }
    }

    func validateAPIKey(_ apiKey: String) async -> Bool {
        let originalKey = KeychainHelper.shared.getAPIKey()

        _ = KeychainHelper.shared.save(apiKey: apiKey)

        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            if let original = originalKey {
                _ = KeychainHelper.shared.save(apiKey: original)
            }
            return false
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                let isValid = httpResponse.statusCode == 200
                if !isValid, let original = originalKey {
                    _ = KeychainHelper.shared.save(apiKey: original)
                }
                return isValid
            }
        } catch {
            if let original = originalKey {
                _ = KeychainHelper.shared.save(apiKey: original)
            }
        }

        return false
    }

    enum CloudTranscriptionError: LocalizedError {
        case noAPIKey
        case invalidURL
        case invalidResponse
        case apiError(String)
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "Clé API non configurée"
            case .invalidURL:
                return "URL invalide"
            case .invalidResponse:
                return "Réponse invalide du serveur"
            case .apiError(let message):
                return "Erreur API: \(message)"
            case .httpError(let code):
                return "Erreur HTTP: \(code)"
            }
        }
    }
}
