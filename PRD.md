# CarAutoPad Product Requirements Document (Pure Wireless & Open-Headunit Full Port)

## 1. Product goal

Build `CarAutoPad` into a full-featured, pure-wireless native iPadOS Android Auto head unit receiver.

By completely removing dependencies on wired USB (AOA), `TrollUSBHostKit`, and private TrollStore hardware entitlements, and porting **over 80% of the core protocols, policy classes, audio/video pipelines, sensor integrations, and UI diagnostic features** from the open-source `open-headunit` project to iPadOS, users can install the app on any non-jailbroken iPad (via a standard personal developer certificate, AltStore, SideStore, or Sideloadly) and enjoy a complete head unit experience featuring full-screen edge-to-edge display (4:3 / 3:2 margin cropping), flexible Coolwalk split-screen DPI adjustment, low-latency HD HEVC video, multi-track audio mixing with ducking, and automatic reconnection on disconnect.

## 2. Source and compatibility assumptions

* **Reference baseline project**: Use the architecture, Protobuf definitions, and business policy classes of `open-headunit` as the sole porting blueprint.
* **Zero private entitlements & jailbreak-free**: Completely remove `TrollUSBHostKit`, `libusb`, and all private USB Host entitlements; rely exclusively on standard iOS/iPadOS sandboxed APIs (`Network.framework`, `VideoToolbox`, `AVFoundation`, `CoreLocation`, `CoreImage`) so the app can be packaged and installed using free Apple ID signing and third-party sideloading tools.
* **System version requirements**: Maintain the current Deployment Target of iOS/iPadOS 16.6; do not raise the minimum system version requirement without explicit user approval.
* **Third-party dependencies**: Retain `OpenSSL-Universal` in `CocoaPods` (for the AAP TLS handshake) and add `SwiftProtobuf` (to compile the full set of `.proto` protocol files from `open-headunit`).

## 3. User-visible requirements

### 3.1 Pure wireless connection modes

Remove all USB options from the settings and main UI, and provide the following pure wireless connection modes:

* `Auto Wireless`: Simultaneously start the wireless helper listener (`WirelessHelperServer` / `WppTcpServer`) and active subnet scanner (`NetworkDiscovery`), automatically initiating a connection as soon as an active head unit server on the phone or a shared hotspot subnet is detected.
* `Direct Headunit Server`: Automatically scan the phone hotspot gateway IP or manually enter `IP:5277` to initiate a TCP connection, while retaining connection history (`WirelessServerHistory`).
* `Wireless Helper / WPP`: Listen on a local TCP port on the iPad and wait passively for the phone to connect via Wireless Projection Protocol (WPP) or a helper tool.
* `QR Code Pairing`: Generate a QR code (`ProjectionSetupQrDialog`) on the main screen containing current LAN/hotspot connection parameters so the phone can scan to connect quickly.

Switching connection modes takes effect immediately on the next connection or reconnection attempt and persists across app launches.

### 3.2 iPad full-screen aspect ratio & Coolwalk DPI split-screen

1. **Resolution & frame rate tiers**: Support negotiating `480p (800×480)`, `720p (1280×720)`, `1080p (1920×1080)`, `1440p (2560×1440)`, and `4K (3840×2160)` resolutions, as well as switching between `30fps` and `60fps`.
2. **iPad full-screen aspect ratio adaptation (Margin Cropping)**:
* Provide three display modes: `Fit` (centered 16:9 with letterboxing), `Fill (Margin Crop)` (protocol-level margin cropping to fill the iPad 4:3 or 3:2 screen edge-to-edge without distortion), and `Stretch` (forced full-screen stretching).
* Calculate `width_margin` and `height_margin` automatically based on the iPad's screen aspect ratio in `Fill (Margin Crop)` mode, report them to the phone, and crop out the black bars via `AVSampleBufferDisplayLayer.contentsRect`.


3. **Accurate touch coordinate inverse mapping (`TouchCoordinateMapper`)**: Map tap and swipe gestures back to the phone container's coordinate space across all scaling modes and margin-cropping states without touch offset.
4. **Coolwalk split-screen DPI adjustment & live preview (`DpiPreviewView`)**:
* Support custom DPI adjustment from `100` to `320` and driver position switching between Left-Hand Drive (`LHD`) and Right-Hand Drive (`RHD`).
* Embed a visual `DpiPreviewView` in the settings screen to preview the sidebar/bottom bar placement and single-, dual-, or triple-pane card proportions in real time at the selected DPI without connecting a phone.


5. **Dynamic UI configuration refresh (`UpdateUiConfigRequest`)**: Send `0x800A` messages over the video channel to dynamically update margins whenever the iPad rotates between portrait and landscape or resizes its split-screen window.

### 3.3 Video & audio pipeline experience

1. **Dual-codec hardware video decoding (H.264 & HEVC/H.265)**: Support selecting H.264 or HEVC (H.265) hardware decoding in settings, automatically stepping down resolution or falling back to an alternate codec along the `DecoderConfigLadder` if decoder initialization fails.
2. **Wireless packet-loss corruption prevention & keyframe self-healing (Keyframe Repair)**: Intercept incomplete frames automatically when wireless packet loss, missing fragments, or background-to-foreground transitions occur (preventing macroblocking and green screens), and immediately send a keyframe refresh request to the phone.
3. **AAC-LC hardware audio decoding & multi-channel mixing (Audio Mixing & Ducking)**:
* Support dual-mode decoding for compressed AAC-LC audio streams and raw PCM.
* Manage `Media` (music), `Guidance` (navigation prompts), and `System` (system alerts) audio tracks independently.
* Smoothly lower background music volume via an envelope algorithm (`MixerDuckingEnvelope`) during navigation voice prompts, and smoothly restore volume once the prompt finishes.
* Include an adaptive jitter buffer (`AdaptivePcmBuffer`) and anti-clipping limiter (`MixerSoftClipper`) to eliminate pops, clicks, and dropouts caused by wireless network jitter.


4. **Voice assistant microphone decimation**: Downsample 48kHz audio captured from the iPad hardware microphone in real time to a standard Android Auto 16kHz mono PCM stream with anti-aliasing via `MicPcmDecimator` for accurate Google Assistant voice recognition.

### 3.4 Smart sensors, HUD navigation & peripherals

1. **Multi-mode day/night switching (Night Mode)**:
* Support `Follow System` (following iPadOS light/dark appearance), `Day Only`, `Night Only`, `Astronomical Twilight` (automatically calculating sunrise and sunset times from GPS coordinates), and `Geofence` (automatically switching to night mode upon entering preset tunnel or underground garage geofence coordinates).


2. **Driving restriction bypass (`DrivingStatusEvent`)**: Report `UNRESTRICTED` parked status by default so users can access the phone's software keyboard during projection.
3. **HUD navigation overlay & system media playback sync**:
* Parse real-time street names, turn arrows, distance to next maneuver, and remaining time from the navigation channel (`AapNavigation`), and support overlaying a translucent HUD navigation guide in video-only mode.
* Parse track title, artist, album name, and cover art from the media playback channel (`AapMediaPlayback`), and synchronize them in real time to the iPadOS Lock Screen and Control Center (`NowPlayingCoordinator`).


4. **External key/rotary knob mapping & vehicle identity spoofing**:
* Support custom mapping and key debouncing for external Bluetooth steering wheel controls, Bluetooth keyboard shortcuts, and trackpad scroll wheel/rotary knob events (`KeyCodeEvent`, `ScrollWheelEvent`).
* Support customizing the vehicle Make, Model, Year, and head unit name reported to the phone.



### 3.5 Floating control, diagnostics & backup

* **Global floating control button (`FloatingButton`)**: Provide a freely draggable floating button on the projection screen that turns translucent when idle and supports one-tap return to the home screen, day/night mode toggling, track skipping, and voice assistant activation.
* **Real-time performance monitoring overlay (`PerformanceOverlay`)**: Display real-time FPS, wireless receive bitrate (Mbps), decoding latency (ms), audio buffer level, keyframe repair count, and packet loss count in the screen corner when enabled.
* **Diagnostics, logging & backup**: Integrate a connection diagnostic banner (`ConnectionIssueBanner`) at the top of the home screen, and provide an independent channel tester (`AudioStreamTester`), one-tap runtime log export/sharing (`LogExporter`), and full settings JSON import/export backup (`SettingsBackupManager`) in the settings screen.

## 4. Architecture requirements

### 4.1 USB removal & transport boundary

* Completely delete the `CarAutoPad/Core/USB/` directory and all USB unit test files under `CarAutoPadTests/`, and clean up dangling references in `project.pbxproj`.
* Abstract all wireless byte-stream transports uniformly behind the `ByteStreamConnection` protocol (providing connection state, asynchronous sending, disconnection, and data receive callbacks).
* Implement `ByteStreamConnection` across `TcpHandler`, `WirelessHelperServer`, and the new `WppTcpServer` so `AapTransport` depends solely on the `ByteStreamConnection` protocol and remains agnostic to whether the underlying transport is an active TCP client or passive listener.

### 4.2 Protocol standardization & message framing

* Incorporate all 8 `.proto` files (`common`, `control`, `input`, `media`, `navigation`, `playback`, `sensors`, `wireless`) from `open-headunit/app/src/main/proto/` into the project and compile them into strongly typed Swift code using `SwiftProtobuf`.
* Fully port `AapMessageFraming`, `AapMessageReassembler`, and `FragmentedMessageAudit` to replace the hardcoded byte-splicing logic in `AapTransport`, ensuring safe and reliable reassembly of concurrent multi-channel fragmented payloads (such as large video keyframes and album art).

### 4.3 Watchdog & auto-reconnect state machine

* Integrate wireless link monitoring policies from `open-headunit` into `ConnectionManager`:
* `LinkGapMonitor`: Monitor Ping/Pong round-trip latency and heartbeat intervals, declaring the link disconnected upon timeout.
* `VideoStarvationPolicy` & `UnresponsivePeerPolicy`: Detect video stream starvation and unresponsive peer states.
* `AutomaticReconnect` & `ReconnectGracePolicy`: Reconnect automatically using exponential backoff after transient wireless drops, and resume music playback automatically via `ReconnectPlaybackSnapshot` and `AutoResumePlaybackPolicy` once reconnected.



### 4.4 Threading & memory safety

* Execute all socket reads/writes, OpenSSL TLS encryption/decryption, NAL framing, hardware video decoding, and audio resampling on dedicated background queues or Swift `Actor`s, never blocking the main UI thread.
* Implement `VideoBackpressurePolicy` and `VideoFeedQueuePolicy` in the video frame bus (`VideoFrameBus`) to proactively drop non-reference frames and trigger a keyframe request when the decoding queue backs up, preventing memory spikes.

## 5. Signing and packaging requirements

* **Remove private entitlements**: Strip `com.apple.vm.device-access`, `com.apple.security.exception.iokit-user-client-class`, and `com.apple.system.diagnostics.iokit-properties` completely from `CarAutoPad/CarAutoPad.entitlements`.
* **Standard sandbox permission configuration**: Retain only standard declarations for network communication, local network discovery (`NSLocalNetworkUsageDescription`), microphone (`NSMicrophoneUsageDescription`), location (`NSLocationWhenInUseUsageDescription`), and background audio playback (`UIBackgroundModes: audio`) in `Info.plist`.
* **Universal IPA build pipeline**: Remove legacy TrollStore-specific signing scripts and build a standard unsigned/self-signable universal `.ipa` (`scripts/build_unsigned_ipa.sh` and `.github/workflows/build-ipa.yml`) bundling all app resources and CocoaPods frameworks.

## 6. Scope

### 6.1 In scope

* Remove all USB and TrollStore dependencies and clean up the Xcode project.
* Port all 8 `.proto` definitions and the fragmented message reassembler from `open-headunit`.
* Port iPad aspect-ratio margin cropping, touch coordinate mapping, Coolwalk DPI adjustment, and `DpiPreviewView`.
* Port pure wireless discovery, WPP server, QR code pairing, link watchdogs, and automatic reconnection.
* Port HEVC (H.265) hardware decoding and the wireless packet-loss keyframe repair pipeline.
* Port AAC-LC hardware audio decoding, multi-track mixing, automatic navigation audio ducking, adaptive jitter buffering, and microphone decimation.
* Port multi-mode day/night switching (including astronomical calculation and geofencing), HUD navigation extraction, media cover art sync, peripheral key mapping, and vehicle identity spoofing.
* Port the global floating button, real-time performance HUD, audio channel tester, connection diagnostic banner, log exporter, and settings JSON backup.

### 6.2 Out of scope

* Any wired USB, AOA protocol, `libusb`, or `TrollUSBHostKit` functionality.
* Android on-device loopback self-connection mode (`connection/self/*`) from `open-headunit`.
* Android-specific privileged features (Root Shell, `SUExecutor`, built-in ADB, Shizuku, `DummyVpnService` virtual VPN routing, and low-level Wi-Fi Direct reflection hacks).
* Aftermarket Android head unit motherboard broadcasts and external serial Bluetooth chip drivers (`byd`, `fyt`, `blink`, `zbt`).

## 7. Delivery phases

Advance one phase at a time; each phase must pass its compilation, unit test, and functional verification gate before moving to the next phase.

### Phase 0 — USB purge and standard IPA foundation

1. Delete `CarAutoPad/Core/USB/`, `CarAutoPadTests/*USB*`, `CarAutoPadTests/AndroidOpenAccessoryTests.swift`, and legacy build scripts, and fix all references in `project.pbxproj`.
2. Strip private hardware permissions from `CarAutoPad.entitlements` and decouple USB branches from `ConnectionManager` and `MainViewController`.
3. Set up the standard `.ipa` build script and GitHub Actions workflow.

**Gate**: Xcode Simulator and Generic iOS Device builds pass with zero errors; the generated `.ipa` contains no private USB entitlements; existing wireless connection features launch and run normally.

### Phase 1 — Protobuf standardization & iPad screen/DPI system (P0)

1. Integrate `SwiftProtobuf`, compile the 8 `.proto` files from `open-headunit`, and refactor `AapMessage`, `AapMessageFraming`, `AapMessageReassembler`, and `AapTransport`.
2. Port `HeadUnitScreenConfig`, `MarginStrategyPolicy`, `VideoFitPolicy`, and `TouchCoordinateMapper` to achieve edge-to-edge 4:3 / 3:2 iPad margin cropping and accurate touch coordinate mapping.
3. Port `DpiPreviewView`, `UpdateUiConfigRequest`, and Left-Hand/Right-Hand Drive (LHD/RHD) settings.

**Gate**: Fragment reassembly and coordinate mapping unit tests pass 100%; physical iPad connections fill the 4:3 screen losslessly with accurate edge touch handling; adjusting DPI updates the Coolwalk split-screen layout and matches the live preview.

### Phase 2 — Pure wireless engine, watchdogs & auto-reconnect (P0)

1. Port `NetworkDiscovery`, `DiscoverySubnetPolicy`, `WppTcpServer`, `WppHandshakeSession`, and the `QrCodeGenerator` pairing modal.
2. Port `LinkGapMonitor`, `VideoStarvationPolicy`, `UnresponsivePeerPolicy`, `AutomaticReconnect`, and `AutoResumePlaybackPolicy` into `ConnectionManager`.

**Gate**: Hotspot subnet auto-discovery and QR code pairing work reliably; simulating brief Wi-Fi drops or restarting the phone head unit server does not crash the app and automatically reconnects and resumes playback within the grace period.

### Phase 3 — HEVC hardware decoding & wireless keyframe repair (P1)

1. Upgrade `NalParser` and `VideoRendererView` to support H.264 and HEVC (H.265) hardware decoding along with automatic fallback via `DecoderConfigLadder`.
2. Port `VideoFragmentAssembler`, `VideoKeyframeScanner`, `KeyframeRepairTracker`, `WarmRelaunchKeyframePolicy`, and `VideoBackpressurePolicy`.

**Gate**: HEVC hardware decoding runs smoothly at 1080p/1440p 60fps; weak-network packet loss or background/foreground switching causes no persistent corruption or black screens, and keyframe requests restore normal video within 1 second.

### Phase 4 — Multi-channel audio mixer, AAC decoding & mic decimator (P1)

1. Implement `AacAudioDecoder` to support hardware decoding of compressed wireless AAC-LC audio.
2. Upgrade `AudioMixerEngine` to integrate `AudioStreamCatalog`, `MixerDuckingEnvelope`, `MixerSoftClipper`, and `AdaptivePcmBuffer`.
3. Port `MicPcmDecimator` (48kHz to 16kHz downsampling) and `MicChunkAccumulator` into `MicrophoneCapture`.

**Gate**: Background music ducks smoothly during navigation prompts and restores afterward; 30 minutes of continuous playback exhibits no audio pops or A/V desync; Google Assistant voice wake and recognition function properly.

### Phase 5 — Smart sensors, geofencing, HUD navigation & keymap (P2)

1. Port `NightModeManager`, `TwilightCalculator`, `GeofenceLocation` (map-based geofence pin selection), and `DrivingStatusEvent`.
2. Port `AapNavigation` (HUD turn-by-turn floating overlay) and `AapMediaPlayback` (Lock Screen album art and track metadata sync).
3. Port `KeyCode`, `ScrollWheelEvent`, `KeymapManager` peripheral key mapping, and `VehicleIdentityPolicy` vehicle identity customization.

**Gate**: All 4 day/night switching modes and geofence triggers work as expected; full-screen HUD navigation cards and system Control Center track metadata/artwork display accurately; Bluetooth keyboards and steering wheel controls operate the head unit reliably.

### Phase 6 — Floating button, performance HUD, diagnostics & backup (P3)

1. Implement the globally draggable translucent floating button `FloatingButtonWindow` and custom background wallpaper support.
2. Implement the real-time performance monitoring layer `PerformanceOverlayView` and standalone audio channel tester `AudioStreamTester`.
3. Port `ConnectionIssueBannerPolicy`, `AppLog`, `LogExporter`, and `SettingsBackupManager`.

**Gate**: Real-time metrics on the performance HUD update accurately; the audio channel tester outputs sound properly on each channel; log export and settings JSON backup/restore pass end-to-end verification.

## 8. Test strategy

### 8.1 Automated tests (`CarAutoPadTests`)

* **Protocol framing & reassembly tests**: Verify the accuracy of `AapMessageFraming` and `AapMessageReassembler` across multi-packet fragments, out-of-order delivery, and oversized payloads.
* **Screen geometry & touch mapping tests**: Verify coordinate inverse-mapping precision in `HeadUnitScreenConfig` and `TouchCoordinateMapper` across `Fit`, `FillMargin`, and `Stretch` modes at various DPIs and resolutions.
* **Video parsing & self-healing tests**: Verify H.264/HEVC parameter set extraction (SPS/PPS/VPS), NAL fragment assembly, and state machine transitions in `KeyframeRepairTracker` under packet loss conditions.
* **Audio buffering & resampling tests**: Verify watermark adjustments in `AdaptivePcmBuffer`, gain curves in `MixerDuckingEnvelope`, and 48kHz-to-16kHz output length and precision in `MicPcmDecimator`.
* **Watchdog & reconnection tests**: Verify timeout detection and reconnection trigger logic in `LinkGapMonitor`, `VideoStarvationPolicy`, and `AutomaticReconnect`.

### 8.2 Physical device acceptance tests

* Install the standard packaged `.ipa` on a non-jailbroken physical iPad and test with an Android phone across both Wi-Fi LAN and personal hotspot environments.
* Verify 4:3 full-screen display, Coolwalk split-screen layout switching across different DPI values, HEVC 60fps smoothness, navigation audio ducking over music, voice assistant microphone capture, automatic day/night mode switching, background/foreground recovery, and automatic reconnection after link drops.

## 9. Completion criteria

The overall port is considered complete only when all of the following criteria are met simultaneously:

* All USB and private TrollStore privilege code is completely removed, and Xcode compilation plus all XCTest unit tests pass 100%.
* All feature modules from Phase 0 through Phase 6 are ported against `open-headunit` (achieving over 80% coverage of core business logic and policies).
* Physical iPad wireless testing passes acceptance for full-screen aspect-ratio cropping, Coolwalk split-screen preview, HEVC video, AAC multi-track mixing and ducking, microphone input, location services, day/night mode, HUD navigation, and external key mapping.
* Continuous wireless projection playback for at least 30 minutes, background/foreground switching, and hotspot drop/reconnect stress tests complete with zero crashes.
* `README.md` and project documentation are updated with the latest pure-wireless installation and usage instructions.

## 10. Stability & Video/Audio Hotfix History

### 10.1 H.264 P-Frame Collision Fix & One-Time Codec Locking
* **Problem**: In previous builds, H.264 P-frames with NAL header byte `0x41` (`nal_ref_idc = 2, type = 1`) mathematically satisfied `(0x41 & 0x7E) >> 1 == 32`, incorrectly identifying them as HEVC VPS units. Furthermore, `processSingleFrame` evaluated `isHevc = (pinnedCodec == .hevc) || isHevcStream` on every frame, re-triggering the check and causing all subsequent 1080p and 720p H.264 frames to be swallowed as VPS packets, causing an indefinite black screen.
* **Resolution**:
  1. In `H264VideoRendererView.swift`, codec detection is locked once upon the first frame (`if pinnedCodec == nil`). All subsequent frames evaluate strictly `let isHevc = (pinnedCodec == .hevc)`.
  2. In `detectHevc(from:)`, H.264 SPS/PPS (`avcType == 7 || avcType == 8`) are rejected immediately, and HEVC VPS/SPS/PPS detection enforces the Base Layer 2-byte NAL header constraint (`nal.count >= 2 && (b0 & 0x81) == 0 && nal[1] == 0x01`). Because `0x41` has bit 0 set (`b0 & 0x81 == 0x01 != 0`), it can never collide with HEVC.
  3. Clean single `videoConfig` payload in `ServiceDiscoveryResponse` with automatic HEVC promotion for 2K/4K resolutions.

### 10.2 Single Profile & On-Demand Microphone Announcement Policy
* **Resolution**:
  1. Handshake uses the unified Motorcycle Profile (`effectiveVehicleType = 3` and `"iPad-CarAutoPad-moto"`), which allows Android Auto (Gearhead) to switch gracefully between head unit microphone and phone microphone without splitting into two registered vehicle devices.
  2. Handshake dynamically announces `Channel.ID_MIC (7)` according to `ProjectionSettings.effectiveUseIpadMic`. When `effectiveUseIpadMic == false`, `Channel.ID_MIC` is omitted, triggering the phone's native microphone for Google Voice / Gemini without assistant cancellation.
  3. All mic modes (`Follow Audio Output`, `iPad Microphone`, `Phone / Car BT Mic`) share a single, permanent vehicle identity.

### 10.3 Phase 9 Smart Features, Sensors & Resilience (100% Completed)
* **F8 Dynamic Network Reachability (`NetworkReachabilityMonitor`)**:
  - `NWPathMonitor` with 0.30s debouncing monitors Wi-Fi connection and station IPv4/gateway addresses.
  - Automatically raises or clears `.wifiRadioOff` standing issue banners.
  - Triggers auto-discovery when reconnecting to Wi-Fi/hotspot with valid IPv4 under auto-reconnect mode.
* **F4 & GPS Astronomical Twilight & Signed Coordinates (`TwilightCalculator`)**:
  - Full NOAA solar declination/hour angle algorithm with +1.0° (0.017453293 rad) early night glare prevention and offline timezone longitude estimation fallback.
  - Integrated into `ProjectionSettings.NightModeSetting.twilight`.
  - Replaced ad-hoc `max(..., 0)` location clamping in `AapTransport.sendLocationUpdate` with standard `SensorBatch.LocationData` Protobuf two's-complement varints, fully preserving western negative longitudes, southern negative latitudes, and negative altitudes.
* **F3 Keymap Manager (`KeymapManager`)**:
  - Full hardware keyboard and Bluetooth steering wheel HID usage mapping to Android AAP KeyCodes (D-Pad, Enter, Back, Home, Play/Pause, Next, Previous, Voice Search, Rotary knobs).
  - Wired directly into `MainViewController` first responder chain and forwarded via `AapTransport.sendKeyEvent`.
* **F10 Decoder Runtime Ladder Auto-Fallback (`DecoderConfigLadder`)**:
  - Monitors consecutive decoding failures (`formatFailures`, `sampleFailures`, `displayLayer.status == .failed`) during playback initialization.
  - Triggers `onDecoderFallbackRequested` after 8 consecutive failures, automatically stepping down resolution preset (4K -> 2K -> 1080p -> 720p -> 480p) and reconnecting cleanly.

### 10.4 Phase 10 Codebase Purge & Architecture Optimization (100% Completed)
* **Elimination of Legacy Multi-Window Controllers & Empty Frame Bus**:
  - Removed deprecated `TrackpadViewController`, `VideoOnlyViewController`, `VideoFrameBus`, and `TrackpadInputBridge`.
  - Projection and gesture interaction are unified in `MainViewController` with low memory overhead.
* **Removal of Obsolete QR, WPP & Passive Servers**:
  - Purged `Core/UI/QR/` (3 files), `Core/Network/WPP/` (7 files), `WirelessProto.swift`, and `WirelessHelperServer.swift` (ports 5288 and 5000 listeners).
  - Modernized wireless connection to high-performance active port 5277 discovery (gateway direct-connect and concurrent subnet scanning).
* **Elimination of Dead Software AudioMixer & Buffer Overheads**:
  - Completely detached `AudioMixer` from `PCMAudioPlayer` (eliminating CPU-wasting registration and per-packet `mixer.feed` passes).
  - Retained essential `MixerDuckingEnvelope` for smooth navigation ducking and unified `PcmInputFormat` under the `Codec` namespace.
* **Purge of 99 Unreferenced Policy Files & Deprecated APIs**:
  - Stripped 99 orphaned policy files across AAP, Audio, Network, Settings, and Video domains with 0 active references.
  - Removed 135 lines of legacy hand-crafted discovery payload assembly in `AapTransport` in favor of strongly typed Protobuf messages (`AapServiceDiscoveryResponseMessage`).
  - Purged deprecated configuration properties (`connectionMode`, margins, Wi-Fi credentials) from `ProjectionSettings` and `SettingsBackupManager`.
  - Updated all unit tests across `CarAutoPadTests/`, guaranteeing 100% test pass rate and pristine repository hygiene.

### 10.5 Phase 11 Rebrand & Independent Bundle Identifier (100% Completed)
* **Official Rebrand to CarAutoPad**:
  - Configured `CFBundleDisplayName` and `CFBundleName` to `"CarAutoPad"` in `Info.plist` and `project.pbxproj` (`INFOPLIST_KEY_CFBundleDisplayName`).
  - Updated all permission usage descriptions (Local Network, Microphone, Location) in `Info.plist` to reflect `"CarAutoPad"`.
  - Updated in-app UI header (`MainViewController`), launch screen (`LaunchScreen.storyboard`), and settings footer (`SettingsViewController`).
* **Independent Bundle Identifier**:
  - Replaced legacy bundle identifiers in `project.pbxproj` with independent bundle identifiers for the main target and unit tests.
  - Enables side-by-side coexistence on iPad with upstream `andyching168.HeadunitPad` without overwriting installs.
  - Renamed internal target name `PRODUCT_NAME = "$(TARGET_NAME)"` (`CarAutoPad.app/CarAutoPad`) and `vehicleId = "iPad-CarAutoPad"` to establish 100% full project consistency.
* **AAP Broadcast & System Lockscreen Alignment**:
  - Updated `ServiceDiscoveryResponse` (`headUnitMake: "CarAutoPad"`, `headUnitModel: "CarAutoPad"`, `displayName: "CarAutoPad"`), `AapTransport` connected device announcements, and `NowPlayingCoordinator` placeholder and owner identifiers.

### 10.6 Smart 3-Attempt Targeted Auto-Reconnect & Precise Discovery Failure Diagnosis (100% Completed)
* **No Blind Rescan or Reconnect on Empty Discovery**:
  - Pre-discovery check validates local IPv4 interface before network scanning; immediately raises `.wifiRadioOff` if disconnected from Wi-Fi/Hotspot.
  - Accurately distinguishes between `.wifiRadioOff` ("Search Failed: No Wi-Fi / Hotspot") and `.noDeviceDiscovered` ("No Device Found on Network (Port 5277)").
  - Terminates discovery cleanly on empty scan without triggering endless blind background scans.
* **Targeted 3-Attempt 3.0s Auto-Reconnect for Discovered Peers**:
  - Directly reconnects to the target peer (`lastConnectedDevice`) at fixed 3.0-second intervals without repeating full subnet sweeps.
  - Enforces a hard ceiling of 3 retries (`reconnectAttempt` 1/3, 2/3, 3/3).
  - Single-event latch (`hasHandledDisconnectForCurrentAttempt`) eliminates duplicate reconnect dispatching across `.error` and `aapTransportDidDisconnect`.
* **Headunit Server Unresponsive / Stuck Alert**:
  - When all 3 retries are exhausted, terminates auto-reconnect and raises `.headunitServerStuckAfterRetries`.
  - Clearly alerts the user that the phone's Headunit Server may be frozen and provides actionable instructions to restart it in Android Auto developer settings (⋮ -> Stop head unit server, then Start head unit server).
* **UI Feedback & Banner Dismiss Fix**:
  - Dashboard dynamically surfaces retry countdown progress (`Retrying in 3s (X/3)...`), orange status pill, active loading indicator, and accessible disconnect button during reconnection.
  - Banner dismiss accurately dismisses the most recently raised standing issue (`max(by: raisedAtEpochMs)`).

### 10.7 Zero-Drop Direct Handshake & Per-Connection Serial Queue TLS Ordering (100% Completed)
* **Elimination of Duplicate Ready & Handshake Collisions on Adopted Connection (`TcpHandler`)**:
  - Resolved duplicate `.ready` state callback when adopting an already-ready `NWConnection` in `adoptConnection()`, preventing double `byteStreamConnectionDidConnect` and dual `startReceiving()` loops from corrupting the TLS byte stream.
  - Guarded `setupStateHandler` against stale callbacks with connection identity check (`self.connection === targetConn`) and `hasReportedReady` single-execution guard.
  - In `disconnect()`, stripped `oldConnection?.stateUpdateHandler = nil` before calling `cancel()`, completely eliminating delayed asynchronous `.cancelled` state deliveries from killing freshly adopted connections.
  - Guarded `startReceiving()` with `isReceivingLoopActive` and bound chunk receiving to `receiveNextChunk(on: targetConnection)` with active socket identity verification.
* **Per-Connection Independent Serial Queues for Discovery Probes (`Discovery`)**:
  - Replaced the shared `.concurrent` `probeQueue` with an independent serial queue (`com.carautopad.tcp.conn.<uuid>`) created per probe attempt.
  - Ensures 100% parallel probing across different IP candidates without thread starvation, while guaranteeing 100% strictly ordered TCP/TLS packet delivery on the adopted socket.
  - Atomically validated `preparedConnections["\(ip):\(port)"]` under `probeLock` in `probePort` `.ready` before saving, clearing `stateUpdateHandler` to guarantee clean handover.
* **Safe Handshake Timeout & Removal of Premature 3.0s Severance (`AapTransport`)**:
  - Removed premature 3.0s `aapTransportDidDetectSilentPeerOnInitialHandshake` redial code that severed sockets during normal handshake negotiation.
  - Adjusted `versionHandshakeTimeout` to 5.0 seconds with standard 3.0s cool-down between retries, protecting the phone's Headunit Server from handshake collision lockups.

### 10.8 Elimination of Discovery isScanning Self-Locking & Seamless Direct Connect (100% Completed)
* **Removal of Self-Locking isScanning Mutation in Discovery Probes (`Discovery`)**:
  - Removed improper `isScanning = false` assignment inside `probePort` `.ready`, preventing `reportFoundService` from dropping `discoveryDidFindDevice` due to its own guard.
  - Refactored `reportFoundService` to atomic deduplication via `reportedEndpoints.isEmpty` under `probeLock`, ensuring the first found device is always dispatched exactly once.
  - Guarded `finishScan` to suppress `discoveryDidFinish` if any device was discovered (`!reportedEndpoints.isEmpty`), eliminating race-condition false-negative "No device found" alerts.
* **Elimination of State Flickering on Immediate Connect (`ConnectionManager`)**:
  - Replaced `stopDiscovery(cancelPrepared: true)` in `connect(to:)` with direct `discovery.stopScan(cancelPrepared: true)` after extracting the prepared connection via `takePreparedConnection`.
  - Avoids resetting `state` to `.disconnected` ("Ready to connect") before transitioning to `.connecting`, preventing UI status label flicker and eliminating orphan socket leaks on port 5277.

### 10.9 Clean Socket Adoption Handshake & Synchronous Main-Thread Status Dispatch (100% Completed)
* **Restoration of Clean Socket Handshake in `TcpHandler`**:
  - Restored clean single-guard connection adoption (`let wasAlreadyConnected = self.isConnected`) matching `bfe43ff` architecture, removing experimental guards that interfered with `adoptConnection` handshake triggering.
  - Enforced strict connection identity check (`self.connection === targetConn`) across all callbacks and preserved handler detachment before cancellation in `disconnect()`.
* **Zero-Suppression Discovery Flow (`Discovery`)**:
  - Prohibited early invocation of `finishScan()` upon priority suspect response or subnet scan matches, preventing premature scan termination callbacks from conflicting with device connection.
  - Kept prepared connection `stateUpdateHandler` intact on `.ready` for seamless handover to `TcpHandler.adoptConnection`.
* **Prevention of Reconnect State Inversion (`ConnectionManager` & `MainViewController`)**:
  - Enhanced `stopDiscovery(cancelPrepared:resetState:)` to allow selective cancellation without emitting `"Ready to connect"`.
  - Refactored `MainViewController` connection callbacks to execute synchronously when already on the main thread, eliminating nested `DispatchQueue.main.async` reordering that caused `"Ready to connect"` to erroneously overwrite active connection progress.

### 10.10 First-Frame Keyframe Discipline, Focus Cycle Escalation & 1.8s Cold-Start Video Watchdog (100% Completed)
* **Prevention of Premature `hasDecodedKeyframe` on Dropped Initial IDR (`H264VideoRendererView`)**:
  - Removed premature `hasDecodedKeyframe = true` assignment prior to `makeSampleBuffer` and `displayLayer.isReadyForMoreMediaData` verification.
  - Bound `hasDecodedKeyframe = true` strictly to the point immediately prior to `displayLayer.enqueue(sampleBuffer)`.
  - Added immediate `onKeyframeRequested?()` triggers when dropping frames due to missing SPS/PPS configuration or awaiting IDR slices.
  - Thread-safe state cleanup in `reset()` dispatched to `processQueue.async`, with synchronous main-thread `displayLayer.flushAndRemoveImage()`.
* **Resolution of Wire-Corruption Deadlock & Focus Cycle Escalation (`AapTransport` & `ConnectionManager`)**:
  - Removed premature `sendVideoFocusNotification` on `Channel.ID_VID` inside `sendChannelOpenResponse(on:)`, ensuring video focus is only negotiated upon formal `0x8000` (Setup) and `0x8001` (Start) control messages.
  - Added `isWireCorruption: Bool = false` parameter to `requestVideoRecoveryIfNeeded`, updating `lastWireCorruptionAtMs` solely upon physical wire corruption (reassembler drops, audit corruption, assembly timeouts). This resolves the deadlock where `wireQuiet` was perpetually `false`, enabling timely escalation to `performVideoFocusCycle`.
  - Added 1.2s cold-start timer upon receiving `0x8001 MEDIA_MESSAGE_START` to cycle video focus if 0 video packets are received.
  - Standardized video focus release/regain gap to 150ms on `processingQueue.asyncAfter`.
  - Exposed `requestVideoFocusCycle(reason:)` on `AapTransport` and bridged through `ConnectionManager`.
* **Responsive 1.8s Cold-Start Video Watchdog & Verified Frame Accounting (`MainViewController`)**:
  - Bound `videoRenderer.onKeyframeRequested` to `connectionManager.requestVideoRecovery()`.
  - Removed speculative `lastVideoFrameTs` updates in `didReceiveVideoData`; frame timestamps are updated solely when frames are actually displayed via `videoRenderer.onFrameDisplayed`.
  - Forced synchronous `view.layoutIfNeeded()` and `videoContainerView.layoutIfNeeded()` on transition to `.running` before geometry synchronization.
  - Tightened video watchdog check interval to 0.6s; when no video frame is displayed within 1.8s after connection (`now - runningSinceTs > 1.8` and 2.0s recovery cooldown), automatically triggers `connectionManager.requestVideoFocusCycle(reason: "watchdog-no-first-frame")`.

### 10.11 Full 60FPS VSync PTS Pacing, DisplayLayer Backpressure Without GOP Drop & Zero-Latency Pipelines (100% Completed)
* **Full 60FPS VSync PTS Scheduling & Hardware Presentation (`H264VideoRendererView`)**:
  - Gated `kCMSampleAttachmentKey_DisplayImmediately = kCFBooleanTrue` strictly to the very first frame (`decodedFrameCount == 0`) for instant cold-start presentation. Subsequent frames rely on `CMSampleTimingInfo.presentationTimeStamp` hardware VSync release pacing, eliminating inter-frame microburst collision and uneven tearing.
  - Restored `FrameReleasePacer.nextPts` catch-up clamp (`targetSeconds - nowSeconds > frameInterval * 2.5`), ensuring timestamps catch up gracefully without unbounded drift.
  - Implemented microsecond backpressure retry (up to 8 loops of 2ms = 16ms, one 60Hz frame interval) before checking `displayLayer.isReadyForMoreMediaData`.
  - **Eliminated GOP lockup**: Removed destructive `hasDecodedKeyframe = false` on transient not-ready drops, preventing subsequent P-frames across the entire GOP from being erroneously discarded at `awaitingIDRDrops`.
* **Immediate Per-Frame Media ACK & Payload Allocation Elimination (`AapTransport`)**:
  - Restored per-frame `MediaAck(sessionId: sessionId, ack: 1)` immediately upon receiving a complete video frame (`message.type == 0` and `AapMessageFraming.isLast(message.flags)`), matching `open-headunit` flow-control cadence while ensuring `type == 1` configuration packets never consume the flow control window.
  - Streamlined `processEncryptedBuffer`: parsed multiple encrypted frames using a single-pass cursor (`var offset = 0`) and consolidated buffer reduction into a single `removeSubrange` call.
  - Avoided computed `message.payload` allocations on high-frequency `type == 0` frames in `recordVideoMessageType`.
  - Upgraded `processingQueue` QoS to `.userInteractive`.
* **Low-Latency Transport & Parser Optimizations (`TcpHandler`, `H264NALParser`, `TouchInputView`)**:
  - Upgraded `TcpHandler.queue` and `receiveQueue` QoS to `.userInteractive`. Removed redundant `receiveQueue.async` dispatch before forwarding chunks to `AapTransport`.
  - Added Annex-B fast-path in `H264NALParser.nalUnits`: frames starting with `00 00 00 01` or `00 00 01` parse immediately via `parseAnnexB`, skipping AVC record checks and data array cloning.
  - Optimized `isEssentialFrame` in `H264VideoRendererView` to inspect only the first 256 bytes (`frame.prefix(256)`) and reserved capacity in `makeLengthPrefixedSample`.
  - Removed touch move throttling (`minMoveInterval = 0.014s`) in `TouchInputView` while maintaining zero-sort single-touch mapping, ensuring 100% smooth gesture tracking.
  - Aligned `decoderAdditionalDepth: nil` in `ServiceDiscoveryResponse` with `open-headunit`.

### 10.12 Background/Foreground Lifecycle Closure, CMTimebase 60FPS Pacing, High-Priority Touch Interleaving & Selectable Debug Telemetry (100% Completed)
* **Background/Foreground Lifecycle Closure & 2.5s Dead-Link Watchdog (`SceneDelegate`, `H264VideoRendererView`, `AapTransport`, `ConnectionManager`)**:
  - Bound `sceneDidEnterBackground` and `sceneWillEnterForeground` directly to `ConnectionManager`.
  - Added `isInBackground` gating to `H264VideoRendererView`: rejects incoming frames during background to prevent iOS graphics sandbox violation, flushes and removes images on background entry, and flushes `.failed` states and re-synchronizes `CMTimebase` on foreground entry.
  - On background entry, `AapTransport` flushes pending media ACKs and sends `sendVideoFocusNotification(gain: false)` to notify phone encoders to pause rendering and save battery.
  - On foreground entry, `AapTransport` clears stale assembly buffers, sends a ping request to probe TCP link liveness, and triggers `performVideoFocusCycle` to force phone generation of SPS/PPS + IDR keyframes.
  - Configured a 2.5s foreground watchdog in `ConnectionManager`: if 0 inbound packets arrive within 2.5s of entering foreground (indicating a dead TCP link during iOS suspension), immediately tears down transport, returns `MainViewController` to the dashboard, and initiates automated 3-attempt reconnect.
* **CoreMedia `CMTimebase` Display Synchronization & Touch Priority Interleaving (`H264VideoRendererView`, `AapTransport`)**:
  - Initialized and synchronized explicit `displayLayer.controlTimebase` linked to `CMClockGetHostTimeClock()`, establishing master clock timing for `AVSampleBufferDisplayLayer`.
  - Clamped target PTS to `nowSeconds + frameInterval` if `targetSeconds - nowSeconds > frameInterval * 1.2`, ensuring the display layer hardware buffer pool never overflows.
  - Implemented high-priority touch queue in `AapTransport` with fragment interleaving: between every decrypted packet in multi-fragment video frames, queued touch events are encrypted and transmitted immediately (< 0.5ms delay).
* **5 Selectable `DebugLogCategory` & High-Precision Telemetry System (`AppLog`, `ProjectionSettings`, `SettingsViewController`)**:
  - Implemented `DebugLogCategory` (`CONN`, `VIDEO`, `TOUCH`, `PROTO`, `AUDIO`) with `@autoclosure` zero-overhead filtering and thread-safe date formatting.
  - Added 1-second concentrated telemetry (`[VIDEO-1S]`) and hitch detection (`[VIDEO-HITCH]`) in `H264VideoRendererView`.
  - Added end-to-end touch latency tracking (`[TOUCH]`) capturing `uiToDispatch`, `queueWait`, and `tlsEncryptSend` durations.
  - Added "Debug Log Categories..." configuration sub-controller and "Clear All Diagnostic Logs" one-tap action in `SettingsViewController`.

---

## 11. Phase 11: Apple CarPlay (`DiPlay`) 双引擎融合架构规划 (Roadmap)

参考工作区 `reference/DiPlay`（Android 端 Apple CarPlay 开源接收端实现）的完整架构，在保持 `CarAutoPad` 现有成熟免越狱硬解、混音与自适应全屏管线的前提下，将项目演进为**支持 Android Auto 与 Apple CarPlay 的免越狱无线双引擎车机接收端**。

### 11.1 Phase 11.1 — 加密原语、TLV8/Bplist 与配对层 (`CarAutoPad/Core/CarPlay/Crypto/` & `Pairing/`)
* **密码学原语绑定**：
  - 基于 iPadOS 原生 `CryptoKit` 实现 `ChaChaPoly` (RFC 7539 / 8439, 12-byte IV + 16-byte tag)、`Curve25519.KeyAgreement` (X25519) 与 `HKDF<SHA512>`。
  - 基于项目中已有的 `OpenSSL-Universal` 封装 `Srp6a`（SRP-6a 协议，RFC 5054，3072-bit 质数群），默认 PIN 码为 `"3939"`。
* **数据序列化**：
  - 移植 `Tlv8Codec`：处理 AirPlay 配对过程中的 TLV8（Type-Length-Value，支持超 255 字节的分片重组）。
  - 使用 Foundation `PropertyListSerialization` 处理二进制 bplist (`.binary`) 编解码。
* **配对握手状态机**：
  - `PairSetup`：完成 SRP-6a 协商、`M1/M2`、`M3/M4` 与 `M5/M6` 阶段，生成长期对端 Ed25519 公钥并保存到钥匙串/沙盒。
  - `PairVerify`：基于 Curve25519 进行临时密钥交换与两阶段验证（`M1/M2`、`M3/M4`），推导出本次 RTSP 会话的对称控制加密密钥 (`ControlCipher`)。

### 11.2 Phase 11.2 — MFi SAP 认证层 (`CarAutoPad/Core/CarPlay/MFi/`)
* **MFi 认证抽象架构**：
  - 定义 `MfiAuthProvider` 协议：包含 `getCertificate() async throws -> Data` 与 `sign(digest: Data) async throws -> Data`。
  - `LocalMfiAuthProvider`：加载本地沙盒内置证书 `certificate.p7b` 与私钥 `identity.pk8`，调用 OpenSSL / Security.framework 执行 P-256 ECDSA SHA-256 签名。
  - `RemoteMfiAuthProvider`：支持通过本地/局域网 HTTP 服务器代理远程获取 MFi 证书 (`GET /mfi/certificate`) 与签名 (`POST /mfi/sign`)。
* **SAP 协商会话**：
  - 实现 `CarPlayMfiSapAuthSetup`，处理 RTSP `/auth-setup` 的两步 SAP 交换（AES-128-CTR 认证挑战协商）。

### 11.3 Phase 11.3 — AirPlay RTSP 会话与 HID 触控回传 (`CarAutoPad/Core/CarPlay/AirPlay/`)
* **RTSP 消息编解码 (`CarPlayRtspMessage`)**：
  - 实现标准的 RTSP 请求与响应解析器（解析 CSeq、Content-Type `image/x-bplist` 或 `text/x-apple-plist+xml`、DACP-ID、Active-Remote）。
* **AirPlay 会话状态机 (`CarPlayAirPlaySession`)**：
  - 支持 `/info` 阶段：组装并回复车机端 `CarPlayInfoPlist`（分辨率、DPI、物理尺寸、音频格式能力集、HID 描述符、支持的流格式等）。
  - 支持双阶段 `SETUP`：
    - Setup 1：建立控制流与时间同步流 (`CarPlayNtpClock`，UDP 7010)。
    - Setup 2：建立数据流通道（视频 Type 110、主音频 Type 100/101、备用音频 Type 102/103、麦克风 Type 111 等）。
  - 支持 `RECORD` 与 `TEARDOWN`。
* **HID 触控与按键回传 (`CarPlayHid`)**：
  - 构造标准的 Apple CarPlay Multi-touch HID 报告描述符。
  - 在建立加密的 `eventPort`（TCP，ChaChaPoly 报文加密）后，将 iPad 屏幕手势与多点触控实时打包为 HID 报告并发送至 iPhone。

### 11.4 Phase 11.4 — 音视频流解包与现有硬解管线复用 (`CarAutoPad/Core/CarPlay/Media/`)
* **视频流解包与硬解复用 (`CarPlayScreenStream`)**：
  - 监听 TCP 数据端口，读取 Type 110 视频报文头，使用会话协商的 ChaChaPoly 密钥解密 payload。
  - 解析 AVCC/HVCC NAL 格式，转为 Annex-B 裸流，直接喂入现有 `H264VideoRendererView`，完全复用 iPadOS 硬件 `VideoToolbox` 解码器与 Metal/AVSampleBufferDisplayLayer 渲染流水线。
* **音频流解密与混音复用 (`CarPlayAudioStream` & `CarPlayBufferedAudioStream`)**：
  - 监听 Type 100（AAC-ELD / PCM 主音频）、Type 101（导航/警示伴音）、Type 102/103（电话/Siri 语音）。
  - 解密音频包，直接投递给现有的 `PCMAudioPlayer` 与 `AacAudioDecoder`，复用三声道独立混合、导航平滑压音（`MixerDuckingEnvelope`）与 30% Ducking 策略。
* **麦克风输入适配 (`CarPlayMicPacketizer`)**：
  - 将现有 `MicrophoneCapture` 采集到的 16kHz / 24kHz PCM 音频数据封装为 CarPlay 规定的 Type 111 音频包，发送至 iPhone。

### 11.5 Phase 11.5 — iAP2 隧道、Bonjour 唤醒与双模 UI 整合 (`CarAutoPad/Core/CarPlay/iAP2/` & `Discovery/`)
* **iAP2 通信协议栈**：
  - 监听 Type 130 隧道通道，解析 iAP2 链接层与会话层帧（Link Synchronization、Control Session、NowPlaying / Media Information）。
  - 将曲目、艺术家、封面元数据无缝桥接到现有的 `NowPlayingCoordinator`，保持 iPad 锁屏 Now Playing 一致体验。
  - 将车载 GPS 坐标（`LocationCapture`）通过 iAP2 Location Information 消息透传至 iPhone。
* **无线发现与热点自动唤醒 (`CarPlayBonjourService`)**：
  - 在局域网发布 `_airplay._tcp` 与 `_raop._tcp` 广播服务（TXT 记录宣告 features、model、pk、srcvers、pi 等）。
  - 监听来自 iPhone 的 `_carplay-ctrl._tcp` 唤醒请求，或主动向 iPhone 发起 `GET /ctrl-int/1/connect` 触发无线反向连接。
* **主控双模 UI 整合**：
  - 在 `MainViewController` 顶部 Header 或 Connection Hub 增加模式选择胶囊：`[ Android Auto | Apple CarPlay ]`。
  - 根据选中的模式分别启动 AAP 5277 发现引擎或 CarPlay AirPlay Bonjour 引擎，实现单 App 兼顾不同车主设备的极致体验。

---

## 12. 运行稳定性加固与 CI 流程优化 (AAP Handshake & Touch Hardening)

### 12.1 修复握手连环退出与 5277 挂死 Bug
1. **控制通道 0x0018 误判退出修复**：`0x0018 (CALL_AVAILABILITY_STATUS)` 不再被误判为视频退出请求，不再触发断开连接。
2. **0x8007 保护期焦点回收机制**：在执行 `performVideoFocusCycle` 或刚进入 `.running` 运行状态（3000ms 保护窗口）内，收到手机端 `0x8007 (mode=2/3)` 不触发断开，而是主动发送视频焦点通知回收焦点。
3. **移除错误的 `controlTimebase`**：移除 `displayLayer.controlTimebase` 绑定，恢复所有帧的 `kCMSampleAttachmentKey_DisplayImmediately = kCFBooleanTrue` 立即上屏特性，防止渲染层进入 `failed` 状态触发连续降级退出。
4. **平稳 BYEBYE 释放与前台防误触**：在主动 `disconnect()` 时先更新 UI 状态并异步发送 `BYEBYE_REQUEST`，通过可取消的 `delayedDisconnectWorkItem` 保持 80ms 延迟让 TLS 加密帧顺利写入 TCP Socket 再关闭连接，并在 `connect()` 时及时取消旧定时器避免断开新连接，避免手机端 5277 Server 挂死；`reconnectForSettingsChange()` 调整为 0.8s；`handleWillEnterForeground()` 仅在真正进入过后台时触发前台恢复看门狗。

### 12.2 触控重复发送修复
1. `MainViewController` 仅保留 `touchOverlayView.onTouchWithTimestamp` 单次回调，移除重复的 `onTouch` 绑定；`TouchInputView` 内部优先采用带时间戳回调并自动去重。
2. `AapTransport` 在 `sendTouchEvent` 与队列排空增加 `state == .running && isVideoChannelStarted` 状态守卫，并在 `startHandshake` / `stop` 时清空待发触控队列。

### 12.3 GitHub Actions 额度节省与按需构建
- `.github/workflows/build-ipa.yml` 移除 `push` 和 `pull_request` 自动触发器，仅保留 `workflow_dispatch` 手动触发，节省 CI 构建分钟数额度。

