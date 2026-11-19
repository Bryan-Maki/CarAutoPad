import UIKit

final class SettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    enum ChangeImpact {
        case uiOnly
        case nightModeChanged
        case geometryChanged
        case requiresReconnect
        case motionBlurChanged
        case audioVolumeOrDuckingChanged
    }

    enum SettingsSection: Int, CaseIterable {
        case activeSession = 0
        case displayLayout = 1
        case videoAudio = 2
        case smartSensors = 3
        case connectionAutomation = 4
        case diagnosticsBackup = 5

        var title: String? {
            switch self {
            case .activeSession:
                return ConnectionManager.shared.state == .running ? L10n.sectionActiveSession : nil
            case .displayLayout:
                return L10n.sectionDisplayLayout
            case .videoAudio:
                return L10n.sectionVideoAudio
            case .smartSensors:
                return L10n.sectionSmartSensors
            case .connectionAutomation:
                return L10n.sectionConnectionAutomation
            case .diagnosticsBackup:
                return L10n.sectionDiagnosticsBackup
            }
        }
    }

    var onSettingsChanged: ((ChangeImpact) -> Void)?
    var onProvideDiagnosticLines: (() -> [String])?
    var openSettingsUrlHandler: ((URL) -> Void)?
    var connectionManager: ConnectionManager = ConnectionManager.shared

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 50
        table.keyboardDismissMode = .onDrag
        return table
    }()

    private var dpiPreviewCell: DpiPreviewCell?

    private var isHandshakeSettingsLocked: Bool {
        return connectionManager.state != .disconnected
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyLocalization),
            name: .appLanguageDidChange,
            object: nil
        )
    }

    @objc private func applyLocalization() {
        title = L10n.projectionSettingsTitle
        navigationItem.rightBarButtonItem?.title = L10n.done
        tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    private func setupUI() {
        title = L10n.projectionSettingsTitle
        view.backgroundColor = CarAutoPadTheme.canvas
        tableView.backgroundColor = CarAutoPadTheme.canvas
        preferredContentSize = CGSize(width: 680, height: 760)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L10n.done,
            style: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }

    private func configurePopover(for controller: UIViewController, sourceView: UIView) {
        if let popover = controller.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sec = SettingsSection(rawValue: section) else { return 0 }
        switch sec {
        case .activeSession:
            return connectionManager.state == .running ? 2 : 0
        case .displayLayout:
            return 8
        case .videoAudio:
            return 5
        case .smartSensors:
            return 3
        case .connectionAutomation:
            return 2
        case .diagnosticsBackup:
            return 7
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return SettingsSection(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let sec = SettingsSection(rawValue: section) else { return nil }
        switch sec {
        case .displayLayout:
            if isHandshakeSettingsLocked {
                return L10n.footerDisplayLayoutLocked
            }
            return L10n.footerDisplayLayoutUnlocked
        case .videoAudio:
            if isHandshakeSettingsLocked {
                return L10n.footerVideoAudioLocked
            }
            return L10n.footerVideoAudioUnlocked
        case .connectionAutomation:
            return L10n.footerConnectionAutomation
        case .diagnosticsBackup:
            return L10n.footerDiagnosticsBackup
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sec = SettingsSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        let cell: UITableViewCell
        switch sec {
        case .activeSession:
            cell = makeActiveSessionCell(for: indexPath.row)
        case .displayLayout:
            cell = makeDisplayLayoutCell(for: indexPath.row)
        case .videoAudio:
            cell = makeVideoAudioCell(for: indexPath.row)
        case .smartSensors:
            cell = makeSmartSensorsCell(for: indexPath.row)
        case .connectionAutomation:
            cell = makeConnectionAutomationCell(for: indexPath.row)
        case .diagnosticsBackup:
            cell = makeDiagnosticsBackupCell(for: indexPath.row)
        }

        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.textLabel?.minimumScaleFactor = 0.75
        cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
        cell.detailTextLabel?.minimumScaleFactor = 0.75
        return cell
    }

    private func makeActiveSessionCell(for row: Int) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        if row == 0 {
            cell.textLabel?.text = L10n.connectedDeviceRow
            let device = connectionManager.connectedDevice
            cell.detailTextLabel?.text = "\(device?.displayName ?? L10n.defaultPhoneName) (\(device?.ip ?? ""):\(device?.port ?? 5277))"
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.textLabel?.text = L10n.disconnectAndroidAutoRow
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            cell.textLabel?.textAlignment = .center
        }
        return cell
    }

    private func makeDisplayLayoutCell(for row: Int) -> UITableViewCell {
        let locked = isHandshakeSettingsLocked
        switch row {
        case 0:
            let cell = DpiPreviewCell()
            cell.configure(with: HeadUnitScreenConfig.shared, isLocked: locked)
            cell.onDpiChanged = { [weak self] impact in
                self?.onSettingsChanged?(impact)
            }
            self.dpiPreviewCell = cell
            return cell

        case 1:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.resolutionTitle
            let currentRes = ProjectionSettings.resolution
            cell.detailTextLabel?.text = locked ? L10n.lockedSuffix(currentRes.title) : currentRes.title
            cell.accessoryType = locked ? .none : .disclosureIndicator
            cell.selectionStyle = locked ? .none : .default
            cell.textLabel?.alpha = locked ? 0.5 : 1.0
            return cell

        case 2:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.frameRateRow
            cell.textLabel?.alpha = locked ? 0.5 : 1.0
            let seg = UISegmentedControl(items: [ProjectionFpsLimit.fps60.title, ProjectionFpsLimit.fps30.title])
            seg.apportionsSegmentWidthsByContent = true
            seg.selectedSegmentIndex = (ProjectionSettings.fpsLimit == .fps60) ? 0 : 1
            seg.isEnabled = !locked
            seg.addAction(UIAction { [weak self] _ in
                let selected: ProjectionFpsLimit = (seg.selectedSegmentIndex == 0) ? .fps60 : .fps30
                ProjectionSettings.fpsLimit = selected
                if self?.connectionManager.state == .running {
                    self?.onSettingsChanged?(.requiresReconnect)
                } else {
                    self?.onSettingsChanged?(.uiOnly)
                }
            }, for: .valueChanged)
            cell.accessoryView = seg
            cell.selectionStyle = .none
            return cell

        case 3:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.displayFitMode
            let seg = UISegmentedControl(items: [L10n.fitSegmentFill, L10n.fitSegmentFit, L10n.fitSegmentStretch])
            seg.apportionsSegmentWidthsByContent = true
            switch ProjectionSettings.videoFitMode {
            case .fillMargin: seg.selectedSegmentIndex = 0
            case .contain, .fill, .cover: seg.selectedSegmentIndex = 1
            case .stretch: seg.selectedSegmentIndex = 2
            }
            seg.addAction(UIAction { [weak self] _ in
                let modes: [VideoFitMode] = [.fillMargin, .contain, .stretch]
                let mode = modes[seg.selectedSegmentIndex]
                ProjectionSettings.videoFitMode = mode
                HeadUnitScreenConfig.shared.videoFitMode = mode
                HeadUnitScreenConfig.shared.recalculate()
                HeadUnitScreenConfig.shared.checkAndNotifyMarginDivergence()
                self?.dpiPreviewCell?.configure(with: HeadUnitScreenConfig.shared, isLocked: self?.isHandshakeSettingsLocked ?? false)
                self?.onSettingsChanged?(.geometryChanged)
            }, for: .valueChanged)
            cell.accessoryView = seg
            cell.selectionStyle = .none
            return cell

        case 4:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.screenOrientationRow
            let seg = UISegmentedControl(items: [
                ProjectionOrientation.landscape.title,
                ProjectionOrientation.portrait.title,
                ProjectionOrientation.system.title
            ])
            seg.apportionsSegmentWidthsByContent = true
            switch ProjectionSettings.orientation {
            case .landscape: seg.selectedSegmentIndex = 0
            case .portrait: seg.selectedSegmentIndex = 1
            case .system: seg.selectedSegmentIndex = 2
            }
            seg.addAction(UIAction { [weak self] _ in
                let orientations: [ProjectionOrientation] = [.landscape, .portrait, .system]
                let opt = orientations[seg.selectedSegmentIndex]
                ProjectionSettings.orientation = opt
                self?.onSettingsChanged?(.geometryChanged)
            }, for: .valueChanged)
            cell.accessoryView = seg
            cell.selectionStyle = .none
            return cell

        case 5:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.drivingPosition
            cell.textLabel?.alpha = locked ? 0.5 : 1.0
            let seg = UISegmentedControl(items: [L10n.lhdShort, L10n.rhdShort])
            seg.apportionsSegmentWidthsByContent = true
            seg.selectedSegmentIndex = (ProjectionSettings.driverPosition == .right) ? 1 : 0
            seg.isEnabled = !locked
            seg.addAction(UIAction { [weak self] _ in
                let isRhd = (seg.selectedSegmentIndex == 1)
                ProjectionSettings.driverPosition = isRhd ? .right : .left
                self?.dpiPreviewCell?.updateRightHandDrive(isRhd)
                if self?.connectionManager.state == .running {
                    self?.onSettingsChanged?(.requiresReconnect)
                } else {
                    self?.onSettingsChanged?(.uiOnly)
                }
            }, for: .valueChanged)
            cell.accessoryView = seg
            cell.selectionStyle = .none
            return cell

        case 6:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.frameSmoothingRow
            let seg = UISegmentedControl(items: MotionBlurMode.allCases.map { $0.shortTitle })
            seg.apportionsSegmentWidthsByContent = true
            seg.selectedSegmentIndex = ProjectionSettings.motionBlurMode.rawValue
            seg.addAction(UIAction { [weak self] _ in
                let modes: [MotionBlurMode] = [.off, .light, .medium, .strong]
                let idx = seg.selectedSegmentIndex
                if idx >= 0 && idx < modes.count {
                    ProjectionSettings.motionBlurMode = modes[idx]
                    self?.onSettingsChanged?(.motionBlurChanged)
                }
            }, for: .valueChanged)
            cell.accessoryView = seg
            cell.selectionStyle = .none
            return cell

        case 7:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.edgeSwipeProtectionRow
            let toggle = UISwitch()
            toggle.isOn = ProjectionSettings.isEdgeSwipeProtectionEnabled
            toggle.addAction(UIAction { [weak self] _ in
                ProjectionSettings.isEdgeSwipeProtectionEnabled = toggle.isOn
                self?.onSettingsChanged?(.uiOnly)
            }, for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
            return cell

        default:
            return UITableViewCell()
        }
    }

    private func makeVideoAudioCell(for row: Int) -> UITableViewCell {
        let locked = isHandshakeSettingsLocked
        switch row {
        case 0:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.videoCodecRow
            cell.textLabel?.alpha = locked ? 0.5 : 1.0
            let seg = UISegmentedControl(items: ["H.264", "HEVC"])
            seg.apportionsSegmentWidthsByContent = true
            switch ProjectionSettings.videoCodecPreference {
            case .h264: seg.selectedSegmentIndex = 0
            case .hevc: seg.selectedSegmentIndex = 1
            }
            seg.isEnabled = !locked
            seg.addAction(UIAction { [weak self] _ in
                let codecs: [VideoCodecPreference] = [.h264, .hevc]
                ProjectionSettings.videoCodecPreference = codecs[seg.selectedSegmentIndex]
                if self?.connectionManager.state == .running {
                    self?.onSettingsChanged?(.requiresReconnect)
                } else {
                    self?.onSettingsChanged?(.uiOnly)
                }
            }, for: .valueChanged)
            cell.accessoryView = seg
            cell.selectionStyle = .none
            return cell

        case 1:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.audioCodecRow
            cell.textLabel?.alpha = locked ? 0.5 : 1.0
            let seg = UISegmentedControl(items: ["AAC-LC", "PCM"])
            seg.apportionsSegmentWidthsByContent = true
            seg.selectedSegmentIndex = (ProjectionSettings.audioCodecPreference == .aac) ? 0 : 1
            seg.isEnabled = !locked
            seg.addAction(UIAction { [weak self] _ in
                let codecs: [AudioCodecPreference] = [.aac, .pcm]
                ProjectionSettings.audioCodecPreference = codecs[seg.selectedSegmentIndex]
                if self?.connectionManager.state == .running {
                    self?.onSettingsChanged?(.requiresReconnect)
                } else {
                    self?.onSettingsChanged?(.uiOnly)
                }
            }, for: .valueChanged)
            cell.accessoryView = seg
            cell.selectionStyle = .none
            return cell

        case 2:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.audioOutputRow
            cell.textLabel?.alpha = locked ? 0.5 : 1.0
            let seg = UISegmentedControl(items: [L10n.audioTargetIpadSegment, L10n.audioTargetPhoneSegment])
            seg.apportionsSegmentWidthsByContent = true
            seg.selectedSegmentIndex = (ProjectionSettings.audioOutputTarget == .ipad) ? 0 : 1
            seg.isEnabled = !locked
            seg.addAction(UIAction { [weak self] _ in
                let targets: [AudioOutputTarget] = [.ipad, .phone]
                let target = targets[seg.selectedSegmentIndex]
                ProjectionSettings.audioOutputTarget = target
                if !target.isAudioSinkEnabled {
                    PCMAudioPlayer.shared.reset()
                }
                self?.tableView.reloadSections(IndexSet(integer: SettingsSection.videoAudio.rawValue), with: .none)
                if self?.connectionManager.state == .running {
                    self?.onSettingsChanged?(.requiresReconnect)
                } else {
                    self?.onSettingsChanged?(.uiOnly)
                }
            }, for: .valueChanged)
            cell.accessoryView = seg
            cell.selectionStyle = .none
            return cell

        case 3:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.microphoneSourceRow
            cell.textLabel?.alpha = locked ? 0.5 : 1.0
            let seg = UISegmentedControl(items: [L10n.micFollowSegment, L10n.micIpadSegment, L10n.micPhoneSegment])
            seg.apportionsSegmentWidthsByContent = true
            switch ProjectionSettings.microphoneSource {
            case .followAudioOutput: seg.selectedSegmentIndex = 0
            case .ipad: seg.selectedSegmentIndex = 1
            case .phone: seg.selectedSegmentIndex = 2
            }
            seg.isEnabled = !locked
            seg.addAction(UIAction { [weak self] _ in
                let sources: [MicrophoneSource] = [.followAudioOutput, .ipad, .phone]
                ProjectionSettings.microphoneSource = sources[seg.selectedSegmentIndex]
                if self?.connectionManager.state == .running {
                    self?.onSettingsChanged?(.requiresReconnect)
                } else {
                    self?.onSettingsChanged?(.uiOnly)
                }
            }, for: .valueChanged)
            cell.accessoryView = seg
            cell.selectionStyle = .none
            return cell

        case 4:
            let cell = AudioChannelMixerCell()
            cell.onSettingsChanged = { [weak self] impact in
                self?.onSettingsChanged?(impact)
            }
            return cell

        default:
            return UITableViewCell()
        }
    }

    private func makeSmartSensorsCell(for row: Int) -> UITableViewCell {
        switch row {
        case 0:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.nightModeRow
            let seg = UISegmentedControl(items: [
                NightModeSetting.auto.shortTitle,
                NightModeSetting.twilight.shortTitle,
                NightModeSetting.day.shortTitle,
                NightModeSetting.night.shortTitle,
                NightModeSetting.system.shortTitle
            ])
            seg.apportionsSegmentWidthsByContent = true
            switch ProjectionSettings.nightMode {
            case .auto: seg.selectedSegmentIndex = 0
            case .twilight: seg.selectedSegmentIndex = 1
            case .day: seg.selectedSegmentIndex = 2
            case .night: seg.selectedSegmentIndex = 3
            case .system: seg.selectedSegmentIndex = 4
            }
            seg.addAction(UIAction { [weak self] _ in
                let modes: [NightModeSetting] = [.auto, .twilight, .day, .night, .system]
                ProjectionSettings.nightMode = modes[seg.selectedSegmentIndex]
                self?.onSettingsChanged?(.nightModeChanged)
            }, for: .valueChanged)
            cell.accessoryView = seg
            cell.selectionStyle = .none
            return cell

        case 1:
            if ProjectionSettings.supportsCellularIpad() {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = L10n.gpsSourceRow
                let seg = UISegmentedControl(items: [L10n.gpsPhoneShort, L10n.gpsIpadShort])
                seg.apportionsSegmentWidthsByContent = true
                seg.selectedSegmentIndex = (ProjectionSettings.gpsSource == .phone) ? 0 : 1
                seg.addAction(UIAction { [weak self] _ in
                    let isIpad = (seg.selectedSegmentIndex == 1)
                    ProjectionSettings.gpsSource = isIpad ? .ipad : .phone
                    if isIpad {
                        self?.connectionManager.requestLocationPermissionIfNeeded()
                    }
                    self?.onSettingsChanged?(.uiOnly)
                }, for: .valueChanged)
                cell.accessoryView = seg
                cell.selectionStyle = .none
                return cell
            } else {
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.textLabel?.text = L10n.gpsSourceRow
                cell.detailTextLabel?.text = L10n.gpsPhoneOnlyWifiIpad
                cell.selectionStyle = .none
                return cell
            }

        case 2:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.languageRowTitle
            cell.detailTextLabel?.text = L10n.current.title
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            return cell

        default:
            return UITableViewCell()
        }
    }

    private func makeConnectionAutomationCell(for row: Int) -> UITableViewCell {
        switch row {
        case 0:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.autoReconnectRow
            let toggle = UISwitch()
            toggle.isOn = ProjectionSettings.autoReconnect
            toggle.addAction(UIAction { _ in
                ProjectionSettings.autoReconnect = toggle.isOn
            }, for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
            return cell

        case 1:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.autoResumePlaybackRow
            let toggle = UISwitch()
            toggle.isOn = ProjectionSettings.autoResumePlayback
            toggle.addAction(UIAction { _ in
                ProjectionSettings.autoResumePlayback = toggle.isOn
            }, for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
            return cell

        default:
            return UITableViewCell()
        }
    }

    private func makeDiagnosticsBackupCell(for row: Int) -> UITableViewCell {
        switch row {
        case 0:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.debugModeRow
            let toggle = UISwitch()
            toggle.isOn = ProjectionSettings.isDebugModeEnabled
            toggle.addAction(UIAction { [weak self] _ in
                ProjectionSettings.isDebugModeEnabled = toggle.isOn
                self?.onSettingsChanged?(.uiOnly)
            }, for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
            return cell

        case 1:
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.debugLogCategoriesRow
            let enabledCount = DebugLogCategory.allCases.filter { ProjectionSettings.isDebugCategoryEnabled($0) }.count
            cell.detailTextLabel?.text = L10n.debugCategoriesEnabledCount(enabled: enabledCount, total: DebugLogCategory.allCases.count)
            cell.accessoryType = .disclosureIndicator
            return cell

        case 2:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.liveDiagnosticsReportRow
            cell.accessoryType = .disclosureIndicator
            return cell

        case 3:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.exportShareSessionLogsRow
            cell.accessoryType = .disclosureIndicator
            return cell

        case 4:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.clearAllDiagnosticLogsRow
            cell.textLabel?.textColor = .systemOrange
            cell.textLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            return cell

        case 5:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.backupRestoreSettingsRow
            cell.accessoryType = .disclosureIndicator
            return cell

        case 6:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = L10n.resetAllSettingsRow
            cell.textLabel?.textColor = .systemRed
            cell.textLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            return cell

        default:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sec = SettingsSection(rawValue: indexPath.section) else { return }

        switch sec {
        case .activeSession:
            if indexPath.row == 0 {
                presentConnectionDetails()
            } else if indexPath.row == 1 {
                connectionManager.disconnect()
                dismiss(animated: true)
            }

        case .displayLayout:
            if indexPath.row == 1 && !isHandshakeSettingsLocked {
                presentResolutionPicker(sourceView: tableView.cellForRow(at: indexPath) ?? tableView)
            }

        case .smartSensors:
            if indexPath.row == 2 {
                openSystemAppLanguageSettings()
            }

        case .diagnosticsBackup:
            switch indexPath.row {
            case 1:
                presentDebugLogCategories()
            case 2:
                presentLiveDiagnostics()
            case 3:
                presentLogExportMenu(sourceView: tableView.cellForRow(at: indexPath) ?? tableView)
            case 4:
                clearDiagnosticLogs(sourceView: tableView.cellForRow(at: indexPath) ?? tableView)
            case 5:
                presentBackupRestoreMenu(sourceView: tableView.cellForRow(at: indexPath) ?? tableView)
            case 6:
                presentResetDefaultsAlert()
            default:
                break
            }

        default:
            break
        }
    }

    func openSystemAppLanguageSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        if let openSettingsUrlHandler = openSettingsUrlHandler {
            openSettingsUrlHandler(url)
            return
        }
        guard UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func presentConnectionDetails() {
        let device = connectionManager.connectedDevice
        let details = [
            "\(L10n.detailState): \(connectionManager.state.localizedDescription)",
            "\(L10n.detailStatus): \(connectionManager.statusDetail)",
            "\(L10n.detailDevice): \(device?.displayName ?? L10n.unknown)",
            "\(L10n.detailIp): \(device?.ip ?? L10n.unknown)",
            "\(L10n.detailPort): \(device?.port ?? 0)"
        ].joined(separator: "\n")

        let alert = UIAlertController(title: L10n.connectionDetailsTitle, message: details, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.ok, style: .default))
        present(alert, animated: true)
    }

    private func presentResolutionPicker(sourceView: UIView) {
        let alert = UIAlertController(title: L10n.resolutionTitle, message: L10n.resolutionPickerMessage, preferredStyle: .actionSheet)
        configurePopover(for: alert, sourceView: sourceView)

        let presets: [ResolutionPreset] = [.auto, .r1280x720, .r1920x1080, .r2560x1440, .r3840x2160]
        for preset in presets {
            let isCurrent = preset == ProjectionSettings.resolution
            let title = isCurrent ? L10n.currentSuffix(preset.title) : preset.title
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                ProjectionSettings.resolution = preset
                HeadUnitScreenConfig.shared.recalculate(requestedResolution: preset)
                self?.dpiPreviewCell?.configure(with: HeadUnitScreenConfig.shared)
                self?.tableView.reloadRows(at: [IndexPath(row: 1, section: SettingsSection.displayLayout.rawValue)], with: .fade)
                if self?.connectionManager.state == .running {
                    self?.onSettingsChanged?(.requiresReconnect)
                } else {
                    self?.onSettingsChanged?(.geometryChanged)
                }
            })
        }
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(alert, animated: true)
    }

    private func presentLiveDiagnostics() {
        let lines = onProvideDiagnosticLines?() ?? connectionManager.diagnosticLines()
        let text = lines.joined(separator: "\n")
        let alert = UIAlertController(title: L10n.liveDiagnosticsTitle, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.copyToClipboard, style: .default) { _ in
            UIPasteboard.general.string = text
        })
        alert.addAction(UIAlertAction(title: L10n.close, style: .cancel))
        present(alert, animated: true)
    }

    private func presentLogExportMenu(sourceView: UIView) {
        let alert = UIAlertController(title: L10n.exportShareLogsTitle, message: L10n.exportShareLogsMessage, preferredStyle: .actionSheet)
        configurePopover(for: alert, sourceView: sourceView)

        alert.addAction(UIAlertAction(title: L10n.copyLogToClipboard, style: .default) { _ in
            let text = LogExporter.exportToClipboardText()
            UIPasteboard.general.string = text
            AppLog.i("Diagnostic log copied to clipboard (\(text.utf8.count) bytes)", tag: "SettingsViewController")
        })
        alert.addAction(UIAlertAction(title: L10n.shareLogFileTxt, style: .default) { [weak self] _ in
            guard let self = self else { return }
            if let fileUrl = LogExporter.exportToTemporaryFile() {
                let activityVC = UIActivityViewController(activityItems: [fileUrl], applicationActivities: nil)
                self.configurePopover(for: activityVC, sourceView: sourceView)
                self.present(activityVC, animated: true)
            }
        })
        alert.addAction(UIAlertAction(title: L10n.clearInMemoryLogs, style: .destructive) { _ in
            AppLog.shared.clear()
        })
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(alert, animated: true)
    }

    private func presentBackupRestoreMenu(sourceView: UIView) {
        let alert = UIAlertController(title: L10n.backupRestoreTitle, message: L10n.backupRestoreMessage, preferredStyle: .actionSheet)
        configurePopover(for: alert, sourceView: sourceView)

        alert.addAction(UIAlertAction(title: L10n.copySettingsJsonToClipboard, style: .default) { [weak self] _ in
            guard let self = self else { return }
            let json = SettingsBackupManager.exportToJson()
            UIPasteboard.general.string = json
            let ok = UIAlertController(title: L10n.settingsExportedTitle, message: L10n.settingsExportedMessage, preferredStyle: .alert)
            ok.addAction(UIAlertAction(title: L10n.ok, style: .default))
            self.present(ok, animated: true)
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
                try SettingsBackupManager.importFromJson(json)
                self.dpiPreviewCell?.configure(with: HeadUnitScreenConfig.shared, isLocked: self.isHandshakeSettingsLocked)
                self.tableView.reloadData()
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

    private func presentResetDefaultsAlert() {
        let alert = UIAlertController(
            title: L10n.resetAllSettingsTitle,
            message: L10n.resetAllSettingsMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.reset, style: .destructive) { [weak self] _ in
            SettingsBackupManager.resetToDefaults()
            self?.dpiPreviewCell?.configure(with: HeadUnitScreenConfig.shared, isLocked: self?.isHandshakeSettingsLocked ?? false)
            self?.tableView.reloadData()
            self?.onSettingsChanged?(.uiOnly)
        })
        alert.addAction(UIAlertAction(title: L10n.cancel, style: .cancel))
        present(alert, animated: true)
    }

    private func presentDebugLogCategories() {
        let vc = DebugLogCategoriesViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    private func clearDiagnosticLogs(sourceView: UIView) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        AppLog.shared.clear()
        let alert = UIAlertController(
            title: L10n.diagnosticLogsClearedTitle,
            message: L10n.diagnosticLogsClearedMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.ok, style: .default))
        present(alert, animated: true)
    }
}

final class DpiPreviewCell: UITableViewCell {

    var onDpiChanged: ((SettingsViewController.ChangeImpact) -> Void)?

    private let previewView: DpiPreviewView = {
        let v = DpiPreviewView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 12
        v.clipsToBounds = true
        return v
    }()

    private let autoDpiLabel: UILabel = {
        let label = UILabel()
        label.text = L10n.autoDpiRecommended
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let autoDpiSwitch: UISwitch = {
        let s = UISwitch()
        s.setContentCompressionResistancePriority(.required, for: .horizontal)
        s.setContentHuggingPriority(.required, for: .horizontal)
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let dpiValueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        label.textAlignment = .center
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let dpiSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 100
        slider.maximumValue = 320
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()

    private let presetStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        selectionStyle = .none
        setupViews()
    }

    private func setupViews() {
        contentView.addSubview(previewView)
        contentView.addSubview(autoDpiLabel)
        contentView.addSubview(autoDpiSwitch)
        contentView.addSubview(dpiValueLabel)
        contentView.addSubview(dpiSlider)
        contentView.addSubview(presetStackView)

        let presets = [120, 160, 200, 240, 280]
        for p in presets {
            var config = UIButton.Configuration.tinted()
            config.title = "\(p)"
            config.cornerStyle = .capsule
            config.buttonSize = .mini
            let btn = UIButton(configuration: config)
            btn.addAction(UIAction { [weak self] _ in
                self?.applyDpi(val: p, isAuto: false)
            }, for: .touchUpInside)
            presetStackView.addArrangedSubview(btn)
        }

        autoDpiSwitch.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            if self.autoDpiSwitch.isOn {
                let rec = ProjectionSettings.recommendedDpiForCurrentDevice()
                self.applyDpi(val: rec, isAuto: true)
            } else {
                let val = Int((self.dpiSlider.value / 10.0).rounded()) * 10
                self.applyDpi(val: val, isAuto: false)
            }
        }, for: .valueChanged)

        dpiSlider.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let stepped = Int((self.dpiSlider.value / 10.0).rounded()) * 10
            self.dpiSlider.value = Float(stepped)
            self.applyDpi(val: stepped, isAuto: false)
        }, for: .valueChanged)

        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            previewView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previewView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            previewView.heightAnchor.constraint(equalToConstant: 248),

            autoDpiLabel.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 14),
            autoDpiLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            autoDpiLabel.trailingAnchor.constraint(lessThanOrEqualTo: autoDpiSwitch.leadingAnchor, constant: -12),

            autoDpiSwitch.centerYAnchor.constraint(equalTo: autoDpiLabel.centerYAnchor),
            autoDpiSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            dpiValueLabel.topAnchor.constraint(equalTo: autoDpiLabel.bottomAnchor, constant: 10),
            dpiValueLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dpiValueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            dpiSlider.topAnchor.constraint(equalTo: dpiValueLabel.bottomAnchor, constant: 10),
            dpiSlider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dpiSlider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            presetStackView.topAnchor.constraint(equalTo: dpiSlider.bottomAnchor, constant: 12),
            presetStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            presetStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            presetStackView.heightAnchor.constraint(equalToConstant: 32),
            presetStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    func configure(with screenConfig: HeadUnitScreenConfig, isLocked: Bool = false) {
        previewView.dpi = ProjectionSettings.effectiveDpi
        previewView.panelWidthPx = screenConfig.screenWidthPx > 0 ? screenConfig.screenWidthPx : 1920
        previewView.panelHeightPx = screenConfig.screenHeightPx > 0 ? screenConfig.screenHeightPx : 1080
        previewView.codecWidthPx = screenConfig.negotiatedWidth > 0 ? screenConfig.negotiatedWidth : 1920
        previewView.codecHeightPx = screenConfig.negotiatedHeight > 0 ? screenConfig.negotiatedHeight : 1080
        previewView.activeWidthPx = screenConfig.activeWidthPx
        previewView.activeHeightPx = screenConfig.activeHeightPx
        previewView.marginWidthPx = screenConfig.widthMargin
        previewView.marginHeightPx = screenConfig.heightMargin
        previewView.isRightHandDrive = (ProjectionSettings.driverPosition == .right)
        previewView.fitMode = ProjectionSettings.videoFitMode

        autoDpiLabel.text = L10n.autoDpiRecommended
        autoDpiSwitch.isOn = ProjectionSettings.isAutoDpi
        dpiSlider.value = Float(ProjectionSettings.effectiveDpi)
        updateDpiLabel()
        previewView.setNeedsDisplay()

        autoDpiSwitch.isEnabled = !isLocked
        dpiSlider.isEnabled = !isLocked
        autoDpiLabel.alpha = isLocked ? 0.5 : 1.0
        dpiValueLabel.alpha = isLocked ? 0.5 : 1.0
        for subview in presetStackView.arrangedSubviews {
            if let btn = subview as? UIButton {
                btn.isEnabled = !isLocked
            }
        }
        presetStackView.alpha = isLocked ? 0.5 : 1.0
    }

    func updateRightHandDrive(_ isRhd: Bool) {
        previewView.isRightHandDrive = isRhd
        previewView.setNeedsDisplay()
    }

    private func applyDpi(val: Int, isAuto: Bool) {
        let clamped = min(max(val, 100), 320)
        dpiSlider.value = Float(clamped)
        previewView.dpi = clamped
        autoDpiSwitch.isOn = isAuto

        if isAuto {
            ProjectionSettings.resetDpiToDefault()
            HeadUnitScreenConfig.shared.customDpi = nil
        } else {
            ProjectionSettings.isAutoDpi = false
            ProjectionSettings.dpi = clamped
            HeadUnitScreenConfig.shared.customDpi = clamped
        }

        updateDpiLabel()
        previewView.setNeedsDisplay()
        onDpiChanged?(.uiOnly)
    }

    private func updateDpiLabel() {
        let prefix = ProjectionSettings.isAutoDpi ? "\(L10n.autoShort) " : "\(L10n.customShort) "
        let splitText = previewView.isCoolwalkSplitScreen ? L10n.coolwalkSplitShort : L10n.singleFullscreenShort
        dpiValueLabel.text = "\(prefix)(\(previewView.dpi) DPI) • \(previewView.virtualWidthDp)×\(previewView.virtualHeightDp) dp (\(splitText))"
    }
}

final class DebugLogCategoriesViewController: UITableViewController {
    init() {
        super.init(style: .insetGrouped)
        title = L10n.debugLogCategoriesTitle
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: L10n.enableAll,
            style: .plain,
            target: self,
            action: #selector(enableAllTapped)
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyLocalization),
            name: .appLanguageDidChange,
            object: nil
        )
    }

    @objc private func applyLocalization() {
        title = L10n.debugLogCategoriesTitle
        navigationItem.rightBarButtonItem?.title = L10n.enableAll
        tableView.reloadData()
    }

    @objc private func enableAllTapped() {
        ProjectionSettings.enableAllDebugCategories()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return DebugLogCategory.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cat = DebugLogCategory.allCases[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = "[\(cat.rawValue)] \(cat.title)"
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cell.textLabel?.adjustsFontSizeToFitWidth = true
        cell.textLabel?.minimumScaleFactor = 0.75
        cell.detailTextLabel?.text = cat.subtitle
        cell.detailTextLabel?.numberOfLines = 2
        cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
        cell.detailTextLabel?.minimumScaleFactor = 0.8
        cell.detailTextLabel?.textColor = .secondaryLabel

        let toggle = UISwitch()
        toggle.isOn = ProjectionSettings.isDebugCategoryEnabled(cat)
        toggle.addAction(UIAction { _ in
            ProjectionSettings.setDebugCategory(cat, enabled: toggle.isOn)
        }, for: .valueChanged)

        cell.accessoryView = toggle
        cell.selectionStyle = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return L10n.debugLogCategoriesFooter
    }
}

final class AudioChannelMixerCell: UITableViewCell {

    var onSettingsChanged: ((SettingsViewController.ChangeImpact) -> Void)?

    private let mainStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let mediaTitleLabel = UILabel()
    private let mediaSwitch = UISwitch()
    private let mediaSlider = UISlider()
    private let mediaValueLabel = UILabel()

    private let navTitleLabel = UILabel()
    private let navSwitch = UISwitch()
    private let navSlider = UISlider()
    private let navValueLabel = UILabel()

    private let sysTitleLabel = UILabel()
    private let sysSwitch = UISwitch()
    private let sysSlider = UISlider()
    private let sysValueLabel = UILabel()

    private let duckingTitleLabel = UILabel()
    private let duckingSubLabel = UILabel()
    private let duckingStatusLabel = UILabel()
    private let duckingSlider = UISlider()
    private let presetStackView = UIStackView()
    private var presetButtons: [NavigationDuckingPreset: UIButton] = [:]
    private var testDuckingButton: UIButton?
    private var resetAudioButton: UIButton?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupViews()
        syncWithCurrentSettings()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        selectionStyle = .none
        setupViews()
        syncWithCurrentSettings()
    }

    private func setupViews() {
        contentView.addSubview(mainStackView)
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])

        // 1) Media Channel
        let mediaBlock = makeChannelRow(
            iconName: "music.note",
            iconColor: .systemBlue,
            titleLabel: mediaTitleLabel,
            title: L10n.mediaAudio,
            toggle: mediaSwitch,
            slider: mediaSlider,
            valueLabel: mediaValueLabel,
            onTone: { AudioStreamTester.shared.playMediaTestTone() }
        )
        mainStackView.addArrangedSubview(mediaBlock)

        // 2) Navigation Channel
        let navBlock = makeChannelRow(
            iconName: "location.fill",
            iconColor: .systemGreen,
            titleLabel: navTitleLabel,
            title: L10n.navigationGuidance,
            toggle: navSwitch,
            slider: navSlider,
            valueLabel: navValueLabel,
            onTone: { AudioStreamTester.shared.playGuidanceTestTone() }
        )
        mainStackView.addArrangedSubview(navBlock)

        // 3) Phone & System Channel
        let sysBlock = makeChannelRow(
            iconName: "bell.fill",
            iconColor: .systemOrange,
            titleLabel: sysTitleLabel,
            title: L10n.phoneSystemAlerts,
            toggle: sysSwitch,
            slider: sysSlider,
            valueLabel: sysValueLabel,
            onTone: { AudioStreamTester.shared.playSystemTestTone() }
        )
        mainStackView.addArrangedSubview(sysBlock)

        // 4) Navigation Ducking Section
        let duckingSection = makeDuckingSection()
        mainStackView.addArrangedSubview(duckingSection)

        wireActions()
    }

    private func makeChannelRow(
        iconName: String,
        iconColor: UIColor,
        titleLabel: UILabel,
        title: String,
        toggle: UISwitch,
        slider: UISlider,
        valueLabel: UILabel,
        onTone: @escaping () -> Void
    ) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6

        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.spacing = 8
        topRow.alignment = .center

        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

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
        let toneButton = UIButton(configuration: toneConfig)
        toneButton.setContentHuggingPriority(.required, for: .horizontal)
        toneButton.addAction(UIAction { _ in onTone() }, for: .touchUpInside)

        topRow.addArrangedSubview(iconView)
        topRow.addArrangedSubview(titleLabel)
        topRow.addArrangedSubview(toneButton)
        topRow.addArrangedSubview(toggle)

        let sliderRow = UIStackView()
        sliderRow.axis = .horizontal
        sliderRow.spacing = 10
        sliderRow.alignment = .center

        slider.minimumValue = 0.0
        slider.maximumValue = ProjectionSettings.maxChannelVolume

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
        return container
    }

    private func makeDuckingSection() -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8

        let sep = UIView()
        sep.backgroundColor = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        container.addArrangedSubview(sep)

        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center
        headerRow.distribution = .equalSpacing

        duckingTitleLabel.text = L10n.navigationDuckingDrop
        duckingTitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        duckingTitleLabel.textColor = .label
        duckingTitleLabel.adjustsFontSizeToFitWidth = true
        duckingTitleLabel.minimumScaleFactor = 0.75
        duckingTitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        duckingStatusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        duckingStatusLabel.textColor = .systemBlue
        duckingStatusLabel.textAlignment = .right
        duckingStatusLabel.adjustsFontSizeToFitWidth = true
        duckingStatusLabel.minimumScaleFactor = 0.75

        headerRow.addArrangedSubview(duckingTitleLabel)
        headerRow.addArrangedSubview(duckingStatusLabel)
        container.addArrangedSubview(headerRow)

        duckingSubLabel.text = L10n.navigationDuckingSubtitle
        duckingSubLabel.font = .systemFont(ofSize: 12)
        duckingSubLabel.textColor = .secondaryLabel
        duckingSubLabel.numberOfLines = 0
        container.addArrangedSubview(duckingSubLabel)

        duckingSlider.minimumValue = 0.0
        duckingSlider.maximumValue = 1.0
        container.addArrangedSubview(duckingSlider)

        presetStackView.axis = .horizontal
        presetStackView.spacing = 6
        presetStackView.distribution = .fillEqually

        for preset in NavigationDuckingPreset.allCases {
            var config = UIButton.Configuration.tinted()
            config.title = preset.shortTitle
            config.titleLineBreakMode = .byClipping
            config.cornerStyle = .capsule
            config.buttonSize = .mini
            let btn = UIButton(configuration: config)
            btn.titleLabel?.numberOfLines = 1
            btn.titleLabel?.adjustsFontSizeToFitWidth = true
            btn.titleLabel?.minimumScaleFactor = 0.65
            btn.addAction(UIAction { [weak self] _ in
                self?.applyDucking(preset.reductionAmount)
            }, for: .touchUpInside)
            presetButtons[preset] = btn
            presetStackView.addArrangedSubview(btn)
        }
        container.addArrangedSubview(presetStackView)

        let actionsRow = UIStackView()
        actionsRow.axis = .horizontal
        actionsRow.spacing = 10
        actionsRow.distribution = .fillEqually

        var testConfig = UIButton.Configuration.tinted()
        testConfig.title = L10n.testNavDucking
        testConfig.image = UIImage(systemName: "play.fill")
        testConfig.imagePadding = 4
        testConfig.buttonSize = .small
        testConfig.cornerStyle = .medium
        let testBtn = UIButton(configuration: testConfig)
        testBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        testBtn.titleLabel?.minimumScaleFactor = 0.75
        testBtn.addAction(UIAction { _ in
            AudioStreamTester.shared.playDuckingTestSequence()
        }, for: .touchUpInside)
        self.testDuckingButton = testBtn

        var resetConfig = UIButton.Configuration.gray()
        resetConfig.title = L10n.resetAudio
        resetConfig.image = UIImage(systemName: "arrow.counterclockwise")
        resetConfig.imagePadding = 4
        resetConfig.buttonSize = .small
        resetConfig.cornerStyle = .medium
        let resetBtn = UIButton(configuration: resetConfig)
        resetBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        resetBtn.titleLabel?.minimumScaleFactor = 0.75
        resetBtn.addAction(UIAction { [weak self] _ in
            self?.resetAudioVolumes()
        }, for: .touchUpInside)
        self.resetAudioButton = resetBtn

        actionsRow.addArrangedSubview(testBtn)
        actionsRow.addArrangedSubview(resetBtn)
        container.addArrangedSubview(actionsRow)

        return container
    }

    private func wireActions() {
        mediaSwitch.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            ProjectionSettings.isMediaChannelEnabled = self.mediaSwitch.isOn
            self.mediaSlider.isEnabled = self.mediaSwitch.isOn
            self.mediaValueLabel.text = self.mediaSwitch.isOn ? "\(Int((ProjectionSettings.mediaVolume * 100).rounded()))%" : L10n.off
            PCMAudioPlayer.shared.refreshVolumes()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)

        mediaSlider.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let val = (self.mediaSlider.value * 100).rounded() / 100.0
            ProjectionSettings.mediaVolume = val
            self.mediaValueLabel.text = "\(Int((val * 100).rounded()))%"
            PCMAudioPlayer.shared.refreshVolumes()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)

        navSwitch.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            ProjectionSettings.isNavigationChannelEnabled = self.navSwitch.isOn
            self.navSlider.isEnabled = self.navSwitch.isOn
            self.navValueLabel.text = self.navSwitch.isOn ? "\(Int((ProjectionSettings.navigationVolume * 100).rounded()))%" : L10n.off
            PCMAudioPlayer.shared.refreshVolumes()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)

        navSlider.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let val = (self.navSlider.value * 100).rounded() / 100.0
            ProjectionSettings.navigationVolume = val
            self.navValueLabel.text = "\(Int((val * 100).rounded()))%"
            PCMAudioPlayer.shared.refreshVolumes()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)

        sysSwitch.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            ProjectionSettings.isSystemChannelEnabled = self.sysSwitch.isOn
            self.sysSlider.isEnabled = self.sysSwitch.isOn
            self.sysValueLabel.text = self.sysSwitch.isOn ? "\(Int((ProjectionSettings.phoneSystemVolume * 100).rounded()))%" : L10n.off
            PCMAudioPlayer.shared.refreshVolumes()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)

        sysSlider.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let val = (self.sysSlider.value * 100).rounded() / 100.0
            ProjectionSettings.phoneSystemVolume = val
            self.sysValueLabel.text = "\(Int((val * 100).rounded()))%"
            PCMAudioPlayer.shared.refreshVolumes()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)

        duckingSlider.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let val = (self.duckingSlider.value * 100).rounded() / 100.0
            ProjectionSettings.navigationDuckingAmount = val
            self.updateDuckingStatusLabel(amount: val)
            self.updatePresetButtonSelection(amount: val)
            PCMAudioPlayer.shared.refreshVolumes()
            self.onSettingsChanged?(.audioVolumeOrDuckingChanged)
        }, for: .valueChanged)
    }

    private func applyDucking(_ amount: Float) {
        let rounded = (amount * 100).rounded() / 100.0
        ProjectionSettings.navigationDuckingAmount = rounded
        duckingSlider.value = rounded
        updateDuckingStatusLabel(amount: rounded)
        updatePresetButtonSelection(amount: rounded)
        PCMAudioPlayer.shared.refreshVolumes()
        onSettingsChanged?(.audioVolumeOrDuckingChanged)
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

    func syncWithCurrentSettings() {
        mediaTitleLabel.text = L10n.mediaAudio
        navTitleLabel.text = L10n.navigationGuidance
        sysTitleLabel.text = L10n.phoneSystemAlerts
        duckingTitleLabel.text = L10n.navigationDuckingDrop
        duckingSubLabel.text = L10n.navigationDuckingSubtitle
        if var testCfg = testDuckingButton?.configuration {
            testCfg.title = L10n.testNavDucking
            testDuckingButton?.configuration = testCfg
        }
        if var resetCfg = resetAudioButton?.configuration {
            resetCfg.title = L10n.resetAudio
            resetAudioButton?.configuration = resetCfg
        }

        let isSink = ProjectionSettings.isAudioSinkEnabled
        mediaSwitch.isEnabled = isSink
        mediaSlider.isEnabled = isSink && ProjectionSettings.isMediaChannelEnabled
        navSwitch.isEnabled = isSink
        navSlider.isEnabled = isSink && ProjectionSettings.isNavigationChannelEnabled
        sysSwitch.isEnabled = isSink
        sysSlider.isEnabled = isSink && ProjectionSettings.isSystemChannelEnabled
        duckingSlider.isEnabled = isSink
        for (_, btn) in presetButtons {
            btn.isEnabled = isSink
        }

        mediaSwitch.isOn = ProjectionSettings.isMediaChannelEnabled
        mediaSlider.value = ProjectionSettings.mediaVolume
        mediaValueLabel.text = (!isSink) ? L10n.notAvailableShort : (ProjectionSettings.isMediaChannelEnabled ? "\(Int((ProjectionSettings.mediaVolume * 100).rounded()))%" : L10n.off)

        navSwitch.isOn = ProjectionSettings.isNavigationChannelEnabled
        navSlider.value = ProjectionSettings.navigationVolume
        navValueLabel.text = (!isSink) ? L10n.notAvailableShort : (ProjectionSettings.isNavigationChannelEnabled ? "\(Int((ProjectionSettings.navigationVolume * 100).rounded()))%" : L10n.off)

        sysSwitch.isOn = ProjectionSettings.isSystemChannelEnabled
        sysSlider.value = ProjectionSettings.phoneSystemVolume
        sysValueLabel.text = (!isSink) ? L10n.notAvailableShort : (ProjectionSettings.isSystemChannelEnabled ? "\(Int((ProjectionSettings.phoneSystemVolume * 100).rounded()))%" : L10n.off)

        let duckAmount = ProjectionSettings.navigationDuckingAmount
        duckingSlider.value = duckAmount
        updateDuckingStatusLabel(amount: duckAmount)
        updatePresetButtonSelection(amount: duckAmount)
    }

    private func updateDuckingStatusLabel(amount: Float) {
        guard ProjectionSettings.isAudioSinkEnabled else {
            duckingStatusLabel.text = L10n.duckingDisabledPhoneAudio
            return
        }
        let pct = Int((amount * 100).rounded())
        if pct == 0 {
            duckingStatusLabel.text = L10n.duckingOffTitle
        } else if pct == 100 {
            duckingStatusLabel.text = L10n.duckingMuteTitle
        } else {
            let retained = 100 - pct
            duckingStatusLabel.text = L10n.duckingStatusRetained(pct: pct, retained: retained)
        }
    }

    private func updatePresetButtonSelection(amount: Float) {
        let pct = Int((amount * 100).rounded())
        for (preset, btn) in presetButtons {
            let isSelected = (preset.dropPercentage == pct)
            var config: UIButton.Configuration = isSelected ? .filled() : .tinted()
            config.title = preset.shortTitle
            config.titleLineBreakMode = .byClipping
            config.cornerStyle = .capsule
            config.buttonSize = .mini
            btn.configuration = config
            btn.titleLabel?.numberOfLines = 1
            btn.titleLabel?.adjustsFontSizeToFitWidth = true
            btn.titleLabel?.minimumScaleFactor = 0.65
        }
    }
}
