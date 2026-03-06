import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.micProcessor.stop()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusItemIcon()

        let menu = NSMenu()
        let menuItem = NSMenuItem()
        let hostingView = NSHostingView(
            rootView: MenuView().environment(appState)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 80)
        menuItem.view = hostingView
        menu.addItem(menuItem)
        statusItem.menu = menu
    }

    func updateStatusItemIcon() {
        guard let button = statusItem?.button else { return }
        let symbolName: String
        switch appState.currentMode {
        case .enhanced:    symbolName = "checkmark.shield.fill"
        case .standalone:  symbolName = "waveform.circle.fill"
        case .off:         symbolName = "waveform.circle"
        }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Szept")
        image?.isTemplate = true
        button.image = image
    }
}
