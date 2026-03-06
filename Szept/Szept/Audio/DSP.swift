import Foundation
import Accelerate
import AVFoundation

enum DSP {
    static func applyMakeupGain(samples: UnsafeMutablePointer<Float>, count: Int, gainLinear: Float) {}
    static func applySoftLimiter(samples: UnsafeMutablePointer<Float>, count: Int, threshold: Float) {}
    static func calculateRMS(samples: UnsafePointer<Float>, count: Int) -> Float { return 0 }
    static func dbToLinear(_ db: Float) -> Float { return 1.0 }
}
