import SwiftUI

struct ControlsSection: View {
    @Environment(AppState.self) var appState
    @AppStorage("qualityPreset") private var qualityPreset: String = "balanced"

    var body: some View {
        @Bindable var processor = appState.micProcessor
        VStack(alignment: .leading, spacing: 10) {
            gainRow(processor: processor)
            Toggle("Auto-adjust isolation", isOn: $processor.autoAdjust)
                .disabled(!processor.isRunning)
                .onChange(of: processor.autoAdjust) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: "autoAdjust")
                }
            qualityRow(processor: processor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func gainRow(processor: MicProcessor) -> some View {
        @Bindable var processor = processor
        return VStack(alignment: .leading, spacing: 4) {
            Text("Voice boost: +\(Int(processor.makeupGainDB)) dB")
                .font(.subheadline)
            Slider(value: $processor.makeupGainDB, in: Float(0)...Float(18), step: Float(1))
                .disabled(!processor.isRunning)
                .onChange(of: processor.makeupGainDB) { _, newValue in
                    UserDefaults.standard.set(Double(newValue), forKey: "makeupGainDB")
                }
        }
    }

    private func qualityRow(processor: MicProcessor) -> some View {
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
            .onChange(of: qualityPreset) { _, newValue in
                processor.applyQualityPreset(newValue)
            }
        }
    }
}
