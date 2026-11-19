import UIKit

public enum CarAutoPadTheme {
    // Pure Apple neutral dark/light elevation tokens (strictly matching Figma 00)
    public static let canvas = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 11.0 / 255.0, green: 11.0 / 255.0, blue: 13.0 / 255.0, alpha: 1.0) // #0B0B0D
            : UIColor.systemGroupedBackground
    }

    public static let sidebar = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 20.0 / 255.0, green: 20.0 / 255.0, blue: 22.0 / 255.0, alpha: 1.0) // #141416
            : UIColor.secondarySystemGroupedBackground
    }

    public static let card = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0, alpha: 1.0) // #1C1C1E
            : UIColor.secondarySystemGroupedBackground
    }

    public static let elevated = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 38.0 / 255.0, green: 38.0 / 255.0, blue: 41.0 / 255.0, alpha: 1.0) // #262629
            : UIColor.tertiarySystemFill
    }

    public static let pill = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 44.0 / 255.0, green: 44.0 / 255.0, blue: 46.0 / 255.0, alpha: 1.0) // #2C2C2E
            : UIColor.secondarySystemFill
    }

    public static let sidebarSelected = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.11)
            : UIColor.black.withAlphaComponent(0.07)
    }

    public static let edgeDivider = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.separator
    }

    public static let hairline = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 84.0 / 255.0, green: 84.0 / 255.0, blue: 88.0 / 255.0, alpha: 0.65)
            : UIColor.separator
    }

    public static let warningSurface = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 44.0 / 255.0, green: 34.0 / 255.0, blue: 20.0 / 255.0, alpha: 1.0) // #2C2214
            : UIColor(red: 1.0, green: 0.957, blue: 0.898, alpha: 1.0)
    }

    public static let warningTitle = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 213.0 / 255.0, blue: 153.0 / 255.0, alpha: 1.0) // #FFD599
            : UIColor(red: 0.60, green: 0.35, blue: 0.0, alpha: 1.0)
    }

    public static let accentBlue = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 10.0 / 255.0, green: 132.0 / 255.0, blue: 1.0, alpha: 1.0) // #0A84FF
            : UIColor.systemBlue
    }

    public static let accentGreen = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 48.0 / 255.0, green: 209.0 / 255.0, blue: 88.0 / 255.0, alpha: 1.0) // #30D158
            : UIColor.systemGreen
    }

    public static let accentOrange = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 159.0 / 255.0, blue: 10.0 / 255.0, alpha: 1.0) // #FF9F0A
            : UIColor.systemOrange
    }

    public static let accentRed = UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 69.0 / 255.0, blue: 58.0 / 255.0, alpha: 1.0) // #FF453A
            : UIColor.systemRed
    }

    public static let lockedAlpha: CGFloat = 0.44

    public static func makeCard(cornerRadius: CGFloat = 22) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = card
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }

    public static func makeHairline(leadingInset: CGFloat = 0) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = hairline
        container.addSubview(line)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 0.5),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: leadingInset),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }

    public static func makeSectionHeaderLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        return label
    }

    public static func makeFooterLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0
        return label
    }

    public static func makePageTitleLabel(_ text: String, size: CGFloat = 30) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: size, weight: .bold)
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        return label
    }

    public static func styleSegmentedControl(_ control: UISegmentedControl) {
        control.apportionsSegmentWidthsByContent = true
        control.backgroundColor = elevated
        control.selectedSegmentTintColor = UIColor { tc in
            tc.userInterfaceStyle == .dark
                ? UIColor(red: 58.0 / 255.0, green: 58.0 / 255.0, blue: 60.0 / 255.0, alpha: 1.0)
                : UIColor.systemBackground
        }
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.systemFont(ofSize: 12, weight: .regular)
        ], for: .normal)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ], for: .selected)
    }

    public static func makeLiquidGlassCircleButton(
        symbolName: String,
        size: CGFloat = 34,
        pointSize: CGFloat = 15,
        accessibilityIdentifier: String? = nil
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = accessibilityIdentifier
        button.layer.cornerRadius = size / 2.0
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true
        button.layer.borderWidth = 0.75
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = false
        button.insertSubview(blur, at: 0)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: size),
            button.heightAnchor.constraint(equalToConstant: size),
            blur.topAnchor.constraint(equalTo: button.topAnchor),
            blur.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: button.trailingAnchor)
        ])

        let cfg = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        button.setImage(UIImage(systemName: symbolName, withConfiguration: cfg), for: .normal)
        button.tintColor = .label
        if let imageView = button.imageView {
            button.bringSubviewToFront(imageView)
        }
        return button
    }
}

public enum CarAutoPadDeviceInfo {
    public static var appName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "CarAutoPad"
    }

    public static var appVersionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.5.3"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    public static var deviceModelDisplayName: String {
        let screen = UIScreen.main
        let nativeW = Int((screen.nativeBounds.width).rounded())
        let nativeH = Int((screen.nativeBounds.height).rounded())
        let family = HeadUnitScreenConfig.detectModelFamily(panelW: nativeW, panelH: nativeH)
        if family != .genericIpad {
            return family.displayName
        }
        return UIDevice.current.model
    }

    public static var osVersionDisplayName: String {
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    public static var screenSpecDisplayName: String {
        let screen = UIScreen.main
        let longEdge = Int(max(screen.nativeBounds.width, screen.nativeBounds.height).rounded())
        let shortEdge = Int(min(screen.nativeBounds.width, screen.nativeBounds.height).rounded())
        let fps = screen.maximumFramesPerSecond
        return "\(longEdge) × \(shortEdge) · \(fps)Hz"
    }

    public static var localIpDisplayName: String {
        return NetworkAddresses.currentWifiIPv4Address() ?? L10n.noWifiText
    }
}
