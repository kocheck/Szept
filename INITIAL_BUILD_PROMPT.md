# Szept — Initial Build Spec

Read CLAUDE.md first. Then read this entire spec before writing any code.
Ultrathink and make a plan before implementing each phase.

## App overview

Szept is a lightweight macOS menu bar app that improves microphone audio quality.
It uses Apple's AUSoundIsolation audio unit (an undocumented Neural Engine-powered
effect) with adaptive gain recovery and soft limiting to suppress background noise
while keeping voice clear. When the user also enables macOS Voice Isolation in system
settings, the two systems stack for near-perfect noise removal. The app works entirely
on-device with zero network access. Target user: remote worker who wants better mic
audio in calls without a subscription service like Krisp.

## App type and lifecycle

- Menu bar–only app. Set `LSUIElement = YES` in Info.plist. No Dock icon.
- Primary interface: NSStatusItem → NSMenu → NSMenuItem with NSHostingView.
  NOT MenuBarExtra. NOT NSPopover. See CLAUDE.md for rationale.
- Secondary interface: Settings window opened via NSApp.sendAction for preferences.
- AppDelegate owns NSStatusItem. Creates menu at applicationDidFinishLaunching.
- App struct uses @NSApplicationDelegateAdaptor(AppDelegate.self).
- The App struct body contains only a Settings scene for the preferences window.

## Core features

<features>

### Feature 1: Audio processing chain
The core audio engine. MicProcessor class manages AVAudioEngine with this chain:
inputNode → AUSoundIsolation → mainMixerNode → outputNode.

AUSoundIsolation is loaded as an AVAudioUnitEffect with AudioComponentDescription:
componentType=kAudioUnitType_Effect, componentSubType=0x766F6973,
componentManufacturer=kAudioUnitManufacturer_Apple.

A tap on mainMixerNode (bufferSize 1024) does three things to the buffer:
1. Makeup gain via vDSP_vsmul (linear gain from user's dB setting)
2. Soft limiting via tanh saturation (threshold 0.7)
3. RMS metering via vDSP_rmsqv (published to AppState.outputLevel on main thread)

Auto-adjust mode: monitors output RMS. If output is too quiet (AU over-suppressing),
reduce isolation toward 15%. If too loud (noise leaking), increase toward 85%.
Simple proportional controller with 1.0 deadband to prevent jitter.

Public interface:
- start() / stop()
- isRunning: Bool
- outputLevel: Float (0-1, for meter)
- currentIsolation: Float (0-100, current AU setting)
- makeupGainDB: Float (user-adjustable, 0-18)
- autoAdjust: Bool

### Feature 2: System mic mode monitoring
MicModeMonitor uses KVO on AVCaptureDevice.activeMicrophoneMode and
AVCaptureDevice.preferredMicrophoneMode to detect whether the user has
Voice Isolation enabled at the system level. Publishes isVoiceIsolationActive: Bool.
Also provides openMicModePicker() which calls
AVCaptureDevice.showSystemUserInterface(.microphoneModes).

### Feature 3: Frontmost app detection
FrontmostAppMonitor observes NSWorkspace.didActivateApplicationNotification.
Reads the frontmost app's bundle identifier. Checks against known Chromium
browsers (com.google.Chrome, com.microsoft.edgemac, com.brave.Browser,
company.thebrowser.Browser, com.operasoftware.Opera, com.vivaldi.Vivaldi)
and known Electron apps (com.tinyspeck.slackmacgap, com.hnc.Discord,
com.microsoft.teams2). Publishes isVoiceIsolationCompatible: Bool and
incompatibilityReason: String?.

### Feature 4: Unified state (AppState)
@Observable class composing all monitors and the processor. Computes:
- currentMode: enum .enhanced (VI on + processing) / .standalone (processing only) / .off
- statusDescription: String for the UI
- shouldShowAppWarning: Bool (Chrome/Electron frontmost)

### Feature 5: Menu bar UI
NSStatusItem with template SF Symbol image (mic.fill or waveform.circle).
NSMenu containing one NSMenuItem with NSHostingView(rootView: MenuView()).
MenuView is ~320×420pt, vertical stack:
1. StatusCard — colored dot + mode name + description
2. AppWarningBanner — orange, only when Chrome/Electron detected
3. AudioMeter — horizontal green→yellow→red bar bound to outputLevel
4. ControlsSection — gain slider (0-18 dB), auto toggle, quality preset picker
5. Footer — "Open Mic Settings" button + separator + "Quit Szept" button

Menu bar icon should update based on currentMode:
- .enhanced: "checkmark.shield.fill" (green tint via symbolRenderingMode)
- .standalone: "waveform.circle.fill"
- .off: "waveform.circle" (unfilled)

### Feature 6: Settings and persistence
Settings window with sections:
- General: Launch at login (SMAppService.mainApp), description text
- Audio: Gain slider, auto-adjust toggle, quality presets (Light/Balanced/Aggressive)
- About: Version from Bundle.main, app description

Preferences stored via @AppStorage:
- makeupGainDB: Float = 6.0
- autoAdjust: Bool = true
- launchAtLogin: Bool = false
- isProcessingEnabled: Bool = true
- qualityPreset: String = "balanced"

### Feature 7: Permission handling
Check AVCaptureDevice.authorizationStatus(for: .audio) on launch.
If .notDetermined, request. If .denied, show message in StatusCard
with button to open System Settings microphone pane.

</features>

## UI specification

<ui_spec>

### Menu bar dropdown (320pt wide, auto-height)
Uses NSMenu + NSHostingView. Not a floating window.
Background: .regularMaterial (Liquid Glass compatible).
Content padding: 12pt all sides.

**StatusCard**: Rounded rect with .fill material. Left-aligned colored circle (10pt)
+ bold mode name + lighter description below. Green for Enhanced, yellow for Standalone,
gray for Off.

**AppWarningBanner**: Only visible when shouldShowAppWarning is true.
Orange tinted background. SF Symbol exclamationmark.triangle + text.
"Voice Isolation doesn't work in [AppName]. Szept is handling it alone."

**AudioMeter**: 8pt tall rounded rect. GeometryReader for width calculation.
Color gradient: green (0-0.5), yellow (0.5-0.8), red (0.8-1.0).
Wrap in EquatableView to throttle redraws.

**ControlsSection**: VStack with 8pt spacing.
- "Voice boost: +6 dB" label + Slider(value: 0...18, step: 1)
- Toggle("Auto-adjust isolation", isOn:)
- Picker("Quality", selection:) with .segmented style: Light / Balanced / Aggressive
- All disabled when processing is off.

**Footer**: HStack with "Open Mic Settings" (calls openMicModePicker) and spacer and
"Quit" button (NSApp.terminate).

### Settings window (450 × 300)
Use TabView with .automatic style. Three tabs with Label tab items.

### Menu bar icon
Template image. Use NSImage(systemSymbolName:) with .isTemplate = true.

</ui_spec>

## Data model

```swift
@Observable
final class AppState {
    // Composed objects
    let micProcessor = MicProcessor()
    let micModeMonitor = MicModeMonitor()
    let frontmostAppMonitor = FrontmostAppMonitor()

    // Computed mode
    var currentMode: SzeptMode {
        guard micProcessor.isRunning else { return .off }
        if micModeMonitor.isVoiceIsolationActive { return .enhanced }
        return .standalone
    }

    var shouldShowAppWarning: Bool {
        micProcessor.isRunning && !frontmostAppMonitor.isVoiceIsolationCompatible
    }
}

enum SzeptMode: String {
    case enhanced    // Voice Isolation + Szept stacked
    case standalone  // Szept processing only
    case off         // No processing
}
```

## Entitlements and permissions

Szept.entitlements:
- com.apple.security.app-sandbox = true
- com.apple.security.device.audio-input = true

Info.plist:
- LSUIElement = true
- NSMicrophoneUsageDescription = "Szept processes your microphone audio
  locally to reduce background noise. Audio never leaves your device."

## Implementation phases

Do not skip any phase. Complete each fully. Build after each phase.

### Phase 1: Project scaffold and menu bar shell
Create the full file structure from CLAUDE.md. Implement:
- SzeptApp.swift with @NSApplicationDelegateAdaptor, Settings scene only
- AppDelegate.swift with NSStatusItem + NSMenu + NSHostingView containing
  a placeholder MenuView that shows "Szept" text
- Stub files for every class in the project structure
- AppState.swift with the @Observable class (properties only, no logic)
- Assets.xcassets with a placeholder menu bar icon
- Info.plist with LSUIElement and NSMicrophoneUsageDescription
- Entitlements file

Build and verify compilation. Verify menu bar icon appears and clicking shows dropdown.

**Checkpoint**: App builds. Menu bar icon appears. Clicking shows dropdown with
placeholder text. No Dock icon visible.

### Phase 2: Audio processing engine
Implement MicProcessor.swift with the full audio chain:
- AVAudioEngine setup: inputNode → AUSoundIsolation → mainMixerNode → outputNode
- AUSoundIsolation loading via AVAudioUnitEffect(audioComponentDescription:)
- Parameter control: AudioUnitSetParameter for WetDryMixPercent (param 0)
- Output tap on mainMixerNode doing: makeup gain, soft limiter, RMS metering
- Auto-adjust proportional controller (15-85% range, 1.0 deadband)
- start() and stop() lifecycle

Implement DSP.swift with pure functions:
- applyMakeupGain using vDSP_vsmul
- applySoftLimiter using tanh saturation
- calculateRMS using vDSP_rmsqv

Build and test. Add a temporary button in MenuView to start/stop the engine.
Verify audio passes through when engine starts (test with headphones).

**Checkpoint**: Engine starts. AUSoundIsolation loads. Audio passes through
with gain and limiting applied. RMS level updates in console logs.

### Phase 3: Monitoring services
Implement MicModeMonitor.swift:
- KVO on AVCaptureDevice.activeMicrophoneMode
- KVO on AVCaptureDevice.preferredMicrophoneMode
- openMicModePicker() calling showSystemUserInterface(.microphoneModes)
- isVoiceIsolationActive computed property

Implement FrontmostAppMonitor.swift:
- NSWorkspace.didActivateApplicationNotification observer
- Bundle ID lookup against BundleIdentifiers lists
- isVoiceIsolationCompatible and incompatibilityReason properties

Implement BundleIdentifiers.swift:
- Static Sets for chromiumBrowsers, electronApps, appsWithBuiltInNoiseCancellation
- Lookup functions

Wire monitors into AppState. Verify currentMode changes when toggling
Voice Isolation in System Settings and when switching to Chrome.

**Checkpoint**: AppState.currentMode reflects real system state.
Switching to Chrome changes shouldShowAppWarning to true.

### Phase 4: Primary UI
Implement all SwiftUI views in UI/:
- MenuView.swift — root view composing all sub-views
- StatusCard.swift — mode indicator with colored dot
- AudioMeter.swift — output level bar with EquatableView
- ControlsSection.swift — gain slider, auto toggle, quality picker
- AppWarningBanner.swift — conditional Chrome/Electron warning
- Footer with Open Mic Settings and Quit buttons

Update AppDelegate to set correct NSHostingView frame size.
Implement dynamic menu bar icon based on currentMode.

Build and verify all UI elements render, controls bind to state,
and mode changes update the display.

**Checkpoint**: Full UI renders in dropdown. Controls adjust audio.
Icon changes with mode. Warning shows for Chrome.

### Phase 5: Settings, persistence, and polish
Implement Preferences.swift with @AppStorage wrappers.
Implement SettingsView.swift with tabbed layout.
Wire up SMAppService for launch at login.

Implement permission handling:
- Check on launch, request if needed
- Show denied state in StatusCard with System Settings button

Polish:
- Fix compiler warnings
- Ensure cleanup on quit (stop engine, remove taps)
- Animate AudioMeter smoothly
- Test light mode, dark mode, Liquid Glass (.regularMaterial)
- Verify menu bar icon as template image adapts to appearance

**Checkpoint**: Settings persist across relaunch. Launch at login works.
Permission flow handles all states. No warnings. Clean quit.

## Constraints

- Do not skip any phase. Complete each phase fully before moving to the next.
- Build and verify compilation after EVERY phase.
- If you encounter an error you cannot resolve, stop and explain — do not work around silently.
- Follow code style and prohibitions in CLAUDE.md exactly.
- Every SwiftUI view body should be under 25 lines. Extract sub-views.
- The audio processing chain MUST match what's documented in CLAUDE.md.
- Do not create any virtual audio driver or HAL plugin.
- Do not add any network code.