# CarAutoPad

[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)
[![Build Unsigned IPA](https://img.shields.io/github/actions/workflow/status/bryan-maki/headunitpad-auto/build-ipa.yml?branch=main&style=flat-square&label=Build%20IPA)](.github/workflows/build-ipa.yml)
[![Platform](https://img.shields.io/badge/platform-iPadOS-blue.svg?style=flat-square)]()
[![Release](https://img.shields.io/badge/version-v0.4.1--beta-orange.svg?style=flat-square)]()

A native, pure-wireless Android Auto head unit receiver for iPadOS with full-screen adaptation.

**CarAutoPad** transforms your iPad into a high-performance, wireless Android Auto head unit without requiring jailbreak, TrollStore, or wired USB hardware privileges. Built natively in Swift, it features a complete AAP (Android Auto Protocol) stack, hardware-accelerated low-latency video decoding, multi-channel audio mixing with adaptive ducking, and end-to-end watchdog recovery mechanisms.

## Table of Contents

- [Security](#security)
- [Background](#background)
- [Features](#features)
- [Install](#install)
  - [Option 1: Sideload Prebuilt IPA (Recommended)](#option-1-sideload-prebuilt-ipa-recommended)
  - [Option 2: Build from Source](#option-2-build-from-source)
- [Usage](#usage)
  - [Wireless Connection](#wireless-connection)
  - [Display & Geometry Configuration](#display--geometry-configuration)
  - [Interaction Modes & Diagnostics](#interaction-modes--diagnostics)
- [Architecture](#architecture)
- [Testing](#testing)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)

## Security

**CarAutoPad** performs local TLS handshakes required by the Android Auto protocol using embedded credentials (`HeadunitPad/Resources/Raw/cert` and `privkey`) managed by `OpenSslTlsHandler`. All projection streams, touch inputs, microphone audio, and location updates are transmitted strictly over your local Wi-Fi network or personal hotspot between your iPad and Android phone—no external servers or cloud relays are involved.

## Background

Running Android Auto on an iPad traditionally suffers from wired USB accessory limitations, 16:9 letterboxed black bars, audio routing glitches, and stream freezes over unstable wireless links. **CarAutoPad** was engineered from the ground up across six development phases to provide a pure-wireless experience over Wi-Fi hotspot or LAN subnet discovery (`WPP-over-TCP`), native iPad aspect ratio and DPI geometry negotiation, and resilient audio/video pipelines tailored for in-vehicle environments.

## Features

- **Pure-Wireless Connectivity & Auto-Reconnect**: High-performance Android Auto port 5277 discovery (gateway direct-connect and concurrent subnet scanning), with seamless link-loss auto-reconnect and playback state restoration (`AutomaticReconnect`, `AutoResumePlaybackPolicy`, `LinkGapMonitor`).
- **Modern Dual-Column Dashboard & Native Settings Center**: Refactored `MainViewController` featuring an automotive card-based dashboard with breathing status pill, direct connection IP hub with one-tap reset, step-by-step Android setup guide, 6 interactive quick-spec tiles, screen keep-awake prevention during projection, and a dedicated `.insetGrouped` modal `SettingsViewController`.
- **Full-Screen iPad Geometry & Live DPI Preview**: Eliminates black bars via dynamic resolution negotiation (`NegotiatedResolutionPolicy`), margin cropping (`MarginStrategyPolicy`, `MarginAnnouncementPolicy`), and an embedded real-time interactive DPI previewer (`DpiPreviewView`).
- **Hardware-Accelerated Video & Self-Healing Pipeline**: Low-latency hardware rendering (`H264VideoRendererView`) backed by an adaptive decoder configuration ladder (`DecoderConfigLadder`), keyframe repair tracking (`KeyframeRepairTracker`, `WarmRelaunchKeyframePolicy`), and latency monitoring (`DecodeLatencyMonitor`).
- **Lockscreen Now Playing & Flexible Microphone Routing**: Restores iOS lockscreen and Control Center Now Playing album artwork and track info via `NowPlayingCoordinator` (zero `.mixWithOthers` interference, keep-alive audio sink), flexible microphone source routing (`Follow Audio`, `iPad Mic`, `Phone / Car BT Mic`), and unified profile identity preventing dual-vehicle split in Android Auto.
- **Smart Sensors, Steering Wheel Controls & Dynamic Reachability**: Astronomical sunrise/sunset calculations (`TwilightCalculator`) with offline timezone estimation, signed GPS coordinate preservation (western negative longitudes, southern negative latitudes), hardware keyboard and Bluetooth steering wheel key mapping (`KeymapManager`), dynamic network status monitoring (`NetworkReachabilityMonitor`), and automatic video decoder fallback ladder recovery (`DecoderConfigLadder`).
- **Hardware Audio Pipeline & Voice Assistant Uplink**: Supports hardware AAC and PCM decoding (`AacAudioDecoder`, `PCMAudioPlayer`), smooth navigation ducking (`MixerDuckingEnvelope`), and flow-controlled microphone capture with PCM decimation (`MicPcmDecimator`, `MicChunkAccumulator`).
- **Built-In Diagnostics & Configuration Backup**: Real-time performance HUD (`PerformanceOverlayView`), standalone audio pipeline tester (`AudioStreamTester`), connection issue guidance banners (`ConnectionIssueBannerView`), settings backup/restore (`SettingsBackupManager`), and one-tap log export (`LogExporter`).

## Install

### Option 1: Sideload Prebuilt IPA (Recommended)

1. Download the latest unsigned `CarAutoPad.ipa` (or `HeadunitPad.ipa`) from the [Releases](../../releases) page (current release: `v0.4.1-beta`).
2. Sign and install the `.ipa` onto your iPad using your preferred sideloading tool (**SideStore**, **AltStore**, **Sideloadly**, or an Apple Developer certificate).
3. On first launch, grant **Local Network**, **Microphone**, and **Location** permissions when prompted.

### Option 2: Build from Source

**Prerequisites:**
- macOS with Xcode 15.0 or later
- CocoaPods

```bash
# 1. Clone the repository
git clone https://github.com/Bryan-Maki/HeadunitPad-Auto.git
cd headunitpad-auto

# 2. Install CocoaPods dependencies
pod install

# 3. Open the workspace in Xcode
open HeadunitPad.xcworkspace

# Or build an unsigned IPA directly via the helper script:
bash scripts/build_unsigned_ipa.sh

```

## Usage

### Wireless Connection

1. **Network Setup**: Connect your iPad to your Android phone's personal Wi-Fi hotspot, or connect both devices to the same local Wi-Fi subnet (`DiscoverySubnetPolicy` automatically detects gateway and subnet addresses).
2. **Start Projection**:
* Start `Head unit server` on your Android phone's Android Auto developer settings.
* Tap **Direct Connect** or **Scan for Headunit Server (Port 5277)** on the iPad dashboard. `ConnectionManager` connects directly, completes the TLS handshake, and opens video, audio, input, and sensor channels.

### Display & Geometry Configuration

* Open the Settings panel to customize target resolution, screen density (DPI), video fit mode (`VideoFitPolicy`), and margin strategy (`MarginStrategyPolicy`).
* Use the **Live DPI Preview (`DpiPreviewView`)** to inspect UI scaling and layout proportions in real time before starting a projection session.
* Export or restore your custom head unit profile anytime via `SettingsBackupManager`.

### Diagnostics & HUD

* **Performance & Troubleshooting**: Toggle `PerformanceOverlayView` to monitor live FPS, decode latency, and network throughput. Use `AudioStreamTester` to verify audio output routing, or tap **Export Logs** (`LogExporter`) to generate a diagnostic bundle for bug reports.

## Architecture

```text
HeadunitPad/
├── Core/
│   ├── AAP/          # Frame reassembly, Protobuf codecs, channel multiplexing & link watchdogs
│   ├── Audio/        # AAC/PCM decoders, navigation ducking envelope, NowPlaying & mic uplink
│   ├── Diagnostics/  # AppLog, audio stream tester, connection issue banners & log exporter
│   ├── Location/     # CoreLocation GPS capture, TwilightCalculator & AAP sensor reporting
│   ├── Network/      # ConnectionArbiter, subnet/gateway discovery, TCP & OpenSSL TLS handlers
│   ├── Settings/     # Resolution, DPI, margin geometry policies & settings backup manager
│   ├── UI/           # Touch coordinate mapping, keymap manager, live DPI preview & settings VC
│   └── Video/        # H.264/HEVC NAL parser, decoder config ladder, keyframe repair & renderer view
├── Resources/Raw/    # Embedded TLS certificate and private key for AAP handshakes
├── AppDelegate.swift
├── MainViewController.swift
└── SceneDelegate.swift

```

## Testing

The repository includes a comprehensive unit and smoke test suite in `HeadunitPadTests/` covering all engineering phases:

* `ByteStreamConnectionTests` & `H264NALParserTests`: Core byte stream and NAL unit parsing verification
* `Phase1ScreenAndFramingTests`: Screen geometry adaptation and AAP fragmented frame reassembly
* `Phase2WirelessAndWatchdogTests`: Port 5277 subnet discovery, gateway detection, and link watchdog policies
* `Phase3VideoAndRecoveryTests`: Decoder configuration ladder, keyframe repair, and latency monitoring
* `Phase4AudioAndMicTests`: AAC decoding, navigation ducking envelope, and microphone decimation
* `Phase5SystemIntegrationTests`: Location forwarding, night mode event dispatch, and system integration
* `Phase6DiagnosticsAndPolishTests` & `ViewControllersSmokeTests`: Diagnostics, backup management, and UI smoke tests
* `Phase7NowPlayingAndMicSourceTests`: Lockscreen now playing sync, unified profile identity, and microphone routing
* `Phase9SmartFeaturesAndResilienceTests`: Astronomical twilight, signed negative GPS coordinates, keymap manager, and decoder fallback ladder

Run all tests in Xcode by pressing `Cmd + U`.

## Maintainers

* [@bryan-maki](https://github.com/Bryan-Maki)

## Contributing

Issues and Pull Requests are welcome! When submitting a bug report, please attach a diagnostic log exported via `LogExporter`. Before opening a Pull Request, please ensure:

1. New protocol or recovery logic follows the modular `*Policy` architecture.
2. All unit test suites under `HeadunitPadTests` pass without regressions.

## Acknowledgments

- [open-headunit](https://github.com/andreknieriem/open-headunit) - The Android Auto Server engine powering wireless projection.
- [HeadunitPad](https://github.com/andyching168/HeadunitPad) - The original project.

## License

See [LICENSE.txt](LICENSE.txt) for license details.
