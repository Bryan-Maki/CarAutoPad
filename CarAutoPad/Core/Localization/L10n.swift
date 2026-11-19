import Foundation
import UIKit

extension Notification.Name {
    public static let appLanguageDidChange = Notification.Name("CarAutoPadAppLanguageDidChange")
}

public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case malay = "ms"
    case korean = "ko"
    case tamil = "ta"

    fileprivate static var isRunningUnitTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    public static func currentSystemPreferredLanguages() -> [String] {
        let cfLanguages = (CFPreferencesCopyAppValue("AppleLanguages" as CFString, kCFPreferencesCurrentApplication) as? [String]) ?? []
        let udLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? []
        return cfLanguages + udLanguages + Locale.preferredLanguages
    }

    public static func resolveSystemLanguage(from preferredLanguages: [String]) -> AppLanguage {
        for raw in preferredLanguages {
            let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !lower.isEmpty else { continue }
            if lower.hasPrefix("zh") {
                if lower.contains("hant")
                    || lower.contains("-tw") || lower.contains("_tw")
                    || lower.contains("-hk") || lower.contains("_hk")
                    || lower.contains("-mo") || lower.contains("_mo") {
                    return .traditionalChinese
                }
                return .simplifiedChinese
            }
            if lower.hasPrefix("yue") {
                return lower.contains("hans") ? .simplifiedChinese : .traditionalChinese
            }
            if lower.hasPrefix("ja") {
                return .japanese
            }
            if lower.hasPrefix("ms") || lower.hasPrefix("id") {
                return .malay
            }
            if lower.hasPrefix("ko") {
                return .korean
            }
            if lower.hasPrefix("ta") {
                return .tamil
            }
            if lower.hasPrefix("en") {
                return .english
            }
        }
        return .english
    }

    public var resolved: AppLanguage {
        switch self {
        case .system:
            if Self.isRunningUnitTests {
                return .english
            }
            return Self.resolveSystemLanguage(from: Self.currentSystemPreferredLanguages())
        default:
            return self
        }
    }

    public var title: String {
        switch self {
        case .system:
            return L10n.systemDefaultLanguageTitle
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .traditionalChinese:
            return "繁體中文"
        case .japanese:
            return "日本語"
        case .malay:
            return "Bahasa Melayu"
        case .korean:
            return "한국어"
        case .tamil:
            return "தமிழ்"
        }
    }

    public var shortBadgeTitle: String {
        switch resolved {
        case .system, .english:
            return "EN"
        case .simplifiedChinese:
            return "简"
        case .traditionalChinese:
            return "繁"
        case .japanese:
            return "JA"
        case .malay:
            return "MS"
        case .korean:
            return "KO"
        case .tamil:
            return "TA"
        }
    }
}

public enum L10n {
    private static let cacheLock = NSLock()
    private static var cachedSystemLanguage: AppLanguage?

    public static var testOverrideLanguage: AppLanguage? = nil {
        didSet {
            if oldValue != testOverrideLanguage {
                let value = testOverrideLanguage
                if Thread.isMainThread {
                    NotificationCenter.default.post(name: .appLanguageDidChange, object: value)
                } else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .appLanguageDidChange, object: value)
                    }
                }
            }
        }
    }

    public static var current: AppLanguage {
        if let override = testOverrideLanguage {
            return override.resolved
        }
        if AppLanguage.isRunningUnitTests {
            return .english
        }
        cacheLock.lock()
        if let cached = cachedSystemLanguage {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        let resolved = AppLanguage.resolveSystemLanguage(from: AppLanguage.currentSystemPreferredLanguages())
        cacheLock.lock()
        cachedSystemLanguage = resolved
        cacheLock.unlock()
        return resolved
    }

    public static func refreshSystemLanguageOnForeground() {
        UserDefaults.standard.removeObject(forKey: "projection-app-language")
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        let updated = AppLanguage.resolveSystemLanguage(from: AppLanguage.currentSystemPreferredLanguages())
        cacheLock.lock()
        cachedSystemLanguage = updated
        cacheLock.unlock()
        if Thread.isMainThread {
            NotificationCenter.default.post(name: .appLanguageDidChange, object: updated)
        } else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .appLanguageDidChange, object: updated)
            }
        }
    }

    public static func tr(
        en: String,
        zhHans: String,
        zhHant: String,
        ja: String,
        ms: String,
        ko: String,
        ta: String
    ) -> String {
        switch current {
        case .system, .english:
            return en
        case .simplifiedChinese:
            return zhHans
        case .traditionalChinese:
            return zhHant
        case .japanese:
            return ja
        case .malay:
            return ms
        case .korean:
            return ko
        case .tamil:
            return ta
        }
    }

    // MARK: - Common Actions & Words
    public static var ok: String {
        tr(en: "OK", zhHans: "好", zhHant: "好", ja: "OK", ms: "OK", ko: "확인", ta: "சரி")
    }
    public static var done: String {
        tr(en: "Done", zhHans: "完成", zhHant: "完成", ja: "完了", ms: "Selesai", ko: "완료", ta: "முடிந்தது")
    }
    public static var cancel: String {
        tr(en: "Cancel", zhHans: "取消", zhHant: "取消", ja: "キャンセル", ms: "Batal", ko: "취소", ta: "ரத்து")
    }
    public static var close: String {
        tr(en: "Close", zhHans: "关闭", zhHant: "關閉", ja: "閉じる", ms: "Tutup", ko: "닫기", ta: "மூடு")
    }
    public static var dismiss: String {
        tr(en: "Dismiss", zhHans: "关闭", zhHant: "關閉", ja: "閉じる", ms: "Tutup", ko: "닫기", ta: "மூடு")
    }
    public static var reset: String {
        tr(en: "Reset", zhHans: "重置", zhHant: "重設", ja: "リセット", ms: "Tetapkan Semula", ko: "재설정", ta: "மீட்டமை")
    }
    public static var off: String {
        tr(en: "Off", zhHans: "关闭", zhHant: "關閉", ja: "オフ", ms: "Mati", ko: "끔", ta: "அணை")
    }
    public static var on: String {
        tr(en: "On", zhHans: "开启", zhHant: "開啟", ja: "オン", ms: "Hidup", ko: "켬", ta: "இயக்கு")
    }
    public static var notAvailableShort: String {
        tr(en: "N/A", zhHans: "不可用", zhHant: "不適用", ja: "対象外", ms: "T/B", ko: "해당 없음", ta: "இல்லை")
    }
    public static var unknown: String {
        tr(en: "Unknown", zhHans: "未知", zhHant: "未知", ja: "不明", ms: "Tidak diketahui", ko: "알 수 없음", ta: "தெரியாதது")
    }
    public static var autoShort: String {
        tr(en: "Auto", zhHans: "自动", zhHant: "自動", ja: "自動", ms: "Auto", ko: "자동", ta: "தானியங்கி")
    }
    public static var customShort: String {
        tr(en: "Custom", zhHans: "自定义", zhHant: "自訂", ja: "カスタム", ms: "Tersuai", ko: "사용자 지정", ta: "தனிப்பயன்")
    }
    public static var currentSuffixFormat: String {
        tr(en: "%@ (Current)", zhHans: "%@（当前）", zhHant: "%@（目前）", ja: "%@（現在）", ms: "%@ (Semasa)", ko: "%@ (현재)", ta: "%@ (தற்போதையது)")
    }
    public static func currentSuffix(_ text: String) -> String {
        String(format: currentSuffixFormat, text)
    }
    public static var lockedSuffixFormat: String {
        tr(en: "%@ (Locked)", zhHans: "%@（已锁定）", zhHant: "%@（已鎖定）", ja: "%@（ロック中）", ms: "%@ (Dikunci)", ko: "%@ (잠김)", ta: "%@ (பூட்டப்பட்டது)")
    }
    public static func lockedSuffix(_ text: String) -> String {
        String(format: lockedSuffixFormat, text)
    }
    public static var noWifiText: String {
        tr(en: "No Wi-Fi", zhHans: "无 Wi-Fi", zhHant: "無 Wi-Fi", ja: "Wi-Fi なし", ms: "Tiada Wi-Fi", ko: "Wi-Fi 없음", ta: "Wi-Fi இல்லை")
    }
    public static var defaultPhoneName: String {
        tr(en: "Phone", zhHans: "手机", zhHant: "手機", ja: "スマートフォン", ms: "Telefon", ko: "휴대폰", ta: "தொலைபேசி")
    }
    public static var unknownArtist: String {
        tr(en: "Unknown Artist", zhHans: "未知艺术家", zhHant: "未知演出者", ja: "不明なアーティスト", ms: "Artis Tidak Diketahui", ko: "알 수 없는 아티스트", ta: "தெரியாத கலைஞர்")
    }
    public static var projectionLabel: String {
        tr(en: "Projection", zhHans: "车载投屏", zhHant: "車載投影", ja: "プロジェクション", ms: "Unjuran", ko: "카 프로젝션", ta: "திரை இணைப்பு")
    }

    // MARK: - Language Selection
    public static var systemDefaultLanguageTitle: String {
        tr(
            en: "System Default",
            zhHans: "跟随系统",
            zhHant: "跟隨系統",
            ja: "システム設定に従う",
            ms: "Ikut Sistem",
            ko: "시스템 기본값",
            ta: "கணினி இயல்புநிலை"
        )
    }
    public static var languageRowTitle: String {
        tr(en: "Language", zhHans: "界面语言", zhHant: "介面語言", ja: "言語", ms: "Bahasa", ko: "언어", ta: "மொழி")
    }

    // MARK: - Projection Settings Enums
    public static var fps60: String {
        tr(en: "60 FPS", zhHans: "60 FPS", zhHant: "60 FPS", ja: "60 FPS", ms: "60 FPS", ko: "60 FPS", ta: "60 FPS")
    }
    public static var fps30: String {
        tr(en: "30 FPS", zhHans: "30 FPS", zhHant: "30 FPS", ja: "30 FPS", ms: "30 FPS", ko: "30 FPS", ta: "30 FPS")
    }

    public static var gpsPhone: String {
        tr(en: "Phone GPS", zhHans: "手机 GPS", zhHant: "手機 GPS", ja: "スマホ GPS", ms: "GPS Telefon", ko: "휴대폰 GPS", ta: "தொலைபேசி GPS")
    }
    public static var gpsIpad: String {
        tr(en: "iPad GPS", zhHans: "iPad GPS", zhHant: "iPad GPS", ja: "iPad GPS", ms: "GPS iPad", ko: "iPad GPS", ta: "iPad GPS")
    }
    public static var gpsPhoneShort: String {
        tr(en: "Phone", zhHans: "手机", zhHant: "手機", ja: "スマホ", ms: "Telefon", ko: "휴대폰", ta: "தொலைபேசி")
    }
    public static var gpsIpadShort: String {
        tr(en: "iPad", zhHans: "iPad", zhHant: "iPad", ja: "iPad", ms: "iPad", ko: "iPad", ta: "iPad")
    }

    public static var orientationLandscape: String {
        tr(en: "Landscape", zhHans: "横屏", zhHant: "橫向", ja: "横向き", ms: "Landskap", ko: "가로", ta: "கிடைமட்டம்")
    }
    public static var orientationPortrait: String {
        tr(en: "Portrait", zhHans: "竖屏", zhHant: "直向", ja: "縦向き", ms: "Potret", ko: "세로", ta: "செங்குத்து")
    }
    public static var orientationSystem: String {
        tr(en: "Auto", zhHans: "自动", zhHant: "自動", ja: "自動", ms: "Auto", ko: "자동", ta: "தானியங்கி")
    }

    public static var nightAutoTitle: String {
        tr(
            en: "Auto (Time 07:00-19:00)",
            zhHans: "自动（时间 07:00-19:00）",
            zhHant: "自動（時間 07:00-19:00）",
            ja: "自動（07:00〜19:00）",
            ms: "Auto (Masa 07:00-19:00)",
            ko: "자동 (07:00-19:00)",
            ta: "தானியங்கி (07:00-19:00)"
        )
    }
    public static var nightTwilightTitle: String {
        tr(
            en: "Twilight (Sunrise / Sunset)",
            zhHans: "天文晨昏（日出 / 日落）",
            zhHant: "天文晨昏（日出 / 日落）",
            ja: "トワイライト（日の出・日の入り）",
            ms: "Senja (Matahari Terbit / Terbenam)",
            ko: "일출/일몰 (천문 박명)",
            ta: "அந்தி (சூரிய உதயம் / அஸ்தமனம்)"
        )
    }
    public static var nightDayTitle: String {
        tr(
            en: "Day (Always Light)",
            zhHans: "日间（始终浅色）",
            zhHant: "日間（始終淺色）",
            ja: "昼モード（常にライト）",
            ms: "Siang (Sentiasa Cerah)",
            ko: "주간 (항상 밝게)",
            ta: "பகல் (எப்போதும் வெளிச்சம்)"
        )
    }
    public static var nightNightTitle: String {
        tr(
            en: "Night (Always Dark)",
            zhHans: "夜间（始终深色）",
            zhHant: "夜間（始終深色）",
            ja: "夜モード（常にダーク）",
            ms: "Malam (Sentiasa Gelap)",
            ko: "야간 (항상 어둡게)",
            ta: "இரவு (எப்போதும் இருள்)"
        )
    }
    public static var nightSystemTitle: String {
        tr(
            en: "System (Follow iPad)",
            zhHans: "跟随系统（iPad 外观）",
            zhHant: "跟隨系統（iPad 外觀）",
            ja: "システム（iPad に合わせる）",
            ms: "Sistem (Ikut iPad)",
            ko: "시스템 (iPad 설정 따름)",
            ta: "கணினி (iPad அமைப்பைப் பின்பற்று)"
        )
    }

    public static var nightAutoShort: String {
        tr(en: "Auto", zhHans: "自动", zhHant: "自動", ja: "自動", ms: "Auto", ko: "자동", ta: "தானியங்கி")
    }
    public static var nightTwilightShort: String {
        tr(en: "Twilight", zhHans: "晨昏", zhHant: "晨昏", ja: "日の出入", ms: "Senja", ko: "일출/일몰", ta: "அந்தி")
    }
    public static var nightDayShort: String {
        tr(en: "Day", zhHans: "日间", zhHant: "日間", ja: "昼", ms: "Siang", ko: "주간", ta: "பகல்")
    }
    public static var nightNightShort: String {
        tr(en: "Night", zhHans: "夜间", zhHant: "夜間", ja: "夜", ms: "Malam", ko: "야간", ta: "இரவு")
    }
    public static var nightSystemShort: String {
        tr(en: "System", zhHans: "系统", zhHant: "系統", ja: "システム", ms: "Sistem", ko: "시스템", ta: "கணினி")
    }

    public static var audioCodecAac: String {
        tr(en: "AAC-LC", zhHans: "AAC-LC", zhHant: "AAC-LC", ja: "AAC-LC", ms: "AAC-LC", ko: "AAC-LC", ta: "AAC-LC")
    }
    public static var audioCodecPcm: String {
        tr(
            en: "PCM (Uncompressed)",
            zhHans: "PCM（无损未压缩）",
            zhHant: "PCM（無損未壓縮）",
            ja: "PCM（非圧縮）",
            ms: "PCM (Tidak Dimampat)",
            ko: "PCM (무손실 비압축)",
            ta: "PCM (சுருக்கப்படாதது)"
        )
    }

    public static var audioTargetIpad: String {
        tr(
            en: "iPad (Speaker / iPad BT)",
            zhHans: "iPad（扬声器 / iPad 蓝牙）",
            zhHant: "iPad（揚聲器 / iPad 藍牙）",
            ja: "iPad（スピーカー / iPad BT）",
            ms: "iPad (Pembesar Suara / BT iPad)",
            ko: "iPad (스피커 / iPad 블루투스)",
            ta: "iPad (ஒலிபெருக்கி / iPad BT)"
        )
    }
    public static var audioTargetPhone: String {
        tr(
            en: "Phone (Original Device)",
            zhHans: "手机（原机 / 车载蓝牙）",
            zhHant: "手機（原機 / 車載藍牙）",
            ja: "スマートフォン（車載BT・端末側）",
            ms: "Telefon (Peranti Asal)",
            ko: "휴대폰 (원본 기기 / 차량 BT)",
            ta: "தொலைபேசி (அசல் சாதனம் / கார் BT)"
        )
    }
    public static var audioTargetIpadSegment: String {
        tr(en: "iPad", zhHans: "iPad", zhHant: "iPad", ja: "iPad", ms: "iPad", ko: "iPad", ta: "iPad")
    }
    public static var audioTargetPhoneSegment: String {
        tr(en: "Phone", zhHans: "手机", zhHant: "手機", ja: "スマホ", ms: "Telefon", ko: "휴대폰", ta: "தொலைபேசி")
    }
    public static var audioOutIpadShort: String {
        tr(en: "iPad (Speaker / BT)", zhHans: "iPad（扬声器/蓝牙）", zhHant: "iPad（揚聲器/藍牙）", ja: "iPad（スピーカー/BT）", ms: "iPad (Speaker / BT)", ko: "iPad (스피커/BT)", ta: "iPad (ஒலி/BT)")
    }
    public static var audioOutPhoneShort: String {
        tr(en: "Phone (Car BT)", zhHans: "手机（车载蓝牙）", zhHant: "手機（車載藍牙）", ja: "スマホ（車載BT）", ms: "Telefon (BT Kereta)", ko: "휴대폰 (차량 BT)", ta: "தொலைபேசி (கார் BT)")
    }

    public static var micFollowAudioOutput: String {
        tr(
            en: "Follow Audio Output",
            zhHans: "跟随音频输出",
            zhHant: "跟隨音訊輸出",
            ja: "音声出力に連動",
            ms: "Ikut Output Audio",
            ko: "오디오 출력 따름",
            ta: "ஒலி வெளியீட்டைப் பின்பற்று"
        )
    }
    public static var micIpad: String {
        tr(
            en: "iPad Microphone",
            zhHans: "iPad 麦克风",
            zhHant: "iPad 麥克風",
            ja: "iPad マイク",
            ms: "Mikrofon iPad",
            ko: "iPad 마이크",
            ta: "iPad ஒலிவாங்கி"
        )
    }
    public static var micPhone: String {
        tr(
            en: "Phone / Car BT Mic",
            zhHans: "手机 / 车载蓝牙麦克风",
            zhHant: "手機 / 車載藍牙麥克風",
            ja: "スマホ / 車載BTマイク",
            ms: "Mikrofon Telefon / BT Kereta",
            ko: "휴대폰 / 차량 BT 마이크",
            ta: "தொலைபேசி / கார் BT ஒலிவாங்கி"
        )
    }
    public static var micFollowSegment: String {
        tr(en: "Follow", zhHans: "跟随", zhHant: "跟隨", ja: "連動", ms: "Ikut", ko: "연동", ta: "தொடர்")
    }
    public static var micIpadSegment: String {
        tr(en: "iPad", zhHans: "iPad", zhHant: "iPad", ja: "iPad", ms: "iPad", ko: "iPad", ta: "iPad")
    }
    public static var micPhoneSegment: String {
        tr(en: "Phone", zhHans: "手机", zhHant: "手機", ja: "スマホ", ms: "Telefon", ko: "휴대폰", ta: "தொலைபேசி")
    }

    public static var duckingOffTitle: String {
        tr(
            en: "0% (No Ducking)",
            zhHans: "0%（不压音）",
            zhHant: "0%（不壓低音量）",
            ja: "0%（ダッキングなし）",
            ms: "0% (Tiada Redaman)",
            ko: "0% (더킹 없음)",
            ta: "0% (ஒலி குறைப்பு இல்லை)"
        )
    }
    public static var duckingLightTitle: String {
        tr(
            en: "-25% (Light)",
            zhHans: "-25%（轻度）",
            zhHant: "-25%（輕度）",
            ja: "-25%（弱）",
            ms: "-25% (Ringan)",
            ko: "-25% (약하게)",
            ta: "-25% (லேசான)"
        )
    }
    public static var duckingMediumTitle: String {
        tr(
            en: "-50% (Half)",
            zhHans: "-50%（减半）",
            zhHant: "-50%（減半）",
            ja: "-50%（半分）",
            ms: "-50% (Separuh)",
            ko: "-50% (절반)",
            ta: "-50% (பாதி)"
        )
    }
    public static var duckingStandardTitle: String {
        tr(
            en: "-70% (Default)",
            zhHans: "-70%（默认）",
            zhHant: "-70%（預設）",
            ja: "-70%（標準）",
            ms: "-70% (Lalai)",
            ko: "-70% (기본값)",
            ta: "-70% (இயல்பு)"
        )
    }
    public static var duckingDeepTitle: String {
        tr(
            en: "-85% (Deep)",
            zhHans: "-85%（深度）",
            zhHant: "-85%（深度）",
            ja: "-85%（強）",
            ms: "-85% (Dalam)",
            ko: "-85% (강하게)",
            ta: "-85% (ஆழமான)"
        )
    }
    public static var duckingMuteTitle: String {
        tr(
            en: "-100% (Mute Media)",
            zhHans: "-100%（媒体静音）",
            zhHant: "-100%（媒體靜音）",
            ja: "-100%（メディア消音）",
            ms: "-100% (Senyapkan Media)",
            ko: "-100% (미디어 음소거)",
            ta: "-100% (ஊடக ஒலி நிறுத்தம்)"
        )
    }
    public static var duckingOffShort: String {
        tr(en: "Off (0%)", zhHans: "关 (0%)", zhHant: "關 (0%)", ja: "オフ(0%)", ms: "Mati (0%)", ko: "끔 (0%)", ta: "அணை (0%)")
    }

    public static var motionBlurOffTitle: String {
        tr(en: "Off", zhHans: "关闭", zhHant: "關閉", ja: "オフ", ms: "Mati", ko: "끔", ta: "அணை")
    }
    public static var motionBlurLightTitle: String {
        tr(
            en: "Subtle (Low-Latency)",
            zhHans: "轻柔（低延迟）",
            zhHant: "輕柔（低延遲）",
            ja: "弱（低遅延）",
            ms: "Halus (Sela Masa Rendah)",
            ko: "약하게 (저지연)",
            ta: "மென்மை (குறைந்த தாமதம்)"
        )
    }
    public static var motionBlurMediumTitle: String {
        tr(
            en: "Balanced (Smooth)",
            zhHans: "均衡（丝滑）",
            zhHant: "均衡（順滑）",
            ja: "バランス（滑らか）",
            ms: "Seimbang (Lancar)",
            ko: "균형 (부드럽게)",
            ta: "சமநிலை (மென்மையான)"
        )
    }
    public static var motionBlurStrongTitle: String {
        tr(
            en: "Strong (Max Pacing)",
            zhHans: "强力（极致稳帧）",
            zhHant: "強力（極致順暢）",
            ja: "強（最大スムージング）",
            ms: "Kuat (Kestabilan Maks)",
            ko: "강하게 (최대 보정)",
            ta: "வலுவான (அதிகபட்ச சீர்மை)"
        )
    }

    public static var motionBlurOffShort: String {
        tr(en: "Off", zhHans: "关闭", zhHant: "關閉", ja: "オフ", ms: "Mati", ko: "끔", ta: "அணை")
    }
    public static var motionBlurLightShort: String {
        tr(en: "Subtle", zhHans: "轻柔", zhHant: "輕柔", ja: "弱", ms: "Halus", ko: "약함", ta: "மென்மை")
    }
    public static var motionBlurMediumShort: String {
        tr(en: "Balanced", zhHans: "均衡", zhHant: "均衡", ja: "バランス", ms: "Seimbang", ko: "균형", ta: "சமநிலை")
    }
    public static var motionBlurStrongShort: String {
        tr(en: "Strong", zhHans: "强力", zhHant: "強力", ja: "強", ms: "Kuat", ko: "강함", ta: "வலிமை")
    }

    public static var driverPositionRhd: String {
        tr(
            en: "Right-Hand Drive (RHD)",
            zhHans: "右舵驾驶 (RHD)",
            zhHant: "右駕 (RHD)",
            ja: "右ハンドル (RHD)",
            ms: "Pandu Kanan (RHD)",
            ko: "우핸들 (RHD)",
            ta: "வலதுபுற ஸ்டியரிங் (RHD)"
        )
    }
    public static var driverPositionLhd: String {
        tr(
            en: "Left-Hand Drive (LHD)",
            zhHans: "左舵驾驶 (LHD)",
            zhHant: "左駕 (LHD)",
            ja: "左ハンドル (LHD)",
            ms: "Pandu Kiri (LHD)",
            ko: "좌핸들 (LHD)",
            ta: "இடதுபுற ஸ்டியரிங் (LHD)"
        )
    }
    public static var rhdAbbrev: String {
        tr(en: "RHD", zhHans: "右舵", zhHant: "右駕", ja: "右ハンドル", ms: "RHD", ko: "우핸들", ta: "RHD")
    }
    public static var lhdAbbrev: String {
        tr(en: "LHD", zhHans: "左舵", zhHant: "左駕", ja: "左ハンドル", ms: "LHD", ko: "좌핸들", ta: "LHD")
    }
    public static var lhdShort: String {
        tr(en: "LHD (Left)", zhHans: "左舵 (LHD)", zhHant: "左駕 (LHD)", ja: "左 (LHD)", ms: "LHD (Kiri)", ko: "좌핸들 (LHD)", ta: "இடது (LHD)")
    }
    public static var rhdShort: String {
        tr(en: "RHD (Right)", zhHans: "右舵 (RHD)", zhHant: "右駕 (RHD)", ja: "右 (RHD)", ms: "RHD (Kanan)", ko: "우핸들 (RHD)", ta: "வலது (RHD)")
    }

    public static func audioChannelsSummary(
        mPct: String,
        nPct: String,
        sPct: String,
        duckPct: Int
    ) -> String {
        let duckStr: String
        if duckPct == 0 {
            duckStr = tr(en: "No Duck", zhHans: "不压音", zhHant: "不壓音", ja: "ダックなし", ms: "Tiada Duck", ko: "더킹 없음", ta: "குறைப்பு இல்லை")
        } else {
            duckStr = tr(
                en: "Duck -\(duckPct)%",
                zhHans: "压音 -\(duckPct)%",
                zhHant: "壓音 -\(duckPct)%",
                ja: "ダック -\(duckPct)%",
                ms: "Duck -\(duckPct)%",
                ko: "더킹 -\(duckPct)%",
                ta: "குறைப்பு -\(duckPct)%"
            )
        }
        return "iPad (\(mPct)/\(nPct)/\(sPct) • \(duckStr))"
    }

    // MARK: - Resolution & Fit Mode
    public static var resolutionAutoTitle: String {
        tr(
            en: "Auto (Native iPad)",
            zhHans: "自动（适配 iPad 原生）",
            zhHant: "自動（iPad 原生解析度）",
            ja: "自動（iPad ネイティブ）",
            ms: "Auto (Asli iPad)",
            ko: "자동 (iPad 기본 해상도)",
            ta: "தானியங்கி (iPad இயல்பு)"
        )
    }
    public static var resolutionAutoRecommended: String {
        tr(
            en: "Auto (Recommended)",
            zhHans: "自动（推荐）",
            zhHant: "自動（推薦）",
            ja: "自動（推奨）",
            ms: "Auto (Disyorkan)",
            ko: "자동 (권장)",
            ta: "தானியங்கி (பரிந்துரை)"
        )
    }

    public static var fitContainTitle: String {
        tr(
            en: "Fit (Letterbox)",
            zhHans: "适应（保留黑边）",
            zhHant: "符合畫面（保留黑邊）",
            ja: "フィット（黒帯あり）",
            ms: "Muat (Letterbox)",
            ko: "맞춤 (레터박스 유지)",
            ta: "பொருத்து (கருப்பு ஓரம்)"
        )
    }
    public static var fitFillTitle: String {
        tr(
            en: "Fill (PAR)",
            zhHans: "填充（像素比）",
            zhHant: "填滿（像素比）",
            ja: "フィル（PAR）",
            ms: "Isi (PAR)",
            ko: "채우기 (픽셀 비율)",
            ta: "நிரப்பு (PAR)"
        )
    }
    public static var fitCoverTitle: String {
        tr(
            en: "Cover (Crop)",
            zhHans: "铺满（裁切边缘）",
            zhHant: "填滿（裁切邊緣）",
            ja: "カバー（切り抜き）",
            ms: "Litup (Pangkas)",
            ko: "꽉 채우기 (가장자리 자르기)",
            ta: "மூடு (வெட்டு)"
        )
    }
    public static var fitFillMarginTitle: String {
        tr(
            en: "Fill Margin (iPad Fullscreen)",
            zhHans: "全屏边距填充（iPad 满屏）",
            zhHant: "全螢幕邊距填滿（iPad 滿版）",
            ja: "全画面マージン最適化 (iPad)",
            ms: "Isi Margin (Skrin Penuh iPad)",
            ko: "여백 채우기 (iPad 전체 화면)",
            ta: "முழு விளிம்பு நிரப்பு (iPad)"
        )
    }
    public static var fitStretchTitle: String {
        tr(
            en: "Stretch",
            zhHans: "拉伸铺满",
            zhHant: "延展填滿",
            ja: "ストレッチ",
            ms: "Regang",
            ko: "늘려서 채우기",
            ta: "நீட்டு"
        )
    }

    public static var fitSegmentFill: String {
        tr(en: "Fill", zhHans: "满屏", zhHant: "滿版", ja: "全画面", ms: "Isi", ko: "채우기", ta: "நிரப்பு")
    }
    public static var fitSegmentFillMargin: String {
        tr(en: "Fill Margin", zhHans: "边距满屏", zhHant: "邊距滿版", ja: "余白最適化", ms: "Isi Margin", ko: "여백 채움", ta: "முழு நிரப்பு")
    }
    public static var fitSegmentFit: String {
        tr(en: "Fit", zhHans: "适应", zhHant: "符合", ja: "フィット", ms: "Muat", ko: "맞춤", ta: "பொருத்து")
    }
    public static var fitSegmentStretch: String {
        tr(en: "Stretch", zhHans: "拉伸", zhHant: "拉伸", ja: "ストレッチ", ms: "Regang", ko: "늘리기", ta: "நீட்டு")
    }

    // MARK: - Settings Backup Errors
    public static var backupErrorInvalidFormat: String {
        tr(
            en: "Invalid settings format: missing or incorrect format identifier",
            zhHans: "无效的设置格式：缺少或错误的格式标识符",
            zhHant: "無效的設定格式：缺少或錯誤的格式識別碼",
            ja: "無効な設定形式：形式識別子が不足または不正です",
            ms: "Format tetapan tidak sah: pengecam format tiada atau salah",
            ko: "잘못된 설정 형식: 형식 식별자가 없거나 올바르지 않습니다",
            ta: "தவறான அமைப்பு வடிவம்: வடிவ அடையாளம் இல்லை அல்லது தவறானது"
        )
    }
    public static func backupErrorUnsupportedVersion(_ version: Int) -> String {
        tr(
            en: "Unsupported settings format version: \(version)",
            zhHans: "不支持的设置格式版本：\(version)",
            zhHant: "不支援的設定格式版本：\(version)",
            ja: "未対応の設定フォーマットバージョン：\(version)",
            ms: "Versi format tetapan tidak disokong: \(version)",
            ko: "지원되지 않는 설정 형식 버전: \(version)",
            ta: "ஆதரிக்கப்படாத அமைப்பு வடிவ பதிப்பு: \(version)"
        )
    }
    public static func backupErrorCorruptedData(_ msg: String) -> String {
        tr(
            en: "Corrupted settings data: \(msg)",
            zhHans: "设置数据已损坏：\(msg)",
            zhHant: "設定資料已損毀：\(msg)",
            ja: "設定データが破損しています：\(msg)",
            ms: "Data tetapan rosak: \(msg)",
            ko: "손상된 설정 데이터: \(msg)",
            ta: "சேதமடைந்த அமைப்புத் தரவு: \(msg)"
        )
    }

    // MARK: - Debug Log Categories
    public static var logCatConnTitle: String {
        tr(
            en: "Connection, Handshake & Lifecycle",
            zhHans: "连接、握手与生命周期",
            zhHant: "連線、握手與生命週期",
            ja: "接続・ハンドシェイク・ライフサイクル",
            ms: "Sambungan, Handshake & Kitaran Hayat",
            ko: "연결, 핸드셰이크 및 수명 주기",
            ta: "இணைப்பு, ஹேண்ட்ஷேக் & வாழ்க்கைச் சுழற்சி"
        )
    }
    public static var logCatConnSubtitle: String {
        tr(
            en: "Scan, TLS timing, SDR config, background/foreground & watchdog",
            zhHans: "扫描、TLS 耗时、SDR 配置、前后台切换与看门狗",
            zhHant: "掃描、TLS 耗時、SDR 設定、前景/背景切換與看門狗",
            ja: "スキャン・TLS 時間・SDR 設定・バックグラウンド切替・監視",
            ms: "Imbasan, masa TLS, konfigurasi SDR, latar belakang/depan & pemantau",
            ko: "스캔, TLS 지연, SDR 설정, 백그라운드/포그라운드 전환 및 워치독",
            ta: "ஸ்கேன், TLS நேரம், SDR அமைப்பு, பின்னணி மாற்றம் & கண்காணிப்பு"
        )
    }
    public static var logCatVideoTitle: String {
        tr(
            en: "Video 60FPS Telemetry & Hitch Catcher",
            zhHans: "视频 60FPS 遥测与卡顿捕获",
            zhHant: "視訊 60FPS 遙測與卡頓擷取",
            ja: "映像 60FPS テレメトリ・ヒッチ検出",
            ms: "Telemetri Video 60FPS & Penangkap Sangkut",
            ko: "비디오 60FPS 원격 측정 및 프레임 드랍 감지",
            ta: "வீடியோ 60FPS அளவீடு & தடங்கல் பிடிப்பு"
        )
    }
    public static var logCatVideoSubtitle: String {
        tr(
            en: "1s summary [VIDEO-1S] + instant hitch capture [VIDEO-HITCH]",
            zhHans: "每秒摘要 [VIDEO-1S] + 瞬时卡顿捕获 [VIDEO-HITCH]",
            zhHant: "每秒摘要 [VIDEO-1S] + 瞬時卡頓擷取 [VIDEO-HITCH]",
            ja: "1秒サマリー [VIDEO-1S] + 瞬間ヒッチ記録 [VIDEO-HITCH]",
            ms: "Ringkasan 1s [VIDEO-1S] + tangkapan sangkut serta-merta [VIDEO-HITCH]",
            ko: "1초 요약 [VIDEO-1S] + 순간 끊김 기록 [VIDEO-HITCH]",
            ta: "1 வினாடி சுருக்கம் [VIDEO-1S] + உடனடி தடங்கல் பதிவு [VIDEO-HITCH]"
        )
    }
    public static var logCatTouchTitle: String {
        tr(
            en: "Touch Input End-to-End Latency",
            zhHans: "触控输入端到端延迟",
            zhHant: "觸控輸入端到端延遲",
            ja: "タッチ入力のエンドツーエンド遅延",
            ms: "Sela Masa Hujung-ke-Hujung Input Sentuhan",
            ko: "터치 입력 종단간 지연 시간",
            ta: "தொடு உள்ளீடு முழு தாமதம்"
        )
    }
    public static var logCatTouchSubtitle: String {
        tr(
            en: "UI -> QueueWait -> TLS Encrypt/Send -> Next Frame [TOUCH]",
            zhHans: "UI -> 队列等待 -> TLS 加密发送 -> 下一帧 [TOUCH]",
            zhHant: "UI -> 佇列等待 -> TLS 加密傳送 -> 下一影格 [TOUCH]",
            ja: "UI -> キュー待機 -> TLS 暗号化送信 -> 次フレーム [TOUCH]",
            ms: "UI -> Tunggu Giliran -> Enkripsi/Hantar TLS -> Bingkai Seterusnya [TOUCH]",
            ko: "UI -> 큐 대기 -> TLS 암호화/전송 -> 다음 프레임 [TOUCH]",
            ta: "UI -> வரிசை -> TLS அனுப்புதல் -> அடுத்த பிரேம் [TOUCH]"
        )
    }
    public static var logCatProtoTitle: String {
        tr(
            en: "AAP Protocol, Focus & Keyframe Recovery",
            zhHans: "AAP 协议、焦点与关键帧自愈",
            zhHant: "AAP 協定、焦點與關鍵影格自動修復",
            ja: "AAP プロトコル・フォーカス・キーフレーム復旧",
            ms: "Protokol AAP, Fokus & Pemulihan Bingkai Utama",
            ko: "AAP 프로토콜, 포커스 및 키프레임 복구",
            ta: "AAP நெறிமுறை, ஃபோகஸ் & கீபிரேம் மீட்பு"
        )
    }
    public static var logCatProtoSubtitle: String {
        tr(
            en: "VideoFocus, Margin 0x8009, Ping RTT & FocusCycle",
            zhHans: "VideoFocus、0x8009 边距、Ping 往返延迟与焦点循环",
            zhHant: "VideoFocus、0x8009 邊距、Ping 往返延遲與焦點循環",
            ja: "VideoFocus、マージン 0x8009、Ping RTT、FocusCycle",
            ms: "VideoFocus, Margin 0x8009, Ping RTT & FocusCycle",
            ko: "VideoFocus, 여백 0x8009, Ping RTT 및 FocusCycle",
            ta: "VideoFocus, விளிம்பு 0x8009, Ping RTT & FocusCycle"
        )
    }
    public static var logCatAudioTitle: String {
        tr(
            en: "Audio Streams, Ducking & Microphone",
            zhHans: "音频流、导航压音与麦克风",
            zhHant: "音訊串流、導航壓音與麥克風",
            ja: "音声ストリーム・ダッキング・マイク",
            ms: "Strim Audio, Redaman & Mikrofon",
            ko: "오디오 스트림, 더킹 및 마이크",
            ta: "ஒலி ஓடைகள், குறைப்பு & ஒலிவாங்கி"
        )
    }
    public static var logCatAudioSubtitle: String {
        tr(
            en: "Audio sink start/stop, ducking gain & mic 0x8005",
            zhHans: "音频通道启停、压音增益与麦克风 0x8005",
            zhHant: "音訊通道啟停、壓音增益與麥克風 0x8005",
            ja: "オーディオシンク開始/停止・ダッキングゲイン・マイク 0x8005",
            ms: "Mula/henti sink audio, gandaan redaman & mik 0x8005",
            ko: "오디오 싱크 시작/중지, 더킹 게인 및 마이크 0x8005",
            ta: "ஒலி சிங்க் தொடக்கம்/நிறுத்தம், குறைப்பு & மைக் 0x8005"
        )
    }

    // MARK: - Connection Issues
    public static var issueWifiOffTitle: String {
        tr(
            en: "Search Failed: No Wi-Fi / Hotspot",
            zhHans: "搜索失败：未连接 Wi-Fi / 手机热点",
            zhHant: "搜尋失敗：未連接 Wi-Fi / 手機熱點",
            ja: "検索失敗：Wi-Fi / テザリング未接続",
            ms: "Carian Gagal: Tiada Wi-Fi / Hotspot",
            ko: "검색 실패: Wi-Fi / 핫스팟 미연결",
            ta: "தேடல் தோல்வி: Wi-Fi / ஹாட்ஸ்பாட் இல்லை"
        )
    }
    public static var issueWifiOffAdvice: String {
        tr(
            en: "No valid local Wi-Fi IPv4 address detected. Please connect iPad to your phone's personal hotspot or the same Wi-Fi network first.",
            zhHans: "未检测到有效的局域网 Wi-Fi IPv4 地址。请先将 iPad 连接到安卓手机的个人热点或同一 Wi-Fi 网络。",
            zhHant: "未偵測到有效的區域網路 Wi-Fi IPv4 位址。請先將 iPad 連接至手機的個人熱點或同一 Wi-Fi 網路。",
            ja: "有効なローカル Wi-Fi IPv4 アドレスが検出されません。先に iPad をスマートフォンのテザリングまたは同じ Wi-Fi に接続してください。",
            ms: "Tiada alamat IPv4 Wi-Fi tempatan yang sah dikesan. Sila sambungkan iPad ke hotspot peribadi telefon atau rangkaian Wi-Fi yang sama dahulu.",
            ko: "유효한 로컬 Wi-Fi IPv4 주소가 감지되지 않았습니다. 먼저 iPad를 휴대폰 개인용 핫스팟이나 동일한 Wi-Fi 네트워크에 연결하세요.",
            ta: "செல்லுபடியாகும் உள்ளூர் Wi-Fi IPv4 முகவரி கண்டறியப்படவில்லை. முதலில் iPad-ஐ தொலைபேசியின் ஹாட்ஸ்பாட் அல்லது அதே Wi-Fi உடன் இணைக்கவும்."
        )
    }
    public static var issueHeadunitNotAnsweringTitle: String {
        tr(
            en: "Headunit Server Not Answering",
            zhHans: "车机服务器未响应",
            zhHant: "車機伺服器無回應",
            ja: "ヘッドユニット サーバーが応答しません",
            ms: "Pelayan Unit Kepala Tidak Menjawab",
            ko: "헤드유닛 서버 응답 없음",
            ta: "ஹெட் யூனிட் சேவையகம் பதிலளிக்கவில்லை"
        )
    }
    public static var issueHeadunitNotAnsweringAdvice: String {
        tr(
            en: "Ensure 'Start Headunit Server' is running in Android Auto developer settings on the phone.",
            zhHans: "请确认安卓手机的 Android Auto 开发者设置中已开启「启动车机服务器」。",
            zhHant: "請確認手機的 Android Auto 開發人員設定中已開啟「啟動車機伺服器」。",
            ja: "スマートフォンの Android Auto 開発者向け設定で「ヘッドユニット サーバーを起動」が有効になっているか確認してください。",
            ms: "Pastikan 'Mulakan pelayan unit kepala' sedang berjalan dalam tetapan pembangun Android Auto pada telefon.",
            ko: "휴대폰의 Android Auto 개발자 설정에서 '헤드유닛 서버 시작'이 실행 중인지 확인하세요.",
            ta: "உங்கள் தொலைபேசியின் Android Auto டெவலப்பர் அமைப்புகளில் 'Start head unit server' இயக்கப்பட்டுள்ளதா என உறுதிப்படுத்தவும்."
        )
    }
    public static var issueRefused5277Title: String {
        tr(
            en: "Connection Refused (Port 5277)",
            zhHans: "连接被拒绝（端口 5277）",
            zhHant: "連線被拒絕（連接埠 5277）",
            ja: "接続が拒否されました（ポート 5277）",
            ms: "Sambungan Ditolak (Port 5277)",
            ko: "연결 거부됨 (포트 5277)",
            ta: "இணைப்பு மறுக்கப்பட்டது (போர்ட் 5277)"
        )
    }
    public static var issueRefused5277Advice: String {
        tr(
            en: "The phone actively refused port 5277. Stop and re-start Headunit Server in Android Auto.",
            zhHans: "手机主动拒绝了 5277 端口连接。请在 Android Auto 中「停止车机服务器」，然后重新「启动车机服务器」。",
            zhHant: "手機主動拒絕了 5277 連接埠連線。請在 Android Auto 中「停止車機伺服器」，然後重新「啟動車機伺服器」。",
            ja: "スマートフォンがポート 5277 への接続を拒否しました。Android Auto で「ヘッドユニット サーバーを停止」してから「ヘッドユニット サーバーを起動」してください。",
            ms: "Telefon menolak sambungan port 5277 secara aktif. Hentikan dan mulakan semula pelayan unit kepala dalam Android Auto.",
            ko: "휴대폰이 5277 포트 연결을 거부했습니다. Android Auto에서 헤드유닛 서버를 중지한 후 다시 시작하세요.",
            ta: "தொலைபேசி போர்ட் 5277 இணைப்பை மறுத்தது. Android Auto-வில் ஹெட் யூனிட் சேவையகத்தை நிறுத்தி மீண்டும் தொடங்கவும்."
        )
    }
    public static var issueTlsFailedTitle: String {
        tr(
            en: "TLS Handshake Failed",
            zhHans: "TLS 安全握手失败",
            zhHant: "TLS 安全握手失敗",
            ja: "TLS ハンドシェイクに失敗しました",
            ms: "Handshake TLS Gagal",
            ko: "TLS 핸드셰이크 실패",
            ta: "TLS ஹேண்ட்ஷேக் தோல்வி"
        )
    }
    public static var issueTlsFailedAdvice: String {
        tr(
            en: "Cryptographic negotiation failed. Check date/time synchronization or re-pair.",
            zhHans: "加密协商失败。请检查设备日期和时间是否同步，或尝试重新配对连接。",
            zhHant: "加密協商失敗。請檢查裝置日期與時間是否同步，或嘗試重新配對連線。",
            ja: "暗号ネゴシエーションに失敗しました。端末の日時設定を確認するか、再接続してください。",
            ms: "Rundingan kriptografi gagal. Semak penyegerakan tarikh/masa atau pasang semula.",
            ko: "암호화 협상에 실패했습니다. 기기 날짜/시간 동기화를 확인하거나 다시 연결하세요.",
            ta: "குறியாக்க பேச்சுவார்த்தை தோல்வியடைந்தது. சாதனத்தின் தேதி/நேரத்தைச் சரிபார்க்கவும் அல்லது மீண்டும் இணைக்கவும்."
        )
    }
    public static var issueVideoSlowTitle: String {
        tr(
            en: "Wireless Link Too Slow",
            zhHans: "无线链路速度过慢",
            zhHant: "無線鏈路速度過慢",
            ja: "無線リンクの速度が低下しています",
            ms: "Pautan Wayarles Terlalu Perlahan",
            ko: "무선 연결 속도 저하",
            ta: "வயர்லெஸ் இணைப்பு மிகவும் மெதுவாக உள்ளது"
        )
    }
    public static var issueVideoSlowAdvice: String {
        tr(
            en: "Heavy packet drops on video feed. Move closer to the Wi-Fi hotspot or switch to 5GHz.",
            zhHans: "视频流出现严重丢包。请靠近手机热点或将热点频段切换为 5GHz。",
            zhHant: "視訊串流出現嚴重封包遺失。請靠近手機熱點或將熱點頻段切換為 5GHz。",
            ja: "映像フィードでパケットロスが発生しています。テザリング端末に近づくか 5GHz 帯へ切り替えてください。",
            ms: "Kehilangan paket tinggi pada suapan video. Dekatkan ke hotspot Wi-Fi atau tukar ke 5GHz.",
            ko: "비디오 스트림에서 심각한 패킷 손실이 발생했습니다. 핫스팟 가까이로 이동하거나 5GHz 대역으로 전환하세요.",
            ta: "வீடியோ ஓடையில் அதிக பாக்கெட் இழப்பு உள்ளது. Wi-Fi ஹாட்ஸ்பாட்டிற்கு அருகில் செல்லவும் அல்லது 5GHz-க்கு மாற்றவும்."
        )
    }
    public static var issueNoDeviceTitle: String {
        tr(
            en: "No Device Found on Network",
            zhHans: "局域网内未发现手机设备",
            zhHant: "區網內未發現手機裝置",
            ja: "ネットワーク上に端末が見つかりません",
            ms: "Tiada Peranti Ditemui di Rangkaian",
            ko: "네트워크에서 기기를 찾을 수 없음",
            ta: "பிணையத்தில் சாதனம் எதுவும் கிடைக்கவில்லை"
        )
    }
    public static var issueNoDeviceAdvice: String {
        tr(
            en: "Wi-Fi is connected, but no phone responded on port 5277. Make sure 'Start head unit server' is active in Android Auto Developer Settings.",
            zhHans: "Wi-Fi 已连接，但没有手机在 5277 端口响应。请确认 Android Auto 开发者设置中的「启动车机服务器」处于开启状态。",
            zhHant: "Wi-Fi 已連線，但沒有手機在 5277 連接埠回應。請確認 Android Auto 開發人員設定中的「啟動車機伺服器」處於開啟狀態。",
            ja: "Wi-Fi には接続されていますが、ポート 5277 で応答する端末がありません。Android Auto 開発者向け設定で「ヘッドユニット サーバーを起動」が有効かご確認ください。",
            ms: "Wi-Fi disambungkan, tetapi tiada telefon bertindak balas pada port 5277. Pastikan 'Mulakan pelayan unit kepala' aktif dalam Tetapan Pembangun Android Auto.",
            ko: "Wi-Fi는 연결되었지만 5277 포트에서 응답하는 휴대폰이 없습니다. Android Auto 개발자 설정에서 '헤드유닛 서버 시작'이 활성화되어 있는지 확인하세요.",
            ta: "Wi-Fi இணைக்கப்பட்டுள்ளது, ஆனால் போர்ட் 5277-இல் எந்தத் தொலைபேசியும் பதிலளிக்கவில்லை. Android Auto டெவலப்பர் அமைப்புகளில் 'Start head unit server' செயலில் உள்ளதா எனச் சரிபார்க்கவும்."
        )
    }
    public static var issueStuckAfterRetriesTitle: String {
        tr(
            en: "Connection Failed After 3 Retries (Server May Be Stuck)",
            zhHans: "连续 3 次重试失败（车机服务器可能卡死）",
            zhHant: "連續 3 次重試失敗（車機伺服器可能卡死）",
            ja: "3回の再試行後も接続失敗（サーバー停止の可能性）",
            ms: "Sambungan Gagal Selepas 3 Percubaan (Pelayan Mungkin Tersekat)",
            ko: "3회 재시도 후 연결 실패 (서버 응답 중지 가능성)",
            ta: "3 முயற்சிகளுக்குப் பிறகு இணைப்பு தோல்வி (சேவையகம் முடங்கியிருக்கலாம்)"
        )
    }
    public static var issueStuckAfterRetriesAdvice: String {
        tr(
            en: "The phone's Headunit Server appears frozen or unresponsive. Please open Android Auto (⋮ -> Stop head unit server, then Start head unit server) on your phone and try again.",
            zhHans: "手机端的车机服务器似乎已卡死或无响应。请在手机上打开 Android Auto（⋮ -> 停止车机服务器，然后点击启动车机服务器）后再试。",
            zhHant: "手機端的車機伺服器似乎已卡死或無回應。請在手機上開啟 Android Auto（⋮ -> 停止車機伺服器，然後點擊啟動車機伺服器）後再試。",
            ja: "スマートフォン側のヘッドユニット サーバーが応答停止している可能性があります。Android Auto を開き（⋮ → ヘッドユニット サーバーを停止 → ヘッドユニット サーバーを起動）を行ってから再度お試しください。",
            ms: "Pelayan Headunit telefon kelihatan tersekat atau tidak bertindak balas. Sila buka Android Auto (⋮ -> Hentikan pelayan unit kepala, kemudian Mulakan pelayan unit kepala) pada telefon dan cuba lagi.",
            ko: "휴대폰의 헤드유닛 서버가 멈춘 것 같습니다. 휴대폰에서 Android Auto를 열어 (⋮ -> 헤드유닛 서버 중지 -> 다시 시작) 후 재시도하세요.",
            ta: "தொலைபேசியின் ஹெட் யூனிட் சேவையகம் முடங்கியுள்ளதாகத் தெரிகிறது. தொலைபேசியில் Android Auto-வைத் திறந்து (⋮ -> Stop head unit server, பிறகு Start head unit server) மீண்டும் முயற்சிக்கவும்."
        )
    }

    // MARK: - Connection States & Status Details
    public static var stateDisconnected: String {
        tr(en: "Disconnected", zhHans: "未连接", zhHant: "未連線", ja: "未接続", ms: "Terputus", ko: "연결 끊김", ta: "துண்டிக்கப்பட்டது")
    }
    public static var stateDiscovering: String {
        tr(en: "Scanning...", zhHans: "正在扫描...", zhHant: "正在掃描...", ja: "スキャン中...", ms: "Mengimbas...", ko: "스캔 중...", ta: "தேடுகிறது...")
    }
    public static var stateWaitingHelper: String {
        tr(en: "Waiting for Wireless Helper / WPP...", zhHans: "正在等待无线连接助手...", zhHant: "正在等待無線連線助手...", ja: "ワイヤレス接続を待機中...", ms: "Menunggu Pembantu Wayarles...", ko: "무선 연결 도우미 대기 중...", ta: "வயர்லெஸ் உதவியாளருக்காகக் காத்திருக்கிறது...")
    }
    public static var stateConnecting: String {
        tr(en: "Connecting...", zhHans: "正在连接...", zhHant: "正在連線...", ja: "接続中...", ms: "Menyambung...", ko: "연결 중...", ta: "இணைக்கிறது...")
    }
    public static var stateHandshaking: String {
        tr(en: "Handshaking...", zhHans: "正在握手...", zhHant: "正在握手...", ja: "ハンドシェイク中...", ms: "Rundingan Handshake...", ko: "핸드셰이크 중...", ta: "ஹேண்ட்ஷேக் செய்கிறது...")
    }
    public static var stateConnected: String {
        tr(en: "Connected", zhHans: "已连接", zhHant: "已連線", ja: "接続済み", ms: "Bersambung", ko: "연결됨", ta: "இணைக்கப்பட்டது")
    }
    public static var stateDisconnecting: String {
        tr(en: "Disconnecting...", zhHans: "正在断开...", zhHant: "正在斷線...", ja: "切断中...", ms: "Memutuskan sambungan...", ko: "연결 해제 중...", ta: "துண்டிக்கிறது...")
    }
    public static func stateError(_ message: String) -> String {
        tr(en: "Error: \(message)", zhHans: "错误：\(message)", zhHant: "錯誤：\(message)", ja: "エラー：\(message)", ms: "Ralat: \(message)", ko: "오류: \(message)", ta: "பிழை: \(message)")
    }

    public static var statusReadyToConnect: String {
        tr(en: "Ready to connect", zhHans: "准备就绪，等待连接", zhHant: "準備就緒，等待連線", ja: "接続準備完了", ms: "Sedia untuk disambungkan", ko: "연결 준비 완료", ta: "இணைக்கத் தயார்")
    }
    public static var statusSearchFailedNoWifi: String {
        tr(
            en: "Search failed: No Wi-Fi / Hotspot connection",
            zhHans: "搜索失败：未连接 Wi-Fi 或手机热点",
            zhHant: "搜尋失敗：未連接 Wi-Fi 或手機熱點",
            ja: "検索失敗：Wi-Fi / テザリング接続がありません",
            ms: "Carian gagal: Tiada sambungan Wi-Fi / Hotspot",
            ko: "검색 실패: Wi-Fi / 핫스팟 연결 없음",
            ta: "தேடல் தோல்வி: Wi-Fi / ஹாட்ஸ்பாட் இணைப்பு இல்லை"
        )
    }
    public static func statusScanning(stationIp: String) -> String {
        let ipDisplay = stationIp.isEmpty ? noWifiText : stationIp
        return tr(
            en: "iPad IP: \(ipDisplay) | Scanning for phone hotspot / headunit...",
            zhHans: "iPad IP: \(ipDisplay) | 正在扫描手机热点 / 主机服务...",
            zhHant: "iPad IP: \(ipDisplay) | 正在掃描手機熱點 / 主機服務...",
            ja: "iPad IP: \(ipDisplay) | 端末・ヘッドユニットを検索中...",
            ms: "IP iPad: \(ipDisplay) | Mengimbas hotspot telefon / headunit...",
            ko: "iPad IP: \(ipDisplay) | 휴대폰 핫스팟 / 헤드유닛 검색 중...",
            ta: "iPad IP: \(ipDisplay) | தொலைபேசி ஹாட்ஸ்பாட் / ஹெட் யூனிட்டைத் தேடுகிறது..."
        )
    }
    public static func statusConnectingTo(_ deviceName: String) -> String {
        tr(
            en: "Connecting to \(deviceName)...",
            zhHans: "正在连接到 \(deviceName)...",
            zhHant: "正在連線至 \(deviceName)...",
            ja: "\(deviceName) に接続中...",
            ms: "Menyambung ke \(deviceName)...",
            ko: "\(deviceName)에 연결 중...",
            ta: "\(deviceName) உடன் இணைக்கிறது..."
        )
    }
    public static func statusFoundDeviceConnecting(_ deviceName: String) -> String {
        tr(
            en: "Found \(deviceName), connecting...",
            zhHans: "已发现 \(deviceName)，正在连接...",
            zhHant: "已發現 \(deviceName)，正在連線...",
            ja: "\(deviceName) を検出、接続中...",
            ms: "Menemui \(deviceName), menyambung...",
            ko: "\(deviceName) 발견, 연결 중...",
            ta: "\(deviceName) கண்டறியப்பட்டது, இணைக்கிறது..."
        )
    }
    public static func statusRetrying(attempt: Int, maxAttempts: Int) -> String {
        tr(
            en: "Connection failed. Retrying in 3s (\(attempt)/\(maxAttempts))...",
            zhHans: "连接失败，3 秒后重试 (\(attempt)/\(maxAttempts))...",
            zhHant: "連線失敗，3 秒後重試 (\(attempt)/\(maxAttempts))...",
            ja: "接続失敗。3秒後に再試行します (\(attempt)/\(maxAttempts))...",
            ms: "Sambungan gagal. Cuba semula dalam 3s (\(attempt)/\(maxAttempts))...",
            ko: "연결 실패. 3초 후 재시도 (\(attempt)/\(maxAttempts))...",
            ta: "இணைப்பு தோல்வி. 3 வினாடிகளில் மீண்டும் முயற்சி (\(attempt)/\(maxAttempts))..."
        )
    }
    public static func statusFailedAfterRetries(_ maxAttempts: Int) -> String {
        tr(
            en: "Failed after \(maxAttempts) retries. Phone Headunit Server may be stuck — please restart it manually.",
            zhHans: "连续 \(maxAttempts) 次重试失败。手机车机服务器可能卡死，请手动重启。",
            zhHant: "連續 \(maxAttempts) 次重試失敗。手機車機伺服器可能卡死，請手動重啟。",
            ja: "\(maxAttempts)回の再試行後も失敗しました。サーバーが停止している可能性があるため手動で再起動してください。",
            ms: "Gagal selepas \(maxAttempts) percubaan. Pelayan unit kepala telefon mungkin tersekat — sila mulakan semula secara manual.",
            ko: "\(maxAttempts)회 재시도 후 실패했습니다. 휴대폰 헤드유닛 서버가 멈췄을 수 있으니 수동으로 재시작하세요.",
            ta: "\(maxAttempts) முயற்சிகளுக்குப் பிறகு தோல்வி. தொலைபேசி ஹெட் யூனிட் சேவையகம் முடங்கியிருக்கலாம் — கைமுறையாக மீண்டும் தொடங்கவும்."
        )
    }
    public static func errorFailedAfterRetries(_ maxAttempts: Int) -> String {
        tr(
            en: "Connection failed after \(maxAttempts) retries. Headunit Server on phone may be stuck — please manually restart Headunit Server.",
            zhHans: "连续 \(maxAttempts) 次重试连接失败。手机端的 Android Auto 车机服务器可能已卡死，请手动重启后再试。",
            zhHant: "連續 \(maxAttempts) 次重試連線失敗。手機端的 Android Auto 車機伺服器可能已卡死，請手動重啟後再試。",
            ja: "\(maxAttempts)回の再試行後も接続に失敗しました。端末側のヘッドユニット サーバーが停止している可能性があります。手動で再起動してください。",
            ms: "Sambungan gagal selepas \(maxAttempts) percubaan. Pelayan unit kepala pada telefon mungkin tersekat — sila mulakan semula secara manual.",
            ko: "\(maxAttempts)회 재시도 후 연결에 실패했습니다. 휴대폰의 헤드유닛 서버가 멈췄을 수 있으니 수동으로 재시작하세요.",
            ta: "\(maxAttempts) முயற்சிகளுக்குப் பிறகு இணைப்பு தோல்வி. தொலைபேசியின் ஹெட் யூனிட் சேவையகம் முடங்கியிருக்கலாம் — கைமுறையாக மீண்டும் தொடங்கவும்."
        )
    }
    public static var statusNoDeviceFound: String {
        tr(
            en: "No device found on network (Check Headunit Server on phone)",
            zhHans: "网络中未发现设备（请检查手机车机服务器是否开启）",
            zhHant: "網路中未發現裝置（請檢查手機車機伺服器是否開啟）",
            ja: "端末が見つかりません（スマホのヘッドユニット サーバーを確認してください）",
            ms: "Tiada peranti ditemui di rangkaian (Semak Pelayan Unit Kepala pada telefon)",
            ko: "네트워크에서 기기를 찾을 수 없습니다 (휴대폰 헤드유닛 서버 확인)",
            ta: "பிணையத்தில் சாதனம் இல்லை (தொலைபேசியில் ஹெட் யூனிட் சேவையகத்தைச் சரிபார்க்கவும்)"
        )
    }
    public static func statusSearchFailed(reason: String) -> String {
        tr(
            en: "Search failed: \(reason)",
            zhHans: "搜索失败：\(reason)",
            zhHant: "搜尋失敗：\(reason)",
            ja: "検索失敗：\(reason)",
            ms: "Carian gagal: \(reason)",
            ko: "검색 실패: \(reason)",
            ta: "தேடல் தோல்வி: \(reason)"
        )
    }
    public static var statusWaitingHeadunitServer: String {
        tr(
            en: "Waiting for Android Auto Headunit Server (5277)...",
            zhHans: "正在等待 Android Auto 车机服务器 (5277)...",
            zhHant: "正在等待 Android Auto 車機伺服器 (5277)...",
            ja: "Android Auto ヘッドユニット サーバー (5277) を待機中...",
            ms: "Menunggu Pelayan Unit Kepala Android Auto (5277)...",
            ko: "Android Auto 헤드유닛 서버 (5277) 대기 중...",
            ta: "Android Auto ஹெட் யூனிட் சேவையகத்திற்காக (5277) காத்திருக்கிறது..."
        )
    }
    public static var statusHandshakingTls: String {
        tr(
            en: "Handshaking with Android Auto (TLS / Service Discovery)...",
            zhHans: "正在与 Android Auto 握手（TLS / 服务发现）...",
            zhHant: "正在與 Android Auto 握手（TLS / 服務探索）...",
            ja: "Android Auto とハンドシェイク中（TLS / サービス検出）...",
            ms: "Sedang Handshake dengan Android Auto (TLS / Penemuan Perkhidmatan)...",
            ko: "Android Auto와 핸드셰이크 중 (TLS / 서비스 검색)...",
            ta: "Android Auto உடன் ஹேண்ட்ஷேக் செய்கிறது (TLS / சேவை தேடல்)..."
        )
    }
    public static var statusRunningWireless: String {
        tr(
            en: "Android Auto is running over wireless",
            zhHans: "Android Auto 正在无线投屏运行",
            zhHant: "Android Auto 正在無線投影運行",
            ja: "Android Auto ワイヤレス投影を実行中",
            ms: "Android Auto sedang berjalan melalui wayarles",
            ko: "Android Auto 무선 프로젝션 실행 중",
            ta: "Android Auto வயர்லெஸ் முறையில் இயங்குகிறது"
        )
    }
    public static var statusDisconnectedFromSession: String {
        tr(
            en: "Android Auto disconnected",
            zhHans: "Android Auto 已断开连接",
            zhHant: "Android Auto 已中斷連線",
            ja: "Android Auto が切断されました",
            ms: "Android Auto terputus sambungan",
            ko: "Android Auto 연결이 해제되었습니다",
            ta: "Android Auto துண்டிக்கப்பட்டது"
        )
    }
    public static var statusHandshakeVersionTimeout: String {
        tr(
            en: "Handshake timeout - no response from Headunit Server",
            zhHans: "握手超时 — 车机服务器无响应",
            zhHant: "握手逾時 — 車機伺服器無回應",
            ja: "ハンドシェイクタイムアウト — ヘッドユニット サーバーから応答がありません",
            ms: "Masa handshake tamat — tiada respons daripada Pelayan Unit Kepala",
            ko: "핸드셰이크 시간 초과 — 헤드유닛 서버 응답 없음",
            ta: "ஹேண்ட்ஷேக் நேரம் முடிந்தது — ஹெட் யூனிட் சேவையகத்திடமிருந்து பதிலில்லை"
        )
    }
    public static var statusTlsHandshakeTimeout: String {
        tr(
            en: "TLS handshake timeout",
            zhHans: "TLS 安全握手超时",
            zhHant: "TLS 安全握手逾時",
            ja: "TLS ハンドシェイクがタイムアウトしました",
            ms: "Masa handshake TLS tamat",
            ko: "TLS 핸드셰이크 시간 초과",
            ta: "TLS ஹேண்ட்ஷேக் நேரம் முடிந்தது"
        )
    }
    public static var discoveryNoNetworkInterface: String {
        tr(
            en: "No valid Wi-Fi network interface found",
            zhHans: "未找到有效的 Wi-Fi 网络接口",
            zhHant: "找不到有效的 Wi-Fi 網路介面",
            ja: "有効な Wi-Fi ネットワークインターフェースが見つかりません",
            ms: "Tiada antara muka rangkaian Wi-Fi yang sah ditemui",
            ko: "유효한 Wi-Fi 네트워크 인터페이스를 찾을 수 없습니다",
            ta: "செல்லுபடியாகும் Wi-Fi பிணைய இடைமுகம் எதுவும் கிடைக்கவில்லை"
        )
    }
    public static var discoveryScanFailed: String {
        tr(
            en: "Network discovery scan failed",
            zhHans: "网络发现扫描失败",
            zhHant: "網路探索掃描失敗",
            ja: "ネットワーク検出スキャンに失敗しました",
            ms: "Imbasan penemuan rangkaian gagal",
            ko: "네트워크 검색 스캔에 실패했습니다",
            ta: "பிணையக் கண்டறிதல் ஸ்கேன் தோல்வியடைந்தது"
        )
    }

    // MARK: - Main Dashboard UI
    public static var appSubtitle: String {
        tr(
            en: "Wireless Android Auto Receiver",
            zhHans: "无线 Android Auto 车载投屏接收端",
            zhHant: "無線 Android Auto 車載投影接收端",
            ja: "ワイヤレス Android Auto レシーバー",
            ms: "Penerima Android Auto Wayarles",
            ko: "무선 Android Auto 리시버",
            ta: "வயர்லெஸ் Android Auto பெறுநர்"
        )
    }
    public static var settingsButtonTitle: String {
        tr(en: "Settings", zhHans: "设置", zhHant: "設定", ja: "設定", ms: "Tetapan", ko: "설정", ta: "அமைப்புகள்")
    }
    public static func statusIpadIpReady(_ ip: String) -> String {
        tr(
            en: "iPad IP: \(ip) • Ready",
            zhHans: "iPad IP: \(ip) • 就绪",
            zhHant: "iPad IP: \(ip) • 就緒",
            ja: "iPad IP: \(ip) • 待機中",
            ms: "IP iPad: \(ip) • Sedia",
            ko: "iPad IP: \(ip) • 대기 중",
            ta: "iPad IP: \(ip) • தயார்"
        )
    }
    public static var statusScanningPort5277: String {
        tr(
            en: "Scanning Port 5277...",
            zhHans: "正在扫描 5277 端口...",
            zhHant: "正在掃描 5277 連接埠...",
            ja: "ポート 5277 をスキャン中...",
            ms: "Mengimbas Port 5277...",
            ko: "포트 5277 스캔 중...",
            ta: "போர்ட் 5277 தேடுகிறது..."
        )
    }
    public static var statusWaitingForWireless: String {
        tr(
            en: "Waiting for wireless...",
            zhHans: "正在等待无线连接...",
            zhHant: "正在等待無線連線...",
            ja: "ワイヤレス接続を待機中...",
            ms: "Menunggu wayarles...",
            ko: "무선 연결 대기 중...",
            ta: "வயர்லெஸுக்காகக் காத்திருக்கிறது..."
        )
    }
    public static var wirelessConnectionHub: String {
        tr(
            en: "Wireless Connection Hub",
            zhHans: "无线连接中心",
            zhHant: "無線連線中心",
            ja: "ワイヤレス接続ハブ",
            ms: "Hab Sambungan Wayarles",
            ko: "무선 연결 허브",
            ta: "வயர்லெஸ் இணைப்பு மையம்"
        )
    }
    public static var directConnectLabel: String {
        tr(
            en: "Direct Connect (Phone Hotspot IP)",
            zhHans: "IP 直连（手机热点网关 IP）",
            zhHant: "IP 直連（手機熱點閘道 IP）",
            ja: "IP 直接接続（テザリング IP）",
            ms: "Sambung Terus (IP Hotspot Telefon)",
            ko: "직접 연결 (휴대폰 핫스팟 게이트웨이 IP)",
            ta: "நேரடி இணைப்பு (தொலைபேசி ஹாட்ஸ்பாட் IP)"
        )
    }
    public static var directConnectButton: String {
        tr(
            en: "Direct Connect",
            zhHans: "直连主机",
            zhHant: "直接連線",
            ja: "直接接続",
            ms: "Sambung Terus",
            ko: "직접 연결",
            ta: "நேரடி இணைப்பு"
        )
    }
    public static var orAutoDiscover: String {
        tr(
            en: "— OR AUTO-DISCOVER —",
            zhHans: "— 或局域网自动发现 —",
            zhHant: "— 或區域網路自動探索 —",
            ja: "— または自動検索 —",
            ms: "— ATAU CARI AUTOMATIK —",
            ko: "— 또는 자동 검색 —",
            ta: "— அல்லது தானியங்கித் தேடல் —"
        )
    }
    public static var scanForHeadunitServer: String {
        tr(
            en: "Scan for Headunit Server (Port 5277)",
            zhHans: "扫描车机主机服务（端口 5277）",
            zhHant: "掃描車機主機服務（連接埠 5277）",
            ja: "ヘッドユニットサーバーを検索 (5277)",
            ms: "Imbas Pelayan Headunit (Port 5277)",
            ko: "헤드유닛 서버 스캔 (포트 5277)",
            ta: "ஹெட் யூனிட் சேவையகத்தைத் தேடு (போர்ட் 5277)"
        )
    }
    public static var cancelDisconnect: String {
        tr(
            en: "Cancel / Disconnect",
            zhHans: "取消 / 断开连接",
            zhHant: "取消 / 中斷連線",
            ja: "キャンセル / 切断",
            ms: "Batal / Putuskan",
            ko: "취소 / 연결 끊기",
            ta: "ரத்து / துண்டி"
        )
    }
    public static var androidPhoneSetupGuide: String {
        tr(
            en: "Android Phone Setup Guide",
            zhHans: "安卓手机开启指南",
            zhHant: "Android 手機設定指南",
            ja: "Android スマホ接続ガイド",
            ms: "Panduan Persediaan Telefon Android",
            ko: "Android 휴대폰 설정 가이드",
            ta: "Android தொலைபேசி அமைப்பு வழிகாட்டி"
        )
    }
    public static var guideStep1Title: String {
        tr(
            en: "1. Open Android Auto Settings",
            zhHans: "1. 打开 Android Auto 设置",
            zhHant: "1. 開啟 Android Auto 設定",
            ja: "1. Android Auto 設定を開く",
            ms: "1. Buka Tetapan Android Auto",
            ko: "1. Android Auto 설정 열기",
            ta: "1. Android Auto அமைப்புகளைத் திறக்கவும்"
        )
    }
    public static var guideStep1Detail: String {
        tr(
            en: "In phone Settings → Connected devices → Android Auto",
            zhHans: "前往手机「设置 → 已连接设备 → Android Auto」",
            zhHant: "前往手機「設定 → 已連結裝置 → Android Auto」",
            ja: "端末の「設定 → 接続済みのデバイス → Android Auto」へ",
            ms: "Dalam Tetapan telefon → Peranti bersambung → Android Auto",
            ko: "휴대폰 설정 → 연결된 기기 → Android Auto로 이동",
            ta: "தொலைபேசி அமைப்புகள் → இணைக்கப்பட்ட சாதனங்கள் → Android Auto"
        )
    }
    public static var guideStep2Title: String {
        tr(
            en: "2. Enable Developer Mode",
            zhHans: "2. 开启开发者模式",
            zhHant: "2. 開啟開發人員模式",
            ja: "2. 開発者モードを有効にする",
            ms: "2. Aktifkan Mod Pembangun",
            ko: "2. 개발자 모드 활성화",
            ta: "2. டெவலப்பர் பயன்முறையை இயக்கவும்"
        )
    }
    public static var guideStep2Detail: String {
        tr(
            en: "Scroll down, tap 'Version' 10 times and confirm OK",
            zhHans: "滑到底部连续点击「版本」10 次并确认开启",
            zhHant: "滑到底部連續點擊「版本」10 次並確認開啟",
            ja: "下部までスクロールし「バージョン」を10回タップして OK",
            ms: "Tatal ke bawah, ketik 'Versi' 10 kali dan sahkan OK",
            ko: "아래로 스크롤하여 '버전'을 10번 탭하고 확인 누르기",
            ta: "கீழே நகர்த்தி 'பதிப்பு' (Version)-ஐ 10 முறை தட்டி OK என உறுதிப்படுத்தவும்"
        )
    }
    public static var guideStep3Title: String {
        tr(
            en: "3. Start Head Unit Server",
            zhHans: "3. 启动车机服务器",
            zhHant: "3. 啟動車機伺服器",
            ja: "3. ヘッドユニット サーバーを起動",
            ms: "3. Mulakan Pelayan Unit Kepala",
            ko: "3. 헤드유닛 서버 시작",
            ta: "3. ஹெட் யூனிட் சேவையகத்தைத் தொடங்கவும்"
        )
    }
    public static var guideStep3Detail: String {
        tr(
            en: "Tap top-right '⋮' menu in Android Auto & start server",
            zhHans: "点击右上角「⋮」菜单，选择「启动车机服务器」",
            zhHant: "點擊右上角「⋮」選單，選擇「啟動車機伺服器」",
            ja: "右上の「⋮」メニューから「ヘッドユニット サーバーを起動」",
            ms: "Ketik menu '⋮' di penjuru kanan atas Android Auto & pilih 'Mulakan pelayan unit kepala'",
            ko: "Android Auto 오른쪽 상단 '⋮' 메뉴에서 '헤드유닛 서버 시작' 선택",
            ta: "Android Auto மேல்-வலது '⋮' மெனுவைத் தட்டி சேவையகத்தைத் தொடங்கவும்"
        )
    }
    public static var guideStep4Title: String {
        tr(
            en: "4. Connect Hotspot & Launch",
            zhHans: "4. 连接热点并开始投屏",
            zhHant: "4. 連接熱點並開始投影",
            ja: "4. テザリング接続して起動",
            ms: "4. Sambung Hotspot & Lancar",
            ko: "4. 핫스팟 연결 및 실행",
            ta: "4. ஹாட்ஸ்பாட் இணைத்து இயக்கவும்"
        )
    }
    public static var guideStep4Detail: String {
        tr(
            en: "Connect iPad to phone hotspot Wi-Fi & tap Connect",
            zhHans: "将 iPad 连入手机 Wi-Fi 热点后，点击左侧按钮连接",
            zhHant: "將 iPad 連入手機 Wi-Fi 熱點後，點擊左側按鈕連線",
            ja: "iPad をスマホのテザリング Wi-Fi に繋ぎ、左の接続ボタンをタップ",
            ms: "Sambungkan iPad ke Wi-Fi hotspot telefon & ketik Sambung",
            ko: "iPad를 휴대폰 Wi-Fi 핫스팟에 연결한 후 연결 버튼 탭",
            ta: "iPad-ஐ தொலைபேசி Wi-Fi ஹாட்ஸ்பாட்டில் இணைத்து இணை என்பதைத் தட்டவும்"
        )
    }

    public static var currentConfigurationHeader: String {
        tr(
            en: "CURRENT CONFIGURATION (TAP TO CONFIGURE)",
            zhHans: "当前配置概览（点击卡片快速调整）",
            zhHant: "目前設定概覽（點擊卡片快速調整）",
            ja: "現在の構成（タップして設定変更）",
            ms: "KONFIGURASI SEMASA (KETIK UNTUK UBAH)",
            ko: "현재 구성 (탭하여 빠르게 설정)",
            ta: "தற்போதைய கட்டமைப்பு (அமைக்கத் தட்டவும்)"
        )
    }
    public static var tileDisplay: String {
        tr(en: "Display", zhHans: "显示规格", zhHant: "顯示規格", ja: "ディスプレイ", ms: "Paparan", ko: "디스플레이", ta: "திரை")
    }
    public static var tileLayoutDpi: String {
        tr(en: "Layout & DPI", zhHans: "布局与 DPI", zhHant: "佈局與 DPI", ja: "レイアウト & DPI", ms: "Susun Atur & DPI", ko: "레이아웃 & DPI", ta: "அமைப்பு & DPI")
    }
    public static var tileCodecs: String {
        tr(en: "Codecs", zhHans: "音视频编解码", zhHant: "影音編解碼", ja: "コーデック", ms: "Kodek", ko: "코덱", ta: "கோடெக்குகள்")
    }
    public static var tileAudioDucking: String {
        tr(en: "Audio & Ducking", zhHans: "音频与压音", zhHant: "音訊與壓音", ja: "オーディオ設定", ms: "Audio & Redaman", ko: "오디오 & 더킹", ta: "ஒலி & குறைப்பு")
    }
    public static var tileMicrophone: String {
        tr(en: "Microphone", zhHans: "麦克风来源", zhHant: "麥克風來源", ja: "マイク入力", ms: "Mikrofon", ko: "마이크", ta: "ஒலிவாங்கி")
    }
    public static var tileSmartMode: String {
        tr(en: "Smart Mode", zhHans: "智能日夜与舵向", zhHant: "智慧日夜與舵向", ja: "スマートモード", ms: "Mod Pintar", ko: "스마트 모드", ta: "ஸ்மார்ட் பயன்முறை")
    }
    public static func smoothTileValue(_ shortTitle: String) -> String {
        tr(
            en: "Smooth: \(shortTitle)",
            zhHans: "稳帧: \(shortTitle)",
            zhHant: "順暢: \(shortTitle)",
            ja: "滑らか: \(shortTitle)",
            ms: "Lancar: \(shortTitle)",
            ko: "보정: \(shortTitle)",
            ta: "சீர்மை: \(shortTitle)"
        )
    }
    public static func autoDpiTileValue(_ dpi: Int) -> String {
        tr(
            en: "Auto (\(dpi))",
            zhHans: "自动 (\(dpi))",
            zhHant: "自動 (\(dpi))",
            ja: "自動 (\(dpi))",
            ms: "Auto (\(dpi))",
            ko: "자동 (\(dpi))",
            ta: "தானியங்கி (\(dpi))"
        )
    }

    // MARK: - Quick Popups & Modals
    public static var quickDisplayTitle: String {
        tr(en: "Display Configuration", zhHans: "显示参数配置", zhHant: "顯示參數設定", ja: "ディスプレイ設定", ms: "Konfigurasi Paparan", ko: "디스플레이 구성", ta: "திரை கட்டமைப்பு")
    }
    public static var quickDisplayMessage: String {
        tr(
            en: "Choose video resolution, frame rate limit, and frame smoothing.",
            zhHans: "选择投屏视频分辨率、帧率上限与流畅模式。",
            zhHant: "選擇投影視訊解析度、畫面更新率上限與畫面平滑緩衝模式。",
            ja: "映像の解像度・最大フレームレート・スムージングを選択します。",
            ms: "Pilih resolusi video, had kadar bingkai, dan pelicinan bingkai.",
            ko: "비디오 해상도, 최대 프레임 속도 및 프레임 보정을 선택하세요.",
            ta: "வீடியோ தெளிவுத்திறன், பிரேம் வீத வரம்பு மற்றும் சீர்மையைத் தேர்ந்தெடுக்கவும்."
        )
    }
    public static func frameRateOption(_ fpsTitle: String) -> String {
        tr(
            en: "Frame Rate: \(fpsTitle)",
            zhHans: "帧率上限：\(fpsTitle)",
            zhHant: "畫面更新率上限：\(fpsTitle)",
            ja: "フレームレート：\(fpsTitle)",
            ms: "Kadar Bingkai: \(fpsTitle)",
            ko: "프레임 속도: \(fpsTitle)",
            ta: "பிரேம் வீதம்: \(fpsTitle)"
        )
    }
    public static func frameSmoothingOption(_ modeTitle: String) -> String {
        tr(
            en: "Frame Smoothing: \(modeTitle)",
            zhHans: "帧平滑缓冲：\(modeTitle)",
            zhHant: "畫面平滑緩衝：\(modeTitle)",
            ja: "フレーム補間：\(modeTitle)",
            ms: "Pelicinan Bingkai: \(modeTitle)",
            ko: "프레임 보정: \(modeTitle)",
            ta: "பிரேம் சீர்மை: \(modeTitle)"
        )
    }

    public static var quickCodecsTitle: String {
        tr(en: "Codecs Configuration", zhHans: "编解码器配置", zhHant: "編解碼器設定", ja: "コーデック設定", ms: "Konfigurasi Kodek", ko: "코덱 구성", ta: "கோடெக் கட்டமைப்பு")
    }
    public static var quickCodecsMessage: String {
        tr(
            en: "Select video decoding and audio stream codecs.",
            zhHans: "选择视频硬解格式与音频流编码格式。",
            zhHant: "選擇視訊硬解格式與音訊串流編碼格式。",
            ja: "映像デコードおよび音声ストリームのコーデックを選択します。",
            ms: "Pilih penyahkodan video dan kodek strim audio.",
            ko: "비디오 디코딩 및 오디오 스트림 코덱을 선택하세요.",
            ta: "வீடியோ டீகோடிங் மற்றும் ஒலி ஓடை கோடெக்குகளைத் தேர்ந்தெடுக்கவும்."
        )
    }
    public static var videoCodecOptionH264: String {
        tr(
            en: "Video: H.264 (AVC - Standard)",
            zhHans: "视频：H.264（AVC 标准兼容）",
            zhHant: "視訊：H.264（AVC 標準相容）",
            ja: "映像：H.264（AVC 標準）",
            ms: "Video: H.264 (AVC - Standard)",
            ko: "비디오: H.264 (AVC - 표준)",
            ta: "வீடியோ: H.264 (AVC - இயல்பு)"
        )
    }
    public static var videoCodecOptionHevc: String {
        tr(
            en: "Video: HEVC (H.265 - Efficient)",
            zhHans: "视频：HEVC（H.265 高效压缩）",
            zhHant: "視訊：HEVC（H.265 高效壓縮）",
            ja: "映像：HEVC（H.265 高効率）",
            ms: "Video: HEVC (H.265 - Cekap)",
            ko: "비디오: HEVC (H.265 - 고효율)",
            ta: "வீடியோ: HEVC (H.265 - திறன்)"
        )
    }
    public static var audioCodecOptionAac: String {
        tr(
            en: "Audio: AAC-LC (Compressed)",
            zhHans: "音频：AAC-LC（压缩流）",
            zhHant: "音訊：AAC-LC（壓縮串流）",
            ja: "音声：AAC-LC（圧縮）",
            ms: "Audio: AAC-LC (Dimampat)",
            ko: "오디오: AAC-LC (압축)",
            ta: "ஒலி: AAC-LC (சுருக்கப்பட்டது)"
        )
    }
    public static var audioCodecOptionPcm: String {
        tr(
            en: "Audio: PCM (Uncompressed)",
            zhHans: "音频：PCM（无损未压缩）",
            zhHant: "音訊：PCM（無損未壓縮）",
            ja: "音声：PCM（非圧縮）",
            ms: "Audio: PCM (Tidak Dimampat)",
            ko: "오디오: PCM (비압축)",
            ta: "ஒலி: PCM (சுருக்கப்படாதது)"
        )
    }

    public static var quickMicTitle: String {
        tr(en: "Microphone Source", zhHans: "麦克风来源", zhHant: "麥克風來源", ja: "マイク入力ソース", ms: "Sumber Mikrofon", ko: "마이크 소스", ta: "ஒலிவாங்கி உள்ளீடு")
    }
    public static var quickMicMessage: String {
        tr(
            en: "Select audio capture device for Google Voice Assistant.",
            zhHans: "选择 Google 语音助手与通话所使用的拾音设备。",
            zhHant: "選擇 Google 語音助理與通話所使用的收音裝置。",
            ja: "Google アシスタント等の音声入力に使用するマイクを選択します。",
            ms: "Pilih peranti tangkapan audio untuk Google Voice Assistant.",
            ko: "Google 어시스턴트 음성 입력에 사용할 마이크를 선택하세요.",
            ta: "Google குரல் உதவியாளருக்கான ஒலிப் பதிவுச் சாதனத்தைத் தேர்ந்தெடுக்கவும்."
        )
    }
    public static var micFollowAutoTitle: String {
        tr(
            en: "Follow Audio Output (Automatic)",
            zhHans: "跟随音频输出（自动选择）",
            zhHant: "跟隨音訊輸出（自動選擇）",
            ja: "音声出力に連動（自動）",
            ms: "Ikut Output Audio (Automatik)",
            ko: "오디오 출력 따름 (자동)",
            ta: "ஒலி வெளியீட்டைப் பின்பற்று (தானியங்கி)"
        )
    }

    public static var quickSmartModeTitle: String {
        tr(
            en: "Smart Mode & Driver Position",
            zhHans: "智能日夜模式与驾驶舵向",
            zhHant: "智慧日夜模式與駕駛舵向",
            ja: "スマートモード・運転席位置",
            ms: "Mod Pintar & Kedudukan Pemandu",
            ko: "스마트 모드 및 운전석 위치",
            ta: "ஸ்மார்ட் பயன்முறை & ஓட்டுநர் பக்கம்"
        )
    }
    public static var quickSmartModeMessage: String {
        tr(
            en: "Configure Day/Night theme and cockpit orientation.",
            zhHans: "配置日夜主题切换策略以及左舵 / 右舵车机布局。",
            zhHant: "設定日夜主題切換策略以及左駕 / 右駕車機佈局。",
            ja: "昼夜テーマ切替とハンドル位置（左/右）を設定します。",
            ms: "Konfigurasikan tema Siang/Malam dan orientasi kokpit.",
            ko: "주간/야간 테마 및 운전석 방향(좌/우)을 설정합니다.",
            ta: "பகல்/இரவு தீம் மற்றும் ஓட்டுநர் இருக்கை திசையை அமைக்கவும்."
        )
    }
    public static var driverOptionLhd: String {
        tr(
            en: "Driver: Left Hand Drive (LHD)",
            zhHans: "驾驶位：左舵驾驶 (LHD)",
            zhHant: "駕駛位：左駕 (LHD)",
            ja: "運転席：左ハンドル (LHD)",
            ms: "Pemandu: Pandu Kiri (LHD)",
            ko: "운전석: 좌핸들 (LHD)",
            ta: "ஓட்டுநர்: இடதுபுற ஸ்டியரிங் (LHD)"
        )
    }
    public static var driverOptionRhd: String {
        tr(
            en: "Driver: Right Hand Drive (RHD)",
            zhHans: "驾驶位：右舵驾驶 (RHD)",
            zhHant: "駕駛位：右駕 (RHD)",
            ja: "運転席：右ハンドル (RHD)",
            ms: "Pemandu: Pandu Kanan (RHD)",
            ko: "운전석: 우핸들 (RHD)",
            ta: "ஓட்டுநர்: வலதுபுற ஸ்டியரிங் (RHD)"
        )
    }

    public static var layoutDpiModalTitle: String {
        tr(en: "Layout & DPI Configuration", zhHans: "布局与 DPI 配置", zhHant: "佈局與 DPI 設定", ja: "レイアウト・DPI 設定", ms: "Konfigurasi Susun Atur & DPI", ko: "레이아웃 & DPI 구성", ta: "அமைப்பு & DPI கட்டமைப்பு")
    }
    public static var displayFitMode: String {
        tr(en: "Display Fit Mode", zhHans: "画面适应模式", zhHant: "畫面適應模式", ja: "画面フィットモード", ms: "Mod Muat Paparan", ko: "화면 맞춤 모드", ta: "திரை பொருத்தப் பயன்முறை")
    }
    public static var drivingPosition: String {
        tr(en: "Driving Position", zhHans: "驾驶舵向", zhHant: "駕駛舵向", ja: "運転席位置", ms: "Kedudukan Pemandu", ko: "운전석 위치", ta: "ஓட்டுநர் பக்கம்")
    }
    public static var autoRecommendedDpi: String {
        tr(en: "Auto Recommended DPI", zhHans: "自动推荐 DPI", zhHant: "自動推薦 DPI", ja: "自動推奨 DPI", ms: "DPI Disyorkan Auto", ko: "자동 권장 DPI", ta: "தானியங்கி பரிந்துரைக்கப்பட்ட DPI")
    }
    public static var autoDpiRecommended: String {
        tr(en: "Auto DPI (Recommended)", zhHans: "自动 DPI（推荐）", zhHant: "自動 DPI（推薦）", ja: "自動 DPI（推奨）", ms: "DPI Auto (Disyorkan)", ko: "자동 DPI (권장)", ta: "தானியங்கி DPI (பரிந்துரை)")
    }
    public static var splitScreenShort: String {
        tr(en: "Split Screen", zhHans: "Coolwalk 分屏", zhHant: "Coolwalk 分割畫面", ja: "分割画面", ms: "Skrin Pisah", ko: "분할 화면", ta: "பிரிவுத் திரை")
    }
    public static var singleCardShort: String {
        tr(en: "Single Card", zhHans: "单卡模式", zhHant: "單卡模式", ja: "シングルカード", ms: "Kad Tunggal", ko: "단일 카드", ta: "ஒற்றை அட்டை")
    }
    public static var coolwalkSplitShort: String {
        tr(en: "Coolwalk Split", zhHans: "Coolwalk 分屏", zhHant: "Coolwalk 分割", ja: "Coolwalk 分割", ms: "Pisah Coolwalk", ko: "Coolwalk 분할", ta: "Coolwalk பிரிவு")
    }
    public static var singleFullscreenShort: String {
        tr(en: "Single Fullscreen", zhHans: "全屏单卡", zhHant: "全螢幕單卡", ja: "シングル全画面", ms: "Skrin Penuh Tunggal", ko: "단일 전체 화면", ta: "ஒற்றை முழுத்திரை")
    }

    // MARK: - Audio & Ducking Modal / Mixer Cell
    public static var audioDuckingModalTitle: String {
        tr(en: "Audio & Ducking Configuration", zhHans: "音频输出与压音调音台", zhHant: "音訊輸出與壓音混音台", ja: "オーディオ・ダッキング設定", ms: "Konfigurasi Audio & Redaman", ko: "오디오 및 더킹 구성", ta: "ஒலி & குறைப்பு கட்டமைப்பு")
    }
    public static var audioOutputDestination: String {
        tr(en: "Audio Output Destination", zhHans: "音频输出设备", zhHant: "音訊輸出裝置", ja: "音声出力先", ms: "Destinasi Output Audio", ko: "오디오 출력 대상", ta: "ஒலி வெளியீட்டு இலக்கு")
    }
    public static var independentChannelVolumes: String {
        tr(en: "Independent Channel Volumes & Toggles", zhHans: "独立声道音量与开关", zhHant: "獨立聲道音量與開關", ja: "チャンネル別音量とミュート", ms: "Kelantangan & Togol Saluran Bebas", ko: "채널별 볼륨 및 음소거", ta: "தனிப்பட்ட சேனல் ஒலியளவு & நிலைமாற்றி")
    }
    public static var mediaAudio: String {
        tr(en: "Media Audio", zhHans: "媒体音乐", zhHant: "媒體音樂", ja: "メディア音楽", ms: "Audio Media", ko: "미디어 오디오", ta: "ஊடக ஒலி")
    }
    public static var navigationGuidance: String {
        tr(en: "Navigation / Guidance", zhHans: "导航播报", zhHant: "導航播報", ja: "ナビ音声案内", ms: "Navigasi / Panduan", ko: "내비게이션 안내", ta: "வழிகாட்டுதல் ஒலி")
    }
    public static var phoneSystemAlerts: String {
        tr(en: "Phone & System Alerts", zhHans: "通话与系统提示音", zhHant: "通話與系統提示音", ja: "通話・システム通知", ms: "Telefon & Amaran Sistem", ko: "통화 및 시스템 알림", ta: "அழைப்பு & கணினி எச்சரிக்கைகள்")
    }
    public static var navigationDuckingDrop: String {
        tr(en: "Navigation Ducking Drop", zhHans: "导航播报压音幅度", zhHant: "導航播報壓音幅度", ja: "ナビ案内時のダッキング量", ms: "Tahap Redaman Audio Navigasi", ko: "내비 안내 시 음량 감소", ta: "வழிகாட்டுதல் ஒலி குறைப்பு")
    }
    public static var navigationDuckingSubtitle: String {
        tr(
            en: "Reduces media music volume during navigation speech guidance.",
            zhHans: "导航语音播报期间，自动按比例压低媒体音乐音量。",
            zhHant: "導航語音播報期間，自動按比例壓低媒體音樂音量。",
            ja: "ナビ音声案内中、メディア音楽の音量を自動的に下げます。",
            ms: "Mengurangkan kelantangan muzik media semasa panduan suara navigasi.",
            ko: "내비게이션 음성 안내 중 미디어 음악 볼륨을 자동으로 줄입니다.",
            ta: "வழிகாட்டுதல் குரலின் போது ஊடக இசை ஒலியைத் தானாகக் குறைக்கும்."
        )
    }
    public static var testNavDucking: String {
        tr(en: "Test Nav Ducking", zhHans: "试听导航压音", zhHant: "試聽導航壓音", ja: "ダッキングテスト", ms: "Uji Redaman Navigasi", ko: "더킹 테스트", ta: "ஒலி குறைப்பு சோதனை")
    }
    public static var resetAudio: String {
        tr(en: "Reset Audio", zhHans: "重置音频", zhHant: "重設音訊", ja: "音量リセット", ms: "Tetap Semula Audio", ko: "오디오 재설정", ta: "ஒலி மீட்டமை")
    }
    public static var duckingDisabledPhoneAudio: String {
        tr(
            en: "Disabled (Audio plays on Phone / Car BT)",
            zhHans: "已禁用（音频由手机 / 车载蓝牙输出）",
            zhHant: "已停用（音訊由手機 / 車載藍牙輸出）",
            ja: "無効（スマホ / 車載BTから出力中）",
            ms: "Dinyahdayakan (Audio dimainkan di Telefon / BT Kereta)",
            ko: "비활성화됨 (휴대폰 / 차량 BT에서 재생 중)",
            ta: "முடக்கம் (தொலைபேசி / கார் BT)"
        )
    }
    public static func duckingStatusRetained(pct: Int, retained: Int) -> String {
        tr(
            en: "-\(pct)% (Media at \(retained)%)",
            zhHans: "-\(pct)%（媒体保留 \(retained)%）",
            zhHant: "-\(pct)%（媒體保留 \(retained)%）",
            ja: "-\(pct)%（音楽 \(retained)%）",
            ms: "-\(pct)% (Media pada \(retained)%)",
            ko: "-\(pct)% (미디어 \(retained)% 유지)",
            ta: "-\(pct)% (ஊடகம் \(retained)%)"
        )
    }

    // MARK: - SettingsViewController Sections, Rows & Footers
    public static var projectionSettingsTitle: String {
        tr(en: "Projection Settings", zhHans: "投屏设置", zhHant: "投影設定", ja: "投影設定", ms: "Tetapan Unjuran", ko: "프로젝션 설정", ta: "திரை இணைப்பு அமைப்புகள்")
    }
    public static var sectionActiveSession: String {
        tr(en: "Active Session", zhHans: "当前会话", zhHant: "目前工作階段", ja: "接続中のセッション", ms: "Sesi Aktif", ko: "활성 세션", ta: "செயலில் உள்ள அமர்வு")
    }
    public static var sectionDisplayLayout: String {
        tr(en: "Display & Coolwalk Layout", zhHans: "显示与 Coolwalk 布局", zhHant: "顯示與 Coolwalk 佈局", ja: "ディスプレイ・Coolwalk レイアウト", ms: "Paparan & Susun Atur Coolwalk", ko: "디스플레이 & Coolwalk 레이아웃", ta: "திரை & Coolwalk அமைப்பு")
    }
    public static var sectionVideoAudio: String {
        tr(en: "Video & Audio Pipeline", zhHans: "音视频通道管线", zhHant: "影音通道管線", ja: "映像・音声パイプライン", ms: "Saluran Video & Audio", ko: "비디오 & 오디오 파이프라인", ta: "வீடியோ & ஒலிப் பாதை")
    }
    public static var sectionSmartSensors: String {
        tr(en: "Smart Sensors, Night Mode & Language", zhHans: "智能传感、日夜与语言", zhHant: "智慧感測、日夜與語言", ja: "スマートセンサー・夜間・言語", ms: "Sensor Pintar, Mod Malam & Bahasa", ko: "스마트 센서, 야간 모드 & 언어", ta: "ஸ்மார்ட் சென்சார்கள், இரவு & மொழி")
    }
    public static var sectionConnectionAutomation: String {
        tr(en: "Connection & Automation", zhHans: "连接与自动化", zhHant: "連線與自動化", ja: "接続・自動化", ms: "Sambungan & Automasi", ko: "연결 & 자동화", ta: "இணைப்பு & தானியக்கம்")
    }
    public static var sectionDiagnosticsBackup: String {
        tr(en: "Diagnostics, Logs & Backup", zhHans: "诊断、日志与备份", zhHant: "診斷、日誌與備份", ja: "診断・ログ・バックアップ", ms: "Diagnostik, Log & Sandaran", ko: "진단, 로그 & 백업", ta: "கண்டறிதல், பதிவுகள் & காப்பு")
    }

    public static var footerDisplayLayoutLocked: String {
        tr(
            en: "Handshake parameters (DPI, Resolution, FPS, Driving Position) are locked during active session. Disconnect to modify. Fit mode and smoothing remain adjustable.",
            zhHans: "握手参数（DPI、分辨率、帧率、驾驶舵向）在投屏会话期间已锁定，请断开后修改。画面适应模式与帧平滑可实时调节。",
            zhHant: "握手參數（DPI、解析度、畫面更新率、駕駛舵向）在投影工作階段期間已鎖定，請中斷連線後修改。畫面適應模式與平滑緩衝可即時調整。",
            ja: "ハンドシェイク設定（DPI・解像度・FPS・運転席位置）はセッション中ロックされます。変更するには切断してください。フィットモードとフレーム補間は調整可能です。",
            ms: "Parameter handshake (DPI, Resolusi, FPS, Kedudukan Pemandu) dikunci semasa sesi aktif. Putuskan sambungan untuk mengubah. Mod muat dan pelicinan kekal boleh laras.",
            ko: "핸드셰이크 매개변수(DPI, 해상도, FPS, 운전석 위치)는 세션 중 잠깁니다. 수정하려면 연결을 끊으세요. 화면 맞춤 모드와 프레임 보정은 실시간 조절 가능합니다.",
            ta: "ஹேண்ட்ஷேக் அளவுருக்கள் (DPI, தெளிவுத்திறன், FPS, ஓட்டுநர் பக்கம்) அமர்வின் போது பூட்டப்படும். மாற்ற இணைப்பைத் துண்டிக்கவும். பொருத்தப் பயன்முறை மற்றும் சீர்மையைத் தொடர்ந்து மாற்றலாம்."
        )
    }
    public static var footerDisplayLayoutUnlocked: String {
        tr(
            en: "Adjust DPI to scale Android Auto UI elements. Virtual width ≥ 800 dp enables Coolwalk split-screen cards. Touch, resolution and margins adapt dynamically.",
            zhHans: "调节 DPI 可缩放 Android Auto 界面元素大小。虚拟宽度 ≥ 800 dp 将启用 Coolwalk 分屏卡片。触控、分辨率与边距均动态自适应。",
            zhHant: "調整 DPI 可縮放 Android Auto 介面元素大小。虛擬寬度 ≥ 800 dp 將啟用 Coolwalk 分割畫面卡片。觸控、解析度與邊距皆動態自適應。",
            ja: "DPI を調整して Android Auto UI の表示倍率を変更します。仮想幅 800 dp 以上で Coolwalk 分割画面が有効になります。タッチと余白は動的に適応します。",
            ms: "Laraskan DPI untuk menskalakan elemen UI Android Auto. Lebar maya ≥ 800 dp mengaktifkan kad skrin pisah Coolwalk. Sentuhan, resolusi dan margin menyesuaikan secara dinamik.",
            ko: "DPI를 조절하여 Android Auto UI 크기를 조정합니다. 가상 너비 ≥ 800 dp일 때 Coolwalk 분할 화면이 활성화됩니다. 터치, 해상도 및 여백은 동적으로 적응합니다.",
            ta: "Android Auto UI கூறுகளை அளவிட DPI-ஐ மாற்றவும். மெய்நிகர் அகலம் ≥ 800 dp ஆனால் Coolwalk பிரிவுத் திரை இயங்கும். தொடுதல், தெளிவுத்திறன் மற்றும் விளிம்புகள் தானாகப் பொருந்தும்."
        )
    }
    public static var footerVideoAudioLocked: String {
        tr(
            en: "Video/Audio codecs, output routing and mic source are locked during active session. Disconnect to modify. Live audio channel mixer remains adjustable.",
            zhHans: "音视频编解码、音频输出目标与麦克风来源在投屏会话期间已锁定，请断开后修改。实时多声道混音台仍可自由调节。",
            zhHant: "影音編解碼、音訊輸出目標與麥克風來源在投影工作階段期間已鎖定，請中斷連線後修改。即時多聲道混音台仍可自由調整。",
            ja: "映像/音声コーデック・出力先・マイク設定はセッション中ロックされます。変更するには切断してください。チャンネルミキサーはリアルタイムで調整できます。",
            ms: "Kodek Video/Audio, penghalaan output dan sumber mikrofon dikunci semasa sesi aktif. Putuskan sambungan untuk mengubah. Pengadun saluran audio langsung kekal boleh laras.",
            ko: "비디오/오디오 코덱, 출력 대상 및 마이크 소스는 세션 중 잠깁니다. 수정하려면 연결을 끊으세요. 실시간 채널 믹서는 조절 가능합니다.",
            ta: "வீடியோ/ஒலி கோடெக்குகள், வெளியீடு மற்றும் ஒலிவாங்கி மூலம் அமர்வின் போது பூட்டப்படும். மாற்ற துண்டிக்கவும். நேரலை ஒலி கலப்பியைத் தொடர்ந்து மாற்றலாம்."
        )
    }
    public static var footerVideoAudioUnlocked: String {
        tr(
            en: "Hardware decoding and microphone routing preferences. Vehicle identity remains permanent Car (CAR 1) for seamless multi-device coexistence.",
            zhHans: "选择硬件解码与麦克风收音策略。车载身份始终保持标准汽车 (CAR 1)，避免多设备配置冲突。",
            zhHant: "設定硬體解碼器與麥克風路由策略。車載裝置身分恆定為標準汽車 (CAR 1)，確保多裝置無縫共存。",
            ja: "ハードウェアデコードとマイク入力ルートを設定します。車両プロファイルはマルチデバイス互換のため常に Car (CAR 1) を維持します。",
            ms: "Keutamaan penyahkodan perkakasan dan penghalaan mikrofon. Identiti kenderaan kekal sebagai Car (CAR 1) untuk keserasian berbilang peranti.",
            ko: "하드웨어 디코딩 및 마이크 라우팅 기본 설정입니다. 다중 기기 호환을 위해 차량 프로필은 항상 Car (CAR 1)로 유지됩니다.",
            ta: "வன்பொருள் டீகோடிங் மற்றும் ஒலிவாங்கி வழித்தட விருப்பங்கள். பல சாதன இணக்கத்திற்காக வாகன அடையாளம் எப்போதும் Car (CAR 1) ஆக இருக்கும்."
        )
    }
    public static var footerConnectionAutomation: String {
        tr(
            en: "Auto Reconnect retries failed or interrupted wireless connections silently.",
            zhHans: "开启自动重连后，无线连接失败或意外中断时将在后台静默重试。",
            zhHant: "開啟自動重連後，無線連線失敗或意外中斷時將在背景靜默重試。",
            ja: "自動再接続を有効にすると、接続失敗や切断時にバックグラウンドで再接続を試みます。",
            ms: "Sambung Semula Auto mencuba semula sambungan wayarles yang gagal atau terganggu secara senyap.",
            ko: "자동 재연결을 켜면 무선 연결 실패 또는 끊김 시 백그라운드에서 조용히 다시 연결을 시도합니다.",
            ta: "தானியங்கி மறுஇணைப்பு தோல்வியடைந்த அல்லது துண்டிக்கப்பட்ட வயர்லெஸ் இணைப்புகளைப் பின்னணியில் அமைதியாக மீண்டும் முயற்சிக்கும்."
        )
    }
    public static var footerDiagnosticsBackup: String {
        tr(
            en: "CarAutoPad • Wireless Android Auto Receiver",
            zhHans: "CarAutoPad • 无线 Android Auto 车载投屏接收端",
            zhHant: "CarAutoPad • 無線 Android Auto 車載投影接收端",
            ja: "CarAutoPad • ワイヤレス Android Auto レシーバー",
            ms: "CarAutoPad • Penerima Android Auto Wayarles",
            ko: "CarAutoPad • 무선 Android Auto 리시버",
            ta: "CarAutoPad • வயர்லெஸ் Android Auto பெறுநர்"
        )
    }

    public static var connectedDeviceRow: String {
        tr(en: "Connected Device", zhHans: "已连接设备", zhHant: "已連線裝置", ja: "接続中の端末", ms: "Peranti Bersambung", ko: "연결된 기기", ta: "இணைக்கப்பட்ட சாதனம்")
    }
    public static var disconnectAndroidAutoRow: String {
        tr(en: "Disconnect Android Auto", zhHans: "断开 Android Auto 连接", zhHant: "中斷 Android Auto 連線", ja: "Android Auto を切断", ms: "Putuskan Android Auto", ko: "Android Auto 연결 끊기", ta: "Android Auto துண்டி")
    }
    public static var resolutionTitle: String {
        tr(en: "Resolution", zhHans: "投屏分辨率", zhHant: "投影解析度", ja: "解像度", ms: "Resolusi", ko: "해상도", ta: "தெளிவுத்திறன்")
    }
    public static var resolutionPickerMessage: String {
        tr(
            en: "Choose target projection video resolution",
            zhHans: "选择投屏视频的目标分辨率档位",
            zhHant: "選擇投影視訊的目標解析度檔位",
            ja: "投影する解像度プリセットを選択します",
            ms: "Pilih tahap resolusi unjuran sasaran",
            ko: "대상 프로젝션 해상도 프리셋을 선택하세요",
            ta: "இலக்குத் திரை இணைப்புத் தெளிவுத்திறனைத் தேர்ந்தெடுக்கவும்"
        )
    }
    public static var frameRateRow: String {
        tr(en: "Frame Rate", zhHans: "帧率上限", zhHant: "畫面更新率上限", ja: "フレームレート", ms: "Kadar Bingkai", ko: "프레임 속도", ta: "பிரேம் வீதம்")
    }
    public static var screenOrientationRow: String {
        tr(en: "Screen Orientation", zhHans: "屏幕方向", zhHant: "螢幕方向", ja: "画面の向き", ms: "Orientasi Skrin", ko: "화면 방향", ta: "திரை திசை")
    }
    public static var frameSmoothingRow: String {
        tr(en: "Frame Smoothing", zhHans: "帧平滑缓冲", zhHant: "畫面平滑緩衝", ja: "フレーム補間", ms: "Pelicinan Bingkai", ko: "프레임 보정", ta: "பிரேம் சீர்மை")
    }
    public static var edgeSwipeProtectionRow: String {
        tr(
            en: "Edge Swipe Protection (Double-Swipe)",
            zhHans: "边缘防误触保护（二次滑动触发）",
            zhHant: "邊緣防誤觸保護（二次滑動觸發）",
            ja: "画面端スワイプ誤操作防止",
            ms: "Perlindungan Leretan Tepi (Leret Dua Kali)",
            ko: "가장자리 스와이프 오작동 방지",
            ta: "ஓரத் தடவல் பாதுகாப்பு (இருமுறை)"
        )
    }
    public static var videoCodecRow: String {
        tr(en: "Video Codec", zhHans: "视频解码器", zhHant: "視訊解碼器", ja: "映像コーデック", ms: "Kodek Video", ko: "비디오 코덱", ta: "வீடியோ கோடெக்")
    }
    public static var audioCodecRow: String {
        tr(en: "Audio Codec", zhHans: "音频编码格式", zhHant: "音訊編碼格式", ja: "音声コーデック", ms: "Kodek Audio", ko: "오디오 코덱", ta: "ஒலி கோடெக்")
    }
    public static var audioOutputRow: String {
        tr(en: "Audio Output", zhHans: "音频输出目标", zhHant: "音訊輸出目標", ja: "音声出力先", ms: "Output Audio", ko: "오디오 출력", ta: "ஒலி வெளியீடு")
    }
    public static var microphoneSourceRow: String {
        tr(en: "Microphone Source", zhHans: "麦克风来源", zhHant: "麥克風來源", ja: "マイク入力", ms: "Sumber Mikrofon", ko: "마이크 소스", ta: "ஒலிவாங்கி உள்ளீடு")
    }
    public static var nightModeRow: String {
        tr(en: "Night Mode", zhHans: "日夜模式", zhHant: "日夜模式", ja: "夜間モード", ms: "Mod Malam", ko: "야간 모드", ta: "இரவுப் பயன்முறை")
    }
    public static var gpsSourceRow: String {
        tr(en: "GPS Source", zhHans: "GPS 定位来源", zhHant: "GPS 定位來源", ja: "GPS ソース", ms: "Sumber GPS", ko: "GPS 소스", ta: "GPS மூலாதாரம்")
    }
    public static var gpsPhoneOnlyWifiIpad: String {
        tr(
            en: "Phone Only (Wi-Fi iPad)",
            zhHans: "仅使用手机（Wi-Fi 版 iPad）",
            zhHant: "僅使用手機（Wi-Fi 版 iPad）",
            ja: "スマホのみ（Wi-Fi 版 iPad）",
            ms: "Telefon Sahaja (iPad Wi-Fi)",
            ko: "휴대폰 전용 (Wi-Fi 전용 iPad)",
            ta: "தொலைபேசி மட்டும் (Wi-Fi iPad)"
        )
    }
    public static var autoReconnectRow: String {
        tr(en: "Auto Reconnect", zhHans: "断线自动重连", zhHant: "斷線自動重連", ja: "自動再接続", ms: "Sambung Semula Auto", ko: "자동 재연결", ta: "தானியங்கி மறுஇணைப்பு")
    }
    public static var autoResumePlaybackRow: String {
        tr(en: "Auto Resume Playback", zhHans: "重连自动续播音乐", zhHant: "重連自動續播音樂", ja: "再接続時に自動再生", ms: "Sambung Main Semula Auto", ko: "재연결 시 자동 재생", ta: "மறுஇணைப்பில் தானாகத் தொடர்")
    }
    public static var debugModeRow: String {
        tr(
            en: "Debug Mode (HUD & Floating Bubble)",
            zhHans: "调试模式（性能浮窗与悬浮球）",
            zhHant: "除錯模式（效能浮窗與浮動按鈕）",
            ja: "デバッグモード（HUD・フローティングボタン）",
            ms: "Mod Nyahpepijat (HUD & Butang Terapung)",
            ko: "디버그 모드 (HUD & 플로팅 버튼)",
            ta: "பிழைத்திருத்தம் (HUD & மிதக்கும் குமிழ்)"
        )
    }
    public static var debugLogCategoriesRow: String {
        tr(
            en: "Debug Log Categories...",
            zhHans: "诊断日志分类开关...",
            zhHant: "診斷日誌分類開關...",
            ja: "デバッグログカテゴリ...",
            ms: "Kategori Log Nyahpepijat...",
            ko: "디버그 로그 카테고리...",
            ta: "பிழைத்திருத்தப் பதிவு வகைகள்..."
        )
    }
    public static func debugCategoriesEnabledCount(enabled: Int, total: Int) -> String {
        tr(
            en: "\(enabled) of \(total) enabled",
            zhHans: "已开启 \(enabled) / \(total) 项",
            zhHant: "已開啟 \(enabled) / \(total) 項",
            ja: "\(total) 個中 \(enabled) 個有効",
            ms: "\(enabled) daripada \(total) diaktifkan",
            ko: "\(total)개 중 \(enabled)개 활성화됨",
            ta: "\(total)-இல் \(enabled) இயக்கப்பட்டது"
        )
    }
    public static var liveDiagnosticsReportRow: String {
        tr(
            en: "Live Diagnostics Report",
            zhHans: "实时诊断报告",
            zhHant: "即時診斷報告",
            ja: "ライブ診断レポート",
            ms: "Laporan Diagnostik Langsung",
            ko: "실시간 진단 리포트",
            ta: "நேரலை கண்டறிதல் அறிக்கை"
        )
    }
    public static var exportShareSessionLogsRow: String {
        tr(
            en: "Export / Share Session Logs",
            zhHans: "导出 / 分享会话日志",
            zhHant: "匯出 / 分享工作階段日誌",
            ja: "セッションログを書き出し / 共有",
            ms: "Eksport / Kongsi Log Sesi",
            ko: "세션 로그 내보내기 / 공유",
            ta: "அமர்வு பதிவுகளை ஏற்றுமதி / பகிர்"
        )
    }
    public static var clearAllDiagnosticLogsRow: String {
        tr(
            en: "Clear All Diagnostic Logs",
            zhHans: "清空全部诊断日志",
            zhHant: "清除全部診斷日誌",
            ja: "診断ログをすべて消去",
            ms: "Kosongkan Semua Log Diagnostik",
            ko: "모든 진단 로그 지우기",
            ta: "அனைத்து கண்டறிதல் பதிவுகளையும் அழி"
        )
    }
    public static var backupRestoreSettingsRow: String {
        tr(
            en: "Backup / Restore Settings (JSON)",
            zhHans: "备份 / 恢复配置 (JSON)",
            zhHant: "備份 / 還原設定 (JSON)",
            ja: "設定のバックアップ / 復元 (JSON)",
            ms: "Sandar / Pulih Tetapan (JSON)",
            ko: "설정 백업 / 복원 (JSON)",
            ta: "அமைப்புகள் காப்பு / மீட்டமை (JSON)"
        )
    }
    public static var resetAllSettingsRow: String {
        tr(
            en: "Reset All Settings to Defaults",
            zhHans: "恢复全部默认设置",
            zhHant: "重設所有設定",
            ja: "すべての設定を初期値に戻す",
            ms: "Tetapkan Semula Semua Tetapan",
            ko: "모든 설정 기본값으로 초기화",
            ta: "அனைத்து அமைப்புகளையும் இயல்புக்கு மீட்டமை"
        )
    }

    // MARK: - Settings Alerts & Details
    public static var connectionDetailsTitle: String {
        tr(en: "Connection Details", zhHans: "连接详情", zhHant: "連線詳情", ja: "接続詳細", ms: "Butiran Sambungan", ko: "연결 세부 정보", ta: "இணைப்பு விவரங்கள்")
    }
    public static var detailState: String {
        tr(en: "State", zhHans: "状态", zhHant: "狀態", ja: "状態", ms: "Keadaan", ko: "상태", ta: "நிலை")
    }
    public static var detailStatus: String {
        tr(en: "Status", zhHans: "详情", zhHant: "詳情", ja: "ステータス", ms: "Status", ko: "세부 상태", ta: "தற்போதைய நிலை")
    }
    public static var detailDevice: String {
        tr(en: "Device", zhHans: "设备", zhHant: "裝置", ja: "端末", ms: "Peranti", ko: "기기", ta: "சாதனம்")
    }
    public static var detailIp: String {
        tr(en: "IP", zhHans: "IP 地址", zhHant: "IP 位址", ja: "IP", ms: "IP", ko: "IP", ta: "IP")
    }
    public static var detailPort: String {
        tr(en: "Port", zhHans: "端口", zhHant: "連接埠", ja: "ポート", ms: "Port", ko: "포트", ta: "போர்ட்")
    }

    public static var liveDiagnosticsTitle: String {
        tr(en: "Live Diagnostics", zhHans: "实时诊断", zhHant: "即時診斷", ja: "ライブ診断", ms: "Diagnostik Langsung", ko: "실시간 진단", ta: "நேரலை கண்டறிதல்")
    }
    public static var copyToClipboard: String {
        tr(en: "Copy to Clipboard", zhHans: "复制到剪贴板", zhHant: "複製到剪貼簿", ja: "クリップボードにコピー", ms: "Salin ke Papan Keratan", ko: "클립보드에 복사", ta: "கிளிப்போர்டுக்கு நகலெடு")
    }

    public static var exportShareLogsTitle: String {
        tr(en: "Export / Share Logs", zhHans: "导出 / 分享日志", zhHant: "匯出 / 分享日誌", ja: "ログの書き出し / 共有", ms: "Eksport / Kongsi Log", ko: "로그 내보내기 / 공유", ta: "பதிவுகளை ஏற்றுமதி / பகிர்")
    }
    public static var exportShareLogsMessage: String {
        tr(
            en: "Session diagnostic logs & audit reports.",
            zhHans: "会话诊断日志与链路审计报告。",
            zhHant: "工作階段診斷日誌與鏈路稽核報告。",
            ja: "セッション診断ログおよび監査レポートです。",
            ms: "Log diagnostik sesi & laporan audit.",
            ko: "세션 진단 로그 및 감사 리포트입니다.",
            ta: "அமர்வு கண்டறிதல் பதிவுகள் & தணிக்கை அறிக்கைகள்."
        )
    }
    public static var copyLogToClipboard: String {
        tr(en: "Copy Log to Clipboard", zhHans: "复制日志到剪贴板", zhHant: "複製日誌到剪貼簿", ja: "ログをコピー", ms: "Salin Log ke Papan Keratan", ko: "클립보드에 로그 복사", ta: "பதிவை கிளிப்போர்டுக்கு நகலெடு")
    }
    public static var shareLogFileTxt: String {
        tr(en: "Share Log File (.txt)", zhHans: "分享日志文件 (.txt)", zhHant: "分享日誌檔案 (.txt)", ja: "ログファイルを共有 (.txt)", ms: "Kongsi Fail Log (.txt)", ko: "로그 파일 공유 (.txt)", ta: "பதிவுக் கோப்பைப் பகிர் (.txt)")
    }
    public static var clearInMemoryLogs: String {
        tr(en: "Clear In-Memory Logs", zhHans: "清除内存日志", zhHant: "清除記憶體日誌", ja: "メモリ内ログを消去", ms: "Kosongkan Log Dalam Memori", ko: "메모리 로그 지우기", ta: "நினைவகப் பதிவுகளை அழி")
    }

    public static var backupRestoreTitle: String {
        tr(en: "Backup / Restore Settings", zhHans: "备份 / 恢复设置", zhHant: "備份 / 還原設定", ja: "設定のバックアップ / 復元", ms: "Sandar / Pulih Tetapan", ko: "설정 백업 / 복원", ta: "அமைப்புகள் காப்பு / மீட்டமை")
    }
    public static var backupRestoreMessage: String {
        tr(
            en: "Export settings to JSON or restore from clipboard.",
            zhHans: "将当前配置导出为 JSON，或从剪贴板恢复配置。",
            zhHant: "將目前設定匯出為 JSON，或從剪貼簿還原設定。",
            ja: "設定を JSON として書き出すか、クリップボードから復元します。",
            ms: "Eksport tetapan ke JSON atau pulihkan daripada papan keratan.",
            ko: "설정을 JSON으로 내보내거나 클립보드에서 복원합니다.",
            ta: "அமைப்புகளை JSON ஆக ஏற்றுமதி செய்யவும் அல்லது கிளிப்போர்டிலிருந்து மீட்டமைக்கவும்."
        )
    }
    public static var copySettingsJsonToClipboard: String {
        tr(
            en: "Copy Settings JSON to Clipboard",
            zhHans: "复制配置 JSON 到剪贴板",
            zhHant: "複製設定 JSON 到剪貼簿",
            ja: "設定 JSON をコピー",
            ms: "Salin JSON Tetapan ke Papan Keratan",
            ko: "설정 JSON을 클립보드에 복사",
            ta: "அமைப்புகள் JSON-ஐ நகலெடு"
        )
    }
    public static var restoreSettingsFromClipboard: String {
        tr(
            en: "Restore Settings from Clipboard",
            zhHans: "从剪贴板恢复设置",
            zhHant: "從剪貼簿還原設定",
            ja: "クリップボードから復元",
            ms: "Pulih Tetapan daripada Papan Keratan",
            ko: "클립보드에서 설정 복원",
            ta: "கிளிப்போர்டிலிருந்து மீட்டமை"
        )
    }
    public static var settingsExportedTitle: String {
        tr(en: "Settings Exported", zhHans: "配置已导出", zhHant: "設定已匯出", ja: "設定を書き出しました", ms: "Tetapan Dieksport", ko: "설정 내보내기 완료", ta: "அமைப்புகள் ஏற்றுமதி ஆயின")
    }
    public static var settingsExportedMessage: String {
        tr(
            en: "JSON settings copied to clipboard.",
            zhHans: "JSON 配置内容已复制到剪贴板。",
            zhHant: "JSON 設定內容已複製到剪貼簿。",
            ja: "設定の JSON をクリップボードにコピーしました。",
            ms: "Tetapan JSON disalin ke papan keratan.",
            ko: "JSON 설정이 클립보드에 복사되었습니다.",
            ta: "JSON அமைப்புகள் கிளிப்போர்டுக்கு நகலெடுக்கப்பட்டன."
        )
    }
    public static var restoreFailedTitle: String {
        tr(en: "Restore Failed", zhHans: "恢复失败", zhHant: "還原失敗", ja: "復元に失敗しました", ms: "Pemulihan Gagal", ko: "복원 실패", ta: "மீட்டமைப்பு தோல்வி")
    }
    public static var restoreFailedNoJson: String {
        tr(
            en: "Clipboard does not contain JSON text.",
            zhHans: "剪贴板中未包含有效的 JSON 文本。",
            zhHant: "剪貼簿中未包含有效的 JSON 文字。",
            ja: "クリップボードに JSON テキストがありません。",
            ms: "Papan keratan tidak mengandungi teks JSON.",
            ko: "클립보드에 유효한 JSON 텍스트가 없습니다.",
            ta: "கிளிப்போர்டில் JSON உரை இல்லை."
        )
    }
    public static var settingsRestoredTitle: String {
        tr(en: "Settings Restored", zhHans: "配置已恢复", zhHant: "設定已還原", ja: "設定を復元しました", ms: "Tetapan Dipulihkan", ko: "설정 복원 완료", ta: "அமைப்புகள் மீட்டமைக்கப்பட்டன")
    }
    public static var settingsRestoredMessage: String {
        tr(
            en: "Preferences have been restored from clipboard.",
            zhHans: "已成功从剪贴板恢复全部配置偏好。",
            zhHant: "已成功從剪貼簿還原全部設定偏好。",
            ja: "クリップボードから設定を復元しました。",
            ms: "Keutamaan telah dipulihkan daripada papan keratan.",
            ko: "클립보드에서 환경설정을 복원했습니다.",
            ta: "கிளிப்போர்டிலிருந்து விருப்பத்தேர்வுகள் மீட்டமைக்கப்பட்டன."
        )
    }
    public static var restoreErrorTitle: String {
        tr(en: "Restore Error", zhHans: "恢复错误", zhHant: "還原錯誤", ja: "復元エラー", ms: "Ralat Pemulihan", ko: "복원 오류", ta: "மீட்டமைப்புப் பிழை")
    }

    public static var resetAllSettingsTitle: String {
        tr(en: "Reset All Settings", zhHans: "恢复全部默认设置", zhHant: "重設所有設定", ja: "すべての設定をリセット", ms: "Tetapkan Semula Semua Tetapan", ko: "모든 설정 재설정", ta: "அனைத்து அமைப்புகளையும் மீட்டமை")
    }
    public static var resetAllSettingsMessage: String {
        tr(
            en: "Are you sure you want to reset all projection preferences to factory defaults? This action cannot be undone.",
            zhHans: "确定要将所有投屏偏好设置重置为出厂默认值吗？此操作无法撤销。",
            zhHant: "確定要將所有投影偏好設定重設為出廠預設值嗎？此操作無法復原。",
            ja: "すべての投影設定を初期値にリセットしますか？この操作は取り消せません。",
            ms: "Adakah anda pasti mahu menetapkan semula semua keutamaan unjuran kepada lalai kilang? Tindakan ini tidak boleh dibuat asal.",
            ko: "모든 프로젝션 환경설정을 초기 기본값으로 재설정하시겠습니까? 이 작업은 되돌릴 수 없습니다.",
            ta: "அனைத்துத் திரை இணைப்பு விருப்பங்களையும் தொழிற்சாலை இயல்புநிலைக்கு மீட்டமைக்கவா? இந்தச் செயலைத் தவிர்க்க முடியாது."
        )
    }

    public static var diagnosticLogsClearedTitle: String {
        tr(en: "Diagnostic Logs Cleared", zhHans: "诊断日志已清空", zhHant: "診斷日誌已清除", ja: "診断ログを消去しました", ms: "Log Diagnostik Dikosongkan", ko: "진단 로그 지워짐", ta: "கண்டறிதல் பதிவுகள் அழிக்கப்பட்டன")
    }
    public static var diagnosticLogsClearedMessage: String {
        tr(
            en: "Memory buffer and disk logs have been emptied (0 entries).",
            zhHans: "内存缓冲与磁盘日志文件均已清空（0 条记录）。",
            zhHant: "記憶體緩衝與磁碟日誌檔案均已清除（0 筆記錄）。",
            ja: "メモリバッファとディスクログを空にしました（0 件）。",
            ms: "Penimbal memori dan log cakera telah dikosongkan (0 entri).",
            ko: "메모리 버퍼와 디스크 로그가 모두 비워졌습니다 (0개 항목).",
            ta: "நினைவகம் மற்றும் வட்டு பதிவுகள் காலியாக்கப்பட்டன (0 பதிவுகள்)."
        )
    }

    // MARK: - DebugLogCategoriesViewController
    public static var debugLogCategoriesTitle: String {
        tr(en: "Debug Log Categories", zhHans: "调试日志分类", zhHant: "除錯日誌分類", ja: "デバッグログカテゴリ", ms: "Kategori Log Nyahpepijat", ko: "디버그 로그 카테고리", ta: "பிழைத்திருத்தப் பதிவு வகைகள்")
    }
    public static var enableAll: String {
        tr(en: "Enable All", zhHans: "全部开启", zhHant: "全部開啟", ja: "すべて有効", ms: "Aktifkan Semua", ko: "모두 활성화", ta: "அனைத்தையும் இயக்கு")
    }
    public static var debugLogCategoriesFooter: String {
        tr(
            en: "Enabled categories emit structured telemetry to AppLog. Disabling unnecessary categories saves CPU overhead.",
            zhHans: "已启用的分类会向 AppLog 输出结构化遥测日志。关闭不需要的分类可降低 CPU 开销。",
            zhHant: "已啟用的分類會向 AppLog 輸出結構化遙測日誌。關閉不需要的分類可降低 CPU 開銷。",
            ja: "有効なカテゴリは構造化テレメトリを AppLog に記録します。不要なカテゴリを無効にすると CPU 負荷を軽減できます。",
            ms: "Kategori yang diaktifkan memancarkan telemetri berstruktur ke AppLog. Menyahdayakan kategori yang tidak perlu menjimatkan overhed CPU.",
            ko: "활성화된 카테고리는 구조화된 원격 측정 데이터를 AppLog로 출력합니다. 불필요한 카테고리를 끄면 CPU 부하를 줄일 수 있습니다.",
            ta: "இயக்கப்பட்ட வகைகள் AppLog-க்கு அளவீட்டுத் தரவை அனுப்பும். தேவையற்ற வகைகளை முடக்குவது CPU சுமையைக் குறைக்கும்."
        )
    }

    // MARK: - DpiPreviewView
    public static var previewPortraitSplit: String {
        tr(
            en: "Portrait Coolwalk (Top Map + Lower Cards)",
            zhHans: "竖屏 Coolwalk（上方地图 + 下方卡片）",
            zhHant: "直向 Coolwalk（上方地圖 + 下方卡片）",
            ja: "縦向き Coolwalk（上地図 + 下カード）",
            ms: "Coolwalk Potret (Peta Atas + Kad Bawah)",
            ko: "세로 Coolwalk (상단 지도 + 하단 카드)",
            ta: "செங்குத்து Coolwalk (மேல் வரைபடம் + கீழ் அட்டைகள்)"
        )
    }
    public static var previewPortraitSingle: String {
        tr(
            en: "Portrait Single Card",
            zhHans: "竖屏单卡模式",
            zhHant: "直向單卡模式",
            ja: "縦向きシングルカード",
            ms: "Kad Tunggal Potret",
            ko: "세로 단일 카드",
            ta: "செங்குத்து ஒற்றை அட்டை"
        )
    }
    public static var previewLandscapeSplit: String {
        tr(
            en: "Coolwalk Split Screen",
            zhHans: "Coolwalk 分屏布局",
            zhHant: "Coolwalk 分割畫面",
            ja: "Coolwalk 分割画面",
            ms: "Skrin Pisah Coolwalk",
            ko: "Coolwalk 분할 화면",
            ta: "Coolwalk பிரிவுத் திரை"
        )
    }
    public static var previewLandscapeSingle: String {
        tr(
            en: "Single Card Compact",
            zhHans: "单卡紧凑模式",
            zhHant: "單卡緊湊模式",
            ja: "シングルカード（コンパクト）",
            ms: "Kad Tunggal Padat",
            ko: "단일 카드 (컴팩트)",
            ta: "ஒற்றை அட்டை சுருக்கம்"
        )
    }
    public static func previewStatusHeaderWithCrop(
        activeW: Int, activeH: Int,
        codecW: Int, codecH: Int,
        dpi: Int,
        dpW: Int, dpH: Int,
        layoutMode: String
    ) -> String {
        tr(
            en: "Active: \(activeW)×\(activeH) (\(codecW)×\(codecH) crop) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            zhHans: "有效: \(activeW)×\(activeH) (\(codecW)×\(codecH) 裁切) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            zhHant: "有效: \(activeW)×\(activeH) (\(codecW)×\(codecH) 裁切) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            ja: "表示: \(activeW)×\(activeH) (\(codecW)×\(codecH) 切抜) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            ms: "Aktif: \(activeW)×\(activeH) (\(codecW)×\(codecH) pangkas) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            ko: "활성: \(activeW)×\(activeH) (\(codecW)×\(codecH) 자르기) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            ta: "செயலில்: \(activeW)×\(activeH) (\(codecW)×\(codecH) வெட்டு) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)"
        )
    }
    public static func previewStatusHeader(
        activeW: Int, activeH: Int,
        dpi: Int,
        dpW: Int, dpH: Int,
        layoutMode: String
    ) -> String {
        tr(
            en: "Active: \(activeW)×\(activeH) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            zhHans: "有效: \(activeW)×\(activeH) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            zhHant: "有效: \(activeW)×\(activeH) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            ja: "表示: \(activeW)×\(activeH) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            ms: "Aktif: \(activeW)×\(activeH) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            ko: "활성: \(activeW)×\(activeH) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            ta: "செயலில்: \(activeW)×\(activeH) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)"
        )
    }

    // MARK: - iPadOS 27 Sidebar, Entry, About, Hidden Diagnostics & Quick Menu
    public static var androidAutoDefaultName: String { "Android Auto" }

    public static var sidebarWirelessConnection: String {
        tr(en: "Wireless", zhHans: "无线连接", zhHant: "無線連線", ja: "ワイヤレス接続", ms: "Wayarles", ko: "무선 연결", ta: "வயர்லெஸ்")
    }
    public static var sidebarDisplayLayout: String {
        tr(en: "Display & Layout", zhHans: "显示与布局", zhHant: "顯示與版面", ja: "表示とレイアウト", ms: "Paparan & Susun Atur", ko: "디스플레이 및 레이아웃", ta: "திரை & அமைப்பு")
    }
    public static var sidebarAudioMixer: String {
        tr(en: "Audio & Mixer", zhHans: "音频与调音台", zhHant: "音訊與混音器", ja: "オーディオとミキサー", ms: "Audio & Pengadun", ko: "오디오 및 믹서", ta: "ஒலி & கலப்பி")
    }
    public static var sidebarSmartLanguage: String {
        tr(en: "Smart & Language", zhHans: "智能与语言", zhHant: "智慧與語言", ja: "スマートと言語", ms: "Pintar & Bahasa", ko: "스마트 및 언어", ta: "ஸ்மார்ட் & மொழி")
    }
    public static var sidebarAbout: String {
        tr(en: "About", zhHans: "关于", zhHant: "關於", ja: "このアプリについて", ms: "Perihal", ko: "정보", ta: "பற்றி")
    }

    public static var sidebarScanningPort5277: String {
        tr(en: "Scanning 5277…", zhHans: "正在扫描 5277…", zhHant: "正在掃描 5277…", ja: "5277 をスキャン中…", ms: "Mengimbas 5277…", ko: "5277 스캔 중…", ta: "5277 தேடுகிறது…")
    }
    public static var wirelessHeroTitleReady: String {
        tr(en: "Wireless Android Auto", zhHans: "无线 Android Auto", zhHant: "無線 Android Auto", ja: "ワイヤレス Android Auto", ms: "Android Auto Wayarles", ko: "무선 Android Auto", ta: "வயர்லெஸ் Android Auto")
    }
    public static var wirelessHeroSubtitleReady: String {
        tr(
            en: "Connect to phone hotspot or same Wi-Fi, then tap below to discover",
            zhHans: "连接手机热点或同一 Wi-Fi 后，点击下方按钮自动发现",
            zhHant: "連上個人熱點或相同 Wi-Fi 後，點選下方按鈕自動探索",
            ja: "スマホのテザリングまたは同じ Wi-Fi に接続後、下のボタンで自動検出します",
            ms: "Sambung ke hotspot telefon atau Wi-Fi yang sama, kemudian ketik butang di bawah",
            ko: "휴대폰 핫스팟 또는 같은 Wi-Fi에 연결한 뒤 아래 버튼을 눌러 자동 검색하세요",
            ta: "தொலைபேசி ஹாட்ஸ்பாட் அல்லது ஒரே Wi-Fi-இல் இணைத்து கீழே தட்டவும்"
        )
    }
    public static var wirelessHeroTitleScanning: String {
        tr(
            en: "Scanning for Headunit Server",
            zhHans: "正在探测车机服务器",
            zhHant: "正在探索車機伺服器",
            ja: "ヘッドユニットサーバーを検索中",
            ms: "Mengesan Pelayan Unit Kepala",
            ko: "헤드유닛 서버 탐색 중",
            ta: "கார் சேவையகத்தைத் தேடுகிறது"
        )
    }
    public static var wirelessHeroSubtitleScanning: String {
        tr(
            en: "Scanning local network port 5277 to start projection automatically",
            zhHans: "正在扫描当前局域网端口 5277，找到后自动建立安全投屏",
            zhHant: "正在掃描區域網路連接埠 5277，找到後自動建立安全投影",
            ja: "ローカルネットワークのポート 5277 をスキャン中。検出後自動で接続します",
            ms: "Mengimbas port 5277 rangkaian tempatan untuk memulakan unjuran secara automatik",
            ko: "로컬 네트워크 포트 5277을 스캔 중이며 발견 시 자동으로 연결됩니다",
            ta: "உள்ளூர் பிணைய போர்ட் 5277-ஐத் தேடுகிறது; கிடைத்ததும் தானாக இணையும்"
        )
    }
    public static var wirelessHeroPrimaryScanButton: String {
        tr(
            en: "Scan Headunit Server",
            zhHans: "扫描车机服务",
            zhHant: "掃描車機服務",
            ja: "車載サーバーをスキャン",
            ms: "Imbas Pelayan Kereta",
            ko: "헤드유닛 서버 스캔",
            ta: "சேவையகத்தைத் தேடு"
        )
    }
    public static func wirelessScanningSubnet(_ hostHint: String) -> String {
        tr(
            en: "Scanning \(hostHint) : 5277…",
            zhHans: "正在扫描局域网 \(hostHint) : 5277…",
            zhHant: "正在掃描區域網路 \(hostHint) : 5277…",
            ja: "スキャン中 \(hostHint) : 5277…",
            ms: "Mengimbas \(hostHint) : 5277…",
            ko: "로컬 스캔 중 \(hostHint) : 5277…",
            ta: "தேடுகிறது \(hostHint) : 5277…"
        )
    }
    public static var cancelScanButton: String {
        tr(en: "Cancel", zhHans: "取消扫描", zhHant: "取消掃描", ja: "キャンセル", ms: "Batal", ko: "스캔 취소", ta: "ரத்து செய்")
    }
    public static var hotspotDirectConnectTitle: String {
        tr(en: "Hotspot Gateway Direct", zhHans: "热点网关直连", zhHant: "熱點閘道直連", ja: "ホットスポット直接接続", ms: "Sambungan Terus Gerbang", ko: "핫스팟 게이트웨이 직접 연결", ta: "ஹாட்ஸ்பாட் நேரடி இணைப்பு")
    }
    public static var hotspotDirectConnectSubtitle: String {
        tr(
            en: "Specify host IP directly after joining phone hotspot",
            zhHans: "连接手机个人热点后可直接指定主机 IP",
            zhHant: "連上個人熱點後可直接指定主機 IP",
            ja: "テザリング接続後にホスト IP を直接指定できます",
            ms: "Nyatakan IP hos terus selepas menyambung hotspot telefon",
            ko: "핫스팟 연결 후 호스트 IP를 직접 지정할 수 있습니다",
            ta: "ஹாட்ஸ்பாட்டில் இணைந்த பின் ஹோஸ்ட் IP-ஐ நேரடியாக உள்ளிடலாம்"
        )
    }
    public static var directConnectShortButton: String {
        tr(en: "Connect", zhHans: "直连", zhHant: "直連", ja: "接続", ms: "Sambung", ko: "연결", ta: "இணை")
    }
    public static var androidSetupStepsTitle: String {
        tr(en: "Android Phone Setup Steps", zhHans: "安卓手机开启步骤", zhHant: "Android 手機開啟步驟", ja: "Android スマホの設定手順", ms: "Langkah Persediaan Android", ko: "Android 휴대폰 설정 단계", ta: "Android அமைப்பு படிகள்")
    }
    public static var androidSetupStepsCountBadge: String {
        tr(en: "4 steps", zhHans: "共 4 步", zhHant: "共 4 步", ja: "全 4 ステップ", ms: "4 langkah", ko: "총 4단계", ta: "4 படிகள்")
    }

    public static var sectionVolumeAndNav: String {
        tr(en: "Volume & Navigation", zhHans: "音量与导航", zhHant: "音量與導航", ja: "音量とナビ案内", ms: "Kelantangan & Navigasi", ko: "볼륨 및 내비게이션", ta: "ஒலி & வழிகாட்டல்")
    }
    public static var sampleToneButtonShort: String {
        tr(en: "♫ Test", zhHans: "♫ 试听", zhHant: "♫ 試聽", ja: "♫ テスト", ms: "♫ Uji", ko: "♫ 테스트", ta: "♫ சோதனை")
    }
    public static var smartNightModeFooter: String {
        tr(
            en: "\"Auto\" switches 07:00–19:00; \"Twilight\" calculates local sunrise/sunset and switches to night early.",
            zhHans: "「自动」按 07:00–19:00 切换；「天文」依据当前位置或系统时区计算真实日出日落时间，并提前切入夜间。",
            zhHant: "「自動」依 07:00–19:00 切換；「天文」依所在位置或時區計算日出日落時間，並提前切入夜間。",
            ja: "「自動」は 07:00〜19:00 で切替。「天文」は位置やタイムゾーンから日の出・日の入りを計算し早めに夜間へ移行します。",
            ms: "\"Auto\" bertukar 07:00–19:00; \"Senja\" mengira waktu matahari terbit/terbenam tempatan untuk mod malam.",
            ko: "'자동'은 07:00–19:00 기준 전환, '일출/일몰'은 위치 또는 시간대에 따라 일몰 전 야간 모드로 전환합니다.",
            ta: "'தானியங்கி' 07:00–19:00 மாற்றும்; 'அந்தி' உள்ளூர் சூரிய உதயம்/மறைவைக் கணக்கிட்டு முன்கூட்டியே இரவு பயன்முறைக்கு மாறும்."
        )
    }
    public static var smartGpsFooter: String {
        tr(
            en: "Cellular iPad models can enable \"iPad GPS\" to pass device location to Android Auto.",
            zhHans: "若您的 iPad 为蜂窝网络版，可开启「优先 iPad GPS」将本机定位透传给 Android Auto",
            zhHant: "若 iPad 為行動網路版，可開啟「優先 iPad GPS」將本機定位透傳給 Android Auto",
            ja: "セルラー版 iPad では「iPad GPS 優先」を有効にして現在地を Android Auto に送信できます",
            ms: "Model iPad selular boleh mengaktifkan \"Utamakan GPS iPad\" untuk menghantar lokasi ke Android Auto",
            ko: "셀룰러 iPad에서는 'iPad GPS 우선'을 켜서 기기 위치를 Android Auto로 전달할 수 있습니다",
            ta: "செல்லுலார் iPad-இல் 'iPad GPS' இயக்கி இடத்தை Android Auto-க்கு அனுப்பலாம்"
        )
    }
    public static var sessionLockedHandshakeFooter: String {
        tr(
            en: "These options are disabled during wireless projection to prevent reconnect drops. Disconnect first to modify.",
            zhHans: "在无线投屏期间已禁用以上选项以防断流重连，请在断开连接后再修改。",
            zhHant: "無線投影期間已停用以上選項以防斷線重連，請在斷開連線後再修改。",
            ja: "ワイヤレス投影中は再接続を防ぐため上記項目は無効です。変更するには接続を解除してください。",
            ms: "Pilihan di atas dinyahdayakan semasa unjuran wayarles untuk mengelakkan terputus. Putuskan sambungan dahulu untuk mengubah.",
            ko: "무선 프로젝션 중 끊김을 방지하기 위해 위 항목이 비활성화되었습니다. 연결 해제 후 변경하세요.",
            ta: "இணைப்புத் துண்டிப்பைத் தவிர்க்க திரை இணைப்பின் போது இவை முடக்கப்பட்டுள்ளன. மாற்ற முதலில் துண்டிக்கவும்."
        )
    }

    // MARK: - About & Hidden Automation/Diagnostics
    public static var aboutAppInfoSection: String {
        tr(en: "App Information", zhHans: "应用信息", zhHant: "應用程式資訊", ja: "アプリ情報", ms: "Maklumat Aplikasi", ko: "앱 정보", ta: "செயலி தகவல்")
    }
    public static var aboutAppNameRow: String {
        tr(en: "App Name", zhHans: "应用名称", zhHant: "應用程式名稱", ja: "アプリ名", ms: "Nama Aplikasi", ko: "앱 이름", ta: "செயலி பெயர்")
    }
    public static var aboutVersionRow: String {
        tr(en: "Version", zhHans: "版本", zhHant: "版本", ja: "バージョン", ms: "Versi", ko: "버전", ta: "பதிப்பு")
    }
    public static var aboutProtocolRow: String {
        tr(en: "Protocol", zhHans: "协议版本", zhHant: "通訊協定", ja: "プロトコル", ms: "Protokol", ko: "프로토콜", ta: "நெறிமுறை")
    }
    public static var aboutDecodePipelineRow: String {
        tr(en: "Media Pipeline", zhHans: "解码管线", zhHant: "解碼管線", ja: "デコード構成", ms: "Saluran Media", ko: "디코딩 파이프라인", ta: "ஊடக செயலாக்கம்")
    }
    public static var aboutThisDeviceSection: String {
        tr(en: "This Device", zhHans: "此设备", zhHant: "此裝置", ja: "このデバイス", ms: "Peranti Ini", ko: "이 기기", ta: "இந்த சாதனம்")
    }
    public static var aboutDeviceModelRow: String {
        tr(en: "Model", zhHans: "设备型号", zhHant: "裝置型號", ja: "モデル", ms: "Model Peranti", ko: "기기 모델", ta: "சாதன மாதிரி")
    }
    public static var aboutOsVersionRow: String {
        tr(en: "System Version", zhHans: "系统版本", zhHant: "系統版本", ja: "システムバージョン", ms: "Versi Sistem", ko: "시스템 버전", ta: "கணினி பதிப்பு")
    }
    public static var aboutScreenSpecRow: String {
        tr(en: "Display", zhHans: "屏幕规格", zhHant: "螢幕規格", ja: "ディスプレイ", ms: "Paparan", ko: "디스플레이", ta: "திரை விவரம்")
    }
    public static var aboutLocalIpRow: String {
        tr(en: "Local IP", zhHans: "本机 IP", zhHant: "本機 IP", ja: "ローカル IP", ms: "IP Tempatan", ko: "로컬 IP", ta: "உள்ளூர் IP")
    }
    public static var aboutConnectedPhonesSection: String {
        tr(en: "Connected Phones", zhHans: "已连接过的手机", zhHant: "已連線過的手機", ja: "接続履歴のあるスマホ", ms: "Telefon Pernah Disambung", ko: "연결된 휴대폰 기록", ta: "இணைந்த தொலைபேசிகள்")
    }
    public static func aboutDeviceCount(_ count: Int) -> String {
        tr(
            en: count == 1 ? "1 device" : "\(count) devices",
            zhHans: "\(count) 台设备",
            zhHant: "\(count) 台裝置",
            ja: "\(count) 台",
            ms: "\(count) peranti",
            ko: "\(count)대",
            ta: "\(count) சாதனங்கள்"
        )
    }
    public static var aboutNoConnectedPhonesTitle: String {
        tr(en: "No Connected Phones Yet", zhHans: "暂无连接记录", zhHant: "尚無連線紀錄", ja: "接続履歴はありません", ms: "Tiada Rekod Sambungan", ko: "연결 기록 없음", ta: "இணைப்பு வரலாறு இல்லை")
    }
    public static var aboutNoConnectedPhonesSubtitle: String {
        tr(
            en: "Android phones connected via port 5277 will appear here automatically.",
            zhHans: "通过 5277 握手连接过的安卓手机会自动记录在此。",
            zhHant: "透過 5277 握手連線過的 Android 手機將自動記錄於此。",
            ja: "ポート 5277 で接続した Android 端末の名前とモデルが自動で記録されます。",
            ms: "Telefon Android yang disambung melalui port 5277 akan direkodkan di sini.",
            ko: "포트 5277로 연결된 Android 휴대폰이 자동으로 여기에 기록됩니다.",
            ta: "போர்ட் 5277 வழியாக இணைந்த Android தொலைபேசிகள் இங்கு தானாகப் பதிவாகும்."
        )
    }
    public static var aboutHiddenDiagnosticsTitle: String {
        tr(en: "Automation & Diagnostics", zhHans: "自动化与诊断", zhHant: "自動化與診斷", ja: "自動化と診断", ms: "Automasi & Diagnostik", ko: "자동화 및 진단", ta: "தானியக்கம் & கண்டறிதல்")
    }
    public static var aboutHideDiagnosticsButton: String {
        tr(en: "Hide Entry", zhHans: "隐藏此入口", zhHant: "隱藏此入口", ja: "この項目を隠す", ms: "Sembunyikan", ko: "이 항목 숨기기", ta: "இதை மறை")
    }
    public static var aboutUnlockedViaFiveTaps: String {
        tr(
            en: "Unlocked via 5 taps on Version",
            zhHans: "已通过连点「版本」5 次解锁",
            zhHant: "已透過連點「版本」5 次解鎖",
            ja: "バージョンを 5 回タップして解除済み",
            ms: "Dibuka melalui 5 ketikan pada Versi",
            ko: "버전 5회 탭으로 잠금 해제됨",
            ta: "பதிப்பை 5 முறை தட்டி திறக்கப்பட்டது"
        )
    }
    public static var diagnosticsCurrentLinkSection: String {
        tr(en: "Current Link Diagnostics", zhHans: "当前链路诊断", zhHant: "目前連線診斷", ja: "現在のリンク診断", ms: "Diagnostik Pautan Semasa", ko: "현재 링크 진단", ta: "தற்போதைய இணைப்பு நிலை")
    }
    public static var diagnosticsVideoDecodeRow: String {
        tr(en: "Video Decoder", zhHans: "视频硬解", zhHant: "視訊硬解", ja: "ビデオデコード", ms: "Penyahkod Video", ko: "비디오 디코더", ta: "வீடியோ டீகோடர்")
    }
    public static var diagnosticsAudioPipelineRow: String {
        tr(en: "Audio Pipeline", zhHans: "音频管线", zhHant: "音訊管線", ja: "オーディオ構成", ms: "Saluran Audio", ko: "오디오 파이프라인", ta: "ஒலி அமைப்பு")
    }
    public static func diagnosticsDroppedFrames(_ count: Int) -> String {
        tr(
            en: "\(count) dropped",
            zhHans: "\(count) 掉帧",
            zhHant: "\(count) 掉幀",
            ja: "ドロップ \(count)",
            ms: "\(count) gugur",
            ko: "\(count) 드롭",
            ta: "\(count) இழப்பு"
        )
    }
    public static var removeRecordAction: String {
        tr(en: "Remove", zhHans: "移除记录", zhHant: "移除紀錄", ja: "削除", ms: "Padam", ko: "삭제", ta: "நீக்கு")
    }

    // MARK: - Active Projection Liquid Glass Quick Menu
    public static var quickMenuHudRow: String {
        tr(en: "Performance HUD", zhHans: "性能 HUD 浮窗", zhHant: "效能 HUD 浮窗", ja: "パフォーマンス HUD", ms: "HUD Prestasi", ko: "성능 HUD 오버레이", ta: "செயல்திறன் HUD")
    }
    public static var quickMenuNavDuckingRow: String {
        tr(en: "Navigation Ducking", zhHans: "导航播报压音", zhHant: "導航播報壓音", ja: "ナビ案内ダッキング", ms: "Redaman Navigasi", ko: "내비게이션 더킹", ta: "வழிகாட்டி ஒலி குறைப்பு")
    }
    public static var quickMenuMediaMuteRow: String {
        tr(en: "Mute Media Audio", zhHans: "媒体声道静音", zhHant: "媒體聲道靜音", ja: "メディア音声をミュート", ms: "Bisukan Audio Media", ko: "미디어 오디오 음소거", ta: "மீடியா ஒலி அமைதி")
    }
    public static var quickMenuOpenFullSettings: String {
        tr(en: "Open CarAutoPad Settings", zhHans: "打开 CarAutoPad 完整设置", zhHant: "開啟 CarAutoPad 完整設定", ja: "CarAutoPad の設定を開く", ms: "Buka Tetapan CarAutoPad", ko: "CarAutoPad 전체 설정 열기", ta: "CarAutoPad அமைப்புகளைத் திற")
    }
    public static var quickMenuDisconnectAction: String {
        tr(en: "Disconnect Android Auto", zhHans: "断开 Android Auto 连接", zhHant: "中斷 Android Auto 連線", ja: "Android Auto を切断", ms: "Putuskan Android Auto", ko: "Android Auto 연결 해제", ta: "Android Auto துண்டி")
    }
    public static var quickDuckOffShort: String {
        tr(en: "Off", zhHans: "关", zhHant: "關", ja: "オフ", ms: "Mati", ko: "끔", ta: "நிறுத்து")
    }
    public static var quickDuckMuteShort: String {
        tr(en: "Mute", zhHans: "静音", zhHant: "靜音", ja: "ミュート", ms: "Bisu", ko: "음소거", ta: "அமைதி")
    }
}
