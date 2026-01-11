import Foundation
import WhisperKit
import Hub
import Combine

@MainActor
final class LocalTranscriptionProvider: ObservableObject, TranscriptionProvider {
    static let shared = LocalTranscriptionProvider()

    @Published private(set) var downloadStates: [LocalWhisperModel: ModelDownloadState] = [:]
    @Published private(set) var isInitializing = false

    private var whisperKit: WhisperKit?
    private var currentLoadedModel: LocalWhisperModel?
    private var progressCancellables: [LocalWhisperModel: AnyCancellable] = [:]
    private var modelsBeingDownloaded: Set<LocalWhisperModel> = []
    private let hubApi = HubApi()
    private let repo = Hub.Repo(id: "argmaxinc/whisperkit-coreml", type: .models)
    
    private init() {
        for model in LocalWhisperModel.allCases {
            downloadStates[model] = .notDownloaded
        }
        
        Task {
            await checkAllModelsStatus()
        }
    }
    
    var downloadState: ModelDownloadState {
        let selectedModel = Constants.selectedLocalModel
        return downloadStates[selectedModel] ?? .notDownloaded
    }
    
    func checkAllModelsStatus() async {
        for model in LocalWhisperModel.allCases {
            let isInstalled = isModelDownloaded(model.fileName)
            downloadStates[model] = isInstalled ? .downloaded : .notDownloaded
        }
    }
    
    func checkModelStatus(for model: LocalWhisperModel) async -> ModelDownloadState {
        let isInstalled = isModelDownloaded(model.fileName)
        let state: ModelDownloadState = isInstalled ? .downloaded : .notDownloaded
        downloadStates[model] = state
        return state
    }
    
    func initializeIfNeeded() async throws {
        let selectedModel = Constants.selectedLocalModel

        // Si WhisperKit est chargé avec un autre modèle, on le réinitialise
        if whisperKit != nil && currentLoadedModel != selectedModel {
            whisperKit = nil
            currentLoadedModel = nil
        }

        // Si déjà initialisé avec le bon modèle, on ne fait rien
        guard whisperKit == nil else { return }

        try await loadModel(selectedModel)
    }

    func initializeIfNeeded(for model: LocalWhisperModel) async throws {
        // Si le modèle est déjà téléchargé ET WhisperKit est chargé avec ce modèle, rien à faire
        if downloadStates[model] == .downloaded && whisperKit != nil && currentLoadedModel == model {
            return
        }

        // Si WhisperKit est chargé avec un autre modèle, on le réinitialise
        if whisperKit != nil && currentLoadedModel != model {
            whisperKit = nil
            currentLoadedModel = nil
        }

        try await loadModel(model)
    }

    private func loadModel(_ model: LocalWhisperModel) async throws {
        // Protection contre les téléchargements concurrents
        guard !modelsBeingDownloaded.contains(model) else {
            throw LocalTranscriptionError.downloadInProgress
        }

        modelsBeingDownloaded.insert(model)
        isInitializing = true

        defer {
            modelsBeingDownloaded.remove(model)
            isInitializing = false
        }

        downloadStates[model] = .downloading(progress: 0, bytesDownloaded: 0, bytesTotal: 0)

        do {
            // Créer un Progress pour suivre le téléchargement
            let progress = Progress(totalUnitCount: model.fileSizeBytes)
            observeProgress(for: model, progress: progress)

            let kit = try await WhisperKit(
                WhisperKitConfig(
                    model: model.fileName,
                    verbose: false,
                    logLevel: .none,
                    prewarm: true,
                    load: true,
                    download: true
                )
            )

            whisperKit = kit
            currentLoadedModel = model
            downloadStates[model] = .downloaded

            // Nettoyer l'observateur de progression
            progressCancellables[model] = nil
        } catch {
            downloadStates[model] = .error(error.localizedDescription)
            progressCancellables[model] = nil
            throw LocalTranscriptionError.initializationFailed(error.localizedDescription)
        }
    }
    
    private func observeProgress(for model: LocalWhisperModel, progress: Progress) {
        let cancellable = progress.publisher(for: \.fractionCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fractionCompleted in
                guard let self = self else { return }
                let totalBytes = model.fileSizeBytes
                let downloadedBytes = Int64(Double(totalBytes) * fractionCompleted)

                downloadStates[model] = .downloading(
                    progress: fractionCompleted,
                    bytesDownloaded: downloadedBytes,
                    bytesTotal: totalBytes
                )
            }
        progressCancellables[model] = cancellable
    }
    
    func transcribe(audioURL: URL) async throws -> String {
        try await initializeIfNeeded()
        
        guard let whisperKit = whisperKit else {
            throw LocalTranscriptionError.notInitialized
        }
        
        do {
            let results = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: DecodingOptions(
                    language: Constants.whisperKitLanguage
                )
            )
            
            let transcribedText = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            
            if transcribedText.isEmpty {
                throw LocalTranscriptionError.emptyResult
            }
            
            return transcribedText
        } catch let error as LocalTranscriptionError {
            throw error
        } catch {
            throw LocalTranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }
    
    func downloadModel(for model: LocalWhisperModel) async throws {
        try await initializeIfNeeded(for: model)
    }
    
    func downloadModel() async throws {
        let selectedModel = Constants.selectedLocalModel
        try await downloadModel(for: selectedModel)
    }
    
    func deleteModel(for model: LocalWhisperModel) throws {
        // Nettoyer WhisperKit si c'est le modèle actuellement chargé
        if currentLoadedModel == model {
            whisperKit = nil
            currentLoadedModel = nil
        }

        // Supprimer uniquement le cancellable de ce modèle
        progressCancellables[model] = nil

        let modelPath = getStoragePath(for: model.fileName)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: modelPath.path) {
            try fileManager.removeItem(at: modelPath)
            downloadStates[model] = .notDownloaded
        } else {
            throw LocalTranscriptionError.modelNotFound(model.displayName)
        }
    }
    
    func getDownloadState(for model: LocalWhisperModel) -> ModelDownloadState {
        return downloadStates[model] ?? .notDownloaded
    }
    
    private func getStoragePath(for modelName: String) -> URL {
        hubApi.localRepoLocation(repo).appendingPathComponent(modelName)
    }
    
    private func isModelDownloaded(_ modelName: String) -> Bool {
        let modelPath = getStoragePath(for: modelName)
        let fileManager = FileManager.default
        
        let mlmodelcPath = modelPath.appendingPathComponent("MelSpectrogram.mlmodelc")
        let mlpackagePath = modelPath.appendingPathComponent("MelSpectrogram.mlpackage")
        
        return fileManager.fileExists(atPath: mlmodelcPath.path) ||
               fileManager.fileExists(atPath: mlpackagePath.path)
    }
    
    enum LocalTranscriptionError: LocalizedError {
        case notInitialized
        case initializationFailed(String)
        case transcriptionFailed(String)
        case emptyResult
        case modelNotFound(String)
        case deletionFailed(String)
        case downloadInProgress

        var errorDescription: String? {
            switch self {
            case .notInitialized:
                return "Modèle WhisperKit non initialisé"
            case .initializationFailed(let message):
                return "Échec de l'initialisation: \(message)"
            case .transcriptionFailed(let message):
                return "Erreur de transcription locale: \(message)"
            case .emptyResult:
                return "Aucun texte transcrit"
            case .modelNotFound(let name):
                return "Modèle '\(name)' introuvable"
            case .deletionFailed(let message):
                return "Échec de la suppression: \(message)"
            case .downloadInProgress:
                return "Un téléchargement est déjà en cours pour ce modèle"
            }
        }
    }
}
