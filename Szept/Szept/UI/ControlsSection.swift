import SwiftUI

struct ControlsSection: View {
    @Environment(AppState.self) var appState
    @AppStorage("qualityPreset") private var qualityPreset: String = "balanced"

    var body: some View {
        @Bindable var processor = appState.micProcessor
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice boost: +\(Int(processor.makeupGainDB)) dB")
                    .font(.subheadline)
                Slider(value: $processor.makeupGainDB, in: Float(0)...Float(18), step: Float(1))
                    .disabled(!processor.isRunning)
            }
            Toggle("Auto-adjust isolation", isOn: $processor.autoAdjust)
                .disabled(!processor.isRunning)
            VStack(alignment: .leading, spacing: 4) {
                Text("Quality")
                    .font(.subheadline)
                Picker("Quality", selection: $qualityPreset) {
                    Text("Light").tag("light")
                    Text("Balanced").tag("balanced")
                    Text("Aggressive").tag("aggressive")
                }
                .pickerStyle(.segmented)
                .disabled(!processor.isRunning)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
