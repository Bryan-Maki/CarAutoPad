import XCTest
import UIKit
@testable import CarAutoPad

final class ViewControllersSmokeTests: XCTestCase {

    override func setUp() {
        super.setUp()
        L10n.testOverrideLanguage = nil
        ProjectionSettings.resetToDefaults()
        ConnectionManager.shared.setStateForTesting(.disconnected)
        ConnectionManager.shared.setStatusKindForTesting(.ready)
        ConnectionIssueStore.shared.clearAll()
    }

    override func tearDown() {
        L10n.testOverrideLanguage = nil
        ProjectionSettings.resetToDefaults()
        ConnectionManager.shared.setStateForTesting(.disconnected)
        ConnectionManager.shared.setStatusKindForTesting(.ready)
        ConnectionIssueStore.shared.clearAll()
        super.tearDown()
    }

    private func collectSubviews<T: UIView>(of type: T.Type, in root: UIView) -> [T] {
        var result: [T] = []
        for subview in root.subviews {
            if let match = subview as? T {
                result.append(match)
            }
            result.append(contentsOf: collectSubviews(of: type, in: subview))
        }
        return result
    }

    @MainActor
    func testMainViewControllerLaunchesWithoutCrash() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1194, height: 834))
        let mainVC = MainViewController()
        window.rootViewController = mainVC
        window.makeKeyAndVisible()

        mainVC.loadViewIfNeeded()
        mainVC.viewWillAppear(false)
        mainVC.viewDidAppear(false)
        mainVC.view.layoutIfNeeded()

        XCTAssertNotNil(mainVC.view)
        XCTAssertEqual(mainVC.selectedSidebarTab, .wirelessConnection)
    }

    @MainActor
    func testMainViewControllerSidebarFiveTabsSwitchingAndResponsiveLayout() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1194, height: 834))
        let mainVC = MainViewController()
        window.rootViewController = mainVC
        window.makeKeyAndVisible()

        mainVC.view.frame = CGRect(x: 0, y: 0, width: 1194, height: 834)
        mainVC.loadViewIfNeeded()
        mainVC.view.layoutIfNeeded()
        mainVC.viewDidLayoutSubviews()

        // Landscape wide: persistent 5-item sidebar visible, compact top bar hidden
        XCTAssertFalse(mainVC.sidebarView.isHidden)
        XCTAssertTrue(mainVC.compactTopBarView.isHidden)
        XCTAssertEqual(mainVC.sidebarView.navStackView.arrangedSubviews.count, 5)

        // Verify each sidebar row contains strictly 1 UILabel (clean [Icon + Title], zero trailing small labels)
        for tab in AppSidebarTab.allCases {
            guard let row = mainVC.sidebarView.rowButton(for: tab) else {
                XCTFail("Missing sidebar row for \(tab)")
                continue
            }
            let labels = collectSubviews(of: UILabel.self, in: row)
            XCTAssertEqual(labels.count, 1, "Sidebar row \(tab) must only contain its title label without trailing mini-text")
        }

        // Switch across all 5 sidebar tabs
        for tab in AppSidebarTab.allCases {
            mainVC.selectSidebarTab(tab)
            XCTAssertEqual(mainVC.selectedSidebarTab, tab)
            XCTAssertEqual(mainVC.sidebarView.selectedTab, tab)
        }

        // Collapse sidebar in landscape
        mainVC.setSidebarCollapsed(true, animated: false)
        XCTAssertTrue(mainVC.sidebarView.isHidden)
        XCTAssertFalse(mainVC.compactTopBarView.isHidden)
        mainVC.setSidebarCollapsed(false, animated: false)
        XCTAssertFalse(mainVC.sidebarView.isHidden)

        // Portrait narrow layout: collapses to compact top bar + menu button
        mainVC.view.frame = CGRect(x: 0, y: 0, width: 700, height: 1024)
        mainVC.view.layoutIfNeeded()
        mainVC.viewDidLayoutSubviews()
        XCTAssertTrue(mainVC.sidebarView.isHidden)
        XCTAssertFalse(mainVC.compactTopBarView.isHidden)
    }

    @MainActor
    func testWirelessEntryHeroButtonAndCollapsibleAndroidSteps() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1194, height: 834))
        let mainVC = MainViewController()
        window.rootViewController = mainVC
        window.makeKeyAndVisible()
        mainVC.loadViewIfNeeded()
        mainVC.view.layoutIfNeeded()

        let wireless = mainVC.wirelessPanelVC
        XCTAssertEqual(wireless.heroPrimaryButton.accessibilityIdentifier, "scanHeadunitPrimaryButton")
        XCTAssertEqual(wireless.heroPrimaryButton.frame.height, 68, accuracy: 1.0)
        XCTAssertFalse(wireless.heroPrimaryButton.isHidden)
        XCTAssertTrue(wireless.scanningBarContainer.isHidden)

        // Default ready state: Android setup steps collapsed
        XCTAssertFalse(wireless.isGuideStepsExpanded)
        XCTAssertTrue(wireless.guideStepsContainer.isHidden)
        XCTAssertTrue(wireless.guideCountBadgeLabel.isHidden)
        XCTAssertEqual(wireless.guideStepsStack.arrangedSubviews.count, 4)

        // Tap disclosure header -> expands
        wireless.guideHeaderControl.sendActions(for: .touchUpInside)
        XCTAssertTrue(wireless.isGuideStepsExpanded)
        XCTAssertFalse(wireless.guideStepsContainer.isHidden)
        XCTAssertFalse(wireless.guideCountBadgeLabel.isHidden)

        // Tap again -> collapses
        wireless.guideHeaderControl.sendActions(for: .touchUpInside)
        XCTAssertFalse(wireless.isGuideStepsExpanded)
        XCTAssertTrue(wireless.guideStepsContainer.isHidden)

        // Connection issue raised -> shows banner and auto-expands steps
        wireless.updateIssueBanner(issue: nil) // resets manual toggle lock
        ConnectionIssueStore.shared.raise(issue: .noDeviceDiscovered)
        mainVC.updateConnectionIssueBanner()
        XCTAssertFalse(wireless.issueBannerCard.isHidden)
        XCTAssertTrue(wireless.isGuideStepsExpanded)

        // Scanning state swaps 68pt CTA to 68pt progress + cancel bar
        wireless.updateConnectionState(.discovering, statusDetail: L10n.statusScanning(stationIp: "192.168.43.128"))
        XCTAssertTrue(wireless.heroPrimaryButton.isHidden)
        XCTAssertFalse(wireless.scanningBarContainer.isHidden)
    }

    func testConnectedPhoneStorePersistenceDeduplicationAndSdrProto() throws {
        let suiteName = "com.carautopad.tests.connectedphones.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ConnectedPhoneStore(userDefaults: defaults, storageKey: "test-phones")
        XCTAssertTrue(store.records().isEmpty)

        // IP-only placeholder replaced once real name/model arrives from ServiceDiscoveryRequest
        let t0 = Date(timeIntervalSince1970: 1000)
        store.recordConnection(deviceName: nil, hardwareModel: nil, ipAddress: "192.168.43.1", port: 5277, at: t0)
        XCTAssertEqual(store.records().count, 1)
        XCTAssertEqual(store.records().first?.deviceName, "192.168.43.1")

        let t1 = Date(timeIntervalSince1970: 2000)
        store.recordConnection(deviceName: "Pixel 9 Pro", hardwareModel: "Google Pixel 9 Pro", ipAddress: "192.168.43.1", port: 5277, at: t1)
        XCTAssertEqual(store.records().count, 1)
        XCTAssertEqual(store.records().first?.deviceName, "Pixel 9 Pro")
        XCTAssertEqual(store.records().first?.hardwareModel, "Google Pixel 9 Pro")

        let t2 = Date(timeIntervalSince1970: 3000)
        store.recordConnection(deviceName: "Galaxy S25 Ultra", hardwareModel: "Samsung SM-S9380", ipAddress: "192.168.137.1", port: 5277, at: t2)
        XCTAssertEqual(store.records().count, 2)
        XCTAssertEqual(store.records()[0].deviceName, "Galaxy S25 Ultra")
        XCTAssertEqual(store.records()[1].deviceName, "Pixel 9 Pro")

        // Remove one record
        let firstId = store.records()[0].id
        store.remove(id: firstId)
        XCTAssertEqual(store.records().count, 1)
        XCTAssertEqual(store.records()[0].deviceName, "Pixel 9 Pro")

        // Verify ServiceDiscoveryRequestProto field 4 & 5 round-trip
        var writer = ProtoWriter()
        ServiceDiscoveryRequestProto(phoneName: "Pixel 9 Pro", phoneBrand: "Google").encode(to: &writer)
        var reader = ProtoReader(data: writer.data)
        let decoded = try ServiceDiscoveryRequestProto(from: &reader)
        XCTAssertEqual(decoded.phoneName, "Pixel 9 Pro")
        XCTAssertEqual(decoded.phoneBrand, "Google")
    }

    @MainActor
    func testAboutPageRealMetadataAndFiveTapHiddenDiagnosticsUnlock() {
        let suiteName = "com.carautopad.tests.about.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ConnectedPhoneStore(userDefaults: defaults, storageKey: "test-about-phones")
        let aboutVC = AboutAndDiagnosticsViewController()
        aboutVC.phoneStore = store
        aboutVC.loadViewIfNeeded()
        aboutVC.view.frame = CGRect(x: 0, y: 0, width: 917, height: 806)
        aboutVC.view.layoutIfNeeded()

        XCTAssertEqual(aboutVC.versionValueLabel.text, CarAutoPadDeviceInfo.appVersionString)
        XCTAssertEqual(aboutVC.deviceModelValueLabel.text, CarAutoPadDeviceInfo.deviceModelDisplayName)
        XCTAssertEqual(aboutVC.osVersionValueLabel.text, CarAutoPadDeviceInfo.osVersionDisplayName)
        XCTAssertEqual(aboutVC.phonesCountLabel.text, L10n.aboutDeviceCount(0))

        // Record a real connected phone and verify UI updates
        store.recordConnection(deviceName: "Pixel 9 Pro", hardwareModel: "Google Pixel 9 Pro", ipAddress: "192.168.43.1", port: 5277)
        aboutVC.refreshDynamicData()
        XCTAssertEqual(aboutVC.phonesCountLabel.text, L10n.aboutDeviceCount(1))

        // Diagnostics hidden by default
        XCTAssertFalse(ProjectionSettings.isHiddenDiagnosticsUnlocked)
        XCTAssertFalse(aboutVC.isShowingDiagnosticsSubpage)
        XCTAssertTrue(aboutVC.unlockedDiagnosticsEntryCard.isHidden)
        XCTAssertTrue(aboutVC.diagnosticsScrollView.isHidden)

        // 4 taps on Version row: still locked
        for i in 0..<4 {
            aboutVC.handleVersionRowTap(now: 100.0 + Double(i) * 0.2)
        }
        XCTAssertFalse(ProjectionSettings.isHiddenDiagnosticsUnlocked)
        XCTAssertFalse(aboutVC.isShowingDiagnosticsSubpage)

        // 5th tap: unlocks and transitions into Automation & Diagnostics
        aboutVC.handleVersionRowTap(now: 100.8)
        XCTAssertTrue(ProjectionSettings.isHiddenDiagnosticsUnlocked)
        XCTAssertTrue(aboutVC.isShowingDiagnosticsSubpage)
        XCTAssertFalse(aboutVC.diagnosticsScrollView.isHidden)
        XCTAssertFalse(aboutVC.unlockedDiagnosticsEntryCard.isHidden)

        // Hide entry resets unlock state and returns to About
        aboutVC.hideDiagnosticsAndReturnToAbout(animated: false)
        XCTAssertFalse(ProjectionSettings.isHiddenDiagnosticsUnlocked)
        XCTAssertFalse(aboutVC.isShowingDiagnosticsSubpage)
        XCTAssertTrue(aboutVC.unlockedDiagnosticsEntryCard.isHidden)
        XCTAssertFalse(aboutVC.aboutScrollView.isHidden)
    }

    @MainActor
    func testEmbeddedSettingsPanelsHandshakeLockDimmingAndLiveControls() {
        let displayVC = DisplayLayoutPanelViewController()
        let audioVC = AudioMixerPanelViewController()
        displayVC.loadViewIfNeeded()
        audioVC.loadViewIfNeeded()

        // Disconnected: all controls enabled
        ConnectionManager.shared.setStateForTesting(.disconnected)
        displayVC.syncWithCurrentSettings()
        audioVC.syncWithCurrentSettings()

        XCTAssertTrue(displayVC.autoDpiSwitch.isEnabled)
        XCTAssertTrue(displayVC.dpiSlider.isEnabled)
        XCTAssertTrue(displayVC.fpsSegment.isEnabled)
        XCTAssertTrue(displayVC.drivePosSegment.isEnabled)
        XCTAssertTrue(audioVC.videoCodecSegment.isEnabled)
        XCTAssertTrue(audioVC.audioCodecSegment.isEnabled)
        XCTAssertTrue(audioVC.audioOutSegment.isEnabled)
        XCTAssertTrue(audioVC.micSourceSegment.isEnabled)

        // Connected: 8 handshake params disabled & dimmed, live params remain enabled
        ConnectionManager.shared.setStateForTesting(.running)
        displayVC.syncWithCurrentSettings()
        audioVC.syncWithCurrentSettings()

        XCTAssertFalse(displayVC.autoDpiSwitch.isEnabled)
        XCTAssertFalse(displayVC.dpiSlider.isEnabled)
        XCTAssertFalse(displayVC.fpsSegment.isEnabled)
        XCTAssertFalse(displayVC.drivePosSegment.isEnabled)
        XCTAssertFalse(audioVC.videoCodecSegment.isEnabled)
        XCTAssertFalse(audioVC.audioCodecSegment.isEnabled)
        XCTAssertFalse(audioVC.audioOutSegment.isEnabled)
        XCTAssertFalse(audioVC.micSourceSegment.isEnabled)

        XCTAssertTrue(displayVC.fitSegment.isEnabled)
        XCTAssertTrue(displayVC.orientSegment.isEnabled)
        XCTAssertTrue(displayVC.smoothSegment.isEnabled)
        XCTAssertTrue(displayVC.edgeSwipeSwitch.isEnabled)
        XCTAssertTrue(audioVC.mediaSlider.isEnabled)
        XCTAssertTrue(audioVC.navSlider.isEnabled)
        XCTAssertTrue(audioVC.sysSlider.isEnabled)
        XCTAssertTrue(audioVC.duckingSlider.isEnabled)

        // Phone audio target disables mixer sliders without starting AVAudioEngine
        ProjectionSettings.audioOutputTarget = .phone
        audioVC.syncWithCurrentSettings()
        XCTAssertFalse(audioVC.mediaSwitch.isEnabled)
        XCTAssertFalse(audioVC.mediaSlider.isEnabled)
        XCTAssertFalse(audioVC.duckingSlider.isEnabled)
    }

    @MainActor
    func testProjectionQuickMenuPopoverActionsAndDismiss() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1194, height: 834))
        let mainVC = MainViewController()
        window.rootViewController = mainVC
        window.makeKeyAndVisible()
        mainVC.loadViewIfNeeded()
        mainVC.view.layoutIfNeeded()

        ConnectionManager.shared.setStateForTesting(.running)
        ProjectionSettings.isDebugModeEnabled = true
        mainVC.updatePerformanceOverlayState()
        XCTAssertFalse(mainVC.debugBubbleButton.isHidden)

        mainVC.presentProjectionQuickMenu()
        guard let menu = mainVC.quickMenuOverlay else {
            XCTFail("Expected ProjectionQuickMenuView to be presented")
            return
        }

        // Toggle Night Mode to Night
        menu.nightModeSegment.selectedSegmentIndex = 2
        menu.nightModeSegment.sendActions(for: .valueChanged)
        XCTAssertEqual(ProjectionSettings.nightMode, .night)

        // Toggle Media Mute ON
        menu.mediaMuteSwitch.isOn = true
        menu.mediaMuteSwitch.sendActions(for: .valueChanged)
        XCTAssertFalse(ProjectionSettings.isMediaChannelEnabled)

        mainVC.dismissProjectionQuickMenu(animated: false)
        XCTAssertNil(mainVC.quickMenuOverlay)
    }

    @MainActor
    func testSettingsViewControllerLoadsAndRendersAllSections() {
        let settingsVC = SettingsViewController()
        settingsVC.loadViewIfNeeded()
        settingsVC.view.layoutIfNeeded()

        guard let tableView = settingsVC.view.subviews.first(where: { $0 is UITableView }) as? UITableView else {
            XCTFail("SettingsViewController must contain a UITableView")
            return
        }

        let sectionCount = settingsVC.numberOfSections(in: tableView)
        XCTAssertEqual(sectionCount, SettingsViewController.SettingsSection.allCases.count)

        let s0Rows = settingsVC.tableView(tableView, numberOfRowsInSection: 0)
        XCTAssertEqual(s0Rows, 0, "Active Session section should have 0 rows when disconnected")

        for s in 1..<sectionCount {
            let rowCount = settingsVC.tableView(tableView, numberOfRowsInSection: s)
            XCTAssertGreaterThan(rowCount, 0, "Section \(s) should have rows")

            for r in 0..<rowCount {
                let cell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: r, section: s))
                XCTAssertNotNil(cell, "Cell at [\(s), \(r)] must not be nil")
            }
        }
    }

    func testDpiPreviewViewScalesElementsDynamically() {
        let previewView = DpiPreviewView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        previewView.panelWidthPx = 1920
        previewView.panelHeightPx = 1080

        let renderer = UIGraphicsImageRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 300))

        previewView.dpi = 120
        _ = renderer.image { _ in
            previewView.draw(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let railW120 = previewView.lastCalculatedRailWidth
        let cardW120 = previewView.lastCalculatedSecondaryCardWidth
        XCTAssertEqual(previewView.virtualWidthDp, 2560)
        XCTAssertTrue(previewView.isCoolwalkSplitScreen)

        previewView.dpi = 240
        _ = renderer.image { _ in
            previewView.draw(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        let railW240 = previewView.lastCalculatedRailWidth
        let cardW240 = previewView.lastCalculatedSecondaryCardWidth
        XCTAssertEqual(previewView.virtualWidthDp, 1280)
        XCTAssertTrue(previewView.isCoolwalkSplitScreen)

        XCTAssertGreaterThan(railW240, railW120, "Rail width should grow as DPI increases")
        XCTAssertGreaterThan(cardW240, cardW120, "Secondary card width should grow as DPI increases")

        previewView.panelWidthPx = 1280
        previewView.panelHeightPx = 720
        previewView.dpi = 320
        _ = renderer.image { _ in
            previewView.draw(CGRect(x: 0, y: 0, width: 400, height: 300))
        }
        XCTAssertEqual(previewView.virtualWidthDp, 640)
        XCTAssertFalse(previewView.isCoolwalkSplitScreen, "Should drop out of Coolwalk split screen when dp < 800")
    }

    func testHotspotGatewayHelper() {
        let gw = NetworkAddresses.currentHotspotGatewayIpv4()
        XCTAssertFalse(gw.isEmpty)
    }

    func testDpiPreviewViewPortraitModeMetrics() {
        let previewView = DpiPreviewView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        previewView.panelWidthPx = 1080
        previewView.panelHeightPx = 1920
        previewView.dpi = 160

        let renderer = UIGraphicsImageRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 500))
        _ = renderer.image { _ in
            previewView.draw(CGRect(x: 0, y: 0, width: 300, height: 500))
        }

        XCTAssertEqual(previewView.virtualWidthDp, 1080)
        XCTAssertEqual(previewView.virtualHeightDp, 1920)
        XCTAssertTrue(previewView.isCoolwalkSplitScreen)
    }

    @MainActor
    func testAudioChannelMixerCellInitializesWithoutCrash() {
        let cell = AudioChannelMixerCell()
        cell.layoutIfNeeded()
        XCTAssertNotNil(cell.contentView)
    }

    @MainActor
    func testAudioChannelMixerCellBoostSliderAndPhoneOutputSync() {
        ProjectionSettings.mediaVolume = 1.5
        ProjectionSettings.audioOutputTarget = .ipad

        let cell = AudioChannelMixerCell()
        cell.layoutIfNeeded()

        let sliders = collectSubviews(of: UISlider.self, in: cell.contentView)
        XCTAssertEqual(sliders.count, 4)
        let boostSliders = sliders.filter { abs($0.maximumValue - ProjectionSettings.maxChannelVolume) < 0.001 }
        XCTAssertEqual(boostSliders.count, 3)

        let switches = collectSubviews(of: UISwitch.self, in: cell.contentView)
        XCTAssertEqual(switches.count, 3)
        XCTAssertTrue(switches.allSatisfy { $0.isEnabled })

        let labelsBefore = collectSubviews(of: UILabel.self, in: cell.contentView).compactMap { $0.text }
        XCTAssertTrue(labelsBefore.contains("150%"))

        ProjectionSettings.audioOutputTarget = .phone
        cell.syncWithCurrentSettings()

        XCTAssertTrue(switches.allSatisfy { !$0.isEnabled })
        XCTAssertTrue(sliders.allSatisfy { !$0.isEnabled })
        let labelsPhone = collectSubviews(of: UILabel.self, in: cell.contentView).compactMap { $0.text }
        XCTAssertEqual(labelsPhone.filter { $0 == "N/A" }.count, 3)
        XCTAssertTrue(labelsPhone.contains("Disabled (Audio plays on Phone / Car BT)"))
    }

    @MainActor
    func testSettingsViewControllerAudioOutputToggleReloadsMixerCell() {
        let settingsVC = SettingsViewController()
        settingsVC.loadViewIfNeeded()
        settingsVC.view.frame = CGRect(x: 0, y: 0, width: 640, height: 740)
        settingsVC.view.layoutIfNeeded()

        guard let tableView = settingsVC.view.subviews.first(where: { $0 is UITableView }) as? UITableView else {
            XCTFail("SettingsViewController must contain a UITableView")
            return
        }

        let vaSec = SettingsViewController.SettingsSection.videoAudio.rawValue
        let audioOutCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 2, section: vaSec))
        guard let seg = audioOutCell.accessoryView as? UISegmentedControl else {
            XCTFail("Audio Output row must use a UISegmentedControl")
            return
        }

        seg.selectedSegmentIndex = 1
        seg.sendActions(for: .valueChanged)
        XCTAssertEqual(ProjectionSettings.audioOutputTarget, .phone)

        let mixerCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 4, section: vaSec))
        let switches = collectSubviews(of: UISwitch.self, in: mixerCell.contentView)
        let sliders = collectSubviews(of: UISlider.self, in: mixerCell.contentView)
        let labels = collectSubviews(of: UILabel.self, in: mixerCell.contentView).compactMap { $0.text }

        XCTAssertEqual(switches.count, 3)
        XCTAssertTrue(switches.allSatisfy { !$0.isEnabled })
        XCTAssertTrue(sliders.allSatisfy { !$0.isEnabled })
        XCTAssertEqual(labels.filter { $0 == "N/A" }.count, 3)
        XCTAssertTrue(labels.contains("Disabled (Audio plays on Phone / Car BT)"))
    }

    @MainActor
    func testSettingsViewControllerVideoAudioSectionHasFiveRows() {
        let settingsVC = SettingsViewController()
        settingsVC.loadViewIfNeeded()
        settingsVC.view.layoutIfNeeded()

        guard let tableView = settingsVC.view.subviews.first(where: { $0 is UITableView }) as? UITableView else {
            XCTFail("SettingsViewController must contain a UITableView")
            return
        }

        let rowCount = settingsVC.tableView(tableView, numberOfRowsInSection: SettingsViewController.SettingsSection.videoAudio.rawValue)
        XCTAssertEqual(rowCount, 5)

        let cell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: SettingsViewController.SettingsSection.diagnosticsBackup.rawValue))
        XCTAssertEqual(cell.textLabel?.text, "Debug Mode (HUD & Floating Bubble)")
    }

    @MainActor
    func testMainViewControllerDebugBubbleButtonPropertiesAndToggle() {
        let mvc = MainViewController()
        mvc.loadViewIfNeeded()
        mvc.view.layoutIfNeeded()

        XCTAssertTrue(mvc.view.subviews.contains(mvc.debugBubbleButton))
        XCTAssertEqual(mvc.debugBubbleButton.accessibilityIdentifier, "debugBubbleButton")
        XCTAssertEqual(mvc.debugBubbleButton.layer.cornerRadius, 24)

        ConnectionManager.shared.setStateForTesting(.disconnected)
        ProjectionSettings.isDebugModeEnabled = true
        mvc.updatePerformanceOverlayState()
        XCTAssertTrue(mvc.debugBubbleButton.isHidden)

        ProjectionSettings.isDebugModeEnabled = false
        mvc.updatePerformanceOverlayState()
        XCTAssertTrue(mvc.debugBubbleButton.isHidden)

        ConnectionManager.shared.setStateForTesting(.running)
        ProjectionSettings.isDebugModeEnabled = true
        mvc.updatePerformanceOverlayState()
        XCTAssertFalse(mvc.debugBubbleButton.isHidden)

        ProjectionSettings.isDebugModeEnabled = false
        mvc.updatePerformanceOverlayState()
        XCTAssertTrue(mvc.debugBubbleButton.isHidden)
    }

    @MainActor
    func testMainViewControllerDebugBubblePanGestureAndSnapping() {
        let mvc = MainViewController()
        mvc.loadViewIfNeeded()
        mvc.view.bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        mvc.view.layoutIfNeeded()

        let pan = mvc.debugBubbleButton.gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer }.first
        XCTAssertNotNil(pan)

        mvc.clampDebugBubbleToSafeBounds(animated: false)
        mvc.isPanningDebugBubble = true
        mvc.view.layoutIfNeeded()
        XCTAssertTrue(mvc.isPanningDebugBubble)

        mvc.isPanningDebugBubble = false
        mvc.clampDebugBubbleToSafeBounds(animated: false)
        XCTAssertFalse(mvc.isPanningDebugBubble)
    }

    @MainActor
    func testDpiPreviewCellConfigureWithIsLocked() {
        let cell = DpiPreviewCell()
        cell.configure(with: HeadUnitScreenConfig.shared, isLocked: true)
        let switches = cell.contentView.subviews.compactMap { $0 as? UISwitch }
        for s in switches { XCTAssertFalse(s.isEnabled) }
        let sliders = cell.contentView.subviews.compactMap { $0 as? UISlider }
        for sl in sliders { XCTAssertFalse(sl.isEnabled) }
        let stackViews = cell.contentView.subviews.compactMap { $0 as? UIStackView }
        for stack in stackViews {
            XCTAssertEqual(stack.alpha, 0.5, accuracy: 0.01)
            for btn in stack.arrangedSubviews.compactMap({ $0 as? UIButton }) {
                XCTAssertFalse(btn.isEnabled)
            }
        }

        cell.configure(with: HeadUnitScreenConfig.shared, isLocked: false)
        for s in switches { XCTAssertTrue(s.isEnabled) }
        for sl in sliders { XCTAssertTrue(sl.isEnabled) }
        for stack in stackViews {
            XCTAssertEqual(stack.alpha, 1.0, accuracy: 0.01)
            for btn in stack.arrangedSubviews.compactMap({ $0 as? UIButton }) {
                XCTAssertTrue(btn.isEnabled)
            }
        }
    }

    @MainActor
    func testSettingsViewControllerHandshakeSettingsLockedWhenConnected() {
        let settingsVC = SettingsViewController()
        settingsVC.loadViewIfNeeded()
        settingsVC.view.layoutIfNeeded()

        guard let tableView = settingsVC.view.subviews.first(where: { $0 is UITableView }) as? UITableView else {
            XCTFail("SettingsViewController must contain a UITableView")
            return
        }

        let dlSec = SettingsViewController.SettingsSection.displayLayout.rawValue
        let vaSec = SettingsViewController.SettingsSection.videoAudio.rawValue

        ConnectionManager.shared.setStateForTesting(.disconnected)
        tableView.reloadData()
        XCTAssertFalse(settingsVC.tableView(tableView, titleForFooterInSection: dlSec)?.contains("locked during active session") ?? true)

        ConnectionManager.shared.setStateForTesting(.running)
        tableView.reloadData()
        XCTAssertTrue(settingsVC.tableView(tableView, titleForFooterInSection: dlSec)?.contains("locked during active session") ?? false)
        XCTAssertTrue(settingsVC.tableView(tableView, titleForFooterInSection: vaSec)?.contains("locked during active session") ?? false)

        let resCellLocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 1, section: dlSec))
        XCTAssertTrue(resCellLocked.detailTextLabel?.text?.contains("(Locked)") ?? false)
        XCTAssertEqual(resCellLocked.accessoryType, .none)

        let fitCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 3, section: dlSec))
        if let seg = fitCell.accessoryView as? UISegmentedControl { XCTAssertTrue(seg.isEnabled) }
        let vcCellLocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: vaSec))
        if let seg = vcCellLocked.accessoryView as? UISegmentedControl { XCTAssertFalse(seg.isEnabled) }
        let mixerCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 4, section: vaSec))
        XCTAssertTrue(mixerCell is AudioChannelMixerCell)
    }

    func testConnectionManagerReconnectDebounceAndCancellation() {
        let cm = ConnectionManager.shared
        defer { cm.disconnect() }

        let device = DiscoveredDevice(ip: "192.168.1.100", port: 5277, name: "TestDevice")
        cm.connect(to: device, userInitiated: true)
        cm.reconnectForSettingsChange()
        XCTAssertEqual(cm.state, .disconnected)
        cm.reconnectForSettingsChange()
        XCTAssertEqual(cm.state, .disconnected)
        cm.disconnect()
        XCTAssertEqual(cm.state, .disconnected)
    }

    @MainActor
    func testMainViewControllerEdgeSwipeProtectionAndHomeIndicatorBehavior() {
        let mainVC = MainViewController()
        mainVC.loadViewIfNeeded()

        XCTAssertFalse(mainVC.prefersHomeIndicatorAutoHidden)

        ConnectionManager.shared.setStateForTesting(.disconnected)
        ProjectionSettings.isEdgeSwipeProtectionEnabled = true
        XCTAssertEqual(mainVC.preferredScreenEdgesDeferringSystemGestures, [])

        ConnectionManager.shared.setStateForTesting(.running)
        XCTAssertFalse(mainVC.prefersHomeIndicatorAutoHidden)
        XCTAssertEqual(mainVC.preferredScreenEdgesDeferringSystemGestures, .all)

        ProjectionSettings.isEdgeSwipeProtectionEnabled = false
        mainVC.refreshSystemGestureDeferral()
        XCTAssertEqual(mainVC.preferredScreenEdgesDeferringSystemGestures, [])
    }

    @MainActor
    func testSettingsViewControllerDisplayLayoutEdgeSwipeProtectionRow() {
        ConnectionManager.shared.setStateForTesting(.running)

        let settingsVC = SettingsViewController()
        settingsVC.loadViewIfNeeded()
        settingsVC.view.layoutIfNeeded()

        guard let tableView = settingsVC.view.subviews.first(where: { $0 is UITableView }) as? UITableView else {
            XCTFail("SettingsViewController must contain a UITableView")
            return
        }

        let dlSec = SettingsViewController.SettingsSection.displayLayout.rawValue
        XCTAssertEqual(settingsVC.tableView(tableView, numberOfRowsInSection: dlSec), 8)

        let cell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 7, section: dlSec))
        XCTAssertEqual(cell.textLabel?.text, "Edge Swipe Protection (Double-Swipe)")
        guard let toggle = cell.accessoryView as? UISwitch else {
            XCTFail("Edge Swipe Protection row must have a UISwitch accessoryView")
            return
        }
        XCTAssertTrue(toggle.isEnabled)
        XCTAssertTrue(toggle.isOn)

        var receivedImpact: SettingsViewController.ChangeImpact?
        settingsVC.onSettingsChanged = { impact in receivedImpact = impact }
        toggle.isOn = false
        toggle.sendActions(for: .valueChanged)
        XCTAssertFalse(ProjectionSettings.isEdgeSwipeProtectionEnabled)
        XCTAssertEqual(receivedImpact, .uiOnly)
    }
}
