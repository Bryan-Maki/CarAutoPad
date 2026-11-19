import UIKit

// MARK: - 1. Display & Coolwalk Layout Panel (Figma 04 & 09 Locked State)

final class DisplayLayoutPanelViewController: UIViewController {
    var connectionManager: ConnectionManager = ConnectionManager.shared
    var onSettingsChanged: ((SettingsViewController.ChangeImpact) -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let titleLabel = CarAutoPadTheme.makePageTitleLabel(L10n.sidebarDisplayLayout, size: 28)

    // Hero Coolwalk Preview + DPI Card
    private let previewCard = CarAutoPadTheme.makeCard(cornerRadius: 22)
    private let previewLayoutStack = UIStackView()
    let dpiPreviewView: DpiPreviewView = {
        let v = DpiPreviewView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 14
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        return v
    }()
    private let dpiControlsStack = UIStackView()
    private let autoDpiTitleLabel = UILabel()
    let autoDpiSwitch = UISwitch()
    private let dpiSummaryLabel = UILabel()
    let dpiSlider = UISlider()
    private let dpiMinLabel = UILabel()
    private let dpiMaxLabel = UILabel()
    private let dpiPresetStack = UIStackView()
    private var dpiPresetButtons: [(dpi: Int, button: UIButton)] = []

    // 7-Row Settings Card
    private let settingsCard = CarAutoPadTheme.makeCard(cornerRadius: 22)
    private let resolutionRowControl = UIControl()
    private let resolutionTitleLabel = UILabel()
    private let resolutionValueLabel = UILabel()
    private let resolutionChevron = UIImageView()

    private let fpsRowView = UIView()
    private let fpsTitleLabel = UILabel()
    let fpsSegment = UISegmentedControl(items: ["", ""])

    private let fitRowView = UIView()
    private let fitTitleLabel = UILabel()
    let fitSegment = UISegmentedControl(items: ["", "", ""])

    private let orientRowView = UIView()
    private let orientTitleLabel = UILabel()
    let orientSegment = UISegmentedControl(items: ["", "", ""])

    private let drivePosRowView = UIView()
    private let drivePosTitleLabel = UILabel()
    let drivePosSegment = UISegmentedControl(items: ["", ""])

    private let smoothRowView = UIView()
    private let smoothTitleLabel = UILabel()
    let smoothSegment = UISegmentedControl(items: ["", "", "", ""])

    private let edgeSwipeRowView = UIView()
    private let edgeSwipeTitleLabel = UILabel()
    let edgeSwipeSwitch = UISwitch()

    private let lockedFooterLabel = CarAutoPadTheme.makeFooterLabel(L10n.sessionLockedHandshakeFooter)

    private var isHandshakeLocked: Bool {
        return connectionManager.state != .disconnected
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CarAutoPadTheme.canvas
        setupUI()
        applyLocalization()
        syncWithCurrentSettings()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let sideBySide = view.bounds.width >= 680
        let targetAxis: NSLayoutConstraint.Axis = sideBySide ? .horizontal : .vertical
        if previewLayoutStack.axis != targetAxis {
            previewLayoutStack.axis = targetAxis
            previewLayoutStack.distribution = sideBySide ? .fillEqually : .fill
        }
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.alignment = .fill
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 28),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 36),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -36)
        ])

        contentStack.addArrangedSubview(titleLabel)

        // Card 1: Coolwalk Preview + DPI controls
        previewLayoutStack.translatesAutoresizingMaskIntoConstraints = false
        previewLayoutStack.axis = .horizontal
        previewLayoutStack.spacing = 20
        previewLayoutStack.alignment = .center
        previewLayoutStack.distribution = .fillEqually
        previewCard.addSubview(previewLayoutStack)

        NSLayoutConstraint.activate([
            previewLayoutStack.topAnchor.constraint(equalTo: previewCard.topAnchor, constant: 18),
            previewLayoutStack.bottomAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: -18),
            previewLayoutStack.leadingAnchor.constraint(equalTo: previewCard.leadingAnchor, constant: 18),
            previewLayoutStack.trailingAnchor.constraint(equalTo: previewCard.trailingAnchor, constant: -18),
            dpiPreviewView.heightAnchor.constraint(equalToConstant: 196)
        ])

        dpiControlsStack.axis = .vertical
        dpiControlsStack.spacing = 12
        dpiControlsStack.alignment = .fill

        autoDpiTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        autoDpiTitleLabel.textColor = .label
        autoDpiTitleLabel.adjustsFontSizeToFitWidth = true
        autoDpiTitleLabel.minimumScaleFactor = 0.75
        autoDpiSwitch.onTintColor = CarAutoPadTheme.accentGreen
        autoDpiSwitch.addTarget(self, action: #selector(autoDpiSwitchChanged), for: .valueChanged)

        dpiSummaryLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        dpiSummaryLabel.textColor = .secondaryLabel
        dpiSummaryLabel.adjustsFontSizeToFitWidth = true
        dpiSummaryLabel.minimumScaleFactor = 0.75

        let autoLeft = UIStackView(arrangedSubviews: [autoDpiTitleLabel, dpiSummaryLabel])
        autoLeft.axis = .vertical
        autoLeft.spacing = 3

        let autoRow = UIStackView(arrangedSubviews: [autoLeft, autoDpiSwitch])
        autoRow.axis = .horizontal
        autoRow.spacing = 12
        autoRow.alignment = .center
        dpiControlsStack.addArrangedSubview(autoRow)

        dpiSlider.minimumValue = Float(ProjectionSettings.minDpi)
        dpiSlider.maximumValue = Float(ProjectionSettings.maxDpi)
        dpiSlider.minimumTrackTintColor = CarAutoPadTheme.accentBlue
        dpiSlider.addTarget(self, action: #selector(dpiSliderChanged), for: .valueChanged)
        dpiControlsStack.addArrangedSubview(dpiSlider)

        dpiMinLabel.text = "\(ProjectionSettings.minDpi)"
        dpiMinLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        dpiMinLabel.textColor = .tertiaryLabel
        dpiMaxLabel.text = "\(ProjectionSettings.maxDpi) DPI"
        dpiMaxLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        dpiMaxLabel.textColor = .tertiaryLabel
        let rangeRow = UIStackView(arrangedSubviews: [dpiMinLabel, dpiMaxLabel])
        rangeRow.axis = .horizontal
        rangeRow.distribution = .equalSpacing
        dpiControlsStack.addArrangedSubview(rangeRow)

        dpiPresetStack.axis = .horizontal
        dpiPresetStack.spacing = 8
        dpiPresetStack.distribution = .fillEqually
        for value in [120, 160, 200, 240, 280] {
            let btn = UIButton(type: .system)
            btn.setTitle("\(value)", for: .normal)
            btn.titleLabel?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            btn.layer.cornerRadius = 15
            btn.layer.cornerCurve = .continuous
            btn.heightAnchor.constraint(equalToConstant: 30).isActive = true
            btn.addAction(UIAction { [weak self] _ in
                self?.applyDpi(val: value, isAuto: false)
            }, for: .touchUpInside)
            dpiPresetButtons.append((value, btn))
            dpiPresetStack.addArrangedSubview(btn)
        }
        dpiControlsStack.addArrangedSubview(dpiPresetStack)

        previewLayoutStack.addArrangedSubview(dpiPreviewView)
        previewLayoutStack.addArrangedSubview(dpiControlsStack)
        contentStack.addArrangedSubview(previewCard)

        // Card 2: 7-Row Settings List
        let listStack = UIStackView()
        listStack.translatesAutoresizingMaskIntoConstraints = false
        listStack.axis = .vertical
        listStack.spacing = 0
        listStack.alignment = .fill
        settingsCard.addSubview(listStack)
        NSLayoutConstraint.activate([
            listStack.topAnchor.constraint(equalTo: settingsCard.topAnchor),
            listStack.bottomAnchor.constraint(equalTo: settingsCard.bottomAnchor),
            listStack.leadingAnchor.constraint(equalTo: settingsCard.leadingAnchor),
            listStack.trailingAnchor.constraint(equalTo: settingsCard.trailingAnchor)
        ])

        // Row 1: Resolution Picker
        resolutionRowControl.translatesAutoresizingMaskIntoConstraints = false
        resolutionRowControl.accessibilityIdentifier = "display.resolutionRow"
        resolutionRowControl.addTarget(self, action: #selector(resolutionRowTapped), for: .touchUpInside)
        resolutionTitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        resolutionTitleLabel.textColor = .label
        resolutionTitleLabel.adjustsFontSizeToFitWidth = true
        resolutionTitleLabel.minimumScaleFactor = 0.75
        resolutionValueLabel.font = .systemFont(ofSize: 14, weight: .regular)
        resolutionValueLabel.textColor = .secondaryLabel
        resolutionValueLabel.textAlignment = .right
        resolutionValueLabel.adjustsFontSizeToFitWidth = true
        resolutionValueLabel.minimumScaleFactor = 0.75
        resolutionChevron.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        resolutionChevron.tintColor = .tertiaryLabel
        resolutionChevron.setContentHuggingPriority(.required, for: .horizontal)

        let resRight = UIStackView(arrangedSubviews: [resolutionValueLabel, resolutionChevron])
        resRight.axis = .horizontal
        resRight.spacing = 6
        resRight.alignment = .center
        resRight.isUserInteractionEnabled = false

        let resRowStack = UIStackView(arrangedSubviews: [resolutionTitleLabel, resRight])
        resRowStack.translatesAutoresizingMaskIntoConstraints = false
        resRowStack.axis = .horizontal
        resRowStack.spacing = 12
        resRowStack.alignment = .center
        resRowStack.isUserInteractionEnabled = false
        resolutionRowControl.addSubview(resRowStack)
        NSLayoutConstraint.activate([
            resolutionRowControl.heightAnchor.constraint(equalToConstant: 50),
            resRowStack.leadingAnchor.constraint(equalTo: resolutionRowControl.leadingAnchor, constant: 20),
            resRowStack.trailingAnchor.constraint(equalTo: resolutionRowControl.trailingAnchor, constant: -20),
            resRowStack.centerYAnchor.constraint(equalTo: resolutionRowControl.centerYAnchor)
        ])

        // Rows 2..6: Segmented rows
        for seg in [fpsSegment, fitSegment, orientSegment, drivePosSegment, smoothSegment] {
            CarAutoPadTheme.styleSegmentedControl(seg)
        }
        fpsSegment.addTarget(self, action: #selector(fpsChanged), for: .valueChanged)
        fitSegment.addTarget(self, action: #selector(fitModeChanged), for: .valueChanged)
        orientSegment.addTarget(self, action: #selector(orientationChanged), for: .valueChanged)
        drivePosSegment.addTarget(self, action: #selector(driverPositionChanged), for: .valueChanged)
        smoothSegment.addTarget(self, action: #selector(smoothingChanged), for: .valueChanged)

        edgeSwipeSwitch.onTintColor = CarAutoPadTheme.accentGreen
        edgeSwipeSwitch.addTarget(self, action: #selector(edgeSwipeChanged), for: .valueChanged)

        configureControlRow(fpsRowView, titleLabel: fpsTitleLabel, accessory: fpsSegment)
        configureControlRow(fitRowView, titleLabel: fitTitleLabel, accessory: fitSegment)
        configureControlRow(orientRowView, titleLabel: orientTitleLabel, accessory: orientSegment)
        configureControlRow(drivePosRowView, titleLabel: drivePosTitleLabel, accessory: drivePosSegment)
        configureControlRow(smoothRowView, titleLabel: smoothTitleLabel, accessory: smoothSegment)
        configureControlRow(edgeSwipeRowView, titleLabel: edgeSwipeTitleLabel, accessory: edgeSwipeSwitch)

        let rows: [UIView] = [
            resolutionRowControl,
            fpsRowView,
            fitRowView,
            orientRowView,
            drivePosRowView,
            smoothRowView,
            edgeSwipeRowView
        ]
        for (idx, r) in rows.enumerated() {
            if idx > 0 {
                listStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 20))
            }
            listStack.addArrangedSubview(r)
        }

        contentStack.addArrangedSubview(settingsCard)
        lockedFooterLabel.isHidden = true
        contentStack.addArrangedSubview(lockedFooterLabel)
    }

    private func configureControlRow(_ container: UIView, titleLabel: UILabel, accessory: UIView) {
        container.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        titleLabel.textColor = .label
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        accessory.setContentHuggingPriority(.required, for: .horizontal)
        accessory.setContentCompressionResistancePriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [titleLabel, accessory])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 9),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -9),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20)
        ])
    }

    func applyLocalization() {
        titleLabel.text = L10n.sidebarDisplayLayout
        autoDpiTitleLabel.text = L10n.autoDpiRecommended
        resolutionTitleLabel.text = L10n.resolutionTitle
        fpsTitleLabel.text = L10n.frameRateRow
        fitTitleLabel.text = L10n.displayFitMode
        orientTitleLabel.text = L10n.screenOrientationRow
        drivePosTitleLabel.text = L10n.drivingPosition
        smoothTitleLabel.text = L10n.frameSmoothingRow
        edgeSwipeTitleLabel.text = L10n.edgeSwipeProtectionRow
        lockedFooterLabel.text = L10n.sessionLockedHandshakeFooter

        fpsSegment.setTitle(ProjectionFpsLimit.fps60.title, forSegmentAt: 0)
        fpsSegment.setTitle(ProjectionFpsLimit.fps30.title, forSegmentAt: 1)

        fitSegment.setTitle(L10n.fitSegmentFill, forSegmentAt: 0)
        fitSegment.setTitle(L10n.fitSegmentFit, forSegmentAt: 1)
        fitSegment.setTitle(L10n.fitSegmentStretch, forSegmentAt: 2)

        orientSegment.setTitle(ProjectionOrientation.landscape.title, forSegmentAt: 0)
        orientSegment.setTitle(ProjectionOrientation.portrait.title, forSegmentAt: 1)
        orientSegment.setTitle(ProjectionOrientation.system.title, forSegmentAt: 2)

        drivePosSegment.setTitle(L10n.lhdShort, forSegmentAt: 0)
        drivePosSegment.setTitle(L10n.rhdShort, forSegmentAt: 1)

        smoothSegment.setTitle(MotionBlurMode.off.shortTitle, forSegmentAt: 0)
        smoothSegment.setTitle(MotionBlurMode.light.shortTitle, forSegmentAt: 1)
        smoothSegment.setTitle(MotionBlurMode.medium.shortTitle, forSegmentAt: 2)
        smoothSegment.setTitle(MotionBlurMode.strong.shortTitle, forSegmentAt: 3)

        syncWithCurrentSettings()
    }

    func syncWithCurrentSettings() {
        let cfg = HeadUnitScreenConfig.shared
        let locked = isHandshakeLocked

        dpiPreviewView.dpi = ProjectionSettings.effectiveDpi
        dpiPreviewView.panelWidthPx = cfg.screenWidthPx > 0 ? cfg.screenWidthPx : 1920
        dpiPreviewView.panelHeightPx = cfg.screenHeightPx > 0 ? cfg.screenHeightPx : 1080
        dpiPreviewView.codecWidthPx = cfg.negotiatedWidth > 0 ? cfg.negotiatedWidth : 1920
        dpiPreviewView.codecHeightPx = cfg.negotiatedHeight > 0 ? cfg.negotiatedHeight : 1080
        dpiPreviewView.activeWidthPx = cfg.activeWidthPx
        dpiPreviewView.activeHeightPx = cfg.activeHeightPx
        dpiPreviewView.marginWidthPx = cfg.widthMargin
        dpiPreviewView.marginHeightPx = cfg.heightMargin
        dpiPreviewView.isRightHandDrive = (ProjectionSettings.driverPosition == .right)
        dpiPreviewView.fitMode = ProjectionSettings.videoFitMode
        dpiPreviewView.setNeedsDisplay()

        autoDpiSwitch.isOn = ProjectionSettings.isAutoDpi
        dpiSlider.value = Float(ProjectionSettings.effectiveDpi)
        updateDpiSummaryAndPresets()

        // Lock 4 handshake display parameters when connected (DPI/AutoDPI, Resolution, FPS, Driver Position)
        autoDpiSwitch.isEnabled = !locked
        dpiSlider.isEnabled = !locked
        dpiControlsStack.alpha = locked ? CarAutoPadTheme.lockedAlpha : 1.0
        for (_, btn) in dpiPresetButtons {
            btn.isEnabled = !locked
        }

        resolutionRowControl.isEnabled = !locked
        resolutionRowControl.alpha = locked ? CarAutoPadTheme.lockedAlpha : 1.0
        resolutionChevron.isHidden = locked
        resolutionValueLabel.text = locked
            ? L10n.lockedSuffix(ProjectionSettings.resolution.title)
            : ProjectionSettings.resolution.title

        fpsSegment.selectedSegmentIndex = (ProjectionSettings.fpsLimit == .fps60) ? 0 : 1
        fpsSegment.isEnabled = !locked
        fpsRowView.alpha = locked ? CarAutoPadTheme.lockedAlpha : 1.0

        switch ProjectionSettings.fitMode {
        case .fillMargin: fitSegment.selectedSegmentIndex = 0
        case .contain, .fill, .cover: fitSegment.selectedSegmentIndex = 1
        case .stretch: fitSegment.selectedSegmentIndex = 2
        }
        fitSegment.isEnabled = true
        fitRowView.alpha = 1.0

        switch ProjectionSettings.orientation {
        case .landscape: orientSegment.selectedSegmentIndex = 0
        case .portrait: orientSegment.selectedSegmentIndex = 1
        case .system: orientSegment.selectedSegmentIndex = 2
        }
        orientSegment.isEnabled = true
        orientRowView.alpha = 1.0

        drivePosSegment.selectedSegmentIndex = ProjectionSettings.rightHandDrive ? 1 : 0
        drivePosSegment.isEnabled = !locked
        drivePosRowView.alpha = locked ? CarAutoPadTheme.lockedAlpha : 1.0

        smoothSegment.selectedSegmentIndex = ProjectionSettings.motionBlurMode.rawValue
        smoothSegment.isEnabled = true
        smoothRowView.alpha = 1.0

        edgeSwipeSwitch.isOn = ProjectionSettings.isEdgeSwipeProtectionEnabled
        edgeSwipeSwitch.isEnabled = true
        edgeSwipeRowView.alpha = 1.0

        lockedFooterLabel.isHidden = !locked
    }

    private func updateDpiSummaryAndPresets() {
        let prefix = ProjectionSettings.isAutoDpi ? L10n.autoShort : L10n.customShort
        dpiSummaryLabel.text = "\(prefix) · \(dpiPreviewView.dpi) DPI · \(dpiPreviewView.virtualWidthDp)×\(dpiPreviewView.virtualHeightDp) dp"
        for (val, btn) in dpiPresetButtons {
            let isSelected = (val == dpiPreviewView.dpi)
            btn.backgroundColor = isSelected ? CarAutoPadTheme.accentBlue : CarAutoPadTheme.pill
            btn.setTitleColor(isSelected ? .white : .secondaryLabel, for: .normal)
        }
    }

    private func applyDpi(val: Int, isAuto: Bool) {
        let clamped = min(max(val, ProjectionSettings.minDpi), ProjectionSettings.maxDpi)
        if isAuto {
            ProjectionSettings.resetDpiToDefault()
            HeadUnitScreenConfig.shared.customDpi = nil
        } else {
            ProjectionSettings.isAutoDpi = false
            ProjectionSettings.dpi = clamped
            HeadUnitScreenConfig.shared.customDpi = clamped
        }
        syncWithCurrentSettings()
        onSettingsChanged?(.uiOnly)
    }

    @objc private func autoDpiSwitchChanged() {
        if autoDpiSwitch.isOn {
            applyDpi(val: ProjectionSettings.recommendedDpiForCurrentDevice(), isAuto: true)
        } else {
            let stepped = Int((dpiSlider.value / 10.0).rounded()) * 10
            applyDpi(val: stepped, isAuto: false)
        }
    }

    @objc private func dpiSliderChanged() {
        let stepped = Int((dpiSlider.value / 10.0).rounded()) * 10
        dpiSlider.value = Float(stepped)
        applyDpi(val: stepped, isAuto: false)
    }

    @objc private func resolutionRowTapped() {
        guard !isHandshakeLocked else { return }
        let alert = UIAlertController(title: L10n.resolutionTitle, message: L10n.resolutionPickerMessage, preferredStyle: .actionSheet)
        if let pop = alert.popoverPresentationController {
            pop.sourceView = resolutionRowControl
            pop.sourceRect = resolutionRowControl.bounds
        }
        for preset in ProjectionSettings.availableResolutions(for: ProjectionSettings.orientation) {
            let title = (preset == ProjectionSettings.resolution) ? L10n.currentSuffix(preset.title) : preset.title
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                ProjectionSettings.resolution = preset
                HeadUnitScreenConfig.shared.recalculate(requestedResolution: preset)
                self?.syncWithCurrentSettings()
                self?.onSettingsChanged?(.geometryChanged)
            })
        }
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(alert, animated: true)
    }

    @objc private func fpsChanged() {
        ProjectionSettings.fpsLimit = (fpsSegment.selectedSegmentIndex == 0) ? .fps60 : .fps30
        onSettingsChanged?(.uiOnly)
    }

    @objc private func fitModeChanged() {
        let modes: [VideoFitMode] = [.fillMargin, .contain, .stretch]
        let idx = fitSegment.selectedSegmentIndex
        guard idx >= 0 && idx < modes.count else { return }
        ProjectionSettings.fitMode = modes[idx]
        HeadUnitScreenConfig.shared.videoFitMode = modes[idx]
        HeadUnitScreenConfig.shared.recalculate()
        HeadUnitScreenConfig.shared.checkAndNotifyMarginDivergence()
        syncWithCurrentSettings()
        onSettingsChanged?(.geometryChanged)
    }

    @objc private func orientationChanged() {
        let orientations: [ProjectionOrientation] = [.landscape, .portrait, .system]
        let idx = orientSegment.selectedSegmentIndex
        guard idx >= 0 && idx < orientations.count else { return }
        ProjectionSettings.orientation = orientations[idx]
        onSettingsChanged?(.geometryChanged)
    }

    @objc private func driverPositionChanged() {
        ProjectionSettings.rightHandDrive = (drivePosSegment.selectedSegmentIndex == 1)
        syncWithCurrentSettings()
        onSettingsChanged?(.uiOnly)
    }

    @objc private func smoothingChanged() {
        if let mode = MotionBlurMode(rawValue: smoothSegment.selectedSegmentIndex) {
            ProjectionSettings.motionBlurMode = mode
            onSettingsChanged?(.motionBlurChanged)
        }
    }

    @objc private func edgeSwipeChanged() {
        ProjectionSettings.isEdgeSwipeProtectionEnabled = edgeSwipeSwitch.isOn
        onSettingsChanged?(.uiOnly)
    }
}

// MARK: - 2. Audio & 3-Channel Mixer Panel (Figma 05 & 09 Locked State)

final class AudioMixerPanelViewController: UIViewController {
    var connectionManager: ConnectionManager = ConnectionManager.shared
    var onSettingsChanged: ((SettingsViewController.ChangeImpact) -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let titleLabel = CarAutoPadTheme.makePageTitleLabel(L10n.sidebarAudioMixer, size: 28)

    // Codec & Routing Matrix Card
    private let routingCard = CarAutoPadTheme.makeCard(cornerRadius: 22)
    private let routingRow1 = UIStackView()
    private let routingRow2 = UIStackView()

    private let videoCodecLabel = UILabel()
    let videoCodecSegment = UISegmentedControl(items: ["H.264", "HEVC"])

    private let audioCodecLabel = UILabel()
    let audioCodecSegment = UISegmentedControl(items: ["AAC-LC", "PCM"])

    private let audioOutLabel = UILabel()
    let audioOutSegment = UISegmentedControl(items: ["", ""])

    private let micSourceLabel = UILabel()
    let micSourceSegment = UISegmentedControl(items: ["", "", ""])

    private let lockedFooterLabel = CarAutoPadTheme.makeFooterLabel(L10n.sessionLockedHandshakeFooter)

    // Volume & Ducking Card
    private let mixerSectionHeader = CarAutoPadTheme.makeSectionHeaderLabel(L10n.sectionVolumeAndNav)
    private let mixerCard = CarAutoPadTheme.makeCard(cornerRadius: 22)

    private let mediaTitleLabel = UILabel()
    let mediaSwitch = UISwitch()
    let mediaSlider = UISlider()
    private let mediaValueLabel = UILabel()
    private var mediaToneButton: UIButton?

    private let navTitleLabel = UILabel()
    let navSwitch = UISwitch()
    let navSlider = UISlider()
    private let navValueLabel = UILabel()
    private var navToneButton: UIButton?

    private let sysTitleLabel = UILabel()
    let sysSwitch = UISwitch()
    let sysSlider = UISlider()
    private let sysValueLabel = UILabel()
    private var sysToneButton: UIButton?

    private let duckingTitleLabel = UILabel()
    private let duckingStatusLabel = UILabel()
    let duckingSlider = UISlider()
    private var duckPresetButtons: [(preset: NavigationDuckingPreset, button: UIButton)] = []
    private let testDuckingButton = UIButton(type: .system)
    private let resetAudioButton = UIButton(type: .system)

    private var isHandshakeLocked: Bool {
        return connectionManager.state != .disconnected
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CarAutoPadTheme.canvas
        setupUI()
        applyLocalization()
        syncWithCurrentSettings()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let wide = view.bounds.width >= 680
        let axis: NSLayoutConstraint.Axis = wide ? .horizontal : .vertical
        if routingRow1.axis != axis {
            routingRow1.axis = axis
            routingRow1.distribution = wide ? .fillEqually : .fill
            routingRow2.axis = axis
            routingRow2.distribution = wide ? .fillEqually : .fill
        }
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.alignment = .fill
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 28),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 36),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -36)
        ])

        contentStack.addArrangedSubview(titleLabel)

        // Card 1: 4 Codec & Routing Controls
        for seg in [videoCodecSegment, audioCodecSegment, audioOutSegment, micSourceSegment] {
            CarAutoPadTheme.styleSegmentedControl(seg)
        }
        videoCodecSegment.addTarget(self, action: #selector(videoCodecChanged), for: .valueChanged)
        audioCodecSegment.addTarget(self, action: #selector(audioCodecChanged), for: .valueChanged)
        audioOutSegment.addTarget(self, action: #selector(audioOutChanged), for: .valueChanged)
        micSourceSegment.addTarget(self, action: #selector(micSourceChanged), for: .valueChanged)

        let routingStack = UIStackView()
        routingStack.translatesAutoresizingMaskIntoConstraints = false
        routingStack.axis = .vertical
        routingStack.spacing = 0
        routingCard.addSubview(routingStack)
        NSLayoutConstraint.activate([
            routingStack.topAnchor.constraint(equalTo: routingCard.topAnchor),
            routingStack.bottomAnchor.constraint(equalTo: routingCard.bottomAnchor),
            routingStack.leadingAnchor.constraint(equalTo: routingCard.leadingAnchor),
            routingStack.trailingAnchor.constraint(equalTo: routingCard.trailingAnchor)
        ])

        routingRow1.axis = .horizontal
        routingRow1.spacing = 24
        routingRow1.distribution = .fillEqually
        routingRow1.isLayoutMarginsRelativeArrangement = true
        routingRow1.layoutMargins = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        routingRow1.addArrangedSubview(makeInlinePair(label: videoCodecLabel, control: videoCodecSegment))
        routingRow1.addArrangedSubview(makeInlinePair(label: audioCodecLabel, control: audioCodecSegment))

        routingRow2.axis = .horizontal
        routingRow2.spacing = 24
        routingRow2.distribution = .fillEqually
        routingRow2.isLayoutMarginsRelativeArrangement = true
        routingRow2.layoutMargins = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        routingRow2.addArrangedSubview(makeInlinePair(label: audioOutLabel, control: audioOutSegment))
        routingRow2.addArrangedSubview(makeInlinePair(label: micSourceLabel, control: micSourceSegment))

        routingStack.addArrangedSubview(routingRow1)
        routingStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 20))
        routingStack.addArrangedSubview(routingRow2)

        contentStack.addArrangedSubview(routingCard)
        lockedFooterLabel.isHidden = true
        contentStack.addArrangedSubview(lockedFooterLabel)

        // Card 2: Volume & Ducking Unified Card
        let mixerGroup = UIStackView()
        mixerGroup.axis = .vertical
        mixerGroup.spacing = 8
        mixerGroup.addArrangedSubview(mixerSectionHeader)

        let mixerInner = UIStackView()
        mixerInner.translatesAutoresizingMaskIntoConstraints = false
        mixerInner.axis = .vertical
        mixerInner.spacing = 0
        mixerCard.addSubview(mixerInner)
        NSLayoutConstraint.activate([
            mixerInner.topAnchor.constraint(equalTo: mixerCard.topAnchor),
            mixerInner.bottomAnchor.constraint(equalTo: mixerCard.bottomAnchor),
            mixerInner.leadingAnchor.constraint(equalTo: mixerCard.leadingAnchor),
            mixerInner.trailingAnchor.constraint(equalTo: mixerCard.trailingAnchor)
        ])

        let mediaBlock = makeChannelRow(
            symbol: "music.note",
            titleLabel: mediaTitleLabel,
            toggle: mediaSwitch,
            slider: mediaSlider,
            valueLabel: mediaValueLabel,
            storeToneButton: { [weak self] btn in self?.mediaToneButton = btn },
            onTone: { AudioStreamTester.shared.playMediaTestTone() }
        )
        let navBlock = makeChannelRow(
            symbol: "location",
            titleLabel: navTitleLabel,
            toggle: navSwitch,
            slider: navSlider,
            valueLabel: navValueLabel,
            storeToneButton: { [weak self] btn in self?.navToneButton = btn },
            onTone: { AudioStreamTester.shared.playGuidanceTestTone() }
        )
        let sysBlock = makeChannelRow(
            symbol: "bell",
            titleLabel: sysTitleLabel,
            toggle: sysSwitch,
            slider: sysSlider,
            valueLabel: sysValueLabel,
            storeToneButton: { [weak self] btn in self?.sysToneButton = btn },
            onTone: { AudioStreamTester.shared.playSystemTestTone() }
        )

        mixerInner.addArrangedSubview(mediaBlock)
        mixerInner.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 20))
        mixerInner.addArrangedSubview(navBlock)
        mixerInner.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 20))
        mixerInner.addArrangedSubview(sysBlock)
        mixerInner.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 20))
        mixerInner.addArrangedSubview(makeDuckingBlock())
        mixerInner.addArrangedSubview(CarAutoPadTheme.makeHairline())
        mixerInner.addArrangedSubview(makeFooterActionBar())

        mixerGroup.addArrangedSubview(mixerCard)
        contentStack.addArrangedSubview(mixerGroup)

        wireMixerActions()
    }

    private func makeInlinePair(label: UILabel, control: UIView) -> UIView {
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: [label, control])
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        return stack
    }

    private func makeChannelRow(
        symbol: String,
        titleLabel: UILabel,
        toggle: UISwitch,
        slider: UISlider,
        valueLabel: UILabel,
        storeToneButton: (UIButton) -> Void,
        onTone: @escaping () -> Void
    ) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 10
        container.isLayoutMarginsRelativeArrangement = true
        container.layoutMargins = UIEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)

        let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18)
        ])

        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        var toneCfg = UIButton.Configuration.filled()
        toneCfg.baseBackgroundColor = CarAutoPadTheme.pill
        toneCfg.baseForegroundColor = .label
        toneCfg.cornerStyle = .capsule
        toneCfg.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        toneCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 11, weight: .medium)
            return out
        }
        let toneBtn = UIButton(configuration: toneCfg)
        toneBtn.setContentHuggingPriority(.required, for: .horizontal)
        toneBtn.addAction(UIAction { _ in onTone() }, for: .touchUpInside)
        storeToneButton(toneBtn)

        toggle.onTintColor = CarAutoPadTheme.accentGreen

        let topRow = UIStackView(arrangedSubviews: [icon, titleLabel, toneBtn, toggle])
        topRow.axis = .horizontal
        topRow.spacing = 10
        topRow.alignment = .center
        container.addArrangedSubview(topRow)

        slider.minimumValue = 0.0
        slider.maximumValue = ProjectionSettings.maxChannelVolume
        slider.minimumTrackTintColor = CarAutoPadTheme.accentBlue

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        let sliderRow = UIStackView(arrangedSubviews: [slider, valueLabel])
        sliderRow.axis = .horizontal
        sliderRow.spacing = 12
        sliderRow.alignment = .center
        container.addArrangedSubview(sliderRow)

        return container
    }

    private func makeDuckingBlock() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 12
        container.isLayoutMarginsRelativeArrangement = true
        container.layoutMargins = UIEdgeInsets(top: 14, left: 20, bottom: 16, right: 20)

        duckingTitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        duckingTitleLabel.textColor = .label
        duckingTitleLabel.adjustsFontSizeToFitWidth = true
        duckingTitleLabel.minimumScaleFactor = 0.75

        duckingStatusLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        duckingStatusLabel.textColor = CarAutoPadTheme.accentBlue
        duckingStatusLabel.textAlignment = .right
        duckingStatusLabel.adjustsFontSizeToFitWidth = true
        duckingStatusLabel.minimumScaleFactor = 0.75

        let head = UIStackView(arrangedSubviews: [duckingTitleLabel, duckingStatusLabel])
        head.axis = .horizontal
        head.spacing = 10
        head.alignment = .center
        container.addArrangedSubview(head)

        duckingSlider.minimumValue = 0.0
        duckingSlider.maximumValue = 1.0
        duckingSlider.minimumTrackTintColor = CarAutoPadTheme.accentBlue
        container.addArrangedSubview(duckingSlider)

        let presetRow = UIStackView()
        presetRow.axis = .horizontal
        presetRow.spacing = 8
        presetRow.distribution = .fillEqually
        for preset in NavigationDuckingPreset.allCases {
            let btn = UIButton(type: .system)
            btn.layer.cornerRadius = 15
            btn.layer.cornerCurve = .continuous
            btn.titleLabel?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            btn.titleLabel?.numberOfLines = 1
            btn.titleLabel?.adjustsFontSizeToFitWidth = true
            btn.titleLabel?.minimumScaleFactor = 0.65
            btn.heightAnchor.constraint(equalToConstant: 30).isActive = true
            btn.addAction(UIAction { [weak self] _ in
                self?.applyDucking(preset.reductionAmount)
            }, for: .touchUpInside)
            duckPresetButtons.append((preset, btn))
            presetRow.addArrangedSubview(btn)
        }
        container.addArrangedSubview(presetRow)

        return container
    }

    private func makeFooterActionBar() -> UIView {
        testDuckingButton.setTitleColor(CarAutoPadTheme.accentBlue, for: .normal)
        testDuckingButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        testDuckingButton.titleLabel?.adjustsFontSizeToFitWidth = true
        testDuckingButton.titleLabel?.minimumScaleFactor = 0.75
        testDuckingButton.addAction(UIAction { _ in
            AudioStreamTester.shared.playDuckingTestSequence()
        }, for: .touchUpInside)

        resetAudioButton.setTitleColor(.secondaryLabel, for: .normal)
        resetAudioButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        resetAudioButton.titleLabel?.adjustsFontSizeToFitWidth = true
        resetAudioButton.titleLabel?.minimumScaleFactor = 0.75
        resetAudioButton.addAction(UIAction { [weak self] _ in
            self?.resetAudioVolumes()
        }, for: .touchUpInside)

        let vDiv = UIView()
        vDiv.translatesAutoresizingMaskIntoConstraints = false
        vDiv.backgroundColor = CarAutoPadTheme.hairline
        vDiv.widthAnchor.constraint(equalToConstant: 0.5).isActive = true

        let bar = UIStackView(arrangedSubviews: [testDuckingButton, vDiv, resetAudioButton])
        bar.axis = .horizontal
        bar.alignment = .fill
        bar.distribution = .fill
        NSLayoutConstraint.activate([
            bar.heightAnchor.constraint(equalToConstant: 46),
            testDuckingButton.widthAnchor.constraint(equalTo: resetAudioButton.widthAnchor)
        ])
        return bar
    }

    private func wireMixerActions() {
        mediaSwitch.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            ProjectionSettings.isMediaChannelEnabled = self.mediaSwitch.isOn
            PCMAudioPlayer.shared.refreshVolumes()
            self.syncWithCurrentSettings()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)

        mediaSlider.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            ProjectionSettings.mediaVolume = (self.mediaSlider.value * 100).rounded() / 100.0
            self.mediaValueLabel.text = "\(Int((ProjectionSettings.mediaVolume * 100).rounded()))%"
            PCMAudioPlayer.shared.refreshVolumes()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)

        navSwitch.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            ProjectionSettings.isNavigationChannelEnabled = self.navSwitch.isOn
            PCMAudioPlayer.shared.refreshVolumes()
            self.syncWithCurrentSettings()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)

        navSlider.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            ProjectionSettings.navigationVolume = (self.navSlider.value * 100).rounded() / 100.0
            self.navValueLabel.text = "\(Int((ProjectionSettings.navigationVolume * 100).rounded()))%"
            PCMAudioPlayer.shared.refreshVolumes()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)

        sysSwitch.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            ProjectionSettings.isSystemChannelEnabled = self.sysSwitch.isOn
            PCMAudioPlayer.shared.refreshVolumes()
            self.syncWithCurrentSettings()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)

        sysSlider.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            ProjectionSettings.phoneSystemVolume = (self.sysSlider.value * 100).rounded() / 100.0
            self.sysValueLabel.text = "\(Int((ProjectionSettings.phoneSystemVolume * 100).rounded()))%"
            PCMAudioPlayer.shared.refreshVolumes()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)

        duckingSlider.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let val = (self.duckingSlider.value * 100).rounded() / 100.0
            self.applyDucking(val)
        }, for: .valueChanged)
    }

    func applyLocalization() {
        titleLabel.text = L10n.sidebarAudioMixer
        videoCodecLabel.text = L10n.videoCodecRow
        audioCodecLabel.text = L10n.audioCodecRow
        audioOutLabel.text = L10n.audioOutputRow
        micSourceLabel.text = L10n.microphoneSourceRow
        lockedFooterLabel.text = L10n.sessionLockedHandshakeFooter
        mixerSectionHeader.text = L10n.sectionVolumeAndNav

        audioOutSegment.setTitle(L10n.audioTargetIpadSegment, forSegmentAt: 0)
        audioOutSegment.setTitle(L10n.audioTargetPhoneSegment, forSegmentAt: 1)

        micSourceSegment.setTitle(L10n.micFollowSegment, forSegmentAt: 0)
        micSourceSegment.setTitle(L10n.micIpadSegment, forSegmentAt: 1)
        micSourceSegment.setTitle(L10n.micPhoneSegment, forSegmentAt: 2)

        mediaTitleLabel.text = L10n.mediaAudio
        navTitleLabel.text = L10n.navigationGuidance
        sysTitleLabel.text = L10n.phoneSystemAlerts
        duckingTitleLabel.text = L10n.navigationDuckingDrop
        for toneBtn in [mediaToneButton, navToneButton, sysToneButton] {
            if var cfg = toneBtn?.configuration {
                cfg.title = L10n.sampleToneButtonShort
                toneBtn?.configuration = cfg
            }
        }
        testDuckingButton.setTitle(L10n.testNavDucking, for: .normal)
        resetAudioButton.setTitle(L10n.resetAudio, for: .normal)

        for (preset, btn) in duckPresetButtons {
            btn.setTitle(preset.shortTitle, for: .normal)
        }
        syncWithCurrentSettings()
    }

    func syncWithCurrentSettings() {
        let locked = isHandshakeLocked

        videoCodecSegment.selectedSegmentIndex = (ProjectionSettings.videoCodecPreference == .h264) ? 0 : 1
        audioCodecSegment.selectedSegmentIndex = (ProjectionSettings.audioCodecPreference == .aac) ? 0 : 1
        audioOutSegment.selectedSegmentIndex = (ProjectionSettings.audioOutputTarget == .ipad) ? 0 : 1
        switch ProjectionSettings.microphoneSource {
        case .followAudioOutput: micSourceSegment.selectedSegmentIndex = 0
        case .ipad: micSourceSegment.selectedSegmentIndex = 1
        case .phone: micSourceSegment.selectedSegmentIndex = 2
        }

        for seg in [videoCodecSegment, audioCodecSegment, audioOutSegment, micSourceSegment] {
            seg.isEnabled = !locked
        }
        routingRow1.alpha = locked ? CarAutoPadTheme.lockedAlpha : 1.0
        routingRow2.alpha = locked ? CarAutoPadTheme.lockedAlpha : 1.0
        lockedFooterLabel.isHidden = !locked

        let isSink = ProjectionSettings.isAudioSinkEnabled
        mediaSwitch.isEnabled = isSink
        mediaSlider.isEnabled = isSink && ProjectionSettings.isMediaChannelEnabled
        mediaToneButton?.isEnabled = isSink
        mediaToneButton?.alpha = isSink ? 1.0 : CarAutoPadTheme.lockedAlpha

        navSwitch.isEnabled = isSink
        navSlider.isEnabled = isSink && ProjectionSettings.isNavigationChannelEnabled
        navToneButton?.isEnabled = isSink
        navToneButton?.alpha = isSink ? 1.0 : CarAutoPadTheme.lockedAlpha

        sysSwitch.isEnabled = isSink
        sysSlider.isEnabled = isSink && ProjectionSettings.isSystemChannelEnabled
        sysToneButton?.isEnabled = isSink
        sysToneButton?.alpha = isSink ? 1.0 : CarAutoPadTheme.lockedAlpha

        duckingSlider.isEnabled = isSink
        testDuckingButton.isEnabled = isSink
        testDuckingButton.alpha = isSink ? 1.0 : CarAutoPadTheme.lockedAlpha

        mediaSwitch.isOn = ProjectionSettings.isMediaChannelEnabled
        mediaSlider.value = ProjectionSettings.mediaVolume
        mediaValueLabel.text = !isSink ? L10n.notAvailableShort : (ProjectionSettings.isMediaChannelEnabled ? "\(Int((ProjectionSettings.mediaVolume * 100).rounded()))%" : L10n.off)

        navSwitch.isOn = ProjectionSettings.isNavigationChannelEnabled
        navSlider.value = ProjectionSettings.navigationVolume
        navValueLabel.text = !isSink ? L10n.notAvailableShort : (ProjectionSettings.isNavigationChannelEnabled ? "\(Int((ProjectionSettings.navigationVolume * 100).rounded()))%" : L10n.off)

        sysSwitch.isOn = ProjectionSettings.isSystemChannelEnabled
        sysSlider.value = ProjectionSettings.phoneSystemVolume
        sysValueLabel.text = !isSink ? L10n.notAvailableShort : (ProjectionSettings.isSystemChannelEnabled ? "\(Int((ProjectionSettings.phoneSystemVolume * 100).rounded()))%" : L10n.off)

        let amount = ProjectionSettings.navigationDuckingAmount
        duckingSlider.value = amount
        updateDuckingDisplay(amount: amount)
    }

    private func applyDucking(_ amount: Float) {
        let rounded = (amount * 100).rounded() / 100.0
        ProjectionSettings.navigationDuckingAmount = rounded
        duckingSlider.value = rounded
        updateDuckingDisplay(amount: rounded)
        PCMAudioPlayer.shared.refreshVolumes()
        onSettingsChanged?(.audioVolumeOrDuckingChanged)
    }

    private func updateDuckingDisplay(amount: Float) {
        let isSink = ProjectionSettings.isAudioSinkEnabled
        let pct = Int((amount * 100).rounded())
        if !isSink {
            duckingStatusLabel.text = L10n.duckingDisabledPhoneAudio
            duckingStatusLabel.textColor = .secondaryLabel
        } else {
            duckingStatusLabel.textColor = CarAutoPadTheme.accentBlue
            if pct == 0 {
                duckingStatusLabel.text = L10n.duckingOffTitle
            } else if pct == 100 {
                duckingStatusLabel.text = L10n.duckingMuteTitle
            } else {
                duckingStatusLabel.text = L10n.duckingStatusRetained(pct: pct, retained: 100 - pct)
            }
        }
        for (preset, btn) in duckPresetButtons {
            btn.isEnabled = isSink
            let isSelected = isSink && (preset.dropPercentage == pct)
            btn.backgroundColor = isSelected ? CarAutoPadTheme.accentBlue : CarAutoPadTheme.pill
            btn.setTitleColor(isSelected ? .white : .secondaryLabel, for: .normal)
            btn.alpha = isSink ? 1.0 : CarAutoPadTheme.lockedAlpha
        }
    }

    private func resetAudioVolumes() {
        ProjectionSettings.mediaVolume = ProjectionSettings.defaultChannelVolume
        ProjectionSettings.navigationVolume = ProjectionSettings.defaultChannelVolume
        ProjectionSettings.phoneSystemVolume = ProjectionSettings.defaultChannelVolume
        ProjectionSettings.isMediaChannelEnabled = true
        ProjectionSettings.isNavigationChannelEnabled = true
        ProjectionSettings.isSystemChannelEnabled = true
        ProjectionSettings.navigationDuckingAmount = ProjectionSettings.defaultNavigationDuckingAmount
        PCMAudioPlayer.shared.refreshVolumes()
        syncWithCurrentSettings()
        onSettingsChanged?(.audioVolumeOrDuckingChanged)
    }

    @objc private func videoCodecChanged() {
        ProjectionSettings.videoCodecPreference = (videoCodecSegment.selectedSegmentIndex == 0) ? .h264 : .hevc
        onSettingsChanged?(.uiOnly)
    }

    @objc private func audioCodecChanged() {
        ProjectionSettings.audioCodecPreference = (audioCodecSegment.selectedSegmentIndex == 0) ? .aac : .pcm
        onSettingsChanged?(.uiOnly)
    }

    @objc private func audioOutChanged() {
        ProjectionSettings.audioOutputTarget = (audioOutSegment.selectedSegmentIndex == 0) ? .ipad : .phone
        syncWithCurrentSettings()
        onSettingsChanged?(.audioVolumeOrDuckingChanged)
    }

    @objc private func micSourceChanged() {
        let sources: [MicrophoneSource] = [.followAudioOutput, .ipad, .phone]
        let idx = micSourceSegment.selectedSegmentIndex
        guard idx >= 0 && idx < sources.count else { return }
        ProjectionSettings.microphoneSource = sources[idx]
        onSettingsChanged?(.uiOnly)
    }
}

// MARK: - 3. Smart & Language Panel (Figma 06)

final class SmartLanguagePanelViewController: UIViewController {
    var onSettingsChanged: ((SettingsViewController.ChangeImpact) -> Void)?
    var openSettingsUrlHandler: ((URL) -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let titleLabel = CarAutoPadTheme.makePageTitleLabel(L10n.sidebarSmartLanguage, size: 30)

    private let nightCard = CarAutoPadTheme.makeCard(cornerRadius: 20)
    private let nightTitleLabel = UILabel()
    let nightModeSegment = UISegmentedControl(items: ["", "", "", "", ""])
    private let nightFooterLabel = CarAutoPadTheme.makeFooterLabel(L10n.smartNightModeFooter)

    private let locLangCard = CarAutoPadTheme.makeCard(cornerRadius: 20)
    private let gpsTitleLabel = UILabel()
    let gpsSegment = UISegmentedControl(items: ["", ""])
    let languageRowControl = UIControl()
    private let languageTitleLabel = UILabel()
    let languageValueLabel = UILabel()
    private let gpsFooterLabel = CarAutoPadTheme.makeFooterLabel(L10n.smartGpsFooter)

    private let nightModes: [NightModeSetting] = [.auto, .twilight, .day, .night, .system]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CarAutoPadTheme.canvas
        setupUI()
        applyLocalization()
        syncWithCurrentSettings()
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 22
        contentStack.alignment = .fill
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 34),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 44),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -44)
        ])

        contentStack.addArrangedSubview(titleLabel)

        // Group 1: Night Mode
        CarAutoPadTheme.styleSegmentedControl(nightModeSegment)
        nightModeSegment.addTarget(self, action: #selector(nightModeChanged), for: .valueChanged)
        nightTitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        nightTitleLabel.textColor = .label
        nightTitleLabel.adjustsFontSizeToFitWidth = true
        nightTitleLabel.minimumScaleFactor = 0.75

        let nightRow = UIStackView(arrangedSubviews: [nightTitleLabel, nightModeSegment])
        nightRow.translatesAutoresizingMaskIntoConstraints = false
        nightRow.axis = .horizontal
        nightRow.spacing = 12
        nightRow.alignment = .center
        nightCard.addSubview(nightRow)
        NSLayoutConstraint.activate([
            nightCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 58),
            nightRow.topAnchor.constraint(equalTo: nightCard.topAnchor, constant: 13),
            nightRow.bottomAnchor.constraint(equalTo: nightCard.bottomAnchor, constant: -13),
            nightRow.leadingAnchor.constraint(equalTo: nightCard.leadingAnchor, constant: 20),
            nightRow.trailingAnchor.constraint(equalTo: nightCard.trailingAnchor, constant: -20)
        ])

        let nightGroup = UIStackView(arrangedSubviews: [nightCard, nightFooterLabel])
        nightGroup.axis = .vertical
        nightGroup.spacing = 8
        contentStack.addArrangedSubview(nightGroup)

        // Group 2: GPS & Language
        CarAutoPadTheme.styleSegmentedControl(gpsSegment)
        gpsSegment.addTarget(self, action: #selector(gpsChanged), for: .valueChanged)
        gpsTitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        gpsTitleLabel.textColor = .label
        gpsTitleLabel.adjustsFontSizeToFitWidth = true
        gpsTitleLabel.minimumScaleFactor = 0.75

        let gpsRow = UIStackView(arrangedSubviews: [gpsTitleLabel, gpsSegment])
        gpsRow.axis = .horizontal
        gpsRow.spacing = 12
        gpsRow.alignment = .center
        gpsRow.isLayoutMarginsRelativeArrangement = true
        gpsRow.layoutMargins = UIEdgeInsets(top: 13, left: 20, bottom: 13, right: 20)

        languageRowControl.translatesAutoresizingMaskIntoConstraints = false
        languageRowControl.accessibilityIdentifier = "smart.languageRow"
        languageRowControl.addTarget(self, action: #selector(languageRowTapped), for: .touchUpInside)
        languageTitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        languageTitleLabel.textColor = .label
        languageTitleLabel.adjustsFontSizeToFitWidth = true
        languageTitleLabel.minimumScaleFactor = 0.75
        languageValueLabel.font = .systemFont(ofSize: 14, weight: .regular)
        languageValueLabel.textColor = .secondaryLabel
        let chev = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        chev.tintColor = .tertiaryLabel
        chev.setContentHuggingPriority(.required, for: .horizontal)

        let langRight = UIStackView(arrangedSubviews: [languageValueLabel, chev])
        langRight.axis = .horizontal
        langRight.spacing = 6
        langRight.alignment = .center
        langRight.isUserInteractionEnabled = false

        let langStack = UIStackView(arrangedSubviews: [languageTitleLabel, langRight])
        langStack.translatesAutoresizingMaskIntoConstraints = false
        langStack.axis = .horizontal
        langStack.spacing = 12
        langStack.alignment = .center
        langStack.isUserInteractionEnabled = false
        languageRowControl.addSubview(langStack)
        NSLayoutConstraint.activate([
            languageRowControl.heightAnchor.constraint(equalToConstant: 54),
            langStack.leadingAnchor.constraint(equalTo: languageRowControl.leadingAnchor, constant: 20),
            langStack.trailingAnchor.constraint(equalTo: languageRowControl.trailingAnchor, constant: -20),
            langStack.centerYAnchor.constraint(equalTo: languageRowControl.centerYAnchor)
        ])

        let locInner = UIStackView(arrangedSubviews: [
            gpsRow,
            CarAutoPadTheme.makeHairline(leadingInset: 20),
            languageRowControl
        ])
        locInner.translatesAutoresizingMaskIntoConstraints = false
        locInner.axis = .vertical
        locInner.spacing = 0
        locLangCard.addSubview(locInner)
        NSLayoutConstraint.activate([
            locInner.topAnchor.constraint(equalTo: locLangCard.topAnchor),
            locInner.bottomAnchor.constraint(equalTo: locLangCard.bottomAnchor),
            locInner.leadingAnchor.constraint(equalTo: locLangCard.leadingAnchor),
            locInner.trailingAnchor.constraint(equalTo: locLangCard.trailingAnchor)
        ])

        let locGroup = UIStackView(arrangedSubviews: [locLangCard, gpsFooterLabel])
        locGroup.axis = .vertical
        locGroup.spacing = 8
        contentStack.addArrangedSubview(locGroup)
    }

    func applyLocalization() {
        titleLabel.text = L10n.sidebarSmartLanguage
        nightTitleLabel.text = L10n.nightModeRow
        for (idx, mode) in nightModes.enumerated() {
            nightModeSegment.setTitle(mode.shortTitle, forSegmentAt: idx)
        }
        nightFooterLabel.text = L10n.smartNightModeFooter

        gpsTitleLabel.text = L10n.gpsSourceRow
        let supportsCellular = ProjectionSettings.supportsCellularIpad()
        gpsSegment.setTitle(supportsCellular ? L10n.gpsPhone : L10n.gpsPhoneOnlyWifiIpad, forSegmentAt: 0)
        gpsSegment.setTitle(L10n.gpsIpad, forSegmentAt: 1)
        gpsSegment.setEnabled(supportsCellular, forSegmentAt: 1)

        languageTitleLabel.text = L10n.languageRowTitle
        languageValueLabel.text = L10n.current.title
        gpsFooterLabel.text = L10n.smartGpsFooter

        syncWithCurrentSettings()
    }

    func syncWithCurrentSettings() {
        if let idx = nightModes.firstIndex(of: ProjectionSettings.nightMode) {
            nightModeSegment.selectedSegmentIndex = idx
        }
        let supportsCellular = ProjectionSettings.supportsCellularIpad()
        gpsSegment.setEnabled(supportsCellular, forSegmentAt: 1)
        gpsSegment.selectedSegmentIndex = (ProjectionSettings.gpsSource == .ipad && supportsCellular) ? 1 : 0
        languageValueLabel.text = L10n.current.title
    }

    func openSystemAppLanguageSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if let handler = openSettingsUrlHandler {
            handler(url)
            return
        }
        guard UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    @objc private func nightModeChanged() {
        let idx = nightModeSegment.selectedSegmentIndex
        guard idx >= 0 && idx < nightModes.count else { return }
        ProjectionSettings.nightMode = nightModes[idx]
        onSettingsChanged?(.nightModeChanged)
    }

    @objc private func gpsChanged() {
        ProjectionSettings.gpsSource = (gpsSegment.selectedSegmentIndex == 1) ? .ipad : .phone
        onSettingsChanged?(.uiOnly)
    }

    @objc private func languageRowTapped() {
        openSystemAppLanguageSettings()
    }
}
