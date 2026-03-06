# Szept — Build Progress

## Phases
- [x] Phase 1: Project scaffold and menu bar shell
- [x] Phase 2: Audio processing engine
- [ ] Phase 3: Monitoring services
- [ ] Phase 4: Primary UI
- [ ] Phase 5: Settings, persistence, and polish

## Current session
Phase 1 and Phase 2 complete. 12/12 DSP tests passing. App builds and runs.

## Decisions made

- `@Observable` + `@AppStorage` cannot coexist — both synthesize `_property` backing storage. `Preferences` stays as a plain `final class`; `@AppStorage` will be used directly in views in Phase 5.
- `@Observable` macro synthesizes `_property` internal names, so audio-thread backing vars in `MicProcessor` use `tap` prefix (`tapGainLinear`, `tapAutoAdjust`, `tapIsolation`) to avoid collision.
- No separate Info.plist or entitlements file needed — `LSUIElement`, `NSMicrophoneUsageDescription`, sandbox, and audio-input entitlement are all configured in Xcode build settings (`GENERATE_INFOPLIST_FILE = YES`).
- AUSoundIsolation auto-adjust deadband is applied in RMS space (0.02 = ±20% of 0.1 target), not as a raw isolation-percentage deadband.
- `runAutoAdjust` only dispatches to main thread when isolation actually changes to avoid unnecessary main-thread pressure on every audio callback.
- `start()` includes cleanup path: if `engine.start()` throws, the AU is detached and `isolationUnit` is nilled before rethrowing.

## Known issues

- AUSoundIsolation is undocumented; may not load on Intel Macs or macOS < 13. App will still build and run — audio passes through with only gain + limiting applied.
- `tapIsolation` has concurrent writes from main thread (`setIsolationLevel`) and audio thread (`runAutoAdjust`). `nonisolated(unsafe)` suppresses the Swift concurrency check; Float writes are atomic on ARM in practice.
- NSHostingView frame height is hardcoded at 80pt (placeholder). Will need dynamic sizing in Phase 4 when the full MenuView content is added.

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