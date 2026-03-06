import Foundation
import AVFoundation

@Observable
final class MicProcessor {
    var isRunning: Bool = false
    var outputLevel: Float = 0
    var currentIsolation: Float = 50
    var makeupGainDB: Float = 6.0
    var autoAdjust: Bool = true

    func start() throws {}
    func stop() {}
}
