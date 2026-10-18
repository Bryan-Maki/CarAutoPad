import Foundation

public final class AapVideoFocusEventMessage {
    public static func make(gain: Bool, unsolicited: Bool) -> AapMessage {
        let notification = VideoFocusNotification(
            mode: gain ? .videoFocusProjected : .videoFocusNative,
            unsolicited: unsolicited
        )

        return AapMessage(
            channel: Int(Channel.ID_VID),
            type: Int(MediaMsgType.mediaMessageVideoFocusNotification.rawValue),
            proto: notification
        )
    }
}
