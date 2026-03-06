import Foundation
import AVFoundation
import AudioToolbox
import Accelerate
import os.log

@Observable
final class MicProcessor {
    // MARK: - Public state (main thread only)
    var isRunning: Bool = false
    var outputLevel: Float = 0
    var currentIsolation: Float = 50

    var makeupGainDB: Float = 6.0 {
        didSet { tapGainLinear = DSP.dbToLinear(makeupGainDB) }
    }

    var autoAdjust: Bool = true {
        didSet { tapAutoAdjust = autoAdjust }
    }

    // MARK: - Audio thread state (read from tap callback — nonisolated(unsafe))
    // Prefixed with "tap" to avoid conflict with @Observable macro synthesized names.
    nonisolated(unsafe) private var tapGainLinear: Float = DSP.dbToLinear(6.0)
    nonisolated(unsafe) private var tapAutoAdjust: Bool = true
    nonisolated(unsafe) private var tapIsolation: Float = 50

    // MARK: - AVAudioEngine
    private let engine = AVAudioEngine()
    private var isolationUnit: AVAudioUnitEffect?
    private let logger = Logger(subsystem: "dev.kocheck.Szept", category: "MicProcessor")

    // MARK: - AUSoundIsolation component description
    private static var isolationDescription: AudioComponentDescription = {
        var desc = AudioComponentDescription()
        desc.componentType = kAudioUnitType_Effect
        desc.componentSubType = 0x766F6973 // 'vois'
        desc.componentManufacturer = kAudioUnitManufacturer_Apple
        desc.componentFlags = 0
        desc.componentFlagsMask = 0
        return desc
    }()

    // MARK: - Lifecycle

    func start() throws {
        guard !isRunning else { return }

        let unit = AVAudioUnitEffect(audioComponentDescription: Self.isolationDescription)
        isolationUnit = unit

        engine.attach(unit)
        engine.connect(engine.inputNode, to: unit, format: nil)
        engine.connect(unit, to: engine.mainMixerNode, format: nil)

        setIsolationParameter(tapIsolation)
        installTap()

        engine.prepare()
        do {
            try engine.start()
        } catch {
            engine.detach(unit)
            isolationUnit = nil
            throw error
        }

        isRunning = true
        logger.info("MicProcessor started")
    }

    func stop() {
        guard isRunning else { return }
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.stop()
        if let unit = isolationUnit {
            engine.detach(unit)
            isolationUnit = nil
        }
        isRunning = false
        outputLevel = 0
        logger.info("MicProcessor stopped")
    }

    // MARK: - Preference loading (call before start())

    func loadPreferences(gainDB: Float, autoAdjust: Bool) {
        makeupGainDB = gainDB
        self.autoAdjust = autoAdjust
    }

    func applyQualityPreset(_ preset: String) {
        let initialIsolation: Float
        switch preset {
        case "light":      initialIsolation = 30
        case "aggressive": initialIsolation = 70
        default:           initialIsolation = 50
        }
        setIsolationLevel(initialIsolation)
    }

    // MARK: - Parameter control (main thread)

    func setIsolationLevel(_ percent: Float) {
        let clamped = min(85, max(15, percent))
        tapIsolation = clamped
        setIsolationParameter(clamped)
        currentIsolation = clamped
    }

    private func setIsolationParameter(_ value: Float) {
        guard let au = isolationUnit?.audioUnit else { return }
        AudioUnitSetParameter(au, 0, kAudioUnitScope_Global, 0, value, 0)
    }

    // MARK: - Tap installation

    private func installTap() {
        let mixerNode = engine.mainMixerNode
        let format = mixerNode.outputFormat(forBus: 0)
        mixerNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processTap(buffer: buffer)
        }
    }

    // Runs on audio thread. Must not allocate or block.
    // nonisolated to opt out of implicit @MainActor isolation.
    private nonisolated func processTap(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        DSP.applyMakeupGain(samples: channelData, count: frameCount, gainLinear: tapGainLinear)
        DSP.applySoftLimiter(samples: channelData, count: frameCount, threshold: 0.7)
        let rms = DSP.calculateRMS(samples: channelData, count: frameCount)

        if tapAutoAdjust {
            runAutoAdjust(rms: rms)
        }

        DispatchQueue.main.async { [weak self] in
            self?.outputLevel = rms
        }
    }

    // Proportional controller: target 0.1 RMS, deadband 0.02, step 0.5, range 15-85%.
    // The deadband is applied in RMS space (0.02 = ±20% of the 0.1 target). This prevents
    // jitter without requiring direct manipulation of the isolation parameter range; changes
    // to the isolation parameter only occur when the output level meaningfully deviates from
    // the target, not on every audio callback.
    private nonisolated func runAutoAdjust(rms: Float) {
        let targetRMS: Float = 0.1
        let deadband: Float = 0.02
        let stepSize: Float = 0.5

        let previousIsolation = tapIsolation

        if rms < targetRMS - deadband {
            tapIsolation = max(15, tapIsolation - stepSize)
        } else if rms > targetRMS + deadband {
            tapIsolation = min(85, tapIsolation + stepSize)
        }

        let newIsolation = tapIsolation
        guard newIsolation != previousIsolation else { return }
        DispatchQueue.main.async { [weak self] in
            self?.setIsolationParameter(newIsolation)
            self?.currentIsolation = newIsolation
        }
    }
}
