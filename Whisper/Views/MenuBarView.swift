import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header avec statut
            HStack {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Whisper")
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()

            // Instructions
            VStack(alignment: .leading, spacing: 4) {
                Label("Maintiens Fn pour parler", systemImage: "keyboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Erreur si présente
            if let error = appState.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            Divider()

            // Historique
            if !HistoryService.shared.entries.isEmpty {
                Menu {
                    ForEach(HistoryService.shared.entries.prefix(5)) { entry in
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.text, forType: .string)
                        } label: {
                            Text(entry.text.prefix(50) + (entry.text.count > 50 ? "..." : ""))
                        }
                    }
                    Divider()
                    Button("Voir tout l'historique...") {
                        showHistoryWindow()
                    }
                } label: {
                    Label("Historique récent", systemImage: "clock.arrow.circlepath")
                }
                .padding(.horizontal, 4)

                Divider()
            }

            // Actions
            Button {
                openSettings()
            } label: {
                Label("Préférences...", systemImage: "gear")
            }
            .keyboardShortcut(",", modifiers: .command)
            .padding(.horizontal, 4)

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quitter Whisper", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .frame(width: 260)
        .buttonStyle(.plain)
    }

    private func showHistoryWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Historique Whisper"
        window.contentView = NSHostingView(rootView: HistoryView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private var statusIcon: String {
        if appState.isTranscribing {
            return "text.bubble"
        } else if appState.isRecording {
            return "mic.fill"
        } else if case .downloading = appState.modelDownloadState {
            return "arrow.down.circle"
        } else if !appState.canTranscribe {
            return "exclamationmark.circle"
        } else {
            return appState.transcriptionMode == .local ? "cpu" : "cloud"
        }
    }

    private var statusColor: Color {
        if appState.isTranscribing {
            return .blue
        } else if appState.isRecording {
            return .red
        } else if case .downloading = appState.modelDownloadState {
            return .blue
        } else if !appState.canTranscribe {
            return .orange
        } else {
            return .green
        }
    }

    private var statusText: String {
        if appState.isTranscribing {
            return "Transcription en cours..."
        } else if appState.isRecording {
            return "Enregistrement..."
        } else if case .downloading(let progress, _, _) = appState.modelDownloadState {
            return "Téléchargement: \(Int(progress * 100))%"
        } else if appState.transcriptionMode == .cloud && !appState.hasAPIKey {
            return "Clé API non configurée"
        } else if appState.transcriptionMode == .local && !appState.modelDownloadState.isReady {
            return "Modèle non téléchargé"
        } else {
            let modeLabel = appState.transcriptionMode == .local ? "Local" : "Cloud"
            return "Prêt (\(modeLabel))"
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState())
}
