import Foundation

public enum VideoFitMode: Int, CaseIterable {
    case contain = 0
    case fill = 1
    case cover = 2
    case fillMargin = 3
    case stretch = 4

    public static let fit = VideoFitMode.contain

    public var title: String {
        switch self {
        case .contain:
            return "Fit (Letterbox)"
        case .fill:
            return "Fill (PAR)"
        case .cover:
            return "Cover (Crop)"
        case .fillMargin:
            return "Fill Margin (iPad Fullscreen)"
        case .stretch:
            return "Stretch"
        }
    }
}

public enum VideoFitPolicy {
    public static func resolve(storedFitMode: Int?) -> VideoFitMode {
        guard let raw = storedFitMode, let mode = VideoFitMode(rawValue: raw) else {
            return .fillMargin
        }
        return mode
    }
}
