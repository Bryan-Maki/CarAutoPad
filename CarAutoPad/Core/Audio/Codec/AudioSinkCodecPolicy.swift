import Foundation

public enum AudioSinkCodecPolicy {
    public static func codec(for setupType: Int) -> AudioSinkCodec? {
        switch setupType {
        case 1:
            return .pcm
        case 2:
            return .aacLc
        case 3, 4:
            return .aacLcAdts
        default:
            return nil
        }
    }

    public static func codec(for codecType: MediaCodecType) -> AudioSinkCodec? {
        switch codecType {
        case .mediaCodecAudioPcm:
            return .pcm
        case .mediaCodecAudioAacLc:
            return .aacLc
        case .mediaCodecAudioAacLcAdts:
            return .aacLcAdts
        default:
            return nil
        }
    }

    public static func codec(forWireValue value: Int) -> AudioSinkCodec {
        switch value {
        case 1:
            return .aacLc
        case 2:
            return .aacLcAdts
        default:
            return .pcm
        }
    }

    public static func wireValue(forCodec codec: AudioSinkCodec) -> Int {
        switch codec {
        case .pcm:
            return 0
        case .aacLc:
            return 1
        case .aacLcAdts:
            return 2
        }
    }
}
