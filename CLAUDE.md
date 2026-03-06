# Szept

A macOS menu bar app that improves microphone audio using Apple's AUSoundIsolation
neural network, with adaptive gain recovery and soft limiting. Fully local, zero network.

## Build commands
- Build: `xcodebuild -scheme Szept -configuration Debug build`
- Test: `xcodebuild -scheme Szept -configuration Debug test`
- Clean: `xcodebuild -scheme Szept clean`

## Tech stack
- Swift 5.9+ / SwiftUI
- macOS 14+ (Sonoma) deployment target
- Xcode 16+
- Frameworks: AVFoundation (AVAudioEngine), AudioToolbox (AUSoundIsolation AU),
  CoreAudio (device enumeration), Accelerate (vDSP for DSP), ServiceManagement (SMAppService)
- No SPM dependencies in v1 (all Apple frameworks)

## Architecture
- Menu bar app using NSStatusItem + NSMenu + NSHostingView (NOT MenuBarExtra)
- Single @Observable `AppState` class at root, injected via .environment()
- AppDelegate owns the NSStatusItem and menu lifecycle
- MicProcessor class encapsulates the full AVAudioEngine + AU chain
- @AppStorage for user preference persistence

## Project structure
```
Szept/
├── App/
│   ├── SzeptApp.swift          // @main with NSApplicationDelegateAdaptor
│   └── AppDelegate.swift         // NSStatusItem + NSMenu + NSHostingView
├── Audio/
│   ├── MicProcessor.swift        // AVAudioEngine + AUSoundIsolation chain
│   ├── AudioDeviceManager.swift  // CoreAudio device enumeration
│   └── DSP.swift                 // Makeup gain + tanh limiter (pure functions)
├── Monitoring/
│   ├── MicModeMonitor.swift      // KVO on AVCaptureDevice mic modes
│   ├── FrontmostAppMonitor.swift // NSWorkspace active app detection
│   └── BundleIdentifiers.swift   // Chromium/Electron bundle ID lists
├── State/
│   ├── AppState.swift            // @Observable root state
│   └── Preferences.swift         // Type-safe UserDefaults wrapper
├── UI/
│   ├── MenuView.swift            // Root SwiftUI view in NSHostingView
│   ├── StatusCard.swift          // Mode indicator (Enhanced/Standalone/Off)
│   ├── AudioMeter.swift          // Output level bar
│   ├── ControlsSection.swift     // Gain slider, auto toggle, preset picker
│   ├── AppWarningBanner.swift    // Chrome incompatibility warning
│   └── SettingsView.swift        // Preferences window content
├── Resources/
│   └── Assets.xcassets           // Menu bar template images
├── Info.plist                    // LSUIElement=YES, mic usage string
└── Szept.entitlements
```

## Code style rules
- Use NSStatusItem + NSMenu + NSHostingView for the menu bar. NOT MenuBarExtra.
- Use @Observable (NOT ObservableObject), @State (NOT @StateObject).
- Use async/await for concurrency. Do NOT import Combine for new code.
- Use SF Symbols for all icons. Menu bar icon MUST be a template image.
- Use `import Accelerate` for all DSP math (vDSP_vsmul, vDSP_rmsqv).
- Break SwiftUI view bodies into sub-views when exceeding 25 lines.
- Audio callback code must never allocate memory or block.
- Use DispatchQueue.main.async for UI updates from audio tap callbacks.

## Do NOT
- Do NOT use UIKit — this is macOS only.
- Do NOT use MenuBarExtra or NSPopover — use NSMenu + NSHostingView.
- Do NOT use legacy Objective-C APIs when Swift equivalents exist.
- Do NOT use NSViewController/NSView when SwiftUI works.
- Do NOT import Combine for new code.
- Do NOT commit without explicit user request.
- Do NOT add AI attribution comments.
- Do NOT implement a virtual audio driver or HAL plugin — v1 outputs to system default or BlackHole.
- Do NOT add any network code, analytics, or telemetry.
- Do NOT use NavigationView — use NavigationStack if needed.

## Workflow
- Always build (`xcodebuild build`) after code changes.
- Run tests after feature completion.
- Commit with descriptive messages after each completed phase.
- When unsure, explain options and ask — do not guess.

## Critical technical context

### AUSoundIsolation (the core audio unit)
This is an undocumented Apple AU that performs neural-network-based sound isolation.
It ships on macOS 13+ Apple Silicon Macs. Component description:
- Type: kAudioUnitType_Effect (aufx)
- SubType: 0x766F6973 (vois)
- Manufacturer: kAudioUnitManufacturer_Apple (appl)

Key parameter: ID 0 (WetDryMixPercent), range 0-100. Values above 85 cause
aggressive voice gating. The auto-adjust system should clamp to 15-85 range.

### The audio processing chain (validated in prototype)
```
AVAudioEngine.inputNode (physical mic)
  → AUSoundIsolation (AVAudioUnitEffect, 15-85% wet/dry)
  → mainMixerNode with tap that applies:
      1. Makeup gain (vDSP_vsmul, +3 to +18 dB user-adjustable)
      2. Soft tanh limiter (threshold 0.7)
      3. RMS metering (vDSP_rmsqv)
  → outputNode (speakers for testing, BlackHole for production)
```

### Voice Isolation stacking (validated)
When the user enables system Voice Isolation AND Szept is running,
both systems stack. Voice Isolation removes noise at the system level,
then AUSoundIsolation + gain + limiter refines the output.
This produces the best quality. The app detects this state via
AVCaptureDevice.activeMicrophoneMode KVO and shows "Enhanced" mode.

### NSMenu + NSHostingView pattern
This app uses NSStatusItem → NSMenu → NSMenuItem with NSHostingView,
NOT MenuBarExtra or NSPopover. This pattern provides instant opening,
native click-away dismissal, and works across all Spaces/fullscreen modes.
AppDelegate.swift owns the statusItem and builds the menu at launch.

## Known issues
- AUSoundIsolation is undocumented and could change in future macOS versions.
- The AU likely requires Apple Silicon (Neural Engine). Intel fallback shows "unavailable" state.
- AVAudioEngine voice processing on macOS can fail with error -10876 on aggregate devices.
  Workaround: don't enable isVoiceProcessingEnabled — we use AUSoundIsolation directly instead.
- NSHostingView in NSMenuItem has a known SwiftUI memory leak (FB7539293).
  Workaround: reuse views, don't recreate on every menu open.

## Testing
- `xcodebuild -scheme SzeptTests -configuration Debug test` — run unit tests
- Test pure logic only: DSP functions, BundleIdentifiers, AppState computed properties, Preferences
- Do NOT test audio hardware, AU loading, or system state — these require real devices
- Write tests alongside each phase, not as a separate phase
```

**The checkpoint updates** go into `INITIAL_BUILD_PROMPT.md`, replacing the existing checkpoints in each phase. For example, Phase 2's checkpoint line changes from:
```
**Checkpoint**: Engine starts. AU loads. Audio passes through.
```

to:
```
**Checkpoint**: Engine starts. AU loads. Audio passes through.
Tests pass for DSP.swift: gain calculation, limiter clamping, RMS computation.