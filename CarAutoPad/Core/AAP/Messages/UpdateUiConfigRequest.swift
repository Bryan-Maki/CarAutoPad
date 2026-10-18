import Foundation

public final class UpdateUiConfigRequest {
    public static func make(left: Int, top: Int, right: Int, bottom: Int, uiTheme: Int32? = nil) -> AapMessage {
        let insets = MediaInsets(
            top: Int32(top),
            bottom: Int32(bottom),
            left: Int32(left),
            right: Int32(right)
        )
        let uiConfig = UiConfig(margins: insets, uiTheme: nil)
        let requestProto = UpdateUiConfigRequestProto(uiConfig: uiConfig)

        return AapMessage(
            channel: Int(Channel.ID_VID),
            type: Int(MediaMsgType.mediaMessageUpdateUiConfigRequest.rawValue),
            proto: requestProto
        )
    }
}
