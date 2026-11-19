import UIKit

/// Authentic iPadOS 27 Liquid Glass Floating Quick Menu Popover shown over Active Projection (Figma 10)
final class ProjectionQuickMenuView: UIView {
    var onNightModeChanged: (() -> Void)?
    var onHudToggled: ((Bool) -> Void)?
    var onAudioChanged: (() -> Void)?
    var onOpenFullSettings: (() -> Void)?
    var onDisconnectTapped: (() -> Void)?
    var onDismissRequested: (() -> Void)?

    private let backdropButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.backgroundColor = .clear
        return btn
    }()

    let popoverContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.accessibilityIdentifier = "projectionQuickMenuPopover"
        view.layer.cornerRadius = 26
        view.layer.cornerCurve = .continuous
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.56
        view.layer.shadowOffset = CGSize(width: 0, height: 22)
        view.layer.shadowRadius = 40
        return view
    }()

    private let glassView: UIVisualEffectView = {
        let v = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 26
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        v.layer.borderWidth = 0.75
        v.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        return v
    }()

    private let peerNameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .bold)
        l.textColor = .white
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let peerEndpointLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        l.textColor = UIColor(white: 0.92, alpha: 0.62)
        return l
    }()

    private let telemetryLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        l.textColor = UIColor(white: 0.92, alpha: 0.62)
        l.textAlignment = .right
        return l
    }()

    private let nightModeTitleLabel = UILabel()
    let nightModeSegment = UISegmentedControl(items: ["", "", ""])

    private let hudTitleLabel = UILabel()
    let hudSwitch = UISwitch()

    private let duckingTitleLabel = UILabel()
    private let duckingValueLabel = UILabel()
    private let duckingPresetStack = UIStackView()
    private var duckingButtons: [(preset: NavigationDuckingPreset, button: UIButton)] = []

    private let mediaMuteTitleLabel = UILabel()
    let mediaMuteSwitch = UISwitch()

    private let openSettingsLabel = UILabel()
    private let disconnectLabel = UILabel()

    private var trailingAnchorConstraint: NSLayoutConstraint?
    private var leadingAnchorConstraint: NSLayoutConstraint?
    private var centerYConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        applyLocalization()
        syncWithCurrentSettings()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        applyLocalization()
        syncWithCurrentSettings()
    }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        addSubview(backdropButton)
        backdropButton.addTarget(self, action: #selector(backdropTapped), for: .touchUpInside)

        addSubview(popoverContainer)
        popoverContainer.addSubview(glassView)

        NSLayoutConstraint.activate([
            backdropButton.topAnchor.constraint(equalTo: topAnchor),
            backdropButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            backdropButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdropButton.trailingAnchor.constraint(equalTo: trailingAnchor),

            popoverContainer.widthAnchor.constraint(equalToConstant: 356),
            glassView.topAnchor.constraint(equalTo: popoverContainer.topAnchor),
            glassView.bottomAnchor.constraint(equalTo: popoverContainer.bottomAnchor),
            glassView.leadingAnchor.constraint(equalTo: popoverContainer.leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: popoverContainer.trailingAnchor)
        ])

        let contentStack = UIStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 0
        contentStack.alignment = .fill
        glassView.contentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: glassView.contentView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor)
        ])

        // 1) Session Header
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.distribution = .equalSpacing
        headerRow.isLayoutMarginsRelativeArrangement = true
        headerRow.layoutMargins = UIEdgeInsets(top: 15, left: 18, bottom: 15, right: 18)

        let devLeft = UIStackView()
        devLeft.axis = .vertical
        devLeft.spacing = 3

        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.backgroundColor = CarAutoPadTheme.accentGreen
        dot.layer.cornerRadius = 3.5
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 7),
            dot.heightAnchor.constraint(equalToConstant: 7)
        ])

        let nameRow = UIStackView(arrangedSubviews: [dot, peerNameLabel])
        nameRow.axis = .horizontal
        nameRow.spacing = 8
        nameRow.alignment = .center

        devLeft.addArrangedSubview(nameRow)
        devLeft.addArrangedSubview(peerEndpointLabel)
        headerRow.addArrangedSubview(devLeft)
        headerRow.addArrangedSubview(telemetryLabel)
        contentStack.addArrangedSubview(headerRow)
        contentStack.addArrangedSubview(makeGlassHairline())

        // 2) Quick Driving Controls
        let controlsStack = UIStackView()
        controlsStack.axis = .vertical
        controlsStack.spacing = 14
        controlsStack.isLayoutMarginsRelativeArrangement = true
        controlsStack.layoutMargins = UIEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)

        // 2A. Night Mode (Auto / Day / Night)
        nightModeTitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        nightModeTitleLabel.textColor = .white
        nightModeTitleLabel.adjustsFontSizeToFitWidth = true
        nightModeTitleLabel.minimumScaleFactor = 0.75
        nightModeSegment.apportionsSegmentWidthsByContent = true
        nightModeSegment.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        nightModeSegment.selectedSegmentTintColor = UIColor.white.withAlphaComponent(0.22)
        nightModeSegment.setTitleTextAttributes([.foregroundColor: UIColor(white: 0.92, alpha: 0.72), .font: UIFont.systemFont(ofSize: 12, weight: .regular)], for: .normal)
        nightModeSegment.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 12, weight: .medium)], for: .selected)
        nightModeSegment.addTarget(self, action: #selector(nightModeChanged), for: .valueChanged)

        let nightRow = UIStackView(arrangedSubviews: [nightModeTitleLabel, nightModeSegment])
        nightRow.axis = .horizontal
        nightRow.spacing = 10
        nightRow.alignment = .center
        controlsStack.addArrangedSubview(nightRow)

        // 2B. Performance HUD Switch
        hudTitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        hudTitleLabel.textColor = .white
        hudTitleLabel.adjustsFontSizeToFitWidth = true
        hudTitleLabel.minimumScaleFactor = 0.75
        hudSwitch.onTintColor = CarAutoPadTheme.accentGreen
        hudSwitch.addTarget(self, action: #selector(hudSwitchChanged), for: .valueChanged)
        let hudRow = UIStackView(arrangedSubviews: [hudTitleLabel, hudSwitch])
        hudRow.axis = .horizontal
        hudRow.alignment = .center
        controlsStack.addArrangedSubview(hudRow)

        // 2C. Navigation Ducking Quick Presets (Off / -50% / -70% / Mute)
        let duckBlock = UIStackView()
        duckBlock.axis = .vertical
        duckBlock.spacing = 9

        duckingTitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        duckingTitleLabel.textColor = .white
        duckingValueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        duckingValueLabel.textColor = CarAutoPadTheme.accentBlue
        let duckHead = UIStackView(arrangedSubviews: [duckingTitleLabel, duckingValueLabel])
        duckHead.axis = .horizontal
        duckHead.alignment = .center
        duckBlock.addArrangedSubview(duckHead)

        duckingPresetStack.axis = .horizontal
        duckingPresetStack.spacing = 6
        duckingPresetStack.distribution = .fillEqually
        let quickPresets: [NavigationDuckingPreset] = [.off, .medium, .standard, .mute]
        for preset in quickPresets {
            let btn = UIButton(type: .system)
            btn.layer.cornerRadius = 9
            btn.layer.cornerCurve = .continuous
            btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
            btn.titleLabel?.adjustsFontSizeToFitWidth = true
            btn.titleLabel?.minimumScaleFactor = 0.7
            btn.heightAnchor.constraint(equalToConstant: 30).isActive = true
            btn.addAction(UIAction { [weak self] _ in
                self?.selectDuckingPreset(preset)
            }, for: .touchUpInside)
            duckingButtons.append((preset, btn))
            duckingPresetStack.addArrangedSubview(btn)
        }
        duckBlock.addArrangedSubview(duckingPresetStack)
        controlsStack.addArrangedSubview(duckBlock)

        // 2D. Media Mute Toggle
        mediaMuteTitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        mediaMuteTitleLabel.textColor = .white
        mediaMuteTitleLabel.adjustsFontSizeToFitWidth = true
        mediaMuteTitleLabel.minimumScaleFactor = 0.75
        mediaMuteSwitch.onTintColor = CarAutoPadTheme.accentGreen
        mediaMuteSwitch.addTarget(self, action: #selector(mediaMuteSwitchChanged), for: .valueChanged)
        let muteRow = UIStackView(arrangedSubviews: [mediaMuteTitleLabel, mediaMuteSwitch])
        muteRow.axis = .horizontal
        muteRow.alignment = .center
        controlsStack.addArrangedSubview(muteRow)

        contentStack.addArrangedSubview(controlsStack)
        contentStack.addArrangedSubview(makeGlassHairline())

        // 3) Open Full Settings Row
        let settingsAction = makeActionRow(
            iconName: "slider.horizontal.3",
            iconColor: CarAutoPadTheme.accentBlue,
            label: openSettingsLabel,
            labelColor: .white,
            showChevron: true,
            accessibilityId: "quickMenuOpenSettings",
            action: #selector(openSettingsTapped)
        )
        contentStack.addArrangedSubview(settingsAction)
        contentStack.addArrangedSubview(makeGlassHairline())

        // 4) Destructive Disconnect Row
        let disconnectAction = makeActionRow(
            iconName: "power",
            iconColor: CarAutoPadTheme.accentRed,
            label: disconnectLabel,
            labelColor: CarAutoPadTheme.accentRed,
            showChevron: false,
            accessibilityId: "quickMenuDisconnect",
            action: #selector(disconnectTapped)
        )
        contentStack.addArrangedSubview(disconnectAction)
    }

    private func makeGlassHairline() -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        v.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return v
    }

    private func makeActionRow(
        iconName: String,
        iconColor: UIColor,
        label: UILabel,
        labelColor: UIColor,
        showChevron: Bool,
        accessibilityId: String,
        action: Selector
    ) -> UIControl {
        let ctrl = UIControl()
        ctrl.translatesAutoresizingMaskIntoConstraints = false
        ctrl.accessibilityIdentifier = accessibilityId
        ctrl.addTarget(self, action: action, for: .touchUpInside)

        let icon = UIImageView(image: UIImage(systemName: iconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)))
        icon.tintColor = iconColor
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 18).isActive = true

        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = labelColor
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75

        var views: [UIView] = [icon, label]
        if showChevron {
            let chev = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
            chev.tintColor = UIColor(white: 0.65, alpha: 0.8)
            chev.setContentHuggingPriority(.required, for: .horizontal)
            views.append(chev)
        }

        let row = UIStackView(arrangedSubviews: views)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        row.isUserInteractionEnabled = false
        ctrl.addSubview(row)

        NSLayoutConstraint.activate([
            ctrl.heightAnchor.constraint(equalToConstant: 46),
            row.leadingAnchor.constraint(equalTo: ctrl.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: ctrl.trailingAnchor, constant: -18),
            row.centerYAnchor.constraint(equalTo: ctrl.centerYAnchor)
        ])
        return ctrl
    }

    func position(relativeTo bubble: UIView, snappedToRight: Bool) {
        trailingAnchorConstraint?.isActive = false
        leadingAnchorConstraint?.isActive = false
        centerYConstraint?.isActive = false

        if snappedToRight {
            trailingAnchorConstraint = popoverContainer.trailingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: -14)
            trailingAnchorConstraint?.isActive = true
        } else {
            leadingAnchorConstraint = popoverContainer.leadingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: 14)
            leadingAnchorConstraint?.isActive = true
        }

        let cy = popoverContainer.centerYAnchor.constraint(equalTo: bubble.centerYAnchor)
        cy.priority = .defaultHigh
        centerYConstraint = cy
        cy.isActive = true

        NSLayoutConstraint.activate([
            popoverContainer.topAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            popoverContainer.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            popoverContainer.leadingAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            popoverContainer.trailingAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
    }

    func applyLocalization() {
        nightModeTitleLabel.text = L10n.nightModeRow
        nightModeSegment.setTitle(L10n.nightAutoShort, forSegmentAt: 0)
        nightModeSegment.setTitle(L10n.nightDayShort, forSegmentAt: 1)
        nightModeSegment.setTitle(L10n.nightNightShort, forSegmentAt: 2)
        hudTitleLabel.text = L10n.quickMenuHudRow
        duckingTitleLabel.text = L10n.quickMenuNavDuckingRow
        mediaMuteTitleLabel.text = L10n.quickMenuMediaMuteRow
        openSettingsLabel.text = L10n.quickMenuOpenFullSettings
        disconnectLabel.text = L10n.quickMenuDisconnectAction

        for (preset, btn) in duckingButtons {
            switch preset {
            case .off: btn.setTitle(L10n.quickDuckOffShort, for: .normal)
            case .mute: btn.setTitle(L10n.quickDuckMuteShort, for: .normal)
            default: btn.setTitle("-\(preset.dropPercentage)%", for: .normal)
            }
        }
        syncWithCurrentSettings()
    }

    func updateSessionInfo(peerName: String, endpoint: String, fps: Double, decodeMs: Double) {
        peerNameLabel.text = peerName
        peerEndpointLabel.text = endpoint
        let fpsInt = Int(fps.rounded())
        telemetryLabel.text = decodeMs > 0
            ? "\(fpsInt) FPS · \(String(format: "%.1f", decodeMs))ms"
            : "\(fpsInt) FPS"
    }

    func syncWithCurrentSettings() {
        switch ProjectionSettings.nightMode {
        case .day: nightModeSegment.selectedSegmentIndex = 1
        case .night: nightModeSegment.selectedSegmentIndex = 2
        default: nightModeSegment.selectedSegmentIndex = 0
        }

        hudSwitch.isOn = ProjectionSettings.isDebugModeEnabled
        mediaMuteSwitch.isOn = !ProjectionSettings.isMediaChannelEnabled

        let isSink = ProjectionSettings.isAudioSinkEnabled
        mediaMuteSwitch.isEnabled = isSink

        let pct = Int((ProjectionSettings.navigationDuckingAmount * 100).rounded())
        duckingValueLabel.text = pct == 0 ? L10n.quickDuckOffShort : "-\(pct)%"

        for (preset, btn) in duckingButtons {
            btn.isEnabled = isSink
            let isSelected = (preset.dropPercentage == pct)
            btn.backgroundColor = isSelected ? CarAutoPadTheme.accentBlue : UIColor.white.withAlphaComponent(0.08)
            btn.setTitleColor(isSelected ? .white : UIColor(white: 0.92, alpha: 0.72), for: .normal)
            btn.alpha = isSink ? 1.0 : CarAutoPadTheme.lockedAlpha
        }
    }

    func animateIn(snappedToRight: Bool) {
        alpha = 0
        popoverContainer.transform = CGAffineTransform(translationX: snappedToRight ? 16 : -16, y: 0).scaledBy(x: 0.96, y: 0.96)
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.3,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.alpha = 1
            self.popoverContainer.transform = .identity
        }
    }

    func animateOut(snappedToRight: Bool, completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn]) {
            self.alpha = 0
            self.popoverContainer.transform = CGAffineTransform(translationX: snappedToRight ? 10 : -10, y: 0).scaledBy(x: 0.97, y: 0.97)
        } completion: { _ in
            completion()
        }
    }

    @objc private func nightModeChanged() {
        switch nightModeSegment.selectedSegmentIndex {
        case 1: ProjectionSettings.nightMode = .day
        case 2: ProjectionSettings.nightMode = .night
        default: ProjectionSettings.nightMode = .auto
        }
        onNightModeChanged?()
    }

    @objc private func hudSwitchChanged() {
        onHudToggled?(hudSwitch.isOn)
    }

    private func selectDuckingPreset(_ preset: NavigationDuckingPreset) {
        ProjectionSettings.navigationDuckingAmount = preset.reductionAmount
        PCMAudioPlayer.shared.refreshVolumes()
        syncWithCurrentSettings()
        onAudioChanged?()
    }

    @objc private func mediaMuteSwitchChanged() {
        ProjectionSettings.isMediaChannelEnabled = !mediaMuteSwitch.isOn
        PCMAudioPlayer.shared.refreshVolumes()
        onAudioChanged?()
    }

    @objc private func openSettingsTapped() {
        onOpenFullSettings?()
    }

    @objc private func disconnectTapped() {
        onDisconnectTapped?()
    }

    @objc private func backdropTapped() {
        onDismissRequested?()
    }
}
