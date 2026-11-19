import Foundation
import UIKit
import Network

public enum ProjectionFpsLimit: Int, CaseIterable {
    case fps60 = 1
    case fps30 = 2

    public var title: String {
        switch self {
        case .fps60: return L10n.fps60
        case .fps30: return L10n.fps30
        }
    }
}

public enum ProjectionGpsSource: Int, CaseIterable {
    case phone = 0
    case ipad = 1

    public var title: String {
        switch self {
        case .phone: return L10n.gpsPhone
        case .ipad: return L10n.gpsIpad
        }
    }
}

public enum ProjectionOrientation: Int, CaseIterable {
    case landscape = 0
    case portrait = 1
    case system = 2

    public var title: String {
        switch self {
        case .landscape: return L10n.orientationLandscape
        case .portrait: return L10n.orientationPortrait
        case .system: return L10n.orientationSystem
        }
    }
}

public enum NightModeSetting: Int, CaseIterable {
    case auto = 0
    case day = 1
    case night = 2
    case system = 3
    case twilight = 4

    public var title: String {
        switch self {
        case .auto: return L10n.nightAutoTitle
        case .twilight: return L10n.nightTwilightTitle
        case .day: return L10n.nightDayTitle
        case .night: return L10n.nightNightTitle
        case .system: return L10n.nightSystemTitle
        }
    }

    public var shortTitle: String {
        switch self {
        case .auto: return L10n.nightAutoShort
        case .twilight: return L10n.nightTwilightShort
        case .day: return L10n.nightDayShort
        case .night: return L10n.nightNightShort
        case .system: return L10n.nightSystemShort
        }
    }
}

public enum AudioCodecPreference: Int, CaseIterable {
    case aac = 1
    case pcm = 2

    public var title: String {
        switch self {
        case .aac: return L10n.audioCodecAac
        case .pcm: return L10n.audioCodecPcm
        }
    }
}

public enum AudioOutputTarget: Int, CaseIterable {
    case ipad = 0
    case phone = 1

    public var title: String {
        switch self {
        case .ipad: return L10n.audioTargetIpad
        case .phone: return L10n.audioTargetPhone
        }
    }

    public var isAudioSinkEnabled: Bool {
        return self == .ipad
    }
}

public enum MicrophoneSource: Int, CaseIterable {
    case followAudioOutput = 0
    case ipad = 1
    case phone = 2

    public var title: String {
        switch self {
        case .followAudioOutput: return L10n.micFollowAudioOutput
        case .ipad: return L10n.micIpad
        case .phone: return L10n.micPhone
        }
    }
}

public enum NavigationDuckingPreset: Int, CaseIterable {
    case off = 0        // 降低 0%（不压音，媒体保持 100%）
    case light = 25     // 降低 -25%（媒体保留 75%）
    case medium = 50    // 降低 -50%（媒体保留 50%）
    case standard = 70  // 降低 -70%（默认，媒体保留 30%）
    case deep = 85      // 降低 -85%（媒体保留 15%）
    case mute = 100     // 降低 -100%（导航播报时媒体完全静音）

    public var dropPercentage: Int { rawValue }
    public var reductionAmount: Float { Float(rawValue) / 100.0 }
    public var retainedGain: Float { 1.0 - reductionAmount }

    public var title: String {
        switch self {
        case .off: return L10n.duckingOffTitle
        case .light: return L10n.duckingLightTitle
        case .medium: return L10n.duckingMediumTitle
        case .standard: return L10n.duckingStandardTitle
        case .deep: return L10n.duckingDeepTitle
        case .mute: return L10n.duckingMuteTitle
        }
    }

    public var shortTitle: String {
        return rawValue == 0 ? L10n.duckingOffShort : "-\(rawValue)%"
    }
}

public enum MotionBlurMode: Int, CaseIterable {
    case off = 0
    case light = 1
    case medium = 2
    case strong = 3

    public var title: String {
        switch self {
        case .off: return L10n.motionBlurOffTitle
        case .light: return L10n.motionBlurLightTitle
        case .medium: return L10n.motionBlurMediumTitle
        case .strong: return L10n.motionBlurStrongTitle
        }
    }

    public var shortTitle: String {
        switch self {
        case .off: return L10n.motionBlurOffShort
        case .light: return L10n.motionBlurLightShort
        case .medium: return L10n.motionBlurMediumShort
        case .strong: return L10n.motionBlurStrongShort
        }
    }

    /// Maximum queued frames held in VSync de-jitter buffer before DoNotDisplay reference-safe catch-up
    public var maxBufferedFrames: Int {
        switch self {
        case .off: return 0
        case .light: return 2
        case .medium: return 3
        case .strong: return 4
        }
    }

    /// Whether single-frame arrivals must wait for the full frame cadence interval
    public var enforcesStrictCadence: Bool {
        switch self {
        case .off, .light: return false
        case .medium, .strong: return true
        }
    }

    /// Kept for backward test compatibility (0.0 since ghosting trail overlay is replaced by VSync pacing)
    public var trailOpacity: Float {
        switch self {
        case .off: return 0.0
        case .light: return 0.18
        case .medium: return 0.32
        case .strong: return 0.48
        }
    }
}

public typealias FrameSmoothingMode = MotionBlurMode

public typealias ProjectionVideoResolution = ResolutionPreset
public typealias ProjectionResolution = ResolutionPreset

public enum ProjectionSettings {
    private static let defaults = UserDefaults.standard

    private static let resolutionKey = "projection-resolution-preset"
    private static let fpsLimitKey = "projection-fps-limit"
    private static let dpiKey = "projection-dpi"
    private static let fitModeKey = "projection-fit-mode"
    private static let rightHandDriveKey = "projection-right-hand-drive"
    private static let gpsSourceKey = "projection-gps-source"
    private static let orientationKey = "projection-orientation"
    private static let autoReconnectKey = "projection-auto-reconnect"
    private static let autoResumePlaybackKey = "projection-auto-resume-playback"
    private static let videoCodecPreferenceKey = "projection-video-codec-preference"
    private static let audioCodecPreferenceKey = "projection-audio-codec-preference"
    private static let audioOutputTargetKey = "projection-audio-output-target"
    private static let microphoneSourceKey = "projection-microphone-source"
    private static let mediaVolumeKey = "projection-audio-media-volume"
    private static let navigationVolumeKey = "projection-audio-navigation-volume"
    private static let phoneSystemVolumeKey = "projection-audio-phone-system-volume"
    private static let mediaChannelEnabledKey = "projection-audio-media-channel-enabled"
    private static let navigationChannelEnabledKey = "projection-audio-navigation-channel-enabled"
    private static let systemChannelEnabledKey = "projection-audio-system-channel-enabled"
    private static let navigationDuckingAmountKey = "projection-audio-navigation-ducking-amount"
    private static let nightModeKey = "projection-night-mode"
    private static let motionBlurModeKey = "projection-motion-blur-mode"

    private static let autoDpiKey = "projection-auto-dpi"
    private static let edgeSwipeProtectionKey = "projection-edge-swipe-protection"
    private static let showPerformanceOverlayKey = "projection-show-performance-overlay"
    private static let lastKnownLatitudeKey = "projection-last-known-latitude"
    private static let lastKnownLongitudeKey = "projection-last-known-longitude"
    private static let debugCategoriesKey = "projection-debug-log-categories"
    private static let hiddenDiagnosticsUnlockedKey = "projection-hidden-diagnostics-unlocked"

    public static let defaultDpi = 160
    public static let minDpi = 100
    public static let maxDpi = 320

    private static var cachedCellularSupport: Bool?

    public static var resolution: ResolutionPreset {
        get {
            if defaults.object(forKey: resolutionKey) == nil {
                return .auto
            }
            let val = defaults.integer(forKey: resolutionKey)
            return ResolutionPreset(rawValue: val) ?? .auto
        }
        set {
            defaults.set(newValue.rawValue, forKey: resolutionKey)
            HeadUnitScreenConfig.shared.recalculate(requestedResolution: newValue)
        }
    }

    public static var fpsLimit: ProjectionFpsLimit {
        get {
            let val = defaults.integer(forKey: fpsLimitKey)
            return ProjectionFpsLimit(rawValue: val) ?? .fps60
        }
        set {
            defaults.set(newValue.rawValue, forKey: fpsLimitKey)
        }
    }

    public static var dpi: Int {
        get {
            let val = defaults.integer(forKey: dpiKey)
            if val == 0 { return defaultDpi }
            return min(max(val, minDpi), maxDpi)
        }
        set {
            let clamped = min(max(newValue, minDpi), maxDpi)
            defaults.set(clamped, forKey: dpiKey)
        }
    }

    public static var fitMode: VideoFitMode {
        get {
            if defaults.object(forKey: fitModeKey) == nil {
                return .fillMargin
            }
            let val = defaults.integer(forKey: fitModeKey)
            return VideoFitMode(rawValue: val) ?? .fillMargin
        }
        set {
            defaults.set(newValue.rawValue, forKey: fitModeKey)
            HeadUnitScreenConfig.shared.videoFitMode = newValue
            HeadUnitScreenConfig.shared.recalculate(requestedResolution: resolution)
        }
    }

    public static var rightHandDrive: Bool {
        get {
            return defaults.bool(forKey: rightHandDriveKey)
        }
        set {
            defaults.set(newValue, forKey: rightHandDriveKey)
        }
    }

    public static var gpsSource: ProjectionGpsSource {
        get {
            let value = defaults.integer(forKey: gpsSourceKey)
            let source = ProjectionGpsSource(rawValue: value) ?? .phone
            if source == .ipad && !supportsCellularIpad() {
                return .phone
            }
            return source
        }
        set {
            let source = (newValue == .ipad && !supportsCellularIpad()) ? ProjectionGpsSource.phone : newValue
            defaults.set(source.rawValue, forKey: gpsSourceKey)
        }
    }

    public static var orientation: ProjectionOrientation {
        get {
            guard defaults.object(forKey: orientationKey) != nil else { return .system }
            let value = defaults.integer(forKey: orientationKey)
            return ProjectionOrientation(rawValue: value) ?? .system
        }
        set {
            defaults.set(newValue.rawValue, forKey: orientationKey)
        }
    }

    public static var nightMode: NightModeSetting {
        get {
            guard defaults.object(forKey: nightModeKey) != nil else { return .auto }
            let val = defaults.integer(forKey: nightModeKey)
            return NightModeSetting(rawValue: val) ?? .auto
        }
        set {
            defaults.set(newValue.rawValue, forKey: nightModeKey)
        }
    }

    public static var showPerformanceOverlay: Bool {
        get {
            return defaults.bool(forKey: showPerformanceOverlayKey)
        }
        set {
            defaults.set(newValue, forKey: showPerformanceOverlayKey)
        }
    }

    public static var isDebugModeEnabled: Bool {
        get { showPerformanceOverlay }
        set { showPerformanceOverlay = newValue }
    }

    public static var isPerformanceHudEnabled: Bool {
        get { showPerformanceOverlay }
        set { showPerformanceOverlay = newValue }
    }

    public static var isHiddenDiagnosticsUnlocked: Bool {
        get {
            return defaults.bool(forKey: hiddenDiagnosticsUnlockedKey)
        }
        set {
            defaults.set(newValue, forKey: hiddenDiagnosticsUnlockedKey)
        }
    }

    public static var lastKnownLatitude: Double? {
        get {
            guard defaults.object(forKey: lastKnownLatitudeKey) != nil else { return nil }
            return defaults.double(forKey: lastKnownLatitudeKey)
        }
        set {
            if let val = newValue {
                defaults.set(val, forKey: lastKnownLatitudeKey)
            } else {
                defaults.removeObject(forKey: lastKnownLatitudeKey)
            }
        }
    }

    public static var lastKnownLongitude: Double? {
        get {
            guard defaults.object(forKey: lastKnownLongitudeKey) != nil else { return nil }
            return defaults.double(forKey: lastKnownLongitudeKey)
        }
        set {
            if let val = newValue {
                defaults.set(val, forKey: lastKnownLongitudeKey)
            } else {
                defaults.removeObject(forKey: lastKnownLongitudeKey)
            }
        }
    }

    public static func recordLastKnownLocation(latitude: Double, longitude: Double) {
        lastKnownLatitude = latitude
        lastKnownLongitude = longitude
    }

    public static func effectiveIsNightMode(userInterfaceStyle: UIUserInterfaceStyle? = nil, now: Date = Date()) -> Bool {
        switch nightMode {
        case .day:
            return false
        case .night:
            return true
        case .auto:
            let hour = Calendar.current.component(.hour, from: now)
            return hour >= 19 || hour < 7
        case .twilight:
            return TwilightCalculator.isNight(date: now, latitude: lastKnownLatitude, longitude: lastKnownLongitude)
        case .system:
            let style: UIUserInterfaceStyle
            if let userInterfaceStyle = userInterfaceStyle {
                style = userInterfaceStyle
            } else if Thread.isMainThread {
                style = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .flatMap { $0.windows }
                    .first(where: { $0.isKeyWindow })?.traitCollection.userInterfaceStyle ?? UITraitCollection.current.userInterfaceStyle
            } else {
                style = UITraitCollection.current.userInterfaceStyle
            }
            return style == .dark
        }
    }

    public static var autoReconnect: Bool {
        get {
            if defaults.object(forKey: autoReconnectKey) == nil {
                return true
            }
            return defaults.bool(forKey: autoReconnectKey)
        }
        set {
            defaults.set(newValue, forKey: autoReconnectKey)
        }
    }

    public static var autoResumePlayback: Bool {
        get {
            if defaults.object(forKey: autoResumePlaybackKey) == nil {
                return true
            }
            return defaults.bool(forKey: autoResumePlaybackKey)
        }
        set {
            defaults.set(newValue, forKey: autoResumePlaybackKey)
        }
    }

    public static var videoCodecPreference: VideoCodecPreference {
        get {
            guard let raw = defaults.string(forKey: videoCodecPreferenceKey),
                  let pref = VideoCodecPreference(rawValue: raw) else {
                return .h264
            }
            return pref
        }
        set {
            defaults.set(newValue.rawValue, forKey: videoCodecPreferenceKey)
        }
    }

    public static var audioCodecPreference: AudioCodecPreference {
        get {
            guard let raw = defaults.object(forKey: audioCodecPreferenceKey) as? Int,
                  let pref = AudioCodecPreference(rawValue: raw) else {
                return .aac
            }
            return pref
        }
        set {
            defaults.set(newValue.rawValue, forKey: audioCodecPreferenceKey)
        }
    }

    public static func resetToDefaults() {
        orientation = .system
        videoCodecPreference = .h264
        audioCodecPreference = .aac
        audioOutputTarget = .ipad
        microphoneSource = .followAudioOutput
        mediaVolume = defaultChannelVolume
        navigationVolume = defaultChannelVolume
        phoneSystemVolume = defaultChannelVolume
        isMediaChannelEnabled = true
        isNavigationChannelEnabled = true
        isSystemChannelEnabled = true
        navigationDuckingAmount = defaultNavigationDuckingAmount
        nightMode = .auto
        motionBlurMode = .off
        isEdgeSwipeProtectionEnabled = true
        isHiddenDiagnosticsUnlocked = false
        resetDpiToDefault()
        defaults.removeObject(forKey: "projection-app-language")
        L10n.testOverrideLanguage = nil
    }

    public static var motionBlurMode: MotionBlurMode {
        get {
            guard let raw = defaults.object(forKey: motionBlurModeKey) as? Int,
                  let mode = MotionBlurMode(rawValue: raw) else {
                return .off
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: motionBlurModeKey)
        }
    }

    public static var audioOutputTarget: AudioOutputTarget {
        get {
            guard let raw = defaults.object(forKey: audioOutputTargetKey) as? Int,
                  let target = AudioOutputTarget(rawValue: raw) else {
                return .ipad
            }
            return target
        }
        set {
            defaults.set(newValue.rawValue, forKey: audioOutputTargetKey)
        }
    }

    public static var isAudioSinkEnabled: Bool {
        return audioOutputTarget == .ipad
    }

    public static var microphoneSource: MicrophoneSource {
        get {
            guard let raw = defaults.object(forKey: microphoneSourceKey) as? Int,
                  let source = MicrophoneSource(rawValue: raw) else {
                return .followAudioOutput
            }
            return source
        }
        set {
            defaults.set(newValue.rawValue, forKey: microphoneSourceKey)
        }
    }

    public static var effectiveUseIpadMic: Bool {
        switch microphoneSource {
        case .followAudioOutput:
            return audioOutputTarget == .ipad
        case .ipad:
            return true
        case .phone:
            return false
        }
    }

    public static let defaultChannelVolume: Float = 1.0
    public static let maxChannelVolume: Float = 1.5
    public static let defaultNavigationDuckingAmount: Float = 0.70

    public static var mediaVolume: Float {
        get {
            guard defaults.object(forKey: mediaVolumeKey) != nil else { return defaultChannelVolume }
            return min(max(defaults.float(forKey: mediaVolumeKey), 0.0), maxChannelVolume)
        }
        set { defaults.set(min(max(newValue, 0.0), maxChannelVolume), forKey: mediaVolumeKey) }
    }

    public static var navigationVolume: Float {
        get {
            guard defaults.object(forKey: navigationVolumeKey) != nil else { return defaultChannelVolume }
            return min(max(defaults.float(forKey: navigationVolumeKey), 0.0), maxChannelVolume)
        }
        set { defaults.set(min(max(newValue, 0.0), maxChannelVolume), forKey: navigationVolumeKey) }
    }

    public static var phoneSystemVolume: Float {
        get {
            guard defaults.object(forKey: phoneSystemVolumeKey) != nil else { return defaultChannelVolume }
            return min(max(defaults.float(forKey: phoneSystemVolumeKey), 0.0), maxChannelVolume)
        }
        set { defaults.set(min(max(newValue, 0.0), maxChannelVolume), forKey: phoneSystemVolumeKey) }
    }

    public static var isMediaChannelEnabled: Bool {
        get {
            guard defaults.object(forKey: mediaChannelEnabledKey) != nil else { return true }
            return defaults.bool(forKey: mediaChannelEnabledKey)
        }
        set { defaults.set(newValue, forKey: mediaChannelEnabledKey) }
    }

    public static var isNavigationChannelEnabled: Bool {
        get {
            guard defaults.object(forKey: navigationChannelEnabledKey) != nil else { return true }
            return defaults.bool(forKey: navigationChannelEnabledKey)
        }
        set { defaults.set(newValue, forKey: navigationChannelEnabledKey) }
    }

    public static var isSystemChannelEnabled: Bool {
        get {
            guard defaults.object(forKey: systemChannelEnabledKey) != nil else { return true }
            return defaults.bool(forKey: systemChannelEnabledKey)
        }
        set { defaults.set(newValue, forKey: systemChannelEnabledKey) }
    }

    /// 导航播报时媒体音量降低比例 (0.0 = 不压音, 0.70 = 降低 -70%, 1.0 = 完全静音媒体)
    public static var navigationDuckingAmount: Float {
        get {
            guard defaults.object(forKey: navigationDuckingAmountKey) != nil else {
                return defaultNavigationDuckingAmount
            }
            return min(max(defaults.float(forKey: navigationDuckingAmountKey), 0.0), 1.0)
        }
        set { defaults.set(min(max(newValue, 0.0), 1.0), forKey: navigationDuckingAmountKey) }
    }

    public static var audioChannelsSummaryText: String {
        guard isAudioSinkEnabled else { return audioOutputTarget.title }
        let mPct = isMediaChannelEnabled ? "\(Int((mediaVolume * 100).rounded()))%" : L10n.off
        let nPct = isNavigationChannelEnabled ? "\(Int((navigationVolume * 100).rounded()))%" : L10n.off
        let sPct = isSystemChannelEnabled ? "\(Int((phoneSystemVolume * 100).rounded()))%" : L10n.off
        let duckPct = Int((navigationDuckingAmount * 100).rounded())
        return L10n.audioChannelsSummary(mPct: mPct, nPct: nPct, sPct: sPct, duckPct: duckPct)
    }

    public static var videoResolution: ResolutionPreset {
        get { resolution }
        set { resolution = newValue }
    }

    public static var videoFitMode: VideoFitMode {
        get { fitMode }
        set { fitMode = newValue }
    }

    public static var driverPosition: DriverPosition {
        get { rightHandDrive ? .right : .left }
        set { rightHandDrive = (newValue == .right) }
    }

    public static var driverPositionTitle: String {
        return rightHandDrive ? L10n.driverPositionRhd : L10n.driverPositionLhd
    }

    public static var effectiveFpsLimit: ProjectionFpsLimit {
        if orientation == .portrait {
            return .fps30
        }
        return fpsLimit
    }

    public static var isAutoDpi: Bool {
        get {
            if defaults.object(forKey: autoDpiKey) == nil {
                return true
            }
            return defaults.bool(forKey: autoDpiKey)
        }
        set {
            defaults.set(newValue, forKey: autoDpiKey)
        }
    }

    public static var isEdgeSwipeProtectionEnabled: Bool {
        get {
            if defaults.object(forKey: edgeSwipeProtectionKey) == nil {
                return true
            }
            return defaults.bool(forKey: edgeSwipeProtectionKey)
        }
        set {
            defaults.set(newValue, forKey: edgeSwipeProtectionKey)
        }
    }

    public static func recommendedDpiForCurrentDevice() -> Int {
        let config = HeadUnitScreenConfig.shared
        let codecW = config.getNegotiatedWidth()
        let codecH = config.getNegotiatedHeight()
        let marginW = config.getWidthMargin()
        let marginH = config.getHeightMargin()
        let activeW = max(1, codecW - marginW)
        let activeH = max(1, codecH - marginH)
        return AnnouncedDensityPolicy.recommendedDpi(activeW: activeW, activeH: activeH)
    }

    public static var effectiveDpi: Int {
        if isAutoDpi {
            return recommendedDpiForCurrentDevice()
        }
        return dpi
    }

    public static var effectiveVideoCodecResolutionValue: Int {
        return resolution.codecResolutionValue
    }

    public static var effectiveVideoDimensions: (width: Int, height: Int) {
        return resolution.dimensions
    }

    public static var effectiveResolution: (width: Int, height: Int) {
        return resolution.dimensions
    }

    public static func resetDpiToDefault() {
        isAutoDpi = true
        dpi = defaultDpi
    }

    public static func isDebugCategoryEnabled(_ category: DebugLogCategory) -> Bool {
        guard let saved = defaults.dictionary(forKey: debugCategoriesKey) as? [String: Bool] else {
            return category.defaultEnabled
        }
        return saved[category.rawValue] ?? category.defaultEnabled
    }

    public static func setDebugCategory(_ category: DebugLogCategory, enabled: Bool) {
        var current = (defaults.dictionary(forKey: debugCategoriesKey) as? [String: Bool]) ?? [:]
        current[category.rawValue] = enabled
        defaults.set(current, forKey: debugCategoriesKey)
    }

    public static func enableAllDebugCategories() {
        var current: [String: Bool] = [:]
        for cat in DebugLogCategory.allCases {
            current[cat.rawValue] = true
        }
        defaults.set(current, forKey: debugCategoriesKey)
    }

    public static func availableResolutions(for orientation: ProjectionOrientation) -> [ResolutionPreset] {
        return [.auto, .r1280x720, .r1920x1080, .r2560x1440, .r3840x2160]
    }

    public static func supportsCellularIpad() -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        if let cached = cachedCellularSupport {
            return cached
        }

#if targetEnvironment(simulator)
        cachedCellularSupport = false
        return false
#else
        let monitor = NWPathMonitor()
        let hasCellular = monitor.currentPath.availableInterfaces.contains { $0.type == .cellular }
        if hasCellular {
            cachedCellularSupport = true
            return true
        }

        if Thread.isMainThread {
            let queue = DispatchQueue(label: "com.carautopad.cellular-detect")
            monitor.pathUpdateHandler = { path in
                cachedCellularSupport = path.availableInterfaces.contains { $0.type == .cellular }
                monitor.cancel()
            }
            monitor.start(queue: queue)
            return false
        }

        let queue = DispatchQueue(label: "com.carautopad.cellular-detect")
        let semaphore = DispatchSemaphore(value: 0)
        var hasCellularInterface = false

        monitor.pathUpdateHandler = { path in
            hasCellularInterface = path.availableInterfaces.contains { $0.type == .cellular }
            semaphore.signal()
        }

        monitor.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + 0.15)
        monitor.cancel()

        cachedCellularSupport = hasCellularInterface
        return hasCellularInterface
#endif
    }
}
