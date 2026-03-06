import Foundation

enum BundleIdentifiers {
    static let chromiumBrowsers: Set<String> = []
    static let electronApps: Set<String> = []

    static func isChromiumBrowser(_ bundleID: String) -> Bool { false }
    static func isElectronApp(_ bundleID: String) -> Bool { false }
}
