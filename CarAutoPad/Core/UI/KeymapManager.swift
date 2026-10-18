import UIKit

public enum AndroidKeyCode {
    public static let SOFT_LEFT = 1
    public static let SOFT_RIGHT = 2
    public static let HOME = 3
    public static let BACK = 4
    public static let DPAD_UP = 19
    public static let DPAD_DOWN = 20
    public static let DPAD_LEFT = 21
    public static let DPAD_RIGHT = 22
    public static let DPAD_CENTER = 23
    public static let TAB = 61
    public static let SEARCH = 84
    public static let MEDIA_PLAY_PAUSE = 85
    public static let MEDIA_STOP = 86
    public static let MEDIA_NEXT = 87
    public static let MEDIA_PREVIOUS = 88
}

public enum KeymapManager {

    public static func androidKeyCode(for hidUsage: UIKeyboardHIDUsage) -> Int? {
        switch hidUsage {
        case .keyboardUpArrow:
            return AndroidKeyCode.DPAD_UP
        case .keyboardDownArrow:
            return AndroidKeyCode.DPAD_DOWN
        case .keyboardLeftArrow:
            return AndroidKeyCode.DPAD_LEFT
        case .keyboardRightArrow:
            return AndroidKeyCode.DPAD_RIGHT
        case .keyboardReturnOrEnter, .keypadEnter:
            return AndroidKeyCode.DPAD_CENTER
        case .keyboardEscape:
            return AndroidKeyCode.BACK
        case .keyboardHome, .keyboardH:
            return AndroidKeyCode.HOME
        case .keyboardSpacebar:
            return AndroidKeyCode.MEDIA_PLAY_PAUSE
        case .keyboardN, .keyboardF9:
            return AndroidKeyCode.MEDIA_NEXT
        case .keyboardP, .keyboardF7:
            return AndroidKeyCode.MEDIA_PREVIOUS
        case .keyboardS, .keyboardF8:
            return AndroidKeyCode.MEDIA_STOP
        case .keyboardV, .keyboardF:
            return AndroidKeyCode.SEARCH
        case .keyboardOpenBracket:
            return AndroidKeyCode.SOFT_LEFT
        case .keyboardCloseBracket:
            return AndroidKeyCode.SOFT_RIGHT
        case .keyboardTab:
            return AndroidKeyCode.TAB
        default:
            return nil
        }
    }

    public static func androidKeyCode(for press: UIPress) -> Int? {
        if let key = press.key {
            if let code = androidKeyCode(for: key.keyCode) {
                return code
            }
            switch key.charactersIgnoringModifiers.lowercased() {
            case "h": return AndroidKeyCode.HOME
            case " ": return AndroidKeyCode.MEDIA_PLAY_PAUSE
            case "n": return AndroidKeyCode.MEDIA_NEXT
            case "p": return AndroidKeyCode.MEDIA_PREVIOUS
            case "s": return AndroidKeyCode.MEDIA_STOP
            case "v", "f": return AndroidKeyCode.SEARCH
            case "[": return AndroidKeyCode.SOFT_LEFT
            case "]": return AndroidKeyCode.SOFT_RIGHT
            case "\r", "\n": return AndroidKeyCode.DPAD_CENTER
            case "\t": return AndroidKeyCode.TAB
            default: break
            }
        }
        return nil
    }
}
