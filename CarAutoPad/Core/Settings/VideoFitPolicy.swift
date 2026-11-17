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
            return L10n.fitContainTitle
        case .fill:
            return L10n.fitFillTitle
        case .cover:
            return L10n.fitCoverTitle
        case .fillMargin:
            return L10n.fitFillMarginTitle
        case .stretch:
            return L10n.fitStretchTitle
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
