import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var lastError: String?
    @Published var hasAPIKey: Bool

    @Published var transcriptionMode: TranscriptionMode {
        didSet {
            UserDefaults.standard.set(transcriptionMode.rawValue, forKey: Constants.transcriptionModeKey)
        }
    }

    var modelDownloadState: ModelDownloadState {
        LocalTranscriptionProvider.shared.downloadState
    }

    let audioRecorder = AudioRecorder()
    let keyboardService = KeyboardService()

    private let cloudProvider = CloudTranscriptionProvider.shared
    private let localProvider = LocalTranscriptionProvider.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        hasAPIKey = KeychainHelper.shared.hasAPIKey

        // Restore saved transcription mode
        if let savedMode = UserDefaults.standard.string(forKey: Constants.transcriptionModeKey),
           let mode = TranscriptionMode(rawValue: savedMode) {
            transcriptionMode = mode
        } else {
            transcriptionMode = .cloud // Default to cloud for backward compatibility
        }

        // Observe local provider download state changes
        localProvider.$downloadStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Push-to-talk: Fn pressé = enregistre, Fn relâché = transcrit
        keyboardService.onFnPressed = { [weak self] in
            Task { @MainActor in
                self?.startRecording()
            }
        }

        keyboardService.onFnReleased = { [weak self] in
            Task { @MainActor in
                self?.stopRecordingAndTranscribe()
            }
        }

        // Démarrer le monitoring du clavier
        keyboardService.startMonitoring()

        // Vérifier les permissions d'accessibilité
        if !TextInjector.hasAccessibilityPermission() {
            TextInjector.requestAccessibilityPermission()
        }
    }

    var canTranscribe: Bool {
        switch transcriptionMode {
        case .cloud:
            return hasAPIKey
        case .local:
            return modelDownloadState.isReady
        }
    }

    private func startRecording() {
        // Vérifier les prérequis selon le mode
        if transcriptionMode == .cloud && !hasAPIKey {
            lastError = "Configure ta clé API dans les préférences"
            SoundService.shared.playErrorSound()
            return
        }

        if transcriptionMode == .local && !modelDownloadState.isReady {
            lastError = "Télécharge d'abord un modèle local dans les préférences"
            SoundService.shared.playErrorSound()
            return
        }

        guard !isTranscribing else { return }
        guard !isRecording else { return }

        // Démarrer l'enregistrement EN PREMIER pour capturer les premiers mots
        do {
            try audioRecorder.startRecording()
            isRecording = true
            lastError = nil
            SoundService.shared.playStartSound()
        } catch {
            lastError = error.localizedDescription
            SoundService.shared.playErrorSound()
            return
        }

        // Capturer l'app qui a le focus APRÈS (en parallèle de l'enregistrement)
        TextInjector.shared.captureTargetApp()
    }

    private func stopRecordingAndTranscribe() {
        guard isRecording else { return }

        guard let audioURL = audioRecorder.stopRecording() else {
            lastError = "Aucun enregistrement trouvé"
            isRecording = false
            SoundService.shared.playErrorSound()
            return
        }

        isRecording = false
        isTranscribing = true
        SoundService.shared.playStopSound()

        Task {
            do {
                let text: String
                switch transcriptionMode {
                case .cloud:
                    text = try await cloudProvider.transcribe(audioURL: audioURL)
                case .local:
                    text = try await localProvider.transcribe(audioURL: audioURL)
                }

                await MainActor.run {
                    // Sauvegarder dans l'historique
                    HistoryService.shared.add(text)
                    // Coller le texte
                    TextInjector.shared.inject(text: text)
                    isTranscribing = false
                }
            } catch {
                await MainActor.run {
                    lastError = error.localizedDescription
                    isTranscribing = false
                    SoundService.shared.playErrorSound()
                }
            }

            // Nettoyer le fichier audio temporaire
            audioRecorder.cleanup()
        }
    }

    func updateAPIKey(_ key: String) async -> Bool {
        let isValid = await cloudProvider.validateAPIKey(key)
        await MainActor.run {
            if isValid {
                _ = KeychainHelper.shared.save(apiKey: key)
                hasAPIKey = true
            }
        }
        return isValid
    }

    func clearAPIKey() {
        KeychainHelper.shared.delete()
        hasAPIKey = false
    }

    func setTranscriptionMode(_ mode: TranscriptionMode) {
        transcriptionMode = mode
    }

    func downloadLocalModel() async {
        do {
            try await localProvider.downloadModel()
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    func getLocalModelDownloadState(_ model: LocalWhisperModel) -> ModelDownloadState {
        return localProvider.getDownloadState(for: model)
    }
    
    func downloadLocalModel(_ model: LocalWhisperModel) async {
        do {
            try await localProvider.downloadModel(for: model)
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    func deleteLocalModel(_ model: LocalWhisperModel) {
        do {
            try localProvider.deleteModel(for: model)
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    func checkLocalModelsStatus() async {
        await localProvider.checkAllModelsStatus()
    }
}
