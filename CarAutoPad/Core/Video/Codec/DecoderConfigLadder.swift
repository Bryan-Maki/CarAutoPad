import Foundation

public enum DecoderConfigLadder {

    public struct Tier: Equatable {
        public let label: String
        public let lowLatency: Bool
        public let realtime: Bool

        public init(label: String, lowLatency: Bool, realtime: Bool) {
            self.label = label
            self.lowLatency = lowLatency
            self.realtime = realtime
        }
    }

    public static let noOptionalKeys = Tier(label: "none", lowLatency: false, realtime: false)
    public static let lowLatencyTier = Tier(label: "low-latency", lowLatency: true, realtime: true)
    public static let realtimeTier = Tier(label: "realtime", lowLatency: false, realtime: true)

    public static func tiers(lowLatencyRequested: Bool) -> [Tier] {
        if !lowLatencyRequested {
            return [noOptionalKeys]
        }
        return [lowLatencyTier, realtimeTier, noOptionalKeys]
    }

    public static func fallbackResolution(currentWidth: Int, currentHeight: Int) -> (width: Int, height: Int)? {
        if currentWidth >= 3840 || currentHeight >= 2160 {
            return (2560, 1440)
        } else if currentWidth >= 2560 || currentHeight >= 1440 {
            return (1920, 1080)
        } else if currentWidth >= 1920 || currentHeight >= 1080 {
            return (1280, 720)
        } else if currentWidth > 1280 || currentHeight > 720 {
            return (1280, 720)
        }
        return nil
    }

    public static func fallbackPreset(from preset: ResolutionPreset, currentWidth: Int = 0, currentHeight: Int = 0) -> ResolutionPreset? {
        switch preset {
        case .r3840x2160:
            return .r2560x1440
        case .r2560x1440:
            return .r1920x1080
        case .r1920x1080:
            return .r1280x720
        case .r1280x720:
            return .r800x480
        case .r800x480:
            return nil
        case .auto:
            if currentWidth >= 3840 || currentHeight >= 2160 {
                return .r2560x1440
            } else if currentWidth >= 2560 || currentHeight >= 1440 {
                return .r1920x1080
            } else if currentWidth >= 1920 || currentHeight >= 1080 {
                return .r1280x720
            } else if currentWidth > 800 || currentHeight > 480 {
                return .r800x480
            }
            return nil
        }
    }
}
