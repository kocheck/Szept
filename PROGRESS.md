# Szept — Build Progress

## Phases
- [x] Phase 1: Project scaffold and menu bar shell
- [x] Phase 2: Audio processing engine
- [x] Phase 3: Monitoring services
- [x] Phase 4: Primary UI
- [x] Phase 5: Settings, persistence, and polish

## Current session
All phases complete. 16/16 tests passing. Phase 5 added: full SettingsView (3-tab TabView: General/Audio/About), SMAppService launch-at-login, mic permission check + denied UI (MicPermissionDeniedCard), auto-start on launch from isProcessingEnabled preference, UserDefaults defaults registration, MicProcessor.loadPreferences + applyQualityPreset, persistence via onChange in ControlsSection, quality preset wired to isolation level, AudioMeter smooth animation.

### Launch bug fix (kyle/enhancements)
Fixed crash/failure when app auto-starts at launch before audio system is ready. Changes:
- `AppDelegate.swift` — `autoStartIfEnabled()` now defers engine start by 0.5s via `asyncAfter`; resets `isProcessingEnabled` to false on failure to prevent retry loop
- `MicProcessor.swift` — `start()` creates a fresh `AVAudioEngine` each time (changed from `let` to `var`); validates inputFormat before connecting; explicit format passed to `engine.connect`; tap removed before re-install; `stop()` disconnects nodes before detaching AU (prevents CoreAudio crash)
- `AppState.swift` — added `lastError: String?` for surfacing engine errors to UI
- `MenuView.swift` — added `ErrorBanner` view that displays `lastError` with dismiss button; `toggleEngine` sets/clears `lastError` on start failure

## Decisions made

- `@Observable` + `@AppStorage` cannot coexist — both synthesize `_property` backing storage. `Preferences` stays as a plain `final class`; `@AppStorage` will be used directly in views in Phase 5.
- `@Observable` macro synthesizes `_property` internal names, so audio-thread backing vars in `MicProcessor` use `tap` prefix (`tapGainLinear`, `tapAutoAdjust`, `tapIsolation`) to avoid collision.
- No separate Info.plist or entitlements file needed — `LSUIElement`, `NSMicrophoneUsageDescription`, sandbox, and audio-input entitlement are all configured in Xcode build settings (`GENERATE_INFOPLIST_FILE = YES`).
- AUSoundIsolation auto-adjust deadband is applied in RMS space (0.02 = ±20% of 0.1 target), not as a raw isolation-percentage deadband.
- `runAutoAdjust` only dispatches to main thread when isolation actually changes to avoid unnecessary main-thread pressure on every audio callback.
- `start()` includes cleanup path: if `engine.start()` throws, the AU is detached and `isolationUnit` is nilled before rethrowing.
- MicModeMonitor uses a private NSObject trampoline (MicModeObserver) for class-level KVO on AVCaptureDevice — @Observable classes cannot subclass NSObject.
- AppDelegate uses withObservationTracking recursive loop to reactively update menu bar icon from @Observable AppState.
- NSHostingView.sizingOptions = [.preferredContentSize] used for auto-height menu — replaces hardcoded 80pt.

### Phase 5
- `Szept/Szept/State/AppState.swift` — added: `micPermissionDenied: Bool`
- `Szept/Szept/Audio/MicProcessor.swift` — added: `loadPreferences(gainDB:autoAdjust:)`, `applyQualityPreset(_:)`
- `Szept/Szept/App/AppDelegate.swift` — updated: `registerDefaults()`, `loadPreferencesIntoProcessor()`, `checkMicPermission()`, `autoStartIfEnabled()` with quality preset on start
- `Szept/Szept/UI/ControlsSection.swift` — updated: persistence via `onChange` for gain + autoAdjust + qualityPreset; qualityPreset change calls `applyQualityPreset`
- `Szept/Szept/UI/MenuView.swift` — updated: `MicPermissionDeniedCard` (permission denied state with Privacy Settings button), `toggleEngine` saves `isProcessingEnabled`
- `Szept/Szept/UI/AudioMeter.swift` — updated: `.animation(.easeOut(duration: 0.1))` on level bar
- `Szept/Szept/UI/SettingsView.swift` — implemented: TabView with GeneralTab (SMAppService launch-at-login), AudioTab (@AppStorage gain/autoAdjust/qualityPreset), AboutTab (version + description)

## Known issues

- AUSoundIsolation is undocumented; may not load on Intel Macs or macOS < 13. App will still build and run — audio passes through with only gain + limiting applied.
- `tapIsolation` has concurrent writes from main thread (`setIsolationLevel`) and audio thread (`runAutoAdjust`). `nonisolated(unsafe)` suppresses the Swift concurrency check; Float writes are atomic on ARM in practice.

## Files modified this session

### Phase 1
- `Szept/Szept/App/SzeptApp.swift` — rewritten: @NSApplicationDelegateAdaptor + Settings scene
- `Szept/Szept/App/AppDelegate.swift` — created: NSStatusItem + NSMenu + NSHostingView
- `Szept/Szept/State/AppState.swift` — created: @Observable root state, SzeptMode enum
- `Szept/Szept/State/Preferences.swift` — created: @AppStorage wrappers (plain class)
- `Szept/Szept/UI/MenuView.swift` — rewritten: placeholder with Start/Stop + Quit
- `Szept/Szept/UI/StatusCard.swift` — created: stub
- `Szept/Szept/UI/AudioMeter.swift` — created: stub
- `Szept/Szept/UI/ControlsSection.swift` — created: stub
- `Szept/Szept/UI/AppWarningBanner.swift` — created: stub
- `Szept/Szept/UI/SettingsView.swift` — created: stub
- `Szept/Szept/Audio/MicProcessor.swift` — created: stub (replaced in Phase 2)
- `Szept/Szept/Audio/AudioDeviceManager.swift` — created: stub
- `Szept/Szept/Audio/DSP.swift` — created: stub (replaced in Phase 2)
- `Szept/Szept/Monitoring/MicModeMonitor.swift` — created: stub
- `Szept/Szept/Monitoring/FrontmostAppMonitor.swift` — created: stub
- `Szept/Szept/Monitoring/BundleIdentifiers.swift` — created: stub

### Phase 2
- `Szept/Szept/Audio/DSP.swift` — implemented: applyMakeupGain, applySoftLimiter, calculateRMS, dbToLinear
- `Szept/Szept/Audio/MicProcessor.swift` — implemented: full AVAudioEngine + AUSoundIsolation chain
- `Szept/Szept/UI/MenuView.swift` — updated: Start/Stop engine toggle
- `Szept/SzeptTests/SzeptTests.swift` — implemented: 12 DSP tests (all passing)

### Phase 3
- `Szept/Szept/Monitoring/BundleIdentifiers.swift` — implemented: known Chromium/Electron bundle ID lists with isChromiumBrowser/isElectronApp helpers
- `Szept/Szept/Monitoring/FrontmostAppMonitor.swift` — implemented: NSWorkspace active app observer, publishes incompatible app warnings to AppState
- `Szept/Szept/Monitoring/MicModeMonitor.swift` — implemented: KVO on AVCaptureDevice.activeMicrophoneMode via private NSObject trampoline (MicModeObserver)
- `Szept/SzeptTests/SzeptTests.swift` — added: 4 BundleIdentifiers tests (chromium, electron, unknown, voiceIsolation coverage)

### Phase 4
- `Szept/Szept/UI/StatusCard.swift` — implemented: colored mode indicator dot + mode name label
- `Szept/Szept/UI/AudioMeter.swift` — implemented: gradient level bar with EquatableView throttling
- `Szept/Szept/UI/ControlsSection.swift` — implemented: gain slider, auto-adjust toggle, isolation quality picker
- `Szept/Szept/UI/AppWarningBanner.swift` — implemented: orange styled banner with dynamic reason text
- `Szept/Szept/UI/MenuView.swift` — rewritten: full composition of all sub-views
- `Szept/Szept/App/AppDelegate.swift` — updated: dynamic NSHostingView sizing (sizingOptions = [.preferredContentSize]) + withObservationTracking reactive icon loop