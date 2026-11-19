import UIKit

/// Design tokens and Liquid Glass components aligned with the Figma `iOS and iPadOS 27` library.
public enum IOS27Theme {

    // MARK: - Dimensions
    public static let largeGlassCornerRadius: CGFloat = 26.0
    public static let mediumGlassCornerRadius: CGFloat = 20.0
    public static let smallGlassCornerRadius: CGFloat = 14.0
    public static let sheetCornerRadius: CGFloat = 28.0
    public static let popoverCornerRadius: CGFloat = 22.0
    public static let grabberSize = CGSize(width: 36.0, height: 5.0)

    // MARK: - Accents (Figma Color Scheme -> Accents/*)
    public static let accentBlue = UIColor.systemBlue
    public static let accentIndigo = UIColor.systemIndigo
    public static let accentPurple = UIColor.systemPurple
    public static let accentPink = UIColor.systemPink
    public static let accentTeal = UIColor.systemTeal
    public static let accentGreen = UIColor.systemGreen
    public static let accentOrange = UIColor.systemOrange
    public static let accentRed = UIColor.systemRed

    // MARK: - Vibrant Fills & Glass Surfaces (Figma Color Scheme -> Fills - Vibrant/*)
    public static let vibrantPrimaryFill = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.14)
            : UIColor.white.withAlphaComponent(0.76)
    }

    public static let vibrantSecondaryFill = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.white.withAlphaComponent(0.56)
    }

    public static let vibrantTertiaryFill = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.05)
            : UIColor.black.withAlphaComponent(0.045)
    }

    public static let recessedFieldFill = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.09, blue: 0.13, alpha: 0.72)
            : UIColor.white.withAlphaComponent(0.72)
    }

    public static let groupedBackdropColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1.0)
            : UIColor(red: 0.94, green: 0.95, blue: 0.98, alpha: 1.0)
    }

    public static let groupedElevatedCellBackground = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.14, blue: 0.19, alpha: 0.92)
            : UIColor.white.withAlphaComponent(0.92)
    }

    public static let vibrantSeparatorColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.14)
            : UIColor.black.withAlphaComponent(0.09)
    }

    public static let segmentedSelectedFill = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.24, green: 0.27, blue: 0.35, alpha: 0.95)
            : UIColor.white
    }

    public static func glassRimColors(isDark: Bool) -> [CGColor] {
        if isDark {
            return [
                UIColor.white.withAlphaComponent(0.32).cgColor,
                UIColor.white.withAlphaComponent(0.08).cgColor,
                UIColor.white.withAlphaComponent(0.18).cgColor
            ]
        } else {
            return [
                UIColor.white.withAlphaComponent(0.92).cgColor,
                UIColor.white.withAlphaComponent(0.38).cgColor,
                UIColor.black.withAlphaComponent(0.08).cgColor
            ]
        }
    }

    // MARK: - Control Styling Helpers
    public static func styleSegmentedControl(_ seg: UISegmentedControl) {
        seg.apportionsSegmentWidthsByContent = true
        seg.backgroundColor = vibrantTertiaryFill
        seg.selectedSegmentTintColor = segmentedSelectedFill
        seg.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 12.5, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ], for: .normal)
        seg.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 12.5, weight: .bold),
            .foregroundColor: UIColor.label
        ], for: .selected)
    }

    public static func styleSlider(_ slider: UISlider, accent: UIColor = .systemBlue) {
        slider.minimumTrackTintColor = accent
        slider.maximumTrackTintColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.16)
                : UIColor.black.withAlphaComponent(0.10)
        }
        slider.thumbTintColor = .white
    }

    public static func styleSwitch(_ toggle: UISwitch, accent: UIColor = .systemGreen) {
        toggle.onTintColor = accent
    }

    public static func makeAudioChannelGlassCard(
        iconName: String,
        iconColor: UIColor,
        titleLabel: UILabel,
        title: String,
        toggle: UISwitch,
        slider: UISlider,
        valueLabel: UILabel,
        onTone: @escaping () -> Void
    ) -> IOS27GlassCardView {
        let card = IOS27GlassCardView(style: .small, cornerRadius: 15, tintColor: iconColor)
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6
        container.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.spacing = 10
        topRow.alignment = .center

        let iconBadge = IOS27IconBadgeView(iconName: iconName, tint: iconColor, size: 28, cornerRadius: 8, symbolPointSize: 13)

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        var toneConfig = UIButton.Configuration.tinted()
        toneConfig.title = "♫"
        toneConfig.cornerStyle = .capsule
        toneConfig.buttonSize = .mini
        toneConfig.baseBackgroundColor = iconColor.withAlphaComponent(0.16)
        toneConfig.baseForegroundColor = iconColor
        let toneButton = UIButton(configuration: toneConfig)
        toneButton.setContentHuggingPriority(.required, for: .horizontal)
        toneButton.addAction(UIAction { _ in onTone() }, for: .touchUpInside)

        styleSwitch(toggle, accent: iconColor)

        topRow.addArrangedSubview(iconBadge)
        topRow.addArrangedSubview(titleLabel)
        topRow.addArrangedSubview(toneButton)
        topRow.addArrangedSubview(toggle)

        let sliderRow = UIStackView()
        sliderRow.axis = .horizontal
        sliderRow.spacing = 10
        sliderRow.alignment = .center

        slider.minimumValue = 0.0
        slider.maximumValue = ProjectionSettings.maxChannelVolume
        styleSlider(slider, accent: iconColor)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: 52).isActive = true

        sliderRow.addArrangedSubview(slider)
        sliderRow.addArrangedSubview(valueLabel)

        container.addArrangedSubview(topRow)
        container.addArrangedSubview(sliderRow)
        card.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            container.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            container.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            container.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12)
        ])
        return card
    }
}

/// Ambient automotive backdrop providing optical depth behind iOS 27 Liquid Glass layers.
public final class IOS27AmbientBackgroundView: UIView {

    private let baseGradientLayer = CAGradientLayer()
    private let topLeftGlowLayer = CAGradientLayer()
    private let bottomRightGlowLayer = CAGradientLayer()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        isUserInteractionEnabled = false
        layer.addSublayer(baseGradientLayer)
        layer.addSublayer(topLeftGlowLayer)
        layer.addSublayer(bottomRightGlowLayer)

        topLeftGlowLayer.type = .radial
        topLeftGlowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        topLeftGlowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)

        bottomRightGlowLayer.type = .radial
        bottomRightGlowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        bottomRightGlowLayer.endPoint = CGPoint(x: 1.0, y: 1.0)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] _, _ in
            self?.updatePalette()
        }
        updatePalette()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        baseGradientLayer.frame = bounds

        let glowSize = max(bounds.width, bounds.height) * 0.72
        topLeftGlowLayer.frame = CGRect(
            x: -glowSize * 0.28,
            y: -glowSize * 0.30,
            width: glowSize,
            height: glowSize
        )
        bottomRightGlowLayer.frame = CGRect(
            x: bounds.width - glowSize * 0.70,
            y: bounds.height - glowSize * 0.65,
            width: glowSize,
            height: glowSize
        )
        CATransaction.commit()
    }

    private func updatePalette() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if isDark {
            baseGradientLayer.colors = [
                UIColor(red: 0.045, green: 0.055, blue: 0.090, alpha: 1.0).cgColor,
                UIColor(red: 0.065, green: 0.075, blue: 0.115, alpha: 1.0).cgColor,
                UIColor(red: 0.040, green: 0.045, blue: 0.070, alpha: 1.0).cgColor
            ]
            topLeftGlowLayer.colors = [
                UIColor(red: 0.08, green: 0.40, blue: 0.88, alpha: 0.24).cgColor,
                UIColor(red: 0.08, green: 0.40, blue: 0.88, alpha: 0.0).cgColor
            ]
            bottomRightGlowLayer.colors = [
                UIColor(red: 0.36, green: 0.25, blue: 0.85, alpha: 0.20).cgColor,
                UIColor(red: 0.36, green: 0.25, blue: 0.85, alpha: 0.0).cgColor
            ]
        } else {
            baseGradientLayer.colors = [
                UIColor(red: 0.935, green: 0.955, blue: 0.990, alpha: 1.0).cgColor,
                UIColor(red: 0.955, green: 0.965, blue: 0.985, alpha: 1.0).cgColor,
                UIColor(red: 0.920, green: 0.940, blue: 0.975, alpha: 1.0).cgColor
            ]
            topLeftGlowLayer.colors = [
                UIColor(red: 0.24, green: 0.60, blue: 1.00, alpha: 0.16).cgColor,
                UIColor(red: 0.24, green: 0.60, blue: 1.00, alpha: 0.0).cgColor
            ]
            bottomRightGlowLayer.colors = [
                UIColor(red: 0.42, green: 0.38, blue: 0.96, alpha: 0.13).cgColor,
                UIColor(red: 0.42, green: 0.38, blue: 0.96, alpha: 0.0).cgColor
            ]
        }
        baseGradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        baseGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        CATransaction.commit()
    }
}

/// Liquid Glass container matching Figma `Liquid Glass - Regular - Large / Medium / Small / Clear`.
public final class IOS27GlassCardView: UIView {

    public enum GlassStyle {
        case large
        case medium
        case small
        case clear
        case capsule

        var defaultCornerRadius: CGFloat {
            switch self {
            case .large: return IOS27Theme.largeGlassCornerRadius
            case .medium: return IOS27Theme.mediumGlassCornerRadius
            case .small: return IOS27Theme.smallGlassCornerRadius
            case .clear: return 16.0
            case .capsule: return 17.0
            }
        }

        var blurStyle: UIBlurEffect.Style {
            switch self {
            case .clear: return .systemUltraThinMaterial
            case .large, .medium, .small, .capsule: return .systemThinMaterial
            }
        }
    }

    public let glassStyle: GlassStyle
    public var customCornerRadius: CGFloat? {
        didSet { setNeedsLayout() }
    }
    public var glassTintColor: UIColor? {
        didSet { updateAppearance() }
    }

    private let clippedContainer = UIView()
    private let blurView: UIVisualEffectView
    private let tintOverlayView = UIView()
    private let specularBorderLayer = CAGradientLayer()
    private let specularMaskLayer = CAShapeLayer()

    public init(style: GlassStyle = .medium, cornerRadius: CGFloat? = nil, tintColor: UIColor? = nil) {
        self.glassStyle = style
        self.customCornerRadius = cornerRadius
        self.glassTintColor = tintColor
        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: style.blurStyle))
        super.init(frame: .zero)
        setupGlassLayers()
    }

    public required init?(coder: NSCoder) {
        self.glassStyle = .medium
        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        super.init(coder: coder)
        setupGlassLayers()
    }

    private func effectiveCornerRadius(for bounds: CGRect) -> CGFloat {
        if glassStyle == .capsule && bounds.height > 0 {
            return bounds.height / 2.0
        }
        return customCornerRadius ?? glassStyle.defaultCornerRadius
    }

    private func setupGlassLayers() {
        backgroundColor = .clear
        layer.masksToBounds = false

        clippedContainer.isUserInteractionEnabled = false
        clippedContainer.clipsToBounds = true
        clippedContainer.layer.cornerCurve = .continuous
        clippedContainer.translatesAutoresizingMaskIntoConstraints = false

        blurView.isUserInteractionEnabled = false
        blurView.translatesAutoresizingMaskIntoConstraints = false

        tintOverlayView.isUserInteractionEnabled = false
        tintOverlayView.translatesAutoresizingMaskIntoConstraints = false

        clippedContainer.addSubview(blurView)
        clippedContainer.addSubview(tintOverlayView)
        addSubview(clippedContainer)

        NSLayoutConstraint.activate([
            clippedContainer.topAnchor.constraint(equalTo: topAnchor),
            clippedContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            clippedContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            clippedContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            blurView.topAnchor.constraint(equalTo: clippedContainer.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: clippedContainer.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: clippedContainer.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: clippedContainer.bottomAnchor),

            tintOverlayView.topAnchor.constraint(equalTo: clippedContainer.topAnchor),
            tintOverlayView.leadingAnchor.constraint(equalTo: clippedContainer.leadingAnchor),
            tintOverlayView.trailingAnchor.constraint(equalTo: clippedContainer.trailingAnchor),
            tintOverlayView.bottomAnchor.constraint(equalTo: clippedContainer.bottomAnchor)
        ])

        specularBorderLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        specularBorderLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        specularBorderLayer.locations = [0.0, 0.45, 1.0]
        specularMaskLayer.fillColor = nil
        specularMaskLayer.strokeColor = UIColor.white.cgColor
        specularMaskLayer.lineWidth = 1.0
        specularBorderLayer.mask = specularMaskLayer
        clippedContainer.layer.addSublayer(specularBorderLayer)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] _, _ in
            self?.updateAppearance()
        }
        updateAppearance()
    }

    public override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        if subview !== clippedContainer {
            sendSubviewToBack(clippedContainer)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let radius = effectiveCornerRadius(for: bounds)
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        clippedContainer.layer.cornerRadius = radius

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        specularBorderLayer.frame = clippedContainer.bounds
        let insetRect = clippedContainer.bounds.insetBy(dx: 0.5, dy: 0.5)
        if insetRect.width > 0 && insetRect.height > 0 {
            let strokePath = UIBezierPath(roundedRect: insetRect, cornerRadius: max(0, radius - 0.5))
            specularMaskLayer.path = strokePath.cgPath
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        }
        CATransaction.commit()
    }

    private func updateAppearance() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        if let tint = glassTintColor {
            tintOverlayView.backgroundColor = tint.withAlphaComponent(isDark ? 0.16 : 0.12)
        } else {
            switch glassStyle {
            case .clear:
                tintOverlayView.backgroundColor = isDark
                    ? UIColor.white.withAlphaComponent(0.05)
                    : UIColor.white.withAlphaComponent(0.35)
            case .large, .medium, .small, .capsule:
                tintOverlayView.backgroundColor = isDark
                    ? UIColor(red: 0.11, green: 0.13, blue: 0.18, alpha: 0.46)
                    : UIColor.white.withAlphaComponent(0.48)
            }
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        specularBorderLayer.colors = IOS27Theme.glassRimColors(isDark: isDark)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: glassStyle == .large ? 10 : 6)
        layer.shadowRadius = glassStyle == .large ? 22 : 14
        layer.shadowOpacity = isDark ? 0.34 : 0.08
        CATransaction.commit()
    }
}

/// iOS 27 tinted glass icon badge with subtle specular rim.
public final class IOS27IconBadgeView: UIView {

    private let iconImageView = UIImageView()
    private var badgeTint: UIColor
    private let badgeSize: CGFloat
    private let symbolPointSize: CGFloat

    public init(
        iconName: String,
        tint: UIColor,
        size: CGFloat = 38,
        cornerRadius: CGFloat = 11,
        symbolPointSize: CGFloat = 18
    ) {
        self.badgeTint = tint
        self.badgeSize = size
        self.symbolPointSize = symbolPointSize
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 0.8

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        addSubview(iconImageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: badgeSize),
            heightAnchor.constraint(equalToConstant: badgeSize),
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(lessThanOrEqualToConstant: badgeSize * 0.65),
            iconImageView.heightAnchor.constraint(lessThanOrEqualToConstant: badgeSize * 0.65)
        ])

        setIcon(iconName, tint: tint)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] _, _ in
            self?.refreshColors()
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setIcon(_ iconName: String, tint: UIColor) {
        self.badgeTint = tint
        let cfg = UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .semibold)
        iconImageView.image = UIImage(systemName: iconName, withConfiguration: cfg)
        refreshColors()
    }

    private func refreshColors() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundColor = badgeTint.withAlphaComponent(isDark ? 0.22 : 0.14)
        layer.borderColor = badgeTint.withAlphaComponent(isDark ? 0.42 : 0.26).cgColor
        iconImageView.tintColor = badgeTint
    }
}

/// Top grabber bar aligned with Figma `Sheet - iPad` / `Grabber` (`36×5pt`).
public final class IOS27SheetGrabberView: UIView {

    private let pillView = UIView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        pillView.translatesAutoresizingMaskIntoConstraints = false
        pillView.backgroundColor = .tertiaryLabel
        pillView.layer.cornerRadius = IOS27Theme.grabberSize.height / 2.0
        pillView.layer.cornerCurve = .continuous
        addSubview(pillView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 12),
            pillView.centerXAnchor.constraint(equalTo: centerXAnchor),
            pillView.centerYAnchor.constraint(equalTo: centerYAnchor),
            pillView.widthAnchor.constraint(equalToConstant: IOS27Theme.grabberSize.width),
            pillView.heightAnchor.constraint(equalToConstant: IOS27Theme.grabberSize.height)
        ])
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Horizontal Liquid Glass capsule navigation bar for jumping between settings categories.
public final class IOS27MenuCategoryBar: UIView {

    public struct CategoryItem: Equatable {
        public let section: Int
        public let title: String
        public let iconName: String
        public let tint: UIColor

        public init(section: Int, title: String, iconName: String, tint: UIColor) {
            self.section = section
            self.title = title
            self.iconName = iconName
            self.tint = tint
        }
    }

    public var onSelectSection: ((Int) -> Void)?
    public private(set) var selectedSection: Int = 0
    private var items: [CategoryItem] = []

    private let glassContainer = IOS27GlassCardView(style: .small, cornerRadius: 18)
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceHorizontal = true
        return sv
    }()
    private let pillsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    private var buttonsBySection: [Int: UIButton] = [:]

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = .clear
        glassContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glassContainer)
        glassContainer.addSubview(scrollView)
        scrollView.addSubview(pillsStack)

        NSLayoutConstraint.activate([
            glassContainer.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            glassContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            glassContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            glassContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: glassContainer.topAnchor, constant: 6),
            scrollView.bottomAnchor.constraint(equalTo: glassContainer.bottomAnchor, constant: -6),
            scrollView.leadingAnchor.constraint(equalTo: glassContainer.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: glassContainer.trailingAnchor, constant: -8),

            pillsStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            pillsStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            pillsStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            pillsStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            pillsStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] _, _ in
            self?.updateSelectionVisuals()
        }
    }

    public func configure(items: [CategoryItem], selectedSection: Int) {
        self.items = items
        self.selectedSection = selectedSection
        buttonsBySection.removeAll()
        for view in pillsStack.arrangedSubviews {
            pillsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for item in items {
            let button = UIButton(type: .system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.accessibilityIdentifier = "categoryPill_\(item.section)"
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.setContentHuggingPriority(.required, for: .horizontal)

            var config = UIButton.Configuration.tinted()
            config.title = item.title
            config.image = UIImage(
                systemName: item.iconName,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            )
            config.imagePadding = 5
            config.cornerStyle = .capsule
            config.buttonSize = .small
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 11, bottom: 6, trailing: 11)
            button.configuration = config
            button.titleLabel?.numberOfLines = 1

            let targetSection = item.section
            button.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                let feedback = UISelectionFeedbackGenerator()
                feedback.selectionChanged()
                self.setSelectedSection(targetSection)
                self.onSelectSection?(targetSection)
            }, for: .touchUpInside)

            buttonsBySection[item.section] = button
            pillsStack.addArrangedSubview(button)
        }

        updateSelectionVisuals()
    }

    public func setSelectedSection(_ section: Int) {
        selectedSection = section
        updateSelectionVisuals()
    }

    private func updateSelectionVisuals() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        for item in items {
            guard let btn = buttonsBySection[item.section], var config = btn.configuration else { continue }
            let isSelected = (item.section == selectedSection)
            if isSelected {
                config.baseBackgroundColor = item.tint.withAlphaComponent(isDark ? 0.30 : 0.18)
                config.baseForegroundColor = item.tint
                config.background.strokeColor = item.tint.withAlphaComponent(0.45)
                config.background.strokeWidth = 1.0
            } else {
                config.baseBackgroundColor = IOS27Theme.vibrantTertiaryFill
                config.baseForegroundColor = .secondaryLabel
                config.background.strokeColor = .clear
                config.background.strokeWidth = 0.0
            }
            btn.configuration = config
        }
    }
}
