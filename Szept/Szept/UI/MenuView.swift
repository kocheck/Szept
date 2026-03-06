import SwiftUI

struct MenuView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            engineToggleSection
            Divider()
            footerSection
        }
        .frame(width: 320)
    }

    private var headerSection: some View {
        HStack {
            Text("Szept")
                .font(.headline)
            Spacer()
            Text(appState.currentMode.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var engineToggleSection: some View {
        HStack {
            Text(appState.micProcessor.isRunning ? "Processing: ON" : "Processing: OFF")
                .font(.subheadline)
            Spacer()
            Button(appState.micProcessor.isRunning ? "Stop" : "Start") {
                toggleEngine()
            }
        }
        .padding(12)
    }

    private var footerSection: some View {
        Button("Quit Szept") {
            NSApp.terminate(nil)
        }
        .padding(12)
    }

    private func toggleEngine() {
        if appState.micProcessor.isRunning {
            appState.micProcessor.stop()
        } else {
            do {
                try appState.micProcessor.start()
            } catch {
                print("Engine start failed: \(error)")
            }
        }
    }
}
