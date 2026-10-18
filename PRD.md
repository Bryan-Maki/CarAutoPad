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