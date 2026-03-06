import SwiftUI

struct MenuView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
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

    private var footerSection: some View {
        Button("Quit Szept") {
            NSApp.terminate(nil)
        }
        .padding(12)
    }
}
