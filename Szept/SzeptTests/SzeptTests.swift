import Testing
import Accelerate
@testable import Szept

struct DSPTests {
    // MARK: - applyMakeupGain

    @Test func gainDoublesAmplitude() {
        var samples: [Float] = [0.5, -0.5, 0.25, -0.25]
        DSP.applyMakeupGain(samples: &samples, count: samples.count, gainLinear: 2.0)
        #expect(abs(samples[0] - 1.0) < 0.0001)
        #expect(abs(samples[1] - (-1.0)) < 0.0001)
        #expect(abs(samples[2] - 0.5) < 0.0001)
    }

    @Test func gainOfOneIsPassthrough() {
        var samples: [Float] = [0.3, -0.7, 0.1]
        let original = samples
        DSP.applyMakeupGain(samples: &samples, count: samples.count, gainLinear: 1.0)
        for i in samples.indices {
            #expect(abs(samples[i] - original[i]) < 0.0001)
        }
    }

    @Test func gainZeroSilences() {
        var samples: [Float] = [0.5, -0.5, 0.3]
        DSP.applyMakeupGain(samples: &samples, count: samples.count, gainLinear: 0.0)
        for s in samples { #expect(s == 0.0) }
    }

    // MARK: - applySoftLimiter

    @Test func softLimiterClampsLargeValues() {
        var samples: [Float] = [10.0, -10.0]
        DSP.applySoftLimiter(samples: &samples, count: samples.count, threshold: 0.7)
        #expect(samples[0] < 0.71 && samples[0] > 0.69)
        #expect(samples[1] > -0.71 && samples[1] < -0.69)
    }

    @Test func softLimiterPreservesSmallValues() {
        var samples: [Float] = [0.01, -0.01]
        DSP.applySoftLimiter(samples: &samples, count: samples.count, threshold: 0.7)
        #expect(abs(samples[0] - 0.01) < 0.001)
        #expect(abs(samples[1] - (-0.01)) < 0.001)
    }

    @Test func softLimiterOutputNeverExceedsThreshold() {
        var samples: [Float] = [1.0, 2.0, 5.0, -1.0, -2.0, -5.0]
        DSP.applySoftLimiter(samples: &samples, count: samples.count, threshold: 0.7)
        for s in samples {
            #expect(abs(s) <= 0.7 + 0.001)
        }
    }

    // MARK: - calculateRMS

    @Test func rmsOfConstantSignal() {
        let samples: [Float] = [0.5, 0.5, 0.5, 0.5]
        let result = DSP.calculateRMS(samples: samples, count: samples.count)
        #expect(abs(result - 0.5) < 0.0001)
    }

    @Test func rmsOfSilenceIsZero() {
        let samples: [Float] = [0.0, 0.0, 0.0, 0.0]
        let result = DSP.calculateRMS(samples: samples, count: samples.count)
        #expect(result == 0.0)
    }

    @Test func rmsOfSineApproximation() {
        let count = 1000
        let samples = (0..<count).map { i -> Float in
            sin(2.0 * Float.pi * Float(i) / Float(count))
        }
        let result = DSP.calculateRMS(samples: samples, count: count)
        #expect(abs(result - 0.707) < 0.01)
    }

    // MARK: - dbToLinear

    @Test func zeroDBIsUnityGain() {
        #expect(abs(DSP.dbToLinear(0) - 1.0) < 0.0001)
    }

    @Test func sixDBIsApproximatelyDouble() {
        #expect(abs(DSP.dbToLinear(6) - 2.0) < 0.01)
    }

    @Test func negativeSixDBIsApproximatelyHalf() {
        #expect(abs(DSP.dbToLinear(-6) - 0.5) < 0.01)
    }

    // MARK: - BundleIdentifiers Tests

    @Test func chromiumBrowsersDetected() {
        let known = [
            "com.google.Chrome",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "company.thebrowser.Browser",
            "com.operasoftware.Opera",
            "com.vivaldi.Vivaldi"
        ]
        for id in known {
            #expect(BundleIdentifiers.isChromiumBrowser(id), "\(id) should be Chromium")
        }
    }

    @Test func electronAppsDetected() {
        let known = [
            "com.tinyspeck.slackmacgap",
            "com.hnc.Discord",
            "com.microsoft.teams2"
        ]
        for id in known {
            #expect(BundleIdentifiers.isElectronApp(id), "\(id) should be Electron")
        }
    }

    @Test func unknownBundleIDsReturnFalse() {
        #expect(!BundleIdentifiers.isChromiumBrowser("com.apple.safari"))
        #expect(!BundleIdentifiers.isElectronApp("com.apple.mail"))
        #expect(!BundleIdentifiers.isChromiumBrowser(""))
    }

    @Test func voiceIsolationIncompatibleCoversAll() {
        for id in BundleIdentifiers.chromiumBrowsers {
            #expect(BundleIdentifiers.isVoiceIsolationIncompatible(id))
        }
        for id in BundleIdentifiers.electronApps {
            #expect(BundleIdentifiers.isVoiceIsolationIncompatible(id))
        }
    }
}
