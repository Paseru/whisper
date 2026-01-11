import Foundation

protocol TranscriptionProvider {
    func transcribe(audioURL: URL) async throws -> String
}
