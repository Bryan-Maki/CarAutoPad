import Foundation

public enum AudioSinkCodec: Equatable, Sendable {
    case pcm
    case aacLc
    case aacLcAdts

    public var isAac: BooleanLiteralType {
        switch self {
        case .pcm:
            return false
        case .aacLc, .aacLcAdts:
            return true
        }
    }
}
