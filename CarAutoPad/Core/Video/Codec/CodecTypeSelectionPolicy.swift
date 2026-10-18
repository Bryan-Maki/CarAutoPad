import Foundation

public enum VideoCodecType: String, CaseIterable, Codable {
    case h264 = "H.264"
    case hevc = "H.265 (HEVC)"
}

public enum VideoCodecPreference: String, CaseIterable, Codable {
    case h264 = "H.264"
    case hevc = "HEVC (H.265)"

    public var title: String {
        return rawValue
    }

    public var effectiveCodecType: VideoCodecType? {
        switch self {
        case .h264: return .h264
        case .hevc: return .hevc
        }
    }
}

public enum CodecTypeSelectionPolicy {
    public static func select(
        detected: VideoCodecType?,
        requested: VideoCodecType,
        hevcDetectable: BooleanLiteralType,
        hevcUsable: BooleanLiteralType
    ) -> VideoCodecType {
        if !hevcUsable {
            return .h264
        }

        if let detected = detected, hevcDetectable {
            return detected
        }

        return requested
    }
}
