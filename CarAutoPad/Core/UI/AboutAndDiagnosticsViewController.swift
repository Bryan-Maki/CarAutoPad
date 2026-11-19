import UIKit

/// Page 5: About (Figma 07) + 5-Tap Version Hidden Drill-Down to Automation & Diagnostics (Figma 08)
final class AboutAndDiagnosticsViewController: UIViewController {
    var connectionManager: ConnectionManager = ConnectionManager.shared
    var phoneStore: ConnectedPhoneStore = ConnectedPhoneStore.shared
    var onSettingsChanged: ((SettingsViewController.ChangeImpact) -> Void)?
    var onProvideDiagnosticLines: (() -> [String])?
    var onProvideVideoDiagnostics: (() -> (codec: String, droppedFrames: Int))?

    private(set) var isShowingDiagnosticsSubpage: Bool = false
    private var versionTapCount: Int = 0
    private var lastVersionTapUptime: TimeInterval = 0
    static let requiredVersionTapCount = 5
    private let versionTapWindowSeconds: TimeInterval = 2.8

    // --- About View (Figma 07) ---
    let aboutScrollView = UIScrollView()
    private let aboutRootStack = UIStackView()
    private let aboutTitleLabel = CarAutoPadTheme.makePageTitleLabel(L10n.sidebarAbout, size: 30)
    private let aboutColumnsStack = UIStackView()

    private let appInfoHeaderLabel = CarAutoPadTheme.makeSectionHeaderLabel(L10n.aboutAppInfoSection)
    private let appNameTitleLabel = UILabel()
    private let appNameValueLabel = UILabel()
    let versionRowControl = UIControl()
    private let versionTitleLabel = UILabel()
    let versionValueLabel = UILabel()
    private let protocolTitleLabel = UILabel()
    private let protocolValueLabel = UILabel()
    private let pipelineTitleLabel = UILabel()
    private let pipelineValueLabel = UILabel()

    // Visible ONLY once unlocked via 5 taps (hidden for normal users)
    let unlockedDiagnosticsEntryCard = CarAutoPadTheme.makeCard(cornerRadius: 20)
    private let unlockedEntryTitleLabel = UILabel()

    private let deviceInfoHeaderLabel = CarAutoPadTheme.makeSectionHeaderLabel(L10n.aboutThisDeviceSection)
    private let deviceModelTitleLabel = UILabel()
    let deviceModelValueLabel = UILabel()
    private let osVersionTitleLabel = UILabel()
    let osVersionValueLabel = UILabel()
    private let screenSpecTitleLabel = UILabel()
    let screenSpecValueLabel = UILabel()
    private let localIpTitleLabel = UILabel()
    let localIpValueLabel = UILabel()

    private let phonesHeaderLabel = CarAutoPadTheme.makeSectionHeaderLabel(L10n.aboutConnectedPhonesSection)
    let phonesCountLabel = UILabel()
    private let phonesCard = CarAutoPadTheme.makeCard(cornerRadius: 20)
    let phonesListStack = UIStackView()

    // --- Hidden Diagnostics Subpage (Figma 08) ---
    let diagnosticsScrollView = UIScrollView()
    private let diagRootStack = UIStackView()
    let backToAboutButton = UIButton(type: .system)
    let hideDiagnosticsButton = UIButton(type: .system)
    private let diagTitleLabel = CarAutoPadTheme.makePageTitleLabel(L10n.aboutHiddenDiagnosticsTitle, size: 28)
    private let diagUnlockedBadgeLabel = UILabel()
    private let diagColumnsStack = UIStackView()

    let autoReconnectSwitch = UISwitch()
    private let autoReconnectLabel = UILabel()
    let autoResumeSwitch = UISwitch()
    private let autoResumeLabel = UILabel()

    let debugModeSwitch = UISwitch()
    private let debugModeLabel = UILabel()
    private let logCategoriesRowLabel = UILabel()
    private let logCategoriesCountLabel = UILabel()
    private let liveDiagnosticsRowLabel = UILabel()
    private let exportLogsRowLabel = UILabel()
    private let backupRestoreRowLabel = UILabel()
    private let clearLogsRowLabel = UILabel()
    private let resetAllRowLabel = UILabel()

    private let rightLogHeaderLabel = CarAutoPadTheme.makeSectionHeaderLabel(L10n.debugLogCategoriesTitle)
    let enableAllCategoriesButton = UIButton(type: .system)
    private let logCategoriesStack = UIStackView()
    private var logCategorySwitches: [DebugLogCategory: UISwitch] = [:]
    private var logCategoryTitleLabels: [DebugLogCategory: UILabel] = [:]
    private var logCategorySubLabels: [DebugLogCategory: UILabel] = [:]

    private let linkDiagHeaderLabel = CarAutoPadTheme.makeSectionHeaderLabel(L10n.diagnosticsCurrentLinkSection)
    private let linkProtocolTitleLabel = UILabel()
    private let linkProtocolValueLabel = UILabel()
    private let linkVideoTitleLabel = UILabel()
    private let linkVideoValueLabel = UILabel()
    private let linkAudioTitleLabel = UILabel()
    private let linkAudioValueLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CarAutoPadTheme.canvas
        setupAboutView()
        setupDiagnosticsView()
        showAboutView(animated: false)
        applyLocalization()
        refreshDynamicData()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectedPhonesChanged),
            name: .carAutoPadConnectedPhonesDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let wide = view.bounds.width >= 720
        let axis: NSLayoutConstraint.Axis = wide ? .horizontal : .vertical
        if aboutColumnsStack.axis != axis {
            aboutColumnsStack.axis = axis
            aboutColumnsStack.distribution = wide ? .fillEqually : .fill
        }
        if diagColumnsStack.axis != axis {
            diagColumnsStack.axis = axis
            diagColumnsStack.distribution = wide ? .fillEqually : .fill
        }
    }

    // MARK: - Build About View (Figma 07 — Clean, zero hint footer!)

    private func setupAboutView() {
        aboutScrollView.translatesAutoresizingMaskIntoConstraints = false
        aboutScrollView.alwaysBounceVertical = true
        aboutScrollView.showsVerticalScrollIndicator = false
        view.addSubview(aboutScrollView)

        aboutRootStack.translatesAutoresizingMaskIntoConstraints = false
        aboutRootStack.axis = .vertical
        aboutRootStack.spacing = 22
        aboutScrollView.addSubview(aboutRootStack)

        NSLayoutConstraint.activate([
            aboutScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            aboutScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            aboutScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            aboutScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            aboutRootStack.topAnchor.constraint(equalTo: aboutScrollView.contentLayoutGuide.topAnchor, constant: 32),
            aboutRootStack.bottomAnchor.constraint(equalTo: aboutScrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            aboutRootStack.leadingAnchor.constraint(equalTo: aboutScrollView.frameLayoutGuide.leadingAnchor, constant: 40),
            aboutRootStack.trailingAnchor.constraint(equalTo: aboutScrollView.frameLayoutGuide.trailingAnchor, constant: -40)
        ])

        aboutRootStack.addArrangedSubview(aboutTitleLabel)

        aboutColumnsStack.axis = .horizontal
        aboutColumnsStack.spacing = 22
        aboutColumnsStack.alignment = .top
        aboutColumnsStack.distribution = .fillEqually
        aboutRootStack.addArrangedSubview(aboutColumnsStack)

        // Left Column: App Info + This Device (+ hidden entry card only if already unlocked)
        let leftCol = UIStackView()
        leftCol.axis = .vertical
        leftCol.spacing = 20
        aboutColumnsStack.addArrangedSubview(leftCol)

        // App Info Card
        let appSection = UIStackView()
        appSection.axis = .vertical
        appSection.spacing = 8
        appSection.addArrangedSubview(appInfoHeaderLabel)

        let appCard = CarAutoPadTheme.makeCard(cornerRadius: 20)
        let appStack = UIStackView()
        appStack.translatesAutoresizingMaskIntoConstraints = false
        appStack.axis = .vertical
        appCard.addSubview(appStack)
        NSLayoutConstraint.activate([
            appStack.topAnchor.constraint(equalTo: appCard.topAnchor),
            appStack.bottomAnchor.constraint(equalTo: appCard.bottomAnchor),
            appStack.leadingAnchor.constraint(equalTo: appCard.leadingAnchor),
            appStack.trailingAnchor.constraint(equalTo: appCard.trailingAnchor)
        ])

        // Version row is an interactive UIControl for 5-tap easter egg unlock
        versionRowControl.translatesAutoresizingMaskIntoConstraints = false
        versionRowControl.accessibilityIdentifier = "about.versionRow"
        versionRowControl.addTarget(self, action: #selector(versionRowTapped), for: .touchUpInside)
        populateKVRow(in: versionRowControl, titleLabel: versionTitleLabel, valueLabel: versionValueLabel, highlightValue: true, nonInteractiveChildren: true)

        let appNameRow = makeKVRow(titleLabel: appNameTitleLabel, valueLabel: appNameValueLabel)
        let protocolRow = makeKVRow(titleLabel: protocolTitleLabel, valueLabel: protocolValueLabel)
        let pipelineRow = makeKVRow(titleLabel: pipelineTitleLabel, valueLabel: pipelineValueLabel)

        appStack.addArrangedSubview(appNameRow)
        appStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        appStack.addArrangedSubview(versionRowControl)
        appStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        appStack.addArrangedSubview(protocolRow)
        appStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        appStack.addArrangedSubview(pipelineRow)

        appSection.addArrangedSubview(appCard)
        leftCol.addArrangedSubview(appSection)

        // This Device Card
        let devSection = UIStackView()
        devSection.axis = .vertical
        devSection.spacing = 8
        devSection.addArrangedSubview(deviceInfoHeaderLabel)

        let devCard = CarAutoPadTheme.makeCard(cornerRadius: 20)
        let devStack = UIStackView()
        devStack.translatesAutoresizingMaskIntoConstraints = false
        devStack.axis = .vertical
        devCard.addSubview(devStack)
        NSLayoutConstraint.activate([
            devStack.topAnchor.constraint(equalTo: devCard.topAnchor),
            devStack.bottomAnchor.constraint(equalTo: devCard.bottomAnchor),
            devStack.leadingAnchor.constraint(equalTo: devCard.leadingAnchor),
            devStack.trailingAnchor.constraint(equalTo: devCard.trailingAnchor)
        ])

        devStack.addArrangedSubview(makeKVRow(titleLabel: deviceModelTitleLabel, valueLabel: deviceModelValueLabel))
        devStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        devStack.addArrangedSubview(makeKVRow(titleLabel: osVersionTitleLabel, valueLabel: osVersionValueLabel))
        devStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        devStack.addArrangedSubview(makeKVRow(titleLabel: screenSpecTitleLabel, valueLabel: screenSpecValueLabel))
        devStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        devStack.addArrangedSubview(makeKVRow(titleLabel: localIpTitleLabel, valueLabel: localIpValueLabel))

        devSection.addArrangedSubview(devCard)
        leftCol.addArrangedSubview(devSection)

        // Unlocked Diagnostics Re-entry Row (ONLY shown when ProjectionSettings.isHiddenDiagnosticsUnlocked == true)
        let entryCtrl = UIControl()
        entryCtrl.translatesAutoresizingMaskIntoConstraints = false
        entryCtrl.accessibilityIdentifier = "about.unlockedDiagnosticsEntry"
        entryCtrl.addTarget(self, action: #selector(openDiagnosticsSubpageTapped), for: .touchUpInside)

        unlockedEntryTitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        unlockedEntryTitleLabel.textColor = CarAutoPadTheme.accentBlue
        let entryChev = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        entryChev.tintColor = .tertiaryLabel
        let entryStack = UIStackView(arrangedSubviews: [unlockedEntryTitleLabel, entryChev])
        entryStack.translatesAutoresizingMaskIntoConstraints = false
        entryStack.axis = .horizontal
        entryStack.alignment = .center
        entryStack.isUserInteractionEnabled = false
        entryCtrl.addSubview(entryStack)
        unlockedDiagnosticsEntryCard.addSubview(entryCtrl)
        NSLayoutConstraint.activate([
            entryCtrl.topAnchor.constraint(equalTo: unlockedDiagnosticsEntryCard.topAnchor),
            entryCtrl.bottomAnchor.constraint(equalTo: unlockedDiagnosticsEntryCard.bottomAnchor),
            entryCtrl.leadingAnchor.constraint(equalTo: unlockedDiagnosticsEntryCard.leadingAnchor),
            entryCtrl.trailingAnchor.constraint(equalTo: unlockedDiagnosticsEntryCard.trailingAnchor),
            entryCtrl.heightAnchor.constraint(equalToConstant: 48),
            entryStack.leadingAnchor.constraint(equalTo: entryCtrl.leadingAnchor, constant: 18),
            entryStack.trailingAnchor.constraint(equalTo: entryCtrl.trailingAnchor, constant: -18),
            entryStack.centerYAnchor.constraint(equalTo: entryCtrl.centerYAnchor)
        ])
        leftCol.addArrangedSubview(unlockedDiagnosticsEntryCard)

        // Right Column: Connected Phones History (100% real records from ConnectedPhoneStore)
        let rightCol = UIStackView()
        rightCol.axis = .vertical
        rightCol.spacing = 8
        aboutColumnsStack.addArrangedSubview(rightCol)

        phonesCountLabel.font = .systemFont(ofSize: 12, weight: .regular)
        phonesCountLabel.textColor = .tertiaryLabel
        let phonesHeader = UIStackView(arrangedSubviews: [phonesHeaderLabel, phonesCountLabel])
        phonesHeader.axis = .horizontal
        phonesHeader.distribution = .equalSpacing
        phonesHeader.alignment = .center
        rightCol.addArrangedSubview(phonesHeader)

        phonesListStack.translatesAutoresizingMaskIntoConstraints = false
        phonesListStack.axis = .vertical
        phonesListStack.spacing = 0
        phonesCard.addSubview(phonesListStack)
        NSLayoutConstraint.activate([
            phonesListStack.topAnchor.constraint(equalTo: phonesCard.topAnchor),
            phonesListStack.bottomAnchor.constraint(equalTo: phonesCard.bottomAnchor),
            phonesListStack.leadingAnchor.constraint(equalTo: phonesCard.leadingAnchor),
            phonesListStack.trailingAnchor.constraint(equalTo: phonesCard.trailingAnchor)
        ])
        rightCol.addArrangedSubview(phonesCard)
    }

    // MARK: - Build Hidden Diagnostics Subpage (Figma 08)

    private func setupDiagnosticsView() {
        diagnosticsScrollView.translatesAutoresizingMaskIntoConstraints = false
        diagnosticsScrollView.alwaysBounceVertical = true
        diagnosticsScrollView.showsVerticalScrollIndicator = false
        diagnosticsScrollView.isHidden = true
        view.addSubview(diagnosticsScrollView)

        diagRootStack.translatesAutoresizingMaskIntoConstraints = false
        diagRootStack.axis = .vertical
        diagRootStack.spacing = 16
        diagnosticsScrollView.addSubview(diagRootStack)

        NSLayoutConstraint.activate([
            diagnosticsScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            diagnosticsScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            diagnosticsScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            diagnosticsScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            diagRootStack.topAnchor.constraint(equalTo: diagnosticsScrollView.contentLayoutGuide.topAnchor, constant: 22),
            diagRootStack.bottomAnchor.constraint(equalTo: diagnosticsScrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            diagRootStack.leadingAnchor.constraint(equalTo: diagnosticsScrollView.frameLayoutGuide.leadingAnchor, constant: 40),
            diagRootStack.trailingAnchor.constraint(equalTo: diagnosticsScrollView.frameLayoutGuide.trailingAnchor, constant: -40)
        ])

        // Top Subpage Bar: < About | Hide Entry
        backToAboutButton.accessibilityIdentifier = "diagnostics.backButton"
        var backCfg = UIButton.Configuration.plain()
        backCfg.image = UIImage(systemName: "chevron.left", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
        backCfg.imagePadding = 4
        backCfg.contentInsets = .zero
        backCfg.baseForegroundColor = CarAutoPadTheme.accentBlue
        backToAboutButton.configuration = backCfg
        backToAboutButton.addTarget(self, action: #selector(backToAboutTapped), for: .touchUpInside)

        hideDiagnosticsButton.accessibilityIdentifier = "diagnostics.hideEntryButton"
        hideDiagnosticsButton.setTitleColor(.secondaryLabel, for: .normal)
        hideDiagnosticsButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        hideDiagnosticsButton.addTarget(self, action: #selector(hideDiagnosticsTapped), for: .touchUpInside)

        let topBar = UIStackView(arrangedSubviews: [backToAboutButton, hideDiagnosticsButton])
        topBar.axis = .horizontal
        topBar.distribution = .equalSpacing
        topBar.alignment = .center
        diagRootStack.addArrangedSubview(topBar)

        diagUnlockedBadgeLabel.font = .systemFont(ofSize: 12, weight: .regular)
        diagUnlockedBadgeLabel.textColor = .tertiaryLabel
        let titleBar = UIStackView(arrangedSubviews: [diagTitleLabel, diagUnlockedBadgeLabel])
        titleBar.axis = .horizontal
        titleBar.distribution = .equalSpacing
        titleBar.alignment = .lastBaseline
        diagRootStack.addArrangedSubview(titleBar)

        diagColumnsStack.axis = .horizontal
        diagColumnsStack.spacing = 20
        diagColumnsStack.alignment = .top
        diagColumnsStack.distribution = .fillEqually
        diagRootStack.addArrangedSubview(diagColumnsStack)

        // Left Column: Automation + Debug/Maintenance Actions
        let leftCol = UIStackView()
        leftCol.axis = .vertical
        leftCol.spacing = 14
        diagColumnsStack.addArrangedSubview(leftCol)

        let autoCard = CarAutoPadTheme.makeCard(cornerRadius: 20)
        let autoStack = UIStackView()
        autoStack.translatesAutoresizingMaskIntoConstraints = false
        autoStack.axis = .vertical
        autoCard.addSubview(autoStack)
        NSLayoutConstraint.activate([
            autoStack.topAnchor.constraint(equalTo: autoCard.topAnchor),
            autoStack.bottomAnchor.constraint(equalTo: autoCard.bottomAnchor),
            autoStack.leadingAnchor.constraint(equalTo: autoCard.leadingAnchor),
            autoStack.trailingAnchor.constraint(equalTo: autoCard.trailingAnchor)
        ])

        autoReconnectSwitch.onTintColor = CarAutoPadTheme.accentGreen
        autoReconnectSwitch.addTarget(self, action: #selector(autoReconnectChanged), for: .valueChanged)
        autoResumeSwitch.onTintColor = CarAutoPadTheme.accentGreen
        autoResumeSwitch.addTarget(self, action: #selector(autoResumeChanged), for: .valueChanged)

        autoStack.addArrangedSubview(makeSwitchRow(label: autoReconnectLabel, toggle: autoReconnectSwitch))
        autoStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        autoStack.addArrangedSubview(makeSwitchRow(label: autoResumeLabel, toggle: autoResumeSwitch))
        leftCol.addArrangedSubview(autoCard)

        let maintCard = CarAutoPadTheme.makeCard(cornerRadius: 20)
        let maintStack = UIStackView()
        maintStack.translatesAutoresizingMaskIntoConstraints = false
        maintStack.axis = .vertical
        maintCard.addSubview(maintStack)
        NSLayoutConstraint.activate([
            maintStack.topAnchor.constraint(equalTo: maintCard.topAnchor),
            maintStack.bottomAnchor.constraint(equalTo: maintCard.bottomAnchor),
            maintStack.leadingAnchor.constraint(equalTo: maintCard.leadingAnchor),
            maintStack.trailingAnchor.constraint(equalTo: maintCard.trailingAnchor)
        ])

        debugModeSwitch.onTintColor = CarAutoPadTheme.accentGreen
        debugModeSwitch.addTarget(self, action: #selector(debugModeChanged), for: .valueChanged)

        maintStack.addArrangedSubview(makeSwitchRow(label: debugModeLabel, toggle: debugModeSwitch))
        maintStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        maintStack.addArrangedSubview(makeActionRow(label: logCategoriesRowLabel, valueLabel: logCategoriesCountLabel, showChevron: true, tint: .label, action: #selector(openLogCategoriesModal)))
        maintStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        maintStack.addArrangedSubview(makeActionRow(label: liveDiagnosticsRowLabel, valueLabel: nil, showChevron: true, tint: .label, action: #selector(presentLiveDiagnostics)))
        maintStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        maintStack.addArrangedSubview(makeActionRow(label: exportLogsRowLabel, valueLabel: nil, showChevron: true, tint: .label, action: #selector(presentLogExportMenu(_:))))
        maintStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        maintStack.addArrangedSubview(makeActionRow(label: backupRestoreRowLabel, valueLabel: nil, showChevron: true, tint: .label, action: #selector(presentBackupRestoreMenu(_:))))
        maintStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        maintStack.addArrangedSubview(makeActionRow(label: clearLogsRowLabel, valueLabel: nil, showChevron: false, tint: CarAutoPadTheme.accentOrange, action: #selector(clearDiagnosticLogs)))
        maintStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        maintStack.addArrangedSubview(makeActionRow(label: resetAllRowLabel, valueLabel: nil, showChevron: false, tint: CarAutoPadTheme.accentRed, action: #selector(presentResetDefaultsAlert)))
        leftCol.addArrangedSubview(maintCard)

        // Right Column: Inline 5 Log Categories + Live Link Telemetry
        let rightCol = UIStackView()
        rightCol.axis = .vertical
        rightCol.spacing = 14
        diagColumnsStack.addArrangedSubview(rightCol)

        let logSec = UIStackView()
        logSec.axis = .vertical
        logSec.spacing = 8
        enableAllCategoriesButton.setTitleColor(CarAutoPadTheme.accentBlue, for: .normal)
        enableAllCategoriesButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        enableAllCategoriesButton.addTarget(self, action: #selector(enableAllCategoriesTapped), for: .touchUpInside)
        let logHead = UIStackView(arrangedSubviews: [rightLogHeaderLabel, enableAllCategoriesButton])
        logHead.axis = .horizontal
        logHead.distribution = .equalSpacing
        logHead.alignment = .center
        logSec.addArrangedSubview(logHead)

        let logCard = CarAutoPadTheme.makeCard(cornerRadius: 20)
        logCategoriesStack.translatesAutoresizingMaskIntoConstraints = false
        logCategoriesStack.axis = .vertical
        logCard.addSubview(logCategoriesStack)
        NSLayoutConstraint.activate([
            logCategoriesStack.topAnchor.constraint(equalTo: logCard.topAnchor),
            logCategoriesStack.bottomAnchor.constraint(equalTo: logCard.bottomAnchor),
            logCategoriesStack.leadingAnchor.constraint(equalTo: logCard.leadingAnchor),
            logCategoriesStack.trailingAnchor.constraint(equalTo: logCard.trailingAnchor)
        ])

        for (idx, cat) in DebugLogCategory.allCases.enumerated() {
            if idx > 0 {
                logCategoriesStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
            }
            let titleLbl = UILabel()
            titleLbl.font = .systemFont(ofSize: 13, weight: .medium)
            titleLbl.textColor = .label
            titleLbl.adjustsFontSizeToFitWidth = true
            titleLbl.minimumScaleFactor = 0.75

            let subLbl = UILabel()
            subLbl.font = .systemFont(ofSize: 11, weight: .regular)
            subLbl.textColor = .secondaryLabel
            subLbl.numberOfLines = 2

            let toggle = UISwitch()
            toggle.onTintColor = CarAutoPadTheme.accentGreen
            toggle.addAction(UIAction { [weak self] _ in
                ProjectionSettings.setDebugCategory(cat, enabled: toggle.isOn)
                self?.refreshDiagnosticsSummary()
            }, for: .valueChanged)

            logCategoryTitleLabels[cat] = titleLbl
            logCategorySubLabels[cat] = subLbl
            logCategorySwitches[cat] = toggle

            let txtStack = UIStackView(arrangedSubviews: [titleLbl, subLbl])
            txtStack.axis = .vertical
            txtStack.spacing = 2

            let row = UIStackView(arrangedSubviews: [txtStack, toggle])
            row.axis = .horizontal
            row.spacing = 12
            row.alignment = .center
            row.isLayoutMarginsRelativeArrangement = true
            row.layoutMargins = UIEdgeInsets(top: 11, left: 18, bottom: 11, right: 18)
            logCategoriesStack.addArrangedSubview(row)
        }

        logSec.addArrangedSubview(logCard)
        rightCol.addArrangedSubview(logSec)

        // Live Link Diagnostics Summary
        let linkSec = UIStackView()
        linkSec.axis = .vertical
        linkSec.spacing = 8
        linkSec.addArrangedSubview(linkDiagHeaderLabel)

        let linkCard = CarAutoPadTheme.makeCard(cornerRadius: 20)
        let linkStack = UIStackView()
        linkStack.translatesAutoresizingMaskIntoConstraints = false
        linkStack.axis = .vertical
        linkCard.addSubview(linkStack)
        NSLayoutConstraint.activate([
            linkStack.topAnchor.constraint(equalTo: linkCard.topAnchor),
            linkStack.bottomAnchor.constraint(equalTo: linkCard.bottomAnchor),
            linkStack.leadingAnchor.constraint(equalTo: linkCard.leadingAnchor),
            linkStack.trailingAnchor.constraint(equalTo: linkCard.trailingAnchor)
        ])

        linkStack.addArrangedSubview(makeKVRow(titleLabel: linkProtocolTitleLabel, valueLabel: linkProtocolValueLabel))
        linkStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        linkStack.addArrangedSubview(makeKVRow(titleLabel: linkVideoTitleLabel, valueLabel: linkVideoValueLabel))
        linkStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 18))
        linkStack.addArrangedSubview(makeKVRow(titleLabel: linkAudioTitleLabel, valueLabel: linkAudioValueLabel))

        linkSec.addArrangedSubview(linkCard)
        rightCol.addArrangedSubview(linkSec)
    }

    // MARK: - Row Builders

    private func makeKVRow(titleLabel: UILabel, valueLabel: UILabel) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        populateKVRow(in: row, titleLabel: titleLabel, valueLabel: valueLabel, highlightValue: false, nonInteractiveChildren: false)
        return row
    }

    private func populateKVRow(
        in container: UIView,
        titleLabel: UILabel,
        valueLabel: UILabel,
        highlightValue: Bool,
        nonInteractiveChildren: Bool
    ) {
        titleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        titleLabel.textColor = .label
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: highlightValue ? .medium : .regular)
        valueLabel.textColor = highlightValue ? .label : .secondaryLabel
        valueLabel.textAlignment = .right
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.72

        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.isUserInteractionEnabled = !nonInteractiveChildren
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 46),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18)
        ])
    }

    private func makeSwitchRow(label: UILabel, toggle: UISwitch) -> UIView {
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        let row = UIStackView(arrangedSubviews: [label, toggle])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        return row
    }

    private func makeActionRow(
        label: UILabel,
        valueLabel: UILabel?,
        showChevron: Bool,
        tint: UIColor,
        action: Selector
    ) -> UIControl {
        let ctrl = UIControl()
        ctrl.translatesAutoresizingMaskIntoConstraints = false
        ctrl.addTarget(self, action: action, for: .touchUpInside)

        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = tint
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75

        var arranged: [UIView] = [label]
        if valueLabel != nil || showChevron {
            let right = UIStackView()
            right.axis = .horizontal
            right.spacing = 6
            right.alignment = .center
            right.isUserInteractionEnabled = false
            if let vl = valueLabel {
                vl.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
                vl.textColor = .secondaryLabel
                right.addArrangedSubview(vl)
            }
            if showChevron {
                let chev = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
                chev.tintColor = .tertiaryLabel
                right.addArrangedSubview(chev)
            }
            arranged.append(right)
        }

        let stack = UIStackView(arrangedSubviews: arranged)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        ctrl.addSubview(stack)
        NSLayoutConstraint.activate([
            ctrl.heightAnchor.constraint(equalToConstant: 46),
            stack.leadingAnchor.constraint(equalTo: ctrl.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: ctrl.trailingAnchor, constant: -18),
            stack.centerYAnchor.constraint(equalTo: ctrl.centerYAnchor)
        ])
        return ctrl
    }

    // MARK: - Localization & Dynamic Refresh

    func applyLocalization() {
        aboutTitleLabel.text = L10n.sidebarAbout
        appInfoHeaderLabel.text = L10n.aboutAppInfoSection
        appNameTitleLabel.text = L10n.aboutAppNameRow
        versionTitleLabel.text = L10n.aboutVersionRow
        protocolTitleLabel.text = L10n.aboutProtocolRow
        pipelineTitleLabel.text = L10n.aboutDecodePipelineRow
        unlockedEntryTitleLabel.text = L10n.aboutHiddenDiagnosticsTitle

        deviceInfoHeaderLabel.text = L10n.aboutThisDeviceSection
        deviceModelTitleLabel.text = L10n.aboutDeviceModelRow
        osVersionTitleLabel.text = L10n.aboutOsVersionRow
        screenSpecTitleLabel.text = L10n.aboutScreenSpecRow
        localIpTitleLabel.text = L10n.aboutLocalIpRow
        phonesHeaderLabel.text = L10n.aboutConnectedPhonesSection

        if var backCfg = backToAboutButton.configuration {
            backCfg.title = L10n.sidebarAbout
            backToAboutButton.configuration = backCfg
        }
        hideDiagnosticsButton.setTitle(L10n.aboutHideDiagnosticsButton, for: .normal)
        diagTitleLabel.text = L10n.aboutHiddenDiagnosticsTitle
        diagUnlockedBadgeLabel.text = L10n.aboutUnlockedViaFiveTaps

        autoReconnectLabel.text = L10n.autoReconnectRow
        autoResumeLabel.text = L10n.autoResumePlaybackRow
        debugModeLabel.text = L10n.debugModeRow
        logCategoriesRowLabel.text = L10n.debugLogCategoriesRow
        liveDiagnosticsRowLabel.text = L10n.liveDiagnosticsReportRow
        exportLogsRowLabel.text = L10n.exportShareSessionLogsRow
        backupRestoreRowLabel.text = L10n.backupRestoreSettingsRow
        clearLogsRowLabel.text = L10n.clearAllDiagnosticLogsRow
        resetAllRowLabel.text = L10n.resetAllSettingsRow

        rightLogHeaderLabel.text = L10n.debugLogCategoriesTitle
        enableAllCategoriesButton.setTitle(L10n.enableAll, for: .normal)
        for cat in DebugLogCategory.allCases {
            logCategoryTitleLabels[cat]?.text = "\(cat.title) · \(cat.rawValue)"
            logCategorySubLabels[cat]?.text = cat.subtitle
        }

        linkDiagHeaderLabel.text = L10n.diagnosticsCurrentLinkSection
        linkProtocolTitleLabel.text = L10n.aboutProtocolRow
        linkVideoTitleLabel.text = L10n.diagnosticsVideoDecodeRow
        linkAudioTitleLabel.text = L10n.diagnosticsAudioPipelineRow

        refreshDynamicData()
    }

    func refreshDynamicData() {
        appNameValueLabel.text = CarAutoPadDeviceInfo.appName
        versionValueLabel.text = CarAutoPadDeviceInfo.appVersionString
        protocolValueLabel.text = "AAP v1.6 · TLS 1.3"
        pipelineValueLabel.text = "VideoToolbox · AudioToolbox"

        deviceModelValueLabel.text = CarAutoPadDeviceInfo.deviceModelDisplayName
        osVersionValueLabel.text = CarAutoPadDeviceInfo.osVersionDisplayName
        screenSpecValueLabel.text = CarAutoPadDeviceInfo.screenSpecDisplayName
        localIpValueLabel.text = CarAutoPadDeviceInfo.localIpDisplayName

        unlockedDiagnosticsEntryCard.isHidden = !ProjectionSettings.isHiddenDiagnosticsUnlocked
        rebuildConnectedPhonesList()
        refreshDiagnosticsSummary()
    }

    private func rebuildConnectedPhonesList() {
        for sub in phonesListStack.arrangedSubviews {
            phonesListStack.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }

        let items = phoneStore.records()
        phonesCountLabel.text = L10n.aboutDeviceCount(items.count)

        if items.isEmpty {
            let emptyStack = UIStackView()
            emptyStack.axis = .vertical
            emptyStack.spacing = 6
            emptyStack.alignment = .center
            emptyStack.isLayoutMarginsRelativeArrangement = true
            emptyStack.layoutMargins = UIEdgeInsets(top: 32, left: 20, bottom: 32, right: 20)

            let icon = UIImageView(image: UIImage(systemName: "iphone", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .light)))
            icon.tintColor = .tertiaryLabel
            let title = UILabel()
            title.text = L10n.aboutNoConnectedPhonesTitle
            title.font = .systemFont(ofSize: 15, weight: .medium)
            title.textColor = .secondaryLabel
            title.textAlignment = .center
            let sub = UILabel()
            sub.text = L10n.aboutNoConnectedPhonesSubtitle
            sub.font = .systemFont(ofSize: 12, weight: .regular)
            sub.textColor = .tertiaryLabel
            sub.numberOfLines = 0
            sub.textAlignment = .center

            emptyStack.addArrangedSubview(icon)
            emptyStack.addArrangedSubview(title)
            emptyStack.addArrangedSubview(sub)
            phonesListStack.addArrangedSubview(emptyStack)
            return
        }

        let dateFormatter = RelativeDateTimeFormatter()
        dateFormatter.unitsStyle = .short
        let now = Date()

        for (idx, record) in items.enumerated() {
            if idx > 0 {
                phonesListStack.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 66))
            }

            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 13
            row.alignment = .center
            row.isLayoutMarginsRelativeArrangement = true
            row.layoutMargins = UIEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)

            let badge = UIView()
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.backgroundColor = CarAutoPadTheme.elevated
            badge.layer.cornerRadius = 10
            badge.layer.cornerCurve = .continuous
            let phoneIcon = UIImageView(image: UIImage(systemName: "iphone", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)))
            phoneIcon.translatesAutoresizingMaskIntoConstraints = false
            phoneIcon.tintColor = (idx == 0) ? .label : .secondaryLabel
            badge.addSubview(phoneIcon)
            NSLayoutConstraint.activate([
                badge.widthAnchor.constraint(equalToConstant: 36),
                badge.heightAnchor.constraint(equalToConstant: 36),
                phoneIcon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
                phoneIcon.centerYAnchor.constraint(equalTo: badge.centerYAnchor)
            ])

            let nameLbl = UILabel()
            nameLbl.text = record.deviceName
            nameLbl.font = .systemFont(ofSize: 15, weight: .medium)
            nameLbl.textColor = .label
            nameLbl.lineBreakMode = .byTruncatingTail

            let modelLbl = UILabel()
            modelLbl.text = record.displaySubtitle
            modelLbl.font = .systemFont(ofSize: 12, weight: .regular)
            modelLbl.textColor = .secondaryLabel
            modelLbl.lineBreakMode = .byTruncatingTail

            let leftMeta = UIStackView(arrangedSubviews: [nameLbl, modelLbl])
            leftMeta.axis = .vertical
            leftMeta.spacing = 3

            let timeLbl = UILabel()
            timeLbl.text = dateFormatter.localizedString(for: record.lastConnectedAt, relativeTo: now)
            timeLbl.font = .systemFont(ofSize: 12, weight: .medium)
            timeLbl.textColor = .secondaryLabel
            timeLbl.textAlignment = .right

            let ipLbl = UILabel()
            ipLbl.text = record.ipAddress
            ipLbl.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            ipLbl.textColor = .tertiaryLabel
            ipLbl.textAlignment = .right

            let rightMeta = UIStackView(arrangedSubviews: [timeLbl, ipLbl])
            rightMeta.axis = .vertical
            rightMeta.spacing = 3
            rightMeta.alignment = .trailing
            rightMeta.setContentHuggingPriority(.required, for: .horizontal)

            let removeBtn = UIButton(type: .system)
            removeBtn.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)), for: .normal)
            removeBtn.tintColor = .tertiaryLabel
            removeBtn.accessibilityLabel = L10n.removeRecordAction
            removeBtn.setContentHuggingPriority(.required, for: .horizontal)
            let recordId = record.id
            removeBtn.addAction(UIAction { [weak self] _ in
                self?.phoneStore.remove(id: recordId)
            }, for: .touchUpInside)

            row.addArrangedSubview(badge)
            row.addArrangedSubview(leftMeta)
            row.addArrangedSubview(rightMeta)
            row.addArrangedSubview(removeBtn)
            phonesListStack.addArrangedSubview(row)
        }
    }

    private func refreshDiagnosticsSummary() {
        autoReconnectSwitch.isOn = ProjectionSettings.autoReconnect
        autoResumeSwitch.isOn = ProjectionSettings.autoResumePlayback
        debugModeSwitch.isOn = ProjectionSettings.isDebugModeEnabled

        let enabledCount = DebugLogCategory.allCases.filter { ProjectionSettings.isDebugCategoryEnabled($0) }.count
        logCategoriesCountLabel.text = L10n.debugCategoriesEnabledCount(enabled: enabledCount, total: DebugLogCategory.allCases.count)
        for cat in DebugLogCategory.allCases {
            logCategorySwitches[cat]?.isOn = ProjectionSettings.isDebugCategoryEnabled(cat)
        }

        linkProtocolValueLabel.text = "AAP v1.6 · TLS 1.3"
        let vidInfo = onProvideVideoDiagnostics?() ?? (codec: ProjectionSettings.videoCodecPreference == .hevc ? "HEVC" : "H.264", droppedFrames: 0)
        linkVideoValueLabel.text = "VideoToolbox \(vidInfo.codec) · \(L10n.diagnosticsDroppedFrames(vidInfo.droppedFrames))"
        let audioCodecText = ProjectionSettings.audioCodecPreference == .aac ? "AAC-LC" : "PCM"
        let duckPct = Int((ProjectionSettings.navigationDuckingAmount * 100).rounded())
        linkAudioValueLabel.text = "\(audioCodecText) 48kHz · -\(duckPct)%"
    }

    // MARK: - 5-Tap Unlock & Navigation

    func handleVersionRowTap(now: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        if ProjectionSettings.isHiddenDiagnosticsUnlocked {
            showDiagnosticsView(animated: true)
            return
        }
        if (now - lastVersionTapUptime) > versionTapWindowSeconds {
            versionTapCount = 0
        }
        lastVersionTapUptime = now
        versionTapCount += 1

        if versionTapCount >= Self.requiredVersionTapCount {
            versionTapCount = 0
            ProjectionSettings.isHiddenDiagnosticsUnlocked = true
            unlockedDiagnosticsEntryCard.isHidden = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showDiagnosticsView(animated: true)
        } else if versionTapCount >= 3 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func hideDiagnosticsAndReturnToAbout(animated: Bool = true) {
        ProjectionSettings.isHiddenDiagnosticsUnlocked = false
        versionTapCount = 0
        unlockedDiagnosticsEntryCard.isHidden = true
        showAboutView(animated: animated)
    }

    func showAboutView(animated: Bool = true) {
        isShowingDiagnosticsSubpage = false
        refreshDynamicData()
        if animated {
            aboutScrollView.alpha = 0
            aboutScrollView.isHidden = false
            UIView.animate(withDuration: 0.22) {
                self.aboutScrollView.alpha = 1
                self.diagnosticsScrollView.alpha = 0
            } completion: { _ in
                self.diagnosticsScrollView.isHidden = true
                self.diagnosticsScrollView.alpha = 1
            }
        } else {
            aboutScrollView.isHidden = false
            aboutScrollView.alpha = 1
            diagnosticsScrollView.isHidden = true
        }
    }

    func showDiagnosticsView(animated: Bool = true) {
        isShowingDiagnosticsSubpage = true
        refreshDiagnosticsSummary()
        if animated {
            diagnosticsScrollView.alpha = 0
            diagnosticsScrollView.isHidden = false
            UIView.animate(withDuration: 0.22) {
                self.diagnosticsScrollView.alpha = 1
                self.aboutScrollView.alpha = 0
            } completion: { _ in
                self.aboutScrollView.isHidden = true
                self.aboutScrollView.alpha = 1
            }
        } else {
            diagnosticsScrollView.isHidden = false
            diagnosticsScrollView.alpha = 1
            aboutScrollView.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func handleConnectedPhonesChanged() {
        rebuildConnectedPhonesList()
    }

    @objc private func versionRowTapped() {
        handleVersionRowTap()
    }

    @objc private func openDiagnosticsSubpageTapped() {
        showDiagnosticsView(animated: true)
    }

    @objc private func backToAboutTapped() {
        showAboutView(animated: true)
    }

    @objc private func hideDiagnosticsTapped() {
        hideDiagnosticsAndReturnToAbout(animated: true)
    }

    @objc private func autoReconnectChanged() {
        ProjectionSettings.autoReconnect = autoReconnectSwitch.isOn
        onSettingsChanged?(.uiOnly)
    }

    @objc private func autoResumeChanged() {
        ProjectionSettings.autoResumePlayback = autoResumeSwitch.isOn
        onSettingsChanged?(.uiOnly)
    }

    @objc private func debugModeChanged() {
        ProjectionSettings.isDebugModeEnabled = debugModeSwitch.isOn
        onSettingsChanged?(.uiOnly)
    }

    @objc private func enableAllCategoriesTapped() {
        ProjectionSettings.enableAllDebugCategories()
        refreshDiagnosticsSummary()
    }

    @objc private func openLogCategoriesModal() {
        let vc = DebugLogCategoriesViewController()
        let nav = UINavigationController(rootViewController: vc)
        vc.navigationItem.leftBarButtonItem = UIBarButtonItem(title: L10n.done, style: .done, target: self, action: #selector(dismissPresentedModal))
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    @objc private func dismissPresentedModal() {
        dismiss(animated: true) { [weak self] in
            self?.refreshDiagnosticsSummary()
        }
    }

    @objc private func presentLiveDiagnostics() {
        let lines = onProvideDiagnosticLines?() ?? connectionManager.diagnosticLines()
        let text = lines.joined(separator: "\n")
        let alert = UIAlertController(title: L10n.liveDiagnosticsTitle, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.copyToClipboard, style: .default) { _ in
            UIPasteboard.general.string = text
        })
        alert.addAction(UIAlertAction(title: L10n.close, style: .cancel))
        present(alert, animated: true)
    }

    @objc private func presentLogExportMenu(_ sender: UIView) {
        let alert = UIAlertController(title: L10n.exportShareLogsTitle, message: L10n.exportShareLogsMessage, preferredStyle: .actionSheet)
        if let pop = alert.popoverPresentationController {
            pop.sourceView = sender
            pop.sourceRect = sender.bounds
        }
        alert.addAction(UIAlertAction(title: L10n.copyLogToClipboard, style: .default) { _ in
            let text = LogExporter.exportToClipboardText()
            UIPasteboard.general.string = text
            AppLog.i("Diagnostic log copied to clipboard (\(text.utf8.count) bytes)", tag: "AboutDiagnostics")
        })
        alert.addAction(UIAlertAction(title: L10n.shareLogFileTxt, style: .default) { [weak self] _ in
            guard let self = self, let fileUrl = LogExporter.exportToTemporaryFile() else { return }
            let activity = UIActivityViewController(activityItems: [fileUrl], applicationActivities: nil)
            if let pop = activity.popoverPresentationController {
                pop.sourceView = sender
                pop.sourceRect = sender.bounds
            }
            self.present(activity, animated: true)
        })
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(alert, animated: true)
    }

    @objc private func presentBackupRestoreMenu(_ sender: UIView) {
        let alert = UIAlertController(title: L10n.backupRestoreTitle, message: L10n.backupRestoreMessage, preferredStyle: .actionSheet)
        if let pop = alert.popoverPresentationController {
            pop.sourceView = sender
            pop.sourceRect = sender.bounds
        }
        alert.addAction(UIAlertAction(title: L10n.copySettingsJsonToClipboard, style: .default) { [weak self] _ in
            UIPasteboard.general.string = SettingsBackupManager.exportToJson()
            let ok = UIAlertController(title: L10n.settingsExportedTitle, message: L10n.settingsExportedMessage, preferredStyle: .alert)
            ok.addAction(UIAlertAction(title: L10n.ok, style: .default))
            self?.present(ok, animated: true)
        })
        alert.addAction(UIAlertAction(title: L10n.restoreSettingsFromClipboard, style: .default) { [weak self] _ in
            guard let self = self else { return }
            guard let json = UIPasteboard.general.string, !json.isEmpty else {
                let err = UIAlertController(title: L10n.restoreFailedTitle, message: L10n.restoreFailedNoJson, preferredStyle: .alert)
                err.addAction(UIAlertAction(title: L10n.ok, style: .default))
                self.present(err, animated: true)
                return
            }
            do {
                _ = try SettingsBackupManager.importFromJson(json)
                self.refreshDiagnosticsSummary()
                self.onSettingsChanged?(.uiOnly)
                let ok = UIAlertController(title: L10n.settingsRestoredTitle, message: L10n.settingsRestoredMessage, preferredStyle: .alert)
                ok.addAction(UIAlertAction(title: L10n.ok, style: .default))
                self.present(ok, animated: true)
            } catch {
                let err = UIAlertController(title: L10n.restoreErrorTitle, message: error.localizedDescription, preferredStyle: .alert)
                err.addAction(UIAlertAction(title: L10n.ok, style: .default))
                self.present(err, animated: true)
            }
        })
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(alert, animated: true)
    }

    @objc private func clearDiagnosticLogs() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AppLog.shared.clear()
        let alert = UIAlertController(title: L10n.diagnosticLogsClearedTitle, message: L10n.diagnosticLogsClearedMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.ok, style: .default))
        present(alert, animated: true)
    }

    @objc private func presentResetDefaultsAlert() {
        let alert = UIAlertController(title: L10n.resetAllSettingsTitle, message: L10n.resetAllSettingsMessage, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.reset, style: .destructive) { [weak self] _ in
            SettingsBackupManager.resetToDefaults()
            self?.refreshDynamicData()
            self?.showAboutView(animated: true)
            self?.onSettingsChanged?(.uiOnly)
        })
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(alert, animated: true)
    }
}
