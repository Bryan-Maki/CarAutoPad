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

    private static var isRunningUnitTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
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
            if lower.hasPrefix("ja") {
                return .japanese
            }
            if lower.hasPrefix("ms") || lower.hasPrefix("id") {
                return .malay
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
            return Self.resolveSystemLanguage(from: Locale.preferredLanguages)
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
        }
    }
}

public enum L10n {
    public static var current: AppLanguage {
        ProjectionSettings.appLanguage.resolved
    }

    public static func tr(
        en: String,
        zhHans: String,
        zhHant: String,
        ja: String,
        ms: String
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
        }
    }

    // MARK: - Common Actions & Words
    public static var ok: String {
        tr(en: "OK", zhHans: "好", zhHant: "好", ja: "OK", ms: "OK")
    }
    public static var cancel: String {
        tr(en: "Cancel", zhHans: "取消", zhHant: "取消", ja: "キャンセル", ms: "Batal")
    }
    public static var close: String {
        tr(en: "Close", zhHans: "关闭", zhHant: "關閉", ja: "閉じる", ms: "Tutup")
    }
    public static var dismiss: String {
        tr(en: "Dismiss", zhHans: "关闭", zhHant: "關閉", ja: "閉じる", ms: "Tutup")
    }
    public static var reset: String {
        tr(en: "Reset", zhHans: "重置", zhHant: "重置", ja: "リセット", ms: "Tetapkan Semula")
    }
    public static var off: String {
        tr(en: "Off", zhHans: "关闭", zhHant: "關閉", ja: "オフ", ms: "Mati")
    }
    public static var on: String {
        tr(en: "On", zhHans: "开启", zhHant: "開啟", ja: "オン", ms: "Hidup")
    }
    public static var notAvailableShort: String {
        tr(en: "N/A", zhHans: "不可用", zhHant: "不適用", ja: "対象外", ms: "T/B")
    }
    public static var unknown: String {
        tr(en: "Unknown", zhHans: "未知", zhHant: "未知", ja: "不明", ms: "Tidak diketahui")
    }
    public static var autoShort: String {
        tr(en: "Auto", zhHans: "自动", zhHant: "自動", ja: "自動", ms: "Auto")
    }
    public static var customShort: String {
        tr(en: "Custom", zhHans: "自定义", zhHant: "自訂", ja: "カスタム", ms: "Tersuai")
    }
    public static var currentSuffixFormat: String {
        tr(en: "%@ (Current)", zhHans: "%@（当前）", zhHant: "%@（目前）", ja: "%@（現在）", ms: "%@ (Semasa)")
    }
    public static func currentSuffix(_ text: String) -> String {
        String(format: currentSuffixFormat, text)
    }
    public static var lockedSuffixFormat: String {
        tr(en: "%@ (Locked)", zhHans: "%@（已锁定）", zhHant: "%@（已鎖定）", ja: "%@（ロック中）", ms: "%@ (Dikunci)")
    }
    public static func lockedSuffix(_ text: String) -> String {
        String(format: lockedSuffixFormat, text)
    }
    public static var noWifiText: String {
        tr(en: "No Wi-Fi", zhHans: "无 Wi-Fi", zhHant: "無 Wi-Fi", ja: "Wi-Fi なし", ms: "Tiada Wi-Fi")
    }
    public static var defaultPhoneName: String {
        tr(en: "Phone", zhHans: "手机", zhHant: "手機", ja: "スマートフォン", ms: "Telefon")
    }
    public static var unknownArtist: String {
        tr(en: "Unknown Artist", zhHans: "未知艺术家", zhHant: "未知演出者", ja: "不明なアーティスト", ms: "Artis Tidak Diketahui")
    }
    public static var projectionLabel: String {
        tr(en: "Projection", zhHans: "车载投屏", zhHant: "車載投影", ja: "プロジェクション", ms: "Unjuran")
    }

    // MARK: - Language Selection
    public static var systemDefaultLanguageTitle: String {
        tr(
            en: "System Default",
            zhHans: "跟随系统",
            zhHant: "跟隨系統",
            ja: "システム設定に従う",
            ms: "Ikut Sistem"
        )
    }
    public static var languageRowTitle: String {
        tr(en: "Language", zhHans: "界面语言", zhHant: "介面語言", ja: "言語", ms: "Bahasa")
    }
    public static var languagePickerTitle: String {
        tr(en: "Language", zhHans: "选择语言", zhHant: "選擇語言", ja: "言語を選択", ms: "Pilih Bahasa")
    }
    public static var languagePickerMessage: String {
        tr(
            en: "Switch interface language immediately without interrupting projection.",
            zhHans: "立即切换界面语言，投屏期间不会中断连接。",
            zhHant: "立即切換介面語言，投影期間不會中斷連線。",
            ja: "投影を中断せずに画面の表示言語を即座に切り替えます。",
            ms: "Tukar bahasa antara muka serta-merta tanpa mengganggu unjuran."
        )
    }

    // MARK: - Projection Settings Enums
    public static var fps60: String {
        tr(en: "60 FPS", zhHans: "60 FPS", zhHant: "60 FPS", ja: "60 FPS", ms: "60 FPS")
    }
    public static var fps30: String {
        tr(en: "30 FPS", zhHans: "30 FPS", zhHant: "30 FPS", ja: "30 FPS", ms: "30 FPS")
    }

    public static var gpsPhone: String {
        tr(en: "Phone GPS", zhHans: "手机 GPS", zhHant: "手機 GPS", ja: "スマホ GPS", ms: "GPS Telefon")
    }
    public static var gpsIpad: String {
        tr(en: "iPad GPS", zhHans: "iPad GPS", zhHant: "iPad GPS", ja: "iPad GPS", ms: "GPS iPad")
    }
    public static var gpsPhoneShort: String {
        tr(en: "Phone", zhHans: "手机", zhHant: "手機", ja: "スマホ", ms: "Telefon")
    }
    public static var gpsIpadShort: String {
        tr(en: "iPad", zhHans: "iPad", zhHant: "iPad", ja: "iPad", ms: "iPad")
    }

    public static var orientationLandscape: String {
        tr(en: "Landscape", zhHans: "横屏", zhHant: "橫向", ja: "横向き", ms: "Landskap")
    }
    public static var orientationPortrait: String {
        tr(en: "Portrait", zhHans: "竖屏", zhHant: "直向", ja: "縦向き", ms: "Potret")
    }
    public static var orientationSystem: String {
        tr(en: "Auto", zhHans: "自动", zhHant: "自動", ja: "自動", ms: "Auto")
    }

    public static var nightAutoTitle: String {
        tr(
            en: "Auto (Time 07:00-19:00)",
            zhHans: "自动（时间 07:00-19:00）",
            zhHant: "自動（時間 07:00-19:00）",
            ja: "自動（07:00〜19:00）",
            ms: "Auto (Masa 07:00-19:00)"
        )
    }
    public static var nightTwilightTitle: String {
        tr(
            en: "Twilight (Sunrise / Sunset)",
            zhHans: "天文晨昏（日出 / 日落）",
            zhHant: "天文晨昏（日出 / 日落）",
            ja: "トワイライト（日の出・日の入り）",
            ms: "Senja (Matahari Terbit / Terbenam)"
        )
    }
    public static var nightDayTitle: String {
        tr(
            en: "Day (Always Light)",
            zhHans: "日间（始终浅色）",
            zhHant: "日間（始終淺色）",
            ja: "昼モード（常にライト）",
            ms: "Siang (Sentiasa Cerah)"
        )
    }
    public static var nightNightTitle: String {
        tr(
            en: "Night (Always Dark)",
            zhHans: "夜间（始终深色）",
            zhHant: "夜間（始終深色）",
            ja: "夜モード（常にダーク）",
            ms: "Malam (Sentiasa Gelap)"
        )
    }
    public static var nightSystemTitle: String {
        tr(
            en: "System (Follow iPad)",
            zhHans: "跟随系统（iPad 外观）",
            zhHant: "跟隨系統（iPad 外觀）",
            ja: "システム（iPad に合わせる）",
            ms: "Sistem (Ikut iPad)"
        )
    }

    public static var nightAutoShort: String {
        tr(en: "Auto", zhHans: "自动", zhHant: "自動", ja: "自動", ms: "Auto")
    }
    public static var nightTwilightShort: String {
        tr(en: "Twilight", zhHans: "晨昏", zhHant: "晨昏", ja: "日出没", ms: "Senja")
    }
    public static var nightDayShort: String {
        tr(en: "Day", zhHans: "日间", zhHant: "日間", ja: "昼", ms: "Siang")
    }
    public static var nightNightShort: String {
        tr(en: "Night", zhHans: "夜间", zhHant: "夜間", ja: "夜", ms: "Malam")
    }
    public static var nightSystemShort: String {
        tr(en: "System", zhHans: "系统", zhHant: "系統", ja: "システム", ms: "Sistem")
    }

    public static var audioCodecAac: String {
        tr(en: "AAC-LC", zhHans: "AAC-LC", zhHant: "AAC-LC", ja: "AAC-LC", ms: "AAC-LC")
    }
    public static var audioCodecPcm: String {
        tr(
            en: "PCM (Uncompressed)",
            zhHans: "PCM（无损未压缩）",
            zhHant: "PCM（無損未壓縮）",
            ja: "PCM（非圧縮）",
            ms: "PCM (Tidak Dimampat)"
        )
    }

    public static var audioTargetIpad: String {
        tr(
            en: "iPad (Speaker / iPad BT)",
            zhHans: "iPad（扬声器 / iPad 蓝牙）",
            zhHant: "iPad（揚聲器 / iPad 藍牙）",
            ja: "iPad（スピーカー / iPad BT）",
            ms: "iPad (Pembesar Suara / BT iPad)"
        )
    }
    public static var audioTargetPhone: String {
        tr(
            en: "Phone (Original Device)",
            zhHans: "手机（原机 / 车载蓝牙）",
            zhHant: "手機（原機 / 車載藍牙）",
            ja: "スマートフォン（車載BT・端末側）",
            ms: "Telefon (Peranti Asal)"
        )
    }
    public static var audioTargetIpadSegment: String {
        tr(en: "iPad", zhHans: "iPad", zhHant: "iPad", ja: "iPad", ms: "iPad")
    }
    public static var audioTargetPhoneSegment: String {
        tr(en: "Phone", zhHans: "手机", zhHant: "手機", ja: "スマホ", ms: "Telefon")
    }
    public static var audioOutIpadShort: String {
        tr(en: "iPad (Speaker / BT)", zhHans: "iPad（扬声器/蓝牙）", zhHant: "iPad（揚聲器/藍牙）", ja: "iPad（スピーカー/BT）", ms: "iPad (Speaker / BT)")
    }
    public static var audioOutPhoneShort: String {
        tr(en: "Phone (Car BT)", zhHans: "手机（车载蓝牙）", zhHant: "手機（車載藍牙）", ja: "スマホ（車載BT）", ms: "Telefon (BT Kereta)")
    }

    public static var micFollowAudioOutput: String {
        tr(
            en: "Follow Audio Output",
            zhHans: "跟随音频输出",
            zhHant: "跟隨音訊輸出",
            ja: "音声出力に連動",
            ms: "Ikut Output Audio"
        )
    }
    public static var micIpad: String {
        tr(
            en: "iPad Microphone",
            zhHans: "iPad 麦克风",
            zhHant: "iPad 麥克風",
            ja: "iPad マイク",
            ms: "Mikrofon iPad"
        )
    }
    public static var micPhone: String {
        tr(
            en: "Phone / Car BT Mic",
            zhHans: "手机 / 车载蓝牙麦克风",
            zhHant: "手機 / 車載藍牙麥克風",
            ja: "スマホ / 車載BTマイク",
            ms: "Mikrofon Telefon / BT Kereta"
        )
    }
    public static var micFollowSegment: String {
        tr(en: "Follow", zhHans: "跟随", zhHant: "跟隨", ja: "連動", ms: "Ikut")
    }
    public static var micIpadSegment: String {
        tr(en: "iPad", zhHans: "iPad", zhHant: "iPad", ja: "iPad", ms: "iPad")
    }
    public static var micPhoneSegment: String {
        tr(en: "Phone", zhHans: "手机", zhHant: "手機", ja: "スマホ", ms: "Telefon")
    }

    public static var duckingOffTitle: String {
        tr(
            en: "0% (No Ducking)",
            zhHans: "0%（不压音）",
            zhHant: "0%（不壓低音量）",
            ja: "0%（ダッキングなし）",
            ms: "0% (Tiada Pengurangan)"
        )
    }
    public static var duckingLightTitle: String {
        tr(
            en: "-25% (Light)",
            zhHans: "-25%（轻度）",
            zhHant: "-25%（輕度）",
            ja: "-25%（弱）",
            ms: "-25% (Ringan)"
        )
    }
    public static var duckingMediumTitle: String {
        tr(
            en: "-50% (Half)",
            zhHans: "-50%（减半）",
            zhHant: "-50%（減半）",
            ja: "-50%（半分）",
            ms: "-50% (Separuh)"
        )
    }
    public static var duckingStandardTitle: String {
        tr(
            en: "-70% (Default)",
            zhHans: "-70%（默认）",
            zhHant: "-70%（預設）",
            ja: "-70%（標準）",
            ms: "-70% (Lalai)"
        )
    }
    public static var duckingDeepTitle: String {
        tr(
            en: "-85% (Deep)",
            zhHans: "-85%（深度）",
            zhHant: "-85%（深度）",
            ja: "-85%（強）",
            ms: "-85% (Dalam)"
        )
    }
    public static var duckingMuteTitle: String {
        tr(
            en: "-100% (Mute Media)",
            zhHans: "-100%（媒体静音）",
            zhHant: "-100%（媒體靜音）",
            ja: "-100%（メディア消音）",
            ms: "-100% (Senyapkan Media)"
        )
    }
    public static var duckingOffShort: String {
        tr(en: "Off (0%)", zhHans: "关 (0%)", zhHant: "關 (0%)", ja: "オフ(0%)", ms: "Mati (0%)")
    }

    public static var motionBlurOffTitle: String {
        tr(en: "Off", zhHans: "关闭", zhHant: "關閉", ja: "オフ", ms: "Mati")
    }
    public static var motionBlurLightTitle: String {
        tr(
            en: "Subtle (Low-Latency)",
            zhHans: "轻柔（低延迟）",
            zhHant: "輕柔（低延遲）",
            ja: "弱（低遅延）",
            ms: "Halus (Latensi Rendah)"
        )
    }
    public static var motionBlurMediumTitle: String {
        tr(
            en: "Balanced (Smooth)",
            zhHans: "均衡（丝滑）",
            zhHant: "均衡（順滑）",
            ja: "バランス（滑らか）",
            ms: "Seimbang (Lancar)"
        )
    }
    public static var motionBlurStrongTitle: String {
        tr(
            en: "Strong (Max Pacing)",
            zhHans: "强力（极致稳帧）",
            zhHant: "強力（極致穩幀）",
            ja: "強（最大スムージング）",
            ms: "Kuat (Kestabilan Maks)"
        )
    }

    public static var motionBlurOffShort: String {
        tr(en: "Off", zhHans: "关闭", zhHant: "關閉", ja: "オフ", ms: "Mati")
    }
    public static var motionBlurLightShort: String {
        tr(en: "Subtle", zhHans: "轻柔", zhHant: "輕柔", ja: "弱", ms: "Halus")
    }
    public static var motionBlurMediumShort: String {
        tr(en: "Balanced", zhHans: "均衡", zhHant: "均衡", ja: "バランス", ms: "Seimbang")
    }
    public static var motionBlurStrongShort: String {
        tr(en: "Strong", zhHans: "强力", zhHant: "強力", ja: "強", ms: "Kuat")
    }

    public static var driverPositionRhd: String {
        tr(
            en: "Right-Hand Drive (RHD)",
            zhHans: "右舵驾驶 (RHD)",
            zhHant: "右駕 (RHD)",
            ja: "右ハンドル (RHD)",
            ms: "Pemanduan Kanan (RHD)"
        )
    }
    public static var driverPositionLhd: String {
        tr(
            en: "Left-Hand Drive (LHD)",
            zhHans: "左舵驾驶 (LHD)",
            zhHant: "左駕 (LHD)",
            ja: "左ハンドル (LHD)",
            ms: "Pemanduan Kiri (LHD)"
        )
    }
    public static var rhdAbbrev: String {
        tr(en: "RHD", zhHans: "右舵", zhHant: "右駕", ja: "右ハンドル", ms: "RHD")
    }
    public static var lhdAbbrev: String {
        tr(en: "LHD", zhHans: "左舵", zhHant: "左駕", ja: "左ハンドル", ms: "LHD")
    }
    public static var lhdShort: String {
        tr(en: "LHD (Left)", zhHans: "左舵 (LHD)", zhHant: "左駕 (LHD)", ja: "左 (LHD)", ms: "LHD (Kiri)")
    }
    public static var rhdShort: String {
        tr(en: "RHD (Right)", zhHans: "右舵 (RHD)", zhHant: "右駕 (RHD)", ja: "右 (RHD)", ms: "RHD (Kanan)")
    }

    public static func audioChannelsSummary(
        mPct: String,
        nPct: String,
        sPct: String,
        duckPct: Int
    ) -> String {
        let duckStr: String
        if duckPct == 0 {
            duckStr = tr(en: "No Duck", zhHans: "不压音", zhHant: "不壓音", ja: "ダックなし", ms: "Tiada Duck")
        } else {
            duckStr = tr(
                en: "Duck -\(duckPct)%",
                zhHans: "压音 -\(duckPct)%",
                zhHant: "壓音 -\(duckPct)%",
                ja: "ダック -\(duckPct)%",
                ms: "Duck -\(duckPct)%"
            )
        }
        return "iPad (\(mPct)/\(nPct)/\(sPct) • \(duckStr))"
    }

    // MARK: - Resolution & Fit Mode
    public static var resolutionAutoTitle: String {
        tr(
            en: "Auto (Native iPad)",
            zhHans: "自动（适配 iPad 原生）",
            zhHant: "自動（適配 iPad 原生）",
            ja: "自動（iPad ネイティブ）",
            ms: "Auto (Asli iPad)"
        )
    }
    public static var resolutionAutoRecommended: String {
        tr(
            en: "Auto (Recommended)",
            zhHans: "自动（推荐）",
            zhHant: "自動（推薦）",
            ja: "自動（推奨）",
            ms: "Auto (Disyorkan)"
        )
    }

    public static var fitContainTitle: String {
        tr(
            en: "Fit (Letterbox)",
            zhHans: "适应（保留黑边）",
            zhHant: "適應（保留黑邊）",
            ja: "フィット（黒帯あり）",
            ms: "Muat (Letterbox)"
        )
    }
    public static var fitFillTitle: String {
        tr(
            en: "Fill (PAR)",
            zhHans: "填充（像素比）",
            zhHant: "填滿（像素比）",
            ja: "フィル（PAR）",
            ms: "Isi (PAR)"
        )
    }
    public static var fitCoverTitle: String {
        tr(
            en: "Cover (Crop)",
            zhHans: "铺满（裁切边缘）",
            zhHant: "鋪滿（裁切邊緣）",
            ja: "カバー（切り抜き）",
            ms: "Litup (Pangkas)"
        )
    }
    public static var fitFillMarginTitle: String {
        tr(
            en: "Fill Margin (iPad Fullscreen)",
            zhHans: "全屏边距填充（iPad 满屏）",
            zhHant: "全螢幕邊距填滿（iPad 滿屏）",
            ja: "全画面マージン最適化 (iPad)",
            ms: "Isi Margin (Skrin Penuh iPad)"
        )
    }
    public static var fitStretchTitle: String {
        tr(
            en: "Stretch",
            zhHans: "拉伸铺满",
            zhHant: "拉伸鋪滿",
            ja: "ストレッチ",
            ms: "Regang"
        )
    }

    public static var fitSegmentFill: String {
        tr(en: "Fill", zhHans: "满屏", zhHant: "滿屏", ja: "満画面", ms: "Isi")
    }
    public static var fitSegmentFillMargin: String {
        tr(en: "Fill Margin", zhHans: "边距满屏", zhHant: "邊距滿屏", ja: "マージン満画面", ms: "Isi Margin")
    }
    public static var fitSegmentFit: String {
        tr(en: "Fit", zhHans: "适应", zhHant: "適應", ja: "フィット", ms: "Muat")
    }
    public static var fitSegmentStretch: String {
        tr(en: "Stretch", zhHans: "拉伸", zhHant: "拉伸", ja: "ストレッチ", ms: "Regang")
    }

    // MARK: - Settings Backup Errors
    public static var backupErrorInvalidFormat: String {
        tr(
            en: "Invalid settings format: missing or incorrect format identifier",
            zhHans: "无效的设置格式：缺少或错误的格式标识符",
            zhHant: "無效的設定格式：缺少或錯誤的格式識別碼",
            ja: "無効な設定形式：形式識別子が不足または不正です",
            ms: "Format tetapan tidak sah: pengecam format tiada atau salah"
        )
    }
    public static func backupErrorUnsupportedVersion(_ version: Int) -> String {
        tr(
            en: "Unsupported settings format version: \(version)",
            zhHans: "不支持的设置格式版本：\(version)",
            zhHant: "不支援的設定格式版本：\(version)",
            ja: "未対応の設定フォーマットバージョン：\(version)",
            ms: "Versi format tetapan tidak disokong: \(version)"
        )
    }
    public static func backupErrorCorruptedData(_ msg: String) -> String {
        tr(
            en: "Corrupted settings data: \(msg)",
            zhHans: "设置数据已损坏：\(msg)",
            zhHant: "設定資料已損毀：\(msg)",
            ja: "設定データが破損しています：\(msg)",
            ms: "Data tetapan rosak: \(msg)"
        )
    }

    // MARK: - Debug Log Categories
    public static var logCatConnTitle: String {
        tr(
            en: "Connection, Handshake & Lifecycle",
            zhHans: "连接、握手与生命周期",
            zhHant: "連線、握手與生命週期",
            ja: "接続・ハンドシェイク・ライフサイクル",
            ms: "Sambungan, Jabat Tangan & Kitaran Hayat"
        )
    }
    public static var logCatConnSubtitle: String {
        tr(
            en: "Scan, TLS timing, SDR config, background/foreground & watchdog",
            zhHans: "扫描、TLS 耗时、SDR 配置、前后台切换与看门狗",
            zhHant: "掃描、TLS 耗時、SDR 設定、前後台切換與看門狗",
            ja: "スキャン・TLS 時間・SDR 設定・バックグラウンド切替・監視",
            ms: "Imbasan, masa TLS, konfigurasi SDR, latar belakang/depan & pemantau"
        )
    }
    public static var logCatVideoTitle: String {
        tr(
            en: "Video 60FPS Telemetry & Hitch Catcher",
            zhHans: "视频 60FPS 遥测与卡顿捕获",
            zhHant: "視訊 60FPS 遙測與卡頓擷取",
            ja: "映像 60FPS テレメトリ・ヒッチ検出",
            ms: "Telemetri Video 60FPS & Penangkap Sangkut"
        )
    }
    public static var logCatVideoSubtitle: String {
        tr(
            en: "1s summary [VIDEO-1S] + instant hitch capture [VIDEO-HITCH]",
            zhHans: "每秒摘要 [VIDEO-1S] + 瞬时卡顿捕获 [VIDEO-HITCH]",
            zhHant: "每秒摘要 [VIDEO-1S] + 瞬時卡頓擷取 [VIDEO-HITCH]",
            ja: "1秒サマリー [VIDEO-1S] + 瞬間ヒッチ記録 [VIDEO-HITCH]",
            ms: "Ringkasan 1s [VIDEO-1S] + tangkapan sangkut serta-merta [VIDEO-HITCH]"
        )
    }
    public static var logCatTouchTitle: String {
        tr(
            en: "Touch Input End-to-End Latency",
            zhHans: "触控输入端到端延迟",
            zhHant: "觸控輸入端到端延遲",
            ja: "タッチ入力のエンドツーエンド遅延",
            ms: "Latensi Hujung-ke-Hujung Input Sentuhan"
        )
    }
    public static var logCatTouchSubtitle: String {
        tr(
            en: "UI -> QueueWait -> TLS Encrypt/Send -> Next Frame [TOUCH]",
            zhHans: "UI -> 队列等待 -> TLS 加密发送 -> 下一帧 [TOUCH]",
            zhHant: "UI -> 佇列等待 -> TLS 加密傳送 -> 下一幀 [TOUCH]",
            ja: "UI -> キュー待機 -> TLS 暗号化送信 -> 次フレーム [TOUCH]",
            ms: "UI -> Tunggu Giliran -> Enkripsi/Hantar TLS -> Bingkai Seterusnya [TOUCH]"
        )
    }
    public static var logCatProtoTitle: String {
        tr(
            en: "AAP Protocol, Focus & Keyframe Recovery",
            zhHans: "AAP 协议、焦点与关键帧自愈",
            zhHant: "AAP 協定、焦點與關鍵幀自癒",
            ja: "AAP プロトコル・フォーカス・キーフレーム復旧",
            ms: "Protokol AAP, Fokus & Pemulihan Bingkai Utama"
        )
    }
    public static var logCatProtoSubtitle: String {
        tr(
            en: "VideoFocus, Margin 0x8009, Ping RTT & FocusCycle",
            zhHans: "VideoFocus、0x8009 边距、Ping 往返延迟与焦点循环",
            zhHant: "VideoFocus、0x8009 邊距、Ping 往返延遲與焦點循環",
            ja: "VideoFocus、マージン 0x8009、Ping RTT、FocusCycle",
            ms: "VideoFocus, Margin 0x8009, Ping RTT & FocusCycle"
        )
    }
    public static var logCatAudioTitle: String {
        tr(
            en: "Audio Streams, Ducking & Microphone",
            zhHans: "音频流、导航压音与麦克风",
            zhHant: "音訊串流、導航壓音與麥克風",
            ja: "音声ストリーム・ダッキング・マイク",
            ms: "Strim Audio, Pengurangan & Mikrofon"
        )
    }
    public static var logCatAudioSubtitle: String {
        tr(
            en: "Audio sink start/stop, ducking gain & mic 0x8005",
            zhHans: "音频通道启停、压音增益与麦克风 0x8005",
            zhHant: "音訊通道啟停、壓音增益與麥克風 0x8005",
            ja: "オーディオシンク開始/停止・ダッキングゲイン・マイク 0x8005",
            ms: "Mula/henti sink audio, gandaan pengurangan & mik 0x8005"
        )
    }

    // MARK: - Connection Issues
    public static var issueWifiOffTitle: String {
        tr(
            en: "Search Failed: No Wi-Fi / Hotspot",
            zhHans: "搜索失败：未连接 Wi-Fi / 手机热点",
            zhHant: "搜尋失敗：未連接 Wi-Fi / 手機熱點",
            ja: "検索失敗：Wi-Fi / テザリング未接続",
            ms: "Carian Gagal: Tiada Wi-Fi / Hotspot"
        )
    }
    public static var issueWifiOffAdvice: String {
        tr(
            en: "No valid local Wi-Fi IPv4 address detected. Please connect iPad to your phone's personal hotspot or the same Wi-Fi network first.",
            zhHans: "未检测到有效的局域网 Wi-Fi IPv4 地址。请先将 iPad 连接到安卓手机的个人热点或同一 Wi-Fi 网络。",
            zhHant: "未偵測到有效的區域網路 Wi-Fi IPv4 位址。請先將 iPad 連接至手機的個人熱點或同一 Wi-Fi 網路。",
            ja: "有効なローカル Wi-Fi IPv4 アドレスが検出されません。先に iPad をスマートフォンのテザリングまたは同じ Wi-Fi に接続してください。",
            ms: "Tiada alamat IPv4 Wi-Fi tempatan yang sah dikesan. Sila sambungkan iPad ke hotspot peribadi telefon atau rangkaian Wi-Fi yang sama dahulu."
        )
    }
    public static var issueHeadunitNotAnsweringTitle: String {
        tr(
            en: "Headunit Server Not Answering",
            zhHans: "主机服务器未响应",
            zhHant: "主機伺服器無回應",
            ja: "ヘッドユニットサーバーが応答しません",
            ms: "Pelayan Headunit Tidak Menjawab"
        )
    }
    public static var issueHeadunitNotAnsweringAdvice: String {
        tr(
            en: "Ensure 'Start Headunit Server' is running in Android Auto developer settings on the phone.",
            zhHans: "请确认安卓手机的 Android Auto 开发者设置中已开启「启动主机服务器」。",
            zhHant: "請確認手機的 Android Auto 開發人員設定中已開啟「啟動主機伺服器」。",
            ja: "スマートフォンの Android Auto 開発者向け設定で「ヘッドユニット サーバーを開始」が有効になっているか確認してください。",
            ms: "Pastikan 'Mula Pelayan Headunit' sedang berjalan dalam tetapan pembangun Android Auto pada telefon."
        )
    }
    public static var issueRefused5277Title: String {
        tr(
            en: "Connection Refused (Port 5277)",
            zhHans: "连接被拒绝（端口 5277）",
            zhHant: "連線被拒絕（連接埠 5277）",
            ja: "接続が拒否されました（ポート 5277）",
            ms: "Sambungan Ditolak (Port 5277)"
        )
    }
    public static var issueRefused5277Advice: String {
        tr(
            en: "The phone actively refused port 5277. Stop and re-start Headunit Server in Android Auto.",
            zhHans: "手机主动拒绝了 5277 端口连接。请在 Android Auto 中停止并重新启动主机服务器。",
            zhHant: "手機主動拒絕了 5277 連接埠連線。請在 Android Auto 中停止並重新啟動主機伺服器。",
            ja: "スマートフォンがポート 5277 への接続を拒否しました。Android Auto でヘッドユニットサーバーを停止してから再起動してください。",
            ms: "Telefon menolak sambungan port 5277 secara aktif. Hentikan dan mulakan semula Pelayan Headunit dalam Android Auto."
        )
    }
    public static var issueTlsFailedTitle: String {
        tr(
            en: "TLS Handshake Failed",
            zhHans: "TLS 安全握手失败",
            zhHant: "TLS 安全握手失敗",
            ja: "TLS ハンドシェイクに失敗しました",
            ms: "Jabat Tangan TLS Gagal"
        )
    }
    public static var issueTlsFailedAdvice: String {
        tr(
            en: "Cryptographic negotiation failed. Check date/time synchronization or re-pair.",
            zhHans: "加密协商失败。请检查设备日期和时间是否同步，或尝试重新配对连接。",
            zhHant: "加密協商失敗。請檢查裝置日期與時間是否同步，或嘗試重新配對連線。",
            ja: "暗号ネゴシエーションに失敗しました。端末の日時設定を確認するか、再接続してください。",
            ms: "Rundingan kriptografi gagal. Semak penyegerakan tarikh/masa atau pasang semula."
        )
    }
    public static var issueVideoSlowTitle: String {
        tr(
            en: "Wireless Link Too Slow",
            zhHans: "无线链路速度过慢",
            zhHant: "無線鏈路速度過慢",
            ja: "無線リンクの速度が低下しています",
            ms: "Pautan Wayarles Terlalu Perlahan"
        )
    }
    public static var issueVideoSlowAdvice: String {
        tr(
            en: "Heavy packet drops on video feed. Move closer to the Wi-Fi hotspot or switch to 5GHz.",
            zhHans: "视频流出现严重丢包。请靠近手机热点或将热点频段切换为 5GHz。",
            zhHant: "視訊串流出現嚴重掉幀。請靠近手機熱點或將熱點頻段切換為 5GHz。",
            ja: "映像フィードでパケットロスが発生しています。テザリング端末に近づくか 5GHz 帯へ切り替えてください。",
            ms: "Kehilangan paket tinggi pada suapan video. Dekatkan ke hotspot Wi-Fi atau tukar ke 5GHz."
        )
    }
    public static var issueNoDeviceTitle: String {
        tr(
            en: "No Device Found on Network",
            zhHans: "局域网内未发现手机设备",
            zhHant: "區網內未發現手機裝置",
            ja: "ネットワーク上に端末が見つかりません",
            ms: "Tiada Peranti Ditemui di Rangkaian"
        )
    }
    public static var issueNoDeviceAdvice: String {
        tr(
            en: "Wi-Fi is connected, but no phone responded on port 5277. Make sure 'Start head unit server' is active in Android Auto Developer Settings.",
            zhHans: "Wi-Fi 已连接，但没有手机在 5277 端口响应。请确认 Android Auto 开发者设置中的「启动主机服务器」处于开启状态。",
            zhHant: "Wi-Fi 已連線，但沒有手機在 5277 連接埠回應。請確認 Android Auto 開發人員設定中的「啟動主機伺服器」處於開啟狀態。",
            ja: "Wi-Fi には接続されていますが、ポート 5277 で応答する端末がありません。Android Auto 開発者向け設定で「ヘッドユニット サーバーを開始」が有効かご確認ください。",
            ms: "Wi-Fi disambungkan, tetapi tiada telefon bertindak balas pada port 5277. Pastikan 'Start head unit server' aktif dalam Tetapan Pembangun Android Auto."
        )
    }
    public static var issueStuckAfterRetriesTitle: String {
        tr(
            en: "Connection Failed After 3 Retries (Server May Be Stuck)",
            zhHans: "连续 3 次重试失败（主机服务器可能卡死）",
            zhHant: "連續 3 次重試失敗（主機伺服器可能卡死）",
            ja: "3回の再試行後も接続失敗（サーバー停止の可能性）",
            ms: "Sambungan Gagal Selepas 3 Percubaan (Pelayan Mungkin Terhenti)"
        )
    }
    public static var issueStuckAfterRetriesAdvice: String {
        tr(
            en: "The phone's Headunit Server appears frozen or unresponsive. Please open Android Auto (⋮ -> Stop head unit server, then Start head unit server) on your phone and try again.",
            zhHans: "手机端的主机服务器似乎已卡死或无响应。请在手机上打开 Android Auto（⋮ -> 停止主机服务器，然后重新启动主机服务器）后再试。",
            zhHant: "手機端的主機伺服器似乎已卡死或無回應。請在手機上開啟 Android Auto（⋮ -> 停止主機伺服器，然後重新啟動主機伺服器）後再試。",
            ja: "スマートフォン側のヘッドユニットサーバーが応答停止している可能性があります。Android Auto を開き（⋮ → ヘッドユニットサーバーを停止 → 開始）を行ってから再度お試しください。",
            ms: "Pelayan Headunit telefon kelihatan beku atau tidak bertindak balas. Sila buka Android Auto (⋮ -> Henti pelayan head unit, kemudian Mula pelayan head unit) pada telefon dan cuba lagi."
        )
    }

    // MARK: - Connection States & Status Details
    public static var stateDisconnected: String {
        tr(en: "Disconnected", zhHans: "未连接", zhHant: "未連線", ja: "未接続", ms: "Terputus")
    }
    public static var stateDiscovering: String {
        tr(en: "Scanning...", zhHans: "正在扫描...", zhHant: "正在掃描...", ja: "スキャン中...", ms: "Mengimbas...")
    }
    public static var stateWaitingHelper: String {
        tr(en: "Waiting for Wireless Helper / WPP...", zhHans: "正在等待无线连接助手...", zhHant: "正在等待無線連線助手...", ja: "ワイヤレス接続を待機中...", ms: "Menunggu Pembantu Wayarles...")
    }
    public static var stateConnecting: String {
        tr(en: "Connecting...", zhHans: "正在连接...", zhHant: "正在連線...", ja: "接続中...", ms: "Menyambung...")
    }
    public static var stateHandshaking: String {
        tr(en: "Handshaking...", zhHans: "正在握手...", zhHant: "正在握手...", ja: "ハンドシェイク中...", ms: "Berjabat Tangan...")
    }
    public static var stateConnected: String {
        tr(en: "Connected", zhHans: "已连接", zhHant: "已連線", ja: "接続済み", ms: "Bersambung")
    }
    public static var stateDisconnecting: String {
        tr(en: "Disconnecting...", zhHans: "正在断开...", zhHant: "正在斷線...", ja: "切断中...", ms: "Memutuskan sambungan...")
    }
    public static func stateError(_ message: String) -> String {
        tr(en: "Error: \(message)", zhHans: "错误：\(message)", zhHant: "錯誤：\(message)", ja: "エラー：\(message)", ms: "Ralat: \(message)")
    }

    public static var statusReadyToConnect: String {
        tr(en: "Ready to connect", zhHans: "准备就绪，等待连接", zhHant: "準備就緒，等待連線", ja: "接続準備完了", ms: "Sedia untuk disambungkan")
    }
    public static var statusSearchFailedNoWifi: String {
        tr(
            en: "Search failed: No Wi-Fi / Hotspot connection",
            zhHans: "搜索失败：未连接 Wi-Fi 或手机热点",
            zhHant: "搜尋失敗：未連接 Wi-Fi 或手機熱點",
            ja: "検索失敗：Wi-Fi / テザリング接続がありません",
            ms: "Carian gagal: Tiada sambungan Wi-Fi / Hotspot"
        )
    }
    public static func statusScanning(stationIp: String) -> String {
        let ipDisplay = stationIp.isEmpty ? noWifiText : stationIp
        return tr(
            en: "iPad IP: \(ipDisplay) | Scanning for phone hotspot / headunit...",
            zhHans: "iPad IP: \(ipDisplay) | 正在扫描手机热点 / 主机服务...",
            zhHant: "iPad IP: \(ipDisplay) | 正在掃描手機熱點 / 主機服務...",
            ja: "iPad IP: \(ipDisplay) | 端末・ヘッドユニットを検索中...",
            ms: "IP iPad: \(ipDisplay) | Mengimbas hotspot telefon / headunit..."
        )
    }
    public static func statusConnectingTo(_ deviceName: String) -> String {
        tr(
            en: "Connecting to \(deviceName)...",
            zhHans: "正在连接到 \(deviceName)...",
            zhHant: "正在連線至 \(deviceName)...",
            ja: "\(deviceName) に接続中...",
            ms: "Menyambung ke \(deviceName)..."
        )
    }
    public static func statusFoundDeviceConnecting(_ deviceName: String) -> String {
        tr(
            en: "Found \(deviceName), connecting...",
            zhHans: "已发现 \(deviceName)，正在连接...",
            zhHant: "已發現 \(deviceName)，正在連線...",
            ja: "\(deviceName) を検出、接続中...",
            ms: "Menemui \(deviceName), menyambung..."
        )
    }
    public static func statusRetrying(attempt: Int, maxAttempts: Int) -> String {
        tr(
            en: "Connection failed. Retrying in 3s (\(attempt)/\(maxAttempts))...",
            zhHans: "连接失败，3 秒后重试 (\(attempt)/\(maxAttempts))...",
            zhHant: "連線失敗，3 秒後重試 (\(attempt)/\(maxAttempts))...",
            ja: "接続失敗。3秒後に再試行します (\(attempt)/\(maxAttempts))...",
            ms: "Sambungan gagal. Cuba semula dalam 3s (\(attempt)/\(maxAttempts))..."
        )
    }
    public static func statusFailedAfterRetries(_ maxAttempts: Int) -> String {
        tr(
            en: "Failed after \(maxAttempts) retries. Phone Headunit Server may be stuck — please restart it manually.",
            zhHans: "连续 \(maxAttempts) 次重试失败。手机主机服务器可能卡死，请手动重启。",
            zhHant: "連續 \(maxAttempts) 次重試失敗。手機主機伺服器可能卡死，請手動重啟。",
            ja: "\(maxAttempts)回の再試行後も失敗しました。サーバーが停止している可能性があるため手動で再起動してください。",
            ms: "Gagal selepas \(maxAttempts) percubaan. Pelayan Headunit telefon mungkin terhenti — sila mulakan semula secara manual."
        )
    }
    public static func errorFailedAfterRetries(_ maxAttempts: Int) -> String {
        tr(
            en: "Connection failed after \(maxAttempts) retries. Headunit Server on phone may be stuck — please manually restart Headunit Server.",
            zhHans: "连续 \(maxAttempts) 次重试连接失败。手机端的 Android Auto 主机服务器可能已卡死，请手动重启后再试。",
            zhHant: "連續 \(maxAttempts) 次重試連線失敗。手機端的 Android Auto 主機伺服器可能已卡死，請手動重啟後再試。",
            ja: "\(maxAttempts)回の再試行後も接続に失敗しました。端末側のヘッドユニットサーバーが停止している可能性があります。手動で再起動してください。",
            ms: "Sambungan gagal selepas \(maxAttempts) percubaan. Pelayan Headunit pada telefon mungkin terhenti — sila mulakan semula Pelayan Headunit secara manual."
        )
    }
    public static var statusNoDeviceFound: String {
        tr(
            en: "No device found on network (Check Headunit Server on phone)",
            zhHans: "网络中未发现设备（请检查手机主机服务器是否开启）",
            zhHant: "網路中未發現裝置（請檢查手機主機伺服器是否開啟）",
            ja: "端末が見つかりません（スマホのヘッドユニットサーバーを確認してください）",
            ms: "Tiada peranti ditemui di rangkaian (Semak Pelayan Headunit pada telefon)"
        )
    }
    public static func statusSearchFailed(reason: String) -> String {
        tr(
            en: "Search failed: \(reason)",
            zhHans: "搜索失败：\(reason)",
            zhHant: "搜尋失敗：\(reason)",
            ja: "検索失敗：\(reason)",
            ms: "Carian gagal: \(reason)"
        )
    }
    public static var statusWaitingHeadunitServer: String {
        tr(
            en: "Waiting for Android Auto Headunit Server (5277)...",
            zhHans: "正在等待 Android Auto 主机服务器 (5277)...",
            zhHant: "正在等待 Android Auto 主機伺服器 (5277)...",
            ja: "Android Auto ヘッドユニットサーバー (5277) を待機中...",
            ms: "Menunggu Pelayan Headunit Android Auto (5277)..."
        )
    }
    public static var statusHandshakingTls: String {
        tr(
            en: "Handshaking with Android Auto (TLS / Service Discovery)...",
            zhHans: "正在与 Android Auto 握手（TLS / 服务发现）...",
            zhHant: "正在與 Android Auto 握手（TLS / 服務探索）...",
            ja: "Android Auto とハンドシェイク中（TLS / サービス検出）...",
            ms: "Berjabat tangan dengan Android Auto (TLS / Penemuan Perkhidmatan)..."
        )
    }
    public static var statusRunningWireless: String {
        tr(
            en: "Android Auto is running over wireless",
            zhHans: "Android Auto 正在无线投屏运行",
            zhHant: "Android Auto 正在無線投影運行",
            ja: "Android Auto ワイヤレス投影を実行中",
            ms: "Android Auto sedang berjalan melalui wayarles"
        )
    }
    public static var statusDisconnectedFromSession: String {
        tr(
            en: "Android Auto disconnected",
            zhHans: "Android Auto 已断开连接",
            zhHant: "Android Auto 已中斷連線",
            ja: "Android Auto が切断されました",
            ms: "Android Auto terputus sambungan"
        )
    }

    // MARK: - Main Dashboard UI
    public static var appSubtitle: String {
        tr(
            en: "Wireless Android Auto Receiver",
            zhHans: "无线 Android Auto 车载投屏接收端",
            zhHant: "無線 Android Auto 車載投影接收端",
            ja: "ワイヤレス Android Auto レシーバー",
            ms: "Penerima Android Auto Wayarles"
        )
    }
    public static var settingsButtonTitle: String {
        tr(en: "Settings", zhHans: "设置", zhHant: "設定", ja: "設定", ms: "Tetapan")
    }
    public static func statusIpadIpReady(_ ip: String) -> String {
        tr(
            en: "iPad IP: \(ip) • Ready",
            zhHans: "iPad IP: \(ip) • 就绪",
            zhHant: "iPad IP: \(ip) • 就緒",
            ja: "iPad IP: \(ip) • 待機中",
            ms: "IP iPad: \(ip) • Sedia"
        )
    }
    public static var statusScanningPort5277: String {
        tr(
            en: "Scanning Port 5277...",
            zhHans: "正在扫描 5277 端口...",
            zhHant: "正在掃描 5277 連接埠...",
            ja: "ポート 5277 をスキャン中...",
            ms: "Mengimbas Port 5277..."
        )
    }
    public static var statusWaitingForWireless: String {
        tr(
            en: "Waiting for wireless...",
            zhHans: "正在等待无线连接...",
            zhHant: "正在等待無線連線...",
            ja: "ワイヤレス接続を待機中...",
            ms: "Menunggu wayarles..."
        )
    }
    public static var wirelessConnectionHub: String {
        tr(
            en: "Wireless Connection Hub",
            zhHans: "无线连接中心",
            zhHant: "無線連線中心",
            ja: "ワイヤレス接続ハブ",
            ms: "Hab Sambungan Wayarles"
        )
    }
    public static var directConnectLabel: String {
        tr(
            en: "Direct Connect (Phone Hotspot IP)",
            zhHans: "IP 直连（手机热点网关 IP）",
            zhHant: "IP 直連（手機熱點閘道 IP）",
            ja: "IP 直接接続（テザリング IP）",
            ms: "Sambung Terus (IP Hotspot Telefon)"
        )
    }
    public static var directConnectButton: String {
        tr(
            en: "Direct Connect",
            zhHans: "直连主机",
            zhHant: "直接連線",
            ja: "直接接続",
            ms: "Sambung Terus"
        )
    }
    public static var orAutoDiscover: String {
        tr(
            en: "— OR AUTO-DISCOVER —",
            zhHans: "— 或局域网自动发现 —",
            zhHant: "— 或區域網路自動探索 —",
            ja: "— または自動検索 —",
            ms: "— ATAU CARI AUTOMATIK —"
        )
    }
    public static var scanForHeadunitServer: String {
        tr(
            en: "Scan for Headunit Server (Port 5277)",
            zhHans: "扫描车机主机服务（端口 5277）",
            zhHant: "掃描車機主機服務（連接埠 5277）",
            ja: "ヘッドユニットサーバーを検索 (5277)",
            ms: "Imbas Pelayan Headunit (Port 5277)"
        )
    }
    public static var cancelDisconnect: String {
        tr(
            en: "Cancel / Disconnect",
            zhHans: "取消 / 断开连接",
            zhHant: "取消 / 中斷連線",
            ja: "キャンセル / 切断",
            ms: "Batal / Putuskan"
        )
    }
    public static var androidPhoneSetupGuide: String {
        tr(
            en: "Android Phone Setup Guide",
            zhHans: "安卓手机开启指南",
            zhHant: "Android 手機設定指南",
            ja: "Android スマホ接続ガイド",
            ms: "Panduan Persediaan Telefon Android"
        )
    }
    public static var guideStep1Title: String {
        tr(
            en: "1. Open Android Auto Settings",
            zhHans: "1. 打开 Android Auto 设置",
            zhHant: "1. 開啟 Android Auto 設定",
            ja: "1. Android Auto 設定を開く",
            ms: "1. Buka Tetapan Android Auto"
        )
    }
    public static var guideStep1Detail: String {
        tr(
            en: "In phone Settings → Connected devices → Android Auto",
            zhHans: "前往手机「设置 → 已连接设备 → Android Auto」",
            zhHant: "前往手機「設定 → 已連結裝置 → Android Auto」",
            ja: "端末の「設定 → 接続済みのデバイス → Android Auto」へ",
            ms: "Dalam Tetapan telefon → Peranti bersambung → Android Auto"
        )
    }
    public static var guideStep2Title: String {
        tr(
            en: "2. Enable Developer Mode",
            zhHans: "2. 开启开发者模式",
            zhHant: "2. 開啟開發人員模式",
            ja: "2. 開発者モードを有効にする",
            ms: "2. Aktifkan Mod Pembangun"
        )
    }
    public static var guideStep2Detail: String {
        tr(
            en: "Scroll down, tap 'Version' 10 times and confirm OK",
            zhHans: "滑到底部连续点击「版本」10 次并确认开启",
            zhHant: "滑到底部連續點擊「版本」10 次並確認開啟",
            ja: "下部までスクロールし「バージョン」を10回タップして OK",
            ms: "Tatal ke bawah, ketik 'Versi' 10 kali dan sahkan OK"
        )
    }
    public static var guideStep3Title: String {
        tr(
            en: "3. Start Head Unit Server",
            zhHans: "3. 启动主机服务器",
            zhHant: "3. 啟動主機伺服器",
            ja: "3. ヘッドユニットサーバーを開始",
            ms: "3. Mula Pelayan Head Unit"
        )
    }
    public static var guideStep3Detail: String {
        tr(
            en: "Tap top-right '⋮' menu in Android Auto & start server",
            zhHans: "点击右上角「⋮」菜单，选择「启动主机服务器」",
            zhHant: "點擊右上角「⋮」選單，選擇「啟動主機伺服器」",
            ja: "右上の「⋮」メニューから「ヘッドユニット サーバーを開始」",
            ms: "Ketik menu '⋮' di penjuru kanan atas Android Auto & mula pelayan"
        )
    }
    public static var guideStep4Title: String {
        tr(
            en: "4. Connect Hotspot & Launch",
            zhHans: "4. 连接热点并开始投屏",
            zhHant: "4. 連接熱點並開始投影",
            ja: "4. テザリング接続して起動",
            ms: "4. Sambung Hotspot & Lancar"
        )
    }
    public static var guideStep4Detail: String {
        tr(
            en: "Connect iPad to phone hotspot Wi-Fi & tap Connect",
            zhHans: "将 iPad 连入手机 Wi-Fi 热点后，点击左侧按钮连接",
            zhHant: "將 iPad 連入手機 Wi-Fi 熱點後，點擊左側按鈕連線",
            ja: "iPad をスマホのテザリングに接続して接続ボタンを押します",
            ms: "Sambungkan iPad ke Wi-Fi hotspot telefon & ketik Sambung"
        )
    }

    public static var currentConfigurationHeader: String {
        tr(
            en: "CURRENT CONFIGURATION (TAP TO CONFIGURE)",
            zhHans: "当前配置概览（点击卡片快速调整）",
            zhHant: "目前設定概覽（點擊卡片快速調整）",
            ja: "現在の構成（タップして設定変更）",
            ms: "KONFIGURASI SEMASA (KETIK UNTUK UBAH)"
        )
    }
    public static var tileDisplay: String {
        tr(en: "Display", zhHans: "显示规格", zhHant: "顯示規格", ja: "ディスプレイ", ms: "Paparan")
    }
    public static var tileLayoutDpi: String {
        tr(en: "Layout & DPI", zhHans: "布局与 DPI", zhHant: "佈局與 DPI", ja: "レイアウト & DPI", ms: "Susun Atur & DPI")
    }
    public static var tileCodecs: String {
        tr(en: "Codecs", zhHans: "音视频编解码", zhHant: "影音編解碼", ja: "コーデック", ms: "Kodek")
    }
    public static var tileAudioDucking: String {
        tr(en: "Audio & Ducking", zhHans: "音频与压音", zhHant: "音訊與壓音", ja: "オーディオ設定", ms: "Audio & Pengurangan")
    }
    public static var tileMicrophone: String {
        tr(en: "Microphone", zhHans: "麦克风来源", zhHant: "麥克風來源", ja: "マイク入力", ms: "Mikrofon")
    }
    public static var tileSmartMode: String {
        tr(en: "Smart Mode", zhHans: "智能日夜与舵向", zhHant: "智慧日夜與舵向", ja: "スマートモード", ms: "Mod Pintar")
    }
    public static func smoothTileValue(_ shortTitle: String) -> String {
        tr(
            en: "Smooth: \(shortTitle)",
            zhHans: "稳帧: \(shortTitle)",
            zhHant: "穩幀: \(shortTitle)",
            ja: "滑らか: \(shortTitle)",
            ms: "Lancar: \(shortTitle)"
        )
    }
    public static func autoDpiTileValue(_ dpi: Int) -> String {
        tr(
            en: "Auto (\(dpi))",
            zhHans: "自动 (\(dpi))",
            zhHant: "自動 (\(dpi))",
            ja: "自動 (\(dpi))",
            ms: "Auto (\(dpi))"
        )
    }

    // MARK: - Quick Popups & Modals
    public static var quickDisplayTitle: String {
        tr(en: "Display Configuration", zhHans: "显示参数配置", zhHant: "顯示參數設定", ja: "ディスプレイ設定", ms: "Konfigurasi Paparan")
    }
    public static var quickDisplayMessage: String {
        tr(
            en: "Choose video resolution and maximum frame rate.",
            zhHans: "选择投屏视频分辨率、帧率上限与流畅模式。",
            zhHant: "選擇投影視訊解析度、幀率上限與流暢模式。",
            ja: "映像の解像度・最大フレームレート・スムージングを選択します。",
            ms: "Pilih resolusi video dan kadar bingkai maksimum."
        )
    }
    public static func frameRateOption(_ fpsTitle: String) -> String {
        tr(
            en: "Frame Rate: \(fpsTitle)",
            zhHans: "帧率上限：\(fpsTitle)",
            zhHant: "幀率上限：\(fpsTitle)",
            ja: "フレームレート：\(fpsTitle)",
            ms: "Kadar Bingkai: \(fpsTitle)"
        )
    }
    public static func frameSmoothingOption(_ modeTitle: String) -> String {
        tr(
            en: "Frame Smoothing: \(modeTitle)",
            zhHans: "帧平滑缓冲：\(modeTitle)",
            zhHant: "幀平滑緩衝：\(modeTitle)",
            ja: "フレーム補間：\(modeTitle)",
            ms: "Pelicinan Bingkai: \(modeTitle)"
        )
    }

    public static var quickCodecsTitle: String {
        tr(en: "Codecs Configuration", zhHans: "编解码器配置", zhHant: "編解碼器設定", ja: "コーデック設定", ms: "Konfigurasi Kodek")
    }
    public static var quickCodecsMessage: String {
        tr(
            en: "Select video decoding and audio stream codecs.",
            zhHans: "选择视频硬解格式与音频流编码格式。",
            zhHant: "選擇視訊硬解格式與音訊串流編碼格式。",
            ja: "映像デコードおよび音声ストリームのコーデックを選択します。",
            ms: "Pilih penyahkodan video dan kodek strim audio."
        )
    }
    public static var videoCodecOptionH264: String {
        tr(
            en: "Video: H.264 (AVC - Standard)",
            zhHans: "视频：H.264（AVC 标准兼容）",
            zhHant: "視訊：H.264（AVC 標準相容）",
            ja: "映像：H.264（AVC 標準）",
            ms: "Video: H.264 (AVC - Standard)"
        )
    }
    public static var videoCodecOptionHevc: String {
        tr(
            en: "Video: HEVC (H.265 - Efficient)",
            zhHans: "视频：HEVC（H.265 高效压缩）",
            zhHant: "視訊：HEVC（H.265 高效壓縮）",
            ja: "映像：HEVC（H.265 高効率）",
            ms: "Video: HEVC (H.265 - Cekap)"
        )
    }
    public static var audioCodecOptionAac: String {
        tr(
            en: "Audio: AAC-LC (Compressed)",
            zhHans: "音频：AAC-LC（压缩流）",
            zhHant: "音訊：AAC-LC（壓縮串流）",
            ja: "音声：AAC-LC（圧縮）",
            ms: "Audio: AAC-LC (Dimampat)"
        )
    }
    public static var audioCodecOptionPcm: String {
        tr(
            en: "Audio: PCM (Uncompressed)",
            zhHans: "音频：PCM（无损未压缩）",
            zhHant: "音訊：PCM（無損未壓縮）",
            ja: "音声：PCM（非圧縮）",
            ms: "Audio: PCM (Tidak Dimampat)"
        )
    }

    public static var quickMicTitle: String {
        tr(en: "Microphone Source", zhHans: "麦克风来源", zhHant: "麥克風來源", ja: "マイク入力ソース", ms: "Sumber Mikrofon")
    }
    public static var quickMicMessage: String {
        tr(
            en: "Select audio capture device for Google Voice Assistant.",
            zhHans: "选择 Google 语音助手与通话所使用的拾音设备。",
            zhHant: "選擇 Google 語音助理與通話所使用的收音裝置。",
            ja: "Google アシスタント等の音声入力に使用するマイクを選択します。",
            ms: "Pilih peranti tangkapan audio untuk Google Voice Assistant."
        )
    }
    public static var micFollowAutoTitle: String {
        tr(
            en: "Follow Audio Output (Automatic)",
            zhHans: "跟随音频输出（自动选择）",
            zhHant: "跟隨音訊輸出（自動選擇）",
            ja: "音声出力に連動（自動）",
            ms: "Ikut Output Audio (Automatik)"
        )
    }

    public static var quickSmartModeTitle: String {
        tr(
            en: "Smart Mode & Driver Position",
            zhHans: "智能日夜模式与驾驶舵向",
            zhHant: "智慧日夜模式與駕駛舵向",
            ja: "スマートモード・運転席位置",
            ms: "Mod Pintar & Posisi Pemandu"
        )
    }
    public static var quickSmartModeMessage: String {
        tr(
            en: "Configure Day/Night theme and cockpit orientation.",
            zhHans: "配置日夜主题切换策略以及左舵 / 右舵车机布局。",
            zhHant: "設定日夜主題切換策略以及左駕 / 右駕車機佈局。",
            ja: "昼夜テーマ切替とハンドル位置（左/右）を設定します。",
            ms: "Konfigurasikan tema Siang/Malam dan orientasi kokpit."
        )
    }
    public static var driverOptionLhd: String {
        tr(
            en: "Driver: Left Hand Drive (LHD)",
            zhHans: "驾驶位：左舵驾驶 (LHD)",
            zhHant: "駕駛位：左駕 (LHD)",
            ja: "運転席：左ハンドル (LHD)",
            ms: "Pemandu: Pemanduan Kiri (LHD)"
        )
    }
    public static var driverOptionRhd: String {
        tr(
            en: "Driver: Right Hand Drive (RHD)",
            zhHans: "驾驶位：右舵驾驶 (RHD)",
            zhHant: "駕駛位：右駕 (RHD)",
            ja: "運転席：右ハンドル (RHD)",
            ms: "Pemandu: Pemanduan Kanan (RHD)"
        )
    }

    public static var layoutDpiModalTitle: String {
        tr(en: "Layout & DPI Configuration", zhHans: "布局与 DPI 配置", zhHant: "佈局與 DPI 設定", ja: "レイアウト・DPI 設定", ms: "Konfigurasi Susun Atur & DPI")
    }
    public static var displayFitMode: String {
        tr(en: "Display Fit Mode", zhHans: "画面适应模式", zhHant: "畫面適應模式", ja: "画面フィットモード", ms: "Mod Muat Paparan")
    }
    public static var drivingPosition: String {
        tr(en: "Driving Position", zhHans: "驾驶舵向", zhHant: "駕駛舵向", ja: "運転席位置", ms: "Posisi Pemanduan")
    }
    public static var autoRecommendedDpi: String {
        tr(en: "Auto Recommended DPI", zhHans: "自动推荐 DPI", zhHant: "自動推薦 DPI", ja: "自動推奨 DPI", ms: "DPI Disyorkan Auto")
    }
    public static var autoDpiRecommended: String {
        tr(en: "Auto DPI (Recommended)", zhHans: "自动 DPI（推荐）", zhHant: "自動 DPI（推薦）", ja: "自動 DPI（推奨）", ms: "DPI Auto (Disyorkan)")
    }
    public static var splitScreenShort: String {
        tr(en: "Split Screen", zhHans: "Coolwalk 分屏", zhHant: "Coolwalk 分割畫面", ja: "分割画面", ms: "Skrin Pisah")
    }
    public static var singleCardShort: String {
        tr(en: "Single Card", zhHans: "单卡模式", zhHant: "單卡模式", ja: "シングルカード", ms: "Kad Tunggal")
    }
    public static var coolwalkSplitShort: String {
        tr(en: "Coolwalk Split", zhHans: "Coolwalk 分屏", zhHant: "Coolwalk 分割", ja: "Coolwalk 分割", ms: "Pisah Coolwalk")
    }
    public static var singleFullscreenShort: String {
        tr(en: "Single Fullscreen", zhHans: "全屏单卡", zhHant: "全螢幕單卡", ja: "シングル全画面", ms: "Skrin Penuh Tunggal")
    }

    // MARK: - Audio & Ducking Modal / Mixer Cell
    public static var audioDuckingModalTitle: String {
        tr(en: "Audio & Ducking Configuration", zhHans: "音频输出与压音调音台", zhHant: "音訊輸出與壓音混音台", ja: "オーディオ・ダッキング設定", ms: "Konfigurasi Audio & Pengurangan")
    }
    public static var audioOutputDestination: String {
        tr(en: "Audio Output Destination", zhHans: "音频输出设备", zhHant: "音訊輸出裝置", ja: "音声出力先", ms: "Destinasi Output Audio")
    }
    public static var independentChannelVolumes: String {
        tr(en: "Independent Channel Volumes & Toggles", zhHans: "独立声道音量与开关", zhHant: "獨立聲道音量與開關", ja: "チャンネル別音量とミュート", ms: "Kelantangan & Togol Saluran Bebas")
    }
    public static var mediaAudio: String {
        tr(en: "Media Audio", zhHans: "媒体音乐", zhHant: "媒體音樂", ja: "メディア音楽", ms: "Audio Media")
    }
    public static var navigationGuidance: String {
        tr(en: "Navigation / Guidance", zhHans: "导航播报", zhHant: "導航播報", ja: "ナビ音声案内", ms: "Navigasi / Panduan")
    }
    public static var phoneSystemAlerts: String {
        tr(en: "Phone & System Alerts", zhHans: "通话与系统提示音", zhHant: "通話與系統提示音", ja: "通話・システム通知", ms: "Telefon & Amaran Sistem")
    }
    public static var navigationDuckingDrop: String {
        tr(en: "Navigation Ducking Drop", zhHans: "导航播报压音幅度", zhHant: "導航播報壓音幅度", ja: "ナビ案内時のダッキング量", ms: "Penurunan Pengurangan Navigasi")
    }
    public static var navigationDuckingSubtitle: String {
        tr(
            en: "Reduces media music volume during navigation speech guidance.",
            zhHans: "导航语音播报期间，自动按比例压低媒体音乐音量。",
            zhHant: "導航語音播報期間，自動按比例壓低媒體音樂音量。",
            ja: "ナビ音声案内中、メディア音楽の音量を自動的に下げます。",
            ms: "Mengurangkan kelantangan muzik media semasa panduan suara navigasi."
        )
    }
    public static var testNavDucking: String {
        tr(en: "Test Nav Ducking", zhHans: "试听导航压音", zhHant: "試聽導航壓音", ja: "ダッキングテスト", ms: "Uji Pengurangan Nav")
    }
    public static var resetAudio: String {
        tr(en: "Reset Audio", zhHans: "重置音频", zhHant: "重置音訊", ja: "音量リセット", ms: "Tetap Semula Audio")
    }
    public static var duckingDisabledPhoneAudio: String {
        tr(
            en: "Disabled (Audio plays on Phone / Car BT)",
            zhHans: "已禁用（音频由手机 / 车载蓝牙输出）",
            zhHant: "已停用（音訊由手機 / 車載藍牙輸出）",
            ja: "無効（スマホ / 車載BTから出力中）",
            ms: "Dinyahdayakan (Audio dimainkan di Telefon / BT Kereta)"
        )
    }
    public static func duckingStatusRetained(pct: Int, retained: Int) -> String {
        tr(
            en: "-\(pct)% (Media at \(retained)%)",
            zhHans: "-\(pct)%（媒体保留 \(retained)%）",
            zhHant: "-\(pct)%（媒體保留 \(retained)%）",
            ja: "-\(pct)%（音楽 \(retained)%）",
            ms: "-\(pct)% (Media pada \(retained)%)"
        )
    }

    // MARK: - SettingsViewController Sections, Rows & Footers
    public static var projectionSettingsTitle: String {
        tr(en: "Projection Settings", zhHans: "投屏设置", zhHant: "投影設定", ja: "投影設定", ms: "Tetapan Unjuran")
    }
    public static var sectionActiveSession: String {
        tr(en: "Active Session", zhHans: "当前会话", zhHant: "目前工作階段", ja: "接続中のセッション", ms: "Sesi Aktif")
    }
    public static var sectionDisplayLayout: String {
        tr(en: "Display & Coolwalk Layout", zhHans: "显示与 Coolwalk 布局", zhHant: "顯示與 Coolwalk 佈局", ja: "ディスプレイ・Coolwalk レイアウト", ms: "Paparan & Susun Atur Coolwalk")
    }
    public static var sectionVideoAudio: String {
        tr(en: "Video & Audio Pipeline", zhHans: "音视频通道管线", zhHant: "影音通道管線", ja: "映像・音声パイプライン", ms: "Saluran Video & Audio")
    }
    public static var sectionSmartSensors: String {
        tr(en: "Smart Sensors & Night Mode", zhHans: "智能传感、日夜与语言", zhHant: "智慧感測、日夜與語言", ja: "スマートセンサー・夜間・言語", ms: "Sensor Pintar, Mod Malam & Bahasa")
    }
    public static var sectionConnectionAutomation: String {
        tr(en: "Connection & Automation", zhHans: "连接与自动化", zhHant: "連線與自動化", ja: "接続・自動化", ms: "Sambungan & Automasi")
    }
    public static var sectionDiagnosticsBackup: String {
        tr(en: "Diagnostics, Logs & Backup", zhHans: "诊断、日志与备份", zhHant: "診斷、日誌與備份", ja: "診断・ログ・バックアップ", ms: "Diagnostik, Log & Sandaran")
    }

    public static var footerDisplayLayoutLocked: String {
        tr(
            en: "Handshake parameters (DPI, Resolution, FPS, Driving Position) are locked during active session. Disconnect to modify. Fit mode and smoothing remain adjustable.",
            zhHans: "握手参数（DPI、分辨率、帧率、驾驶舵向）在投屏会话期间已锁定，请断开后修改。画面适应模式与帧平滑可实时调节。",
            zhHant: "握手參數（DPI、解析度、幀率、駕駛舵向）在投影工作階段期間已鎖定，請中斷連線後修改。畫面適應模式與幀平滑可即時調整。",
            ja: "ハンドシェイク設定（DPI・解像度・FPS・運転席位置）はセッション中ロックされます。変更するには切断してください。フィットモードとフレーム補間は調整可能です。",
            ms: "Parameter jabat tangan (DPI, Resolusi, FPS, Posisi Pemanduan) dikunci semasa sesi aktif. Putuskan sambungan untuk mengubah. Mod muat dan pelicinan kekal boleh laras."
        )
    }
    public static var footerDisplayLayoutUnlocked: String {
        tr(
            en: "Adjust DPI to scale Android Auto UI elements. Virtual width ≥ 800 dp enables Coolwalk split-screen cards. Touch, resolution and margins adapt dynamically.",
            zhHans: "调节 DPI 可缩放 Android Auto 界面元素大小。虚拟宽度 ≥ 800 dp 将启用 Coolwalk 分屏卡片。触控、分辨率与边距均动态自适应。",
            zhHant: "調整 DPI 可縮放 Android Auto 介面元素大小。虛擬寬度 ≥ 800 dp 將啟用 Coolwalk 分割畫面卡片。觸控、解析度與邊距皆動態自適應。",
            ja: "DPI を調整して Android Auto UI の表示倍率を変更します。仮想幅 800 dp 以上で Coolwalk 分割画面が有効になります。タッチと余白は動的に適応します。",
            ms: "Laraskan DPI untuk menskalakan elemen UI Android Auto. Lebar maya ≥ 800 dp mengaktifkan kad skrin pisah Coolwalk. Sentuhan, resolusi dan margin menyesuaikan secara dinamik."
        )
    }
    public static var footerVideoAudioLocked: String {
        tr(
            en: "Video/Audio codecs, output routing and mic source are locked during active session. Disconnect to modify. Live audio channel mixer remains adjustable.",
            zhHans: "音视频编解码、音频输出目标与麦克风来源在投屏会话期间已锁定，请断开后修改。实时多声道混音台仍可自由调节。",
            zhHant: "影音編解碼、音訊輸出目標與麥克風來源在投影工作階段期間已鎖定，請中斷連線後修改。即時多聲道混音台仍可自由調整。",
            ja: "映像/音声コーデック・出力先・マイク設定はセッション中ロックされます。変更するには切断してください。チャンネルミキサーはリアルタイムで調整できます。",
            ms: "Kodek Video/Audio, penghalaan output dan sumber mikrofon dikunci semasa sesi aktif. Putuskan sambungan untuk mengubah. Pengadun saluran audio langsung kekal boleh laras."
        )
    }
    public static var footerVideoAudioUnlocked: String {
        tr(
            en: "Hardware decoding and microphone routing preferences. Vehicle identity remains permanent Car (CAR 1) for seamless multi-device coexistence.",
            zhHans: "配置硬件解码器与麦克风路由策略。车载设备身份恒定为标准汽车 (CAR 1)，确保多设备无缝共存。",
            zhHant: "設定硬體解碼器與麥克風路由策略。車載裝置身分恆定為標準汽車 (CAR 1)，確保多裝置無縫共存。",
            ja: "ハードウェアデコードとマイク入力ルートを設定します。車両プロファイルはマルチデバイス互換のため常に Car (CAR 1) を維持します。",
            ms: "Keutamaan penyahkodan perkakasan dan penghalaan mikrofon. Identiti kenderaan kekal sebagai Car (CAR 1) untuk keserasian berbilang peranti."
        )
    }
    public static var footerConnectionAutomation: String {
        tr(
            en: "Auto Reconnect retries failed or interrupted wireless connections silently.",
            zhHans: "开启自动重连后，无线连接失败或意外中断时将在后台静默重试。",
            zhHant: "開啟自動重連後，無線連線失敗或意外中斷時將在背景靜默重試。",
            ja: "自動再接続を有効にすると、接続失敗や切断時にバックグラウンドで再接続を試みます。",
            ms: "Sambung Semula Auto mencuba semula sambungan wayarles yang gagal atau terganggu secara senyap."
        )
    }
    public static var footerDiagnosticsBackup: String {
        tr(
            en: "CarAutoPad • Wireless Android Auto Receiver",
            zhHans: "CarAutoPad • 无线 Android Auto 车载投屏接收端",
            zhHant: "CarAutoPad • 無線 Android Auto 車載投影接收端",
            ja: "CarAutoPad • ワイヤレス Android Auto レシーバー",
            ms: "CarAutoPad • Penerima Android Auto Wayarles"
        )
    }

    public static var connectedDeviceRow: String {
        tr(en: "Connected Device", zhHans: "已连接设备", zhHant: "已連線裝置", ja: "接続中の端末", ms: "Peranti Bersambung")
    }
    public static var disconnectAndroidAutoRow: String {
        tr(en: "Disconnect Android Auto", zhHans: "断开 Android Auto 连接", zhHant: "中斷 Android Auto 連線", ja: "Android Auto を切断", ms: "Putuskan Android Auto")
    }
    public static var resolutionTitle: String {
        tr(en: "Resolution", zhHans: "投屏分辨率", zhHant: "投影解析度", ja: "解像度", ms: "Resolusi")
    }
    public static var resolutionPickerMessage: String {
        tr(
            en: "Choose target projection resolution ladder",
            zhHans: "选择目标投屏视频分辨率阶梯",
            zhHant: "選擇目標投影視訊解析度階梯",
            ja: "投影する解像度プリセットを選択します",
            ms: "Pilih tangga resolusi unjuran sasaran"
        )
    }
    public static var frameRateRow: String {
        tr(en: "Frame Rate", zhHans: "帧率上限", zhHant: "幀率上限", ja: "フレームレート", ms: "Kadar Bingkai")
    }
    public static var screenOrientationRow: String {
        tr(en: "Screen Orientation", zhHans: "屏幕方向", zhHant: "螢幕方向", ja: "画面の向き", ms: "Orientasi Skrin")
    }
    public static var frameSmoothingRow: String {
        tr(en: "Frame Smoothing", zhHans: "帧平滑缓冲", zhHant: "幀平滑緩衝", ja: "フレーム補間", ms: "Pelicinan Bingkai")
    }
    public static var edgeSwipeProtectionRow: String {
        tr(
            en: "Edge Swipe Protection (Double-Swipe)",
            zhHans: "边缘防误触保护（二次滑动触发）",
            zhHant: "邊緣防誤觸保護（二次滑動觸發）",
            ja: "画面端スワイプ誤操作防止",
            ms: "Perlindungan Leretan Tepi (Leret Dua Kali)"
        )
    }
    public static var videoCodecRow: String {
        tr(en: "Video Codec", zhHans: "视频解码器", zhHant: "視訊解碼器", ja: "映像コーデック", ms: "Kodek Video")
    }
    public static var audioCodecRow: String {
        tr(en: "Audio Codec", zhHans: "音频编码格式", zhHant: "音訊編碼格式", ja: "音声コーデック", ms: "Kodek Audio")
    }
    public static var audioOutputRow: String {
        tr(en: "Audio Output", zhHans: "音频输出目标", zhHant: "音訊輸出目標", ja: "音声出力先", ms: "Output Audio")
    }
    public static var microphoneSourceRow: String {
        tr(en: "Microphone Source", zhHans: "麦克风来源", zhHant: "麥克風來源", ja: "マイク入力", ms: "Sumber Mikrofon")
    }
    public static var nightModeRow: String {
        tr(en: "Night Mode", zhHans: "日夜模式", zhHant: "日夜模式", ja: "夜間モード", ms: "Mod Malam")
    }
    public static var gpsSourceRow: String {
        tr(en: "GPS Source", zhHans: "GPS 定位来源", zhHant: "GPS 定位來源", ja: "GPS ソース", ms: "Sumber GPS")
    }
    public static var gpsPhoneOnlyWifiIpad: String {
        tr(
            en: "Phone Only (Wi-Fi iPad)",
            zhHans: "仅使用手机（Wi-Fi 版 iPad）",
            zhHant: "僅使用手機（Wi-Fi 版 iPad）",
            ja: "スマホのみ（Wi-Fi 版 iPad）",
            ms: "Telefon Sahaja (iPad Wi-Fi)"
        )
    }
    public static var autoReconnectRow: String {
        tr(en: "Auto Reconnect", zhHans: "断线自动重连", zhHant: "斷線自動重連", ja: "自動再接続", ms: "Sambung Semula Auto")
    }
    public static var autoResumePlaybackRow: String {
        tr(en: "Auto Resume Playback", zhHans: "重连自动续播音乐", zhHant: "重連自動續播音樂", ja: "再接続時に自動再生", ms: "Sambung Main Semula Auto")
    }
    public static var debugModeRow: String {
        tr(
            en: "Debug Mode (HUD & Floating Bubble)",
            zhHans: "调试模式（性能浮窗与悬浮球）",
            zhHant: "除錯模式（效能浮窗與懸浮球）",
            ja: "デバッグモード（HUD・フローティングボタン）",
            ms: "Mod Nyahpepijat (HUD & Buih Terapung)"
        )
    }
    public static var debugLogCategoriesRow: String {
        tr(
            en: "Debug Log Categories...",
            zhHans: "诊断日志分类开关...",
            zhHant: "診斷日誌分類開關...",
            ja: "デバッグログカテゴリ...",
            ms: "Kategori Log Nyahpepijat..."
        )
    }
    public static func debugCategoriesEnabledCount(enabled: Int, total: Int) -> String {
        tr(
            en: "\(enabled) of \(total) enabled",
            zhHans: "已开启 \(enabled) / \(total) 项",
            zhHant: "已開啟 \(enabled) / \(total) 項",
            ja: "\(total) 個中 \(enabled) 個有効",
            ms: "\(enabled) daripada \(total) diaktifkan"
        )
    }
    public static var liveDiagnosticsReportRow: String {
        tr(
            en: "Live Diagnostics Report",
            zhHans: "实时诊断报告",
            zhHant: "即時診斷報告",
            ja: "ライブ診断レポート",
            ms: "Laporan Diagnostik Langsung"
        )
    }
    public static var exportShareSessionLogsRow: String {
        tr(
            en: "Export / Share Session Logs",
            zhHans: "导出 / 分享会话日志",
            zhHant: "匯出 / 分享工作階段日誌",
            ja: "セッションログを書き出し / 共有",
            ms: "Eksport / Kongsi Log Sesi"
        )
    }
    public static var clearAllDiagnosticLogsRow: String {
        tr(
            en: "Clear All Diagnostic Logs",
            zhHans: "清空全部诊断日志",
            zhHant: "清除全部診斷日誌",
            ja: "診断ログをすべて消去",
            ms: "Kosongkan Semua Log Diagnostik"
        )
    }
    public static var backupRestoreSettingsRow: String {
        tr(
            en: "Backup / Restore Settings (JSON)",
            zhHans: "备份 / 恢复配置 (JSON)",
            zhHant: "備份 / 還原設定 (JSON)",
            ja: "設定のバックアップ / 復元 (JSON)",
            ms: "Sandar / Pulih Tetapan (JSON)"
        )
    }
    public static var resetAllSettingsRow: String {
        tr(
            en: "Reset All Settings to Defaults",
            zhHans: "恢复全部默认设置",
            zhHant: "恢復全部預設設定",
            ja: "すべての設定を初期値に戻す",
            ms: "Tetapkan Semula Semua Tetapan"
        )
    }

    // MARK: - Settings Alerts & Details
    public static var connectionDetailsTitle: String {
        tr(en: "Connection Details", zhHans: "连接详情", zhHant: "連線詳情", ja: "接続詳細", ms: "Butiran Sambungan")
    }
    public static var detailState: String {
        tr(en: "State", zhHans: "状态", zhHant: "狀態", ja: "状態", ms: "Keadaan")
    }
    public static var detailStatus: String {
        tr(en: "Status", zhHans: "详情", zhHant: "詳情", ja: "ステータス", ms: "Status")
    }
    public static var detailDevice: String {
        tr(en: "Device", zhHans: "设备", zhHant: "裝置", ja: "端末", ms: "Peranti")
    }
    public static var detailIp: String {
        tr(en: "IP", zhHans: "IP 地址", zhHant: "IP 位址", ja: "IP", ms: "IP")
    }
    public static var detailPort: String {
        tr(en: "Port", zhHans: "端口", zhHant: "連接埠", ja: "ポート", ms: "Port")
    }

    public static var liveDiagnosticsTitle: String {
        tr(en: "Live Diagnostics", zhHans: "实时诊断", zhHant: "即時診斷", ja: "ライブ診断", ms: "Diagnostik Langsung")
    }
    public static var copyToClipboard: String {
        tr(en: "Copy to Clipboard", zhHans: "复制到剪贴板", zhHant: "複製到剪貼簿", ja: "クリップボードにコピー", ms: "Salin ke Papan Keratan")
    }

    public static var exportShareLogsTitle: String {
        tr(en: "Export / Share Logs", zhHans: "导出 / 分享日志", zhHant: "匯出 / 分享日誌", ja: "ログの書き出し / 共有", ms: "Eksport / Kongsi Log")
    }
    public static var exportShareLogsMessage: String {
        tr(
            en: "Session diagnostic logs & audit reports.",
            zhHans: "会话诊断日志与链路审计报告。",
            zhHant: "工作階段診斷日誌與鏈路稽核報告。",
            ja: "セッション診断ログおよび監査レポートです。",
            ms: "Log diagnostik sesi & laporan audit."
        )
    }
    public static var copyLogToClipboard: String {
        tr(en: "Copy Log to Clipboard", zhHans: "复制日志到剪贴板", zhHant: "複製日誌到剪貼簿", ja: "ログをコピー", ms: "Salin Log ke Papan Keratan")
    }
    public static var shareLogFileTxt: String {
        tr(en: "Share Log File (.txt)", zhHans: "分享日志文件 (.txt)", zhHant: "分享日誌檔案 (.txt)", ja: "ログファイルを共有 (.txt)", ms: "Kongsi Fail Log (.txt)")
    }
    public static var clearInMemoryLogs: String {
        tr(en: "Clear In-Memory Logs", zhHans: "清除内存日志", zhHant: "清除記憶體日誌", ja: "メモリ内ログを消去", ms: "Kosongkan Log Dalam Memori")
    }

    public static var backupRestoreTitle: String {
        tr(en: "Backup / Restore Settings", zhHans: "备份 / 恢复设置", zhHant: "備份 / 還原設定", ja: "設定のバックアップ / 復元", ms: "Sandar / Pulih Tetapan")
    }
    public static var backupRestoreMessage: String {
        tr(
            en: "Export settings to JSON or restore from clipboard.",
            zhHans: "将当前配置导出为 JSON，或从剪贴板恢复配置。",
            zhHant: "將目前設定匯出為 JSON，或從剪貼簿還原設定。",
            ja: "設定を JSON として書き出すか、クリップボードから復元します。",
            ms: "Eksport tetapan ke JSON atau pulihkan daripada papan keratan."
        )
    }
    public static var copySettingsJsonToClipboard: String {
        tr(
            en: "Copy Settings JSON to Clipboard",
            zhHans: "复制配置 JSON 到剪贴板",
            zhHant: "複製設定 JSON 到剪貼簿",
            ja: "設定 JSON をコピー",
            ms: "Salin JSON Tetapan ke Papan Keratan"
        )
    }
    public static var restoreSettingsFromClipboard: String {
        tr(
            en: "Restore Settings from Clipboard",
            zhHans: "从剪贴板恢复设置",
            zhHant: "從剪貼簿還原設定",
            ja: "クリップボードから復元",
            ms: "Pulih Tetapan daripada Papan Keratan"
        )
    }
    public static var settingsExportedTitle: String {
        tr(en: "Settings Exported", zhHans: "配置已导出", zhHant: "設定已匯出", ja: "設定を書き出しました", ms: "Tetapan Dieksport")
    }
    public static var settingsExportedMessage: String {
        tr(
            en: "JSON settings copied to clipboard.",
            zhHans: "JSON 配置内容已复制到剪贴板。",
            zhHant: "JSON 設定內容已複製到剪貼簿。",
            ja: "設定の JSON をクリップボードにコピーしました。",
            ms: "Tetapan JSON disalin ke papan keratan."
        )
    }
    public static var restoreFailedTitle: String {
        tr(en: "Restore Failed", zhHans: "恢复失败", zhHant: "還原失敗", ja: "復元に失敗しました", ms: "Pemulihan Gagal")
    }
    public static var restoreFailedNoJson: String {
        tr(
            en: "Clipboard does not contain JSON text.",
            zhHans: "剪贴板中未包含有效的 JSON 文本。",
            zhHant: "剪貼簿中未包含有效的 JSON 文字。",
            ja: "クリップボードに JSON テキストがありません。",
            ms: "Papan keratan tidak mengandungi teks JSON."
        )
    }
    public static var settingsRestoredTitle: String {
        tr(en: "Settings Restored", zhHans: "配置已恢复", zhHant: "設定已還原", ja: "設定を復元しました", ms: "Tetapan Dipulihkan")
    }
    public static var settingsRestoredMessage: String {
        tr(
            en: "Preferences have been restored from clipboard.",
            zhHans: "已成功从剪贴板恢复全部配置偏好。",
            zhHant: "已成功從剪貼簿還原全部設定偏好。",
            ja: "クリップボードから設定を復元しました。",
            ms: "Keutamaan telah dipulihkan daripada papan keratan."
        )
    }
    public static var restoreErrorTitle: String {
        tr(en: "Restore Error", zhHans: "恢复错误", zhHant: "還原錯誤", ja: "復元エラー", ms: "Ralat Pemulihan")
    }

    public static var resetAllSettingsTitle: String {
        tr(en: "Reset All Settings", zhHans: "恢复全部默认设置", zhHant: "恢復全部預設設定", ja: "すべての設定をリセット", ms: "Tetapkan Semula Semua Tetapan")
    }
    public static var resetAllSettingsMessage: String {
        tr(
            en: "Are you sure you want to reset all projection preferences to factory defaults? This action cannot be undone.",
            zhHans: "确定要将所有投屏偏好设置重置为出厂默认值吗？此操作无法撤销。",
            zhHant: "確定要將所有投影偏好設定重設為出廠預設值嗎？此操作無法復原。",
            ja: "すべての投影設定を初期値にリセットしますか？この操作は取り消せません。",
            ms: "Adakah anda pasti mahu menetapkan semula semua keutamaan unjuran kepada lalai kilang? Tindakan ini tidak boleh dibuat asal."
        )
    }

    public static var diagnosticLogsClearedTitle: String {
        tr(en: "Diagnostic Logs Cleared", zhHans: "诊断日志已清空", zhHant: "診斷日誌已清除", ja: "診断ログを消去しました", ms: "Log Diagnostik Dikosongkan")
    }
    public static var diagnosticLogsClearedMessage: String {
        tr(
            en: "Memory buffer and disk logs have been emptied (0 entries).",
            zhHans: "内存缓冲与磁盘日志文件均已清空（0 条记录）。",
            zhHant: "記憶體緩衝與磁碟日誌檔案均已清除（0 筆記錄）。",
            ja: "メモリバッファとディスクログを空にしました（0 件）。",
            ms: "Penimbal memori dan log cakera telah dikosongkan (0 entri)."
        )
    }

    // MARK: - DebugLogCategoriesViewController
    public static var debugLogCategoriesTitle: String {
        tr(en: "Debug Log Categories", zhHans: "调试日志分类", zhHant: "除錯日誌分類", ja: "デバッグログカテゴリ", ms: "Kategori Log Nyahpepijat")
    }
    public static var enableAll: String {
        tr(en: "Enable All", zhHans: "全部开启", zhHant: "全部開啟", ja: "すべて有効", ms: "Aktifkan Semua")
    }
    public static var debugLogCategoriesFooter: String {
        tr(
            en: "Enabled categories emit structured telemetry to AppLog. Disabling unnecessary categories saves CPU overhead.",
            zhHans: "已启用的分类会向 AppLog 输出结构化遥测日志。关闭不需要的分类可降低 CPU 开销。",
            zhHant: "已啟用的分類會向 AppLog 輸出結構化遙測日誌。關閉不需要的分類可降低 CPU 開銷。",
            ja: "有効なカテゴリは構造化テレメトリを AppLog に記録します。不要なカテゴリを無効にすると CPU 負荷を軽減できます。",
            ms: "Kategori yang diaktifkan memancarkan telemetri berstruktur ke AppLog. Menyahdayakan kategori yang tidak perlu menjimatkan overhed CPU."
        )
    }

    // MARK: - DpiPreviewView
    public static var previewPortraitSplit: String {
        tr(
            en: "Portrait Coolwalk (Top Map + Lower Cards)",
            zhHans: "竖屏 Coolwalk（上方地图 + 下方卡片）",
            zhHant: "直向 Coolwalk（上方地圖 + 下方卡片）",
            ja: "縦向き Coolwalk（上地図 + 下カード）",
            ms: "Coolwalk Potret (Peta Atas + Kad Bawah)"
        )
    }
    public static var previewPortraitSingle: String {
        tr(
            en: "Portrait Single Card",
            zhHans: "竖屏单卡模式",
            zhHant: "直向單卡模式",
            ja: "縦向きシングルカード",
            ms: "Kad Tunggal Potret"
        )
    }
    public static var previewLandscapeSplit: String {
        tr(
            en: "Coolwalk Split Screen",
            zhHans: "Coolwalk 分屏布局",
            zhHant: "Coolwalk 分割畫面",
            ja: "Coolwalk 分割画面",
            ms: "Skrin Pisah Coolwalk"
        )
    }
    public static var previewLandscapeSingle: String {
        tr(
            en: "Single Card Compact",
            zhHans: "单卡紧凑模式",
            zhHant: "單卡緊湊模式",
            ja: "シングルカード（コンパクト）",
            ms: "Kad Tunggal Padat"
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
            ja: "有効: \(activeW)×\(activeH) (\(codecW)×\(codecH) 切抜) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            ms: "Aktif: \(activeW)×\(activeH) (\(codecW)×\(codecH) pangkas) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)"
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
            ja: "有効: \(activeW)×\(activeH) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)",
            ms: "Aktif: \(activeW)×\(activeH) • \(dpi) DPI (\(dpW)×\(dpH) dp) • \(layoutMode)"
        )
    }
}

extension UIViewController {
    func presentLanguagePicker(from sourceView: UIView) {
        let alert = UIAlertController(
            title: L10n.languagePickerTitle,
            message: L10n.languagePickerMessage,
            preferredStyle: .actionSheet
        )
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }

        let currentLang = ProjectionSettings.appLanguage
        for lang in AppLanguage.allCases {
            let isCurrent = (lang == currentLang)
            let displayTitle: String
            if lang == .system {
                displayTitle = "\(lang.title) (\(lang.resolved.shortBadgeTitle))"
            } else {
                displayTitle = lang.title
            }
            let prefix = isCurrent ? "✓ " : ""
            alert.addAction(UIAlertAction(title: "\(prefix)\(displayTitle)", style: .default) { _ in
                ProjectionSettings.appLanguage = lang
            })
        }

        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(alert, animated: true)
    }
}
