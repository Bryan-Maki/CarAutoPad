import Foundation

public final class AudioSinkAnnouncementPolicy {
    public init() {}

    public static func announcesMediaAndSpeech(sinkEnabled: Bool, isSelfModeSession: Bool = false) -> Bool {
        return sinkEnabled && !isSelfModeSession
    }

    public func supportedCodecs(for preference: AudioCodecPreference, channel: Int) -> [AudioSinkCodec] {
        switch preference {
        case .pcm:
            return [.pcm]
        case .aac:
            return [.aacLc, .aacLcAdts]
        }
    }
}
