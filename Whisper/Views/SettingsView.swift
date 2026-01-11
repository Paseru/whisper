import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var apiKeyInput: String = ""
    @State private var isValidating: Bool = false
    @State private var showSuccessHint: Bool = false
    @State private var showErrorHint: Bool = false
    @State private var selectedLocalModel: LocalWhisperModel = Constants.selectedLocalModel
    @State private var showingDeleteConfirmation = false
    @State private var modelToDelete: LocalWhisperModel?
    
    private let accentColor = Color(nsColor: .controlAccentColor)
    private let secondaryBg = Color(white: 1).opacity(0.04)
    private let borderColor = Color(white: 1).opacity(0.08)
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerSection
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // MARK: - Transcription Mode Section
                    SettingsSection(title: "MODE DE TRANSCRIPTION", icon: "cpu") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Mode", selection: $appState.transcriptionMode) {
                                ForEach(TranscriptionMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            Text(appState.transcriptionMode.description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            // Show model status for local mode
                            if appState.transcriptionMode == .local {
                                modelManagementView
                            }
                        }
                    }

                    // MARK: - API Configuration Section (only for cloud mode)
                    if appState.transcriptionMode == .cloud {
                        SettingsSection(title: "CONFIGURATION API", icon: "key.fill") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    SecureField("sk-...", text: $apiKeyInput)
                                        .textFieldStyle(RefinedTextFieldStyle())
                                        .frame(maxWidth: .infinity)

                                    Button(action: validateKey) {
                                        HStack(spacing: 6) {
                                            if isValidating {
                                                ProgressView()
                                                    .controlSize(.small)
                                                    .scaleEffect(0.6)
                                            } else {
                                                Text("Valider")
                                                    .font(.system(size: 11, weight: .medium))
                                            }
                                        }
                                        .frame(width: 70, height: 24)
                                    }
                                    .buttonStyle(RefinedButtonStyle(isPrimary: true))
                                    .disabled(apiKeyInput.isEmpty || isValidating)
                                }

                                HStack(spacing: 12) {
                                    statusIndicator

                                    Spacer()

                                    Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                                        HStack(spacing: 4) {
                                            Text("Obtenir une clé")
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 9))
                                        }
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(accentColor.opacity(0.9))
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { inside in
                                        if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                    }
                                }
                            }
                        }
                    }
                    
                    // MARK: - Usage Section
                    SettingsSection(title: "UTILISATION", icon: "command") {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 16) {
                                ShortcutKeyView(label: "Fn", subLabel: "Maintenir")

                                Text("Maintenez la touche Fn enfoncée pour parler. Relâchez pour transcrire et coller le texte.")
                                    .font(.system(size: 12))
                                    .lineSpacing(3)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider().opacity(0.5)
                            
                            HStack(spacing: 12) {
                                Image(systemName: "text.cursor")
                                    .font(.system(size: 14))
                                    .foregroundColor(accentColor)
                                    .frame(width: 24)
                                
                                Text("Le texte transcrit sera inséré automatiquement à l'emplacement actuel de votre curseur.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // MARK: - About Section
                    SettingsSection(title: "À PROPOS", icon: "info.circle") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Whisper for macOS")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Version 1.0.0")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(currentModelName)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(24)
            }
            
            // MARK: - Footer
            footerSection
        }
        .frame(width: 440, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Computed Properties

    private var currentModelName: String {
        switch appState.transcriptionMode {
        case .cloud:
            return Constants.openAIModel
        case .local:
            return Constants.selectedLocalModel.displayName
        }
    }

    // MARK: - Subviews

    private var modelManagementView: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Gestion des modèles")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                
                Text("Sélectionnez un modèle et gérez ses téléchargements")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Picker("Modèle actif", selection: $selectedLocalModel) {
                ForEach(LocalWhisperModel.allCases, id: \.self) { model in
                    Text("\(model.displayName) (\(model.fileSize))")
                        .tag(model)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedLocalModel) { newModel in
                Constants.selectedLocalModel = newModel
            }
            
            Divider()
                .opacity(0.5)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(LocalWhisperModel.allCases, id: \.self) { model in
                    ModelRowView(
                        model: model,
                        isSelected: selectedLocalModel == model,
                        downloadState: appState.getLocalModelDownloadState(model),
                        onDownload: {
                            Task {
                                await appState.downloadLocalModel(model)
                            }
                        },
                        onDelete: {
                            modelToDelete = model
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
        }
        .alert("Supprimer le modèle", isPresented: $showingDeleteConfirmation) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                if let model = modelToDelete {
                    appState.deleteLocalModel(model)
                }
            }
        } message: {
            if let model = modelToDelete {
                Text("Êtes-vous sûr de vouloir supprimer le modèle \(model.displayName) ?\n\nLa transcription nécessitera un nouveau téléchargement si ce modèle est réutilisé.")
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: [accentColor, accentColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                        .shadow(color: accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Whisper")
                        .font(.system(size: 16, weight: .bold))
                        .kerning(-0.2)
                    Text("Préférences Système")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider().opacity(0.5)
        }
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.hasAPIKey ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
                .shadow(color: (appState.hasAPIKey ? Color.green : Color.orange).opacity(0.4), radius: 3)
            
            Text(appState.hasAPIKey ? "Clé API valide" : "Clé non configurée")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            if appState.hasAPIKey {
                Button(action: { appState.clearAPIKey() }) {
                    Text("Réinitialiser")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.5)
            HStack {
                Text(footerText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))

                Spacer()

                Button("Quitter") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(RefinedButtonStyle(isPrimary: false))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
    }

    private var footerText: String {
        switch appState.transcriptionMode {
        case .cloud:
            return "Mode Cloud: transcription via l'API OpenAI."
        case .local:
            return "Mode Local: transcription sur l'appareil avec WhisperKit."
        }
    }
    
    // MARK: - Logic
    
    private func validateKey() {
        guard !apiKeyInput.isEmpty else { return }
        
        isValidating = true
        showErrorHint = false
        
        Task {
            let success = await appState.updateAPIKey(apiKeyInput)
            await MainActor.run {
                isValidating = false
                if success {
                    apiKeyInput = ""
                    showSuccessHint = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showSuccessHint = false }
                } else {
                    showErrorHint = true
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .kerning(0.5)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

struct ShortcutKeyView: View {
    let label: String
    let subLabel: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 1, opacity: 0.1), Color(white: 1, opacity: 0.05)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    .frame(width: 36, height: 36)
                
                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            
            Text(subLabel)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary.opacity(0.8))
                .textCase(.uppercase)
        }
    }
}

// MARK: - Styles

struct RefinedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.2))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .font(.system(size: 12, design: .monospaced))
    }
}

struct RefinedButtonStyle: ButtonStyle {
    let isPrimary: Bool
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    if isPrimary {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(isHovering ? 0.08 : 0.04))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isPrimary ? Color.white.opacity(0.1) : Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .foregroundColor(isPrimary ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { inside in
                isHovering = inside
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
    }
}

struct ModelRowView: View {
    let model: LocalWhisperModel
    let isSelected: Bool
    let downloadState: ModelDownloadState
    let onDownload: () -> Void
    let onDelete: () -> Void
    
    private let accentColor = Color(nsColor: .controlAccentColor)
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: model.icon)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? accentColor : .secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(model.displayName)
                        .font(.system(size: 12, weight: .medium))
                    
                    Text(model.fileSize)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Text(model.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            statusAndActionView
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isSelected ? 0.05 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var statusAndActionView: some View {
        switch downloadState {
        case .notDownloaded:
            Button(action: onDownload) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 11))
                    Text("Télécharger")
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(RefinedButtonStyle(isPrimary: true))
            
        case .downloading:
            VStack(spacing: 2) {
                ProgressView()
                    .controlSize(.small)
                Text(downloadState.shortStatusText)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .frame(width: 120)
            
        case .downloaded:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
                
                Text("Prêt")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                
                if !isSelected {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Supprimer le modèle")
                }
            }
            
        case .error(let message):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                
                Text(message)
                    .font(.system(size: 9))
                    .foregroundColor(.red)
                    .lineLimit(1)
                
                Button(action: onDownload) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}