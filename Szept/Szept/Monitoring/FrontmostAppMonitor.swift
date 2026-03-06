import Foundation

@Observable
final class FrontmostAppMonitor {
    var isVoiceIsolationCompatible: Bool = true
    var incompatibilityReason: String? = nil
}
