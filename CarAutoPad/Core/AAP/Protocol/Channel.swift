import Foundation

enum Channel {
    static let ID_CTR: UInt8 = 0
    static let ID_SEN: UInt8 = 1
    static let ID_VID: UInt8 = 2
    static let ID_INP: UInt8 = 3
    static let ID_AUD: UInt8 = 6
    static let ID_AU1: UInt8 = 4
    static let ID_AU2: UInt8 = 5
    static let ID_MED: UInt8 = ID_AUD
    static let ID_GUD: UInt8 = ID_AU1
    static let ID_SYS: UInt8 = ID_AU2
    static let ID_MIC: UInt8 = 7
    static let ID_BTH: UInt8 = 8
    static let ID_MPB: UInt8 = 9
    static let ID_NAV: UInt8 = 10
    static let ID_NOT: UInt8 = 11
    static let ID_PHONE: UInt8 = 12
    static let ID_WIFI: UInt8 = 13

    static func name(for channel: UInt8) -> String {
        switch channel {
        case ID_CTR: return "CONTROL"
        case ID_SEN: return "SENSOR"
        case ID_VID: return "VIDEO"
        case ID_INP: return "INPUT"
        case ID_AUD, ID_AU1, ID_AU2: return "AUDIO"
        case ID_MIC: return "MIC"
        case ID_BTH: return "BLUETOOTH"
        case ID_MPB: return "MEDIA_PLAYBACK"
        case ID_NAV: return "NAVIGATION"
        case ID_NOT: return "NOTIFICATION"
        case ID_PHONE: return "PHONE"
        case ID_WIFI: return "WIFI"
        default: return "UNKNOWN(\(channel))"
        }
    }

    static func name(for channel: Int) -> String {
        return name(for: UInt8(channel & 0xFF))
    }

    static func isAudio(_ channel: UInt8) -> Bool {
        return channel == ID_AUD || channel == ID_AU1 || channel == ID_AU2
    }
}
