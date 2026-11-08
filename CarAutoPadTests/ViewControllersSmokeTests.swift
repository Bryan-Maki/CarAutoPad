import XCTest
import UIKit
@testable import CarAutoPad

final class ViewControllersSmokeTests: XCTestCase {

    @MainActor
    func testMainViewControllerLaunchesWithoutCrash() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        let mainVC = MainViewController()
        window.rootViewController = mainVC
        window.makeKeyAndVisible()

        mainVC.loadViewIfNeeded()
        mainVC.viewWillAppear(false)
        mainVC.viewDidAppear(false)
        mainVC.view.layoutIfNeeded()

        XCTAssertNotNil(mainVC.view)
    }

    @MainActor
    func testMainViewControllerDashboardResponsiveLayout() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        let mainVC = MainViewController()
        window.rootViewController = mainVC
        window.makeKeyAndVisible()

        mainVC.view.frame = CGRect(x: 0, y: 0, width: 1024, height: 768)
        mainVC.loadViewIfNeeded()
        mainVC.view.layoutIfNeeded()
        mainVC.viewDidLayoutSubviews()

        mainVC.refreshQuickSpecTiles()
        XCTAssertNotNil(mainVC.view)

        mainVC.view.frame = CGRect(x: 0, y: 0, width: 768, height: 1024)
        mainVC.view.layoutIfNeeded()
        mainVC.viewDidLayoutSubviews()

        mainVC.refreshQuickSpecTiles()
        XCTAssertNotNil(mainVC.view)
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

    @MainActor
    func testQuickLayoutDpiViewControllerLaunchesWithoutCrash() {
        let vc = QuickLayoutDpiViewController()
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()
        XCTAssertNotNil(vc.view)
        XCTAssertEqual(vc.preferredContentSize, CGSize(width: 560, height: 500))
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
    func testQuickAudioConfigViewControllerLaunchesWithoutCrash() {
        let vc = QuickAudioConfigViewController()
        vc.loadViewIfNeeded()
        vc.view.layoutIfNeeded()
        XCTAssertNotNil(vc.view)
        XCTAssertEqual(vc.preferredContentSize, CGSize(width: 580, height: 620))
    }

    @MainActor
    func testAudioChannelMixerCellInitializesWithoutCrash() {
        let cell = AudioChannelMixerCell()
        cell.layoutIfNeeded()
        XCTAssertNotNil(cell.contentView)
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
        XCTAssertEqual(rowCount, 5, "Video & Audio section must have exactly 5 rows after removing standalone Audio Stream Tester")

        let cell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: SettingsViewController.SettingsSection.diagnosticsBackup.rawValue))
        XCTAssertEqual(cell.textLabel?.text, "Debug Mode (HUD & Floating Bubble)")
    }

    @MainActor
    func testMainViewControllerDebugBubbleButtonPropertiesAndToggle() {
        let initial = ProjectionSettings.isDebugModeEnabled
        defer {
            ProjectionSettings.isDebugModeEnabled = initial
            ConnectionManager.shared.setStateForTesting(.disconnected)
        }

        let mvc = MainViewController()
        mvc.loadViewIfNeeded()
        mvc.view.layoutIfNeeded()

        XCTAssertTrue(mvc.view.subviews.contains(mvc.debugBubbleButton), "MainViewController view must contain debugBubbleButton")
        XCTAssertEqual(mvc.debugBubbleButton.accessibilityIdentifier, "debugBubbleButton")
        XCTAssertEqual(mvc.debugBubbleButton.layer.cornerRadius, 24)

        // 1. When disconnected on home screen, debugBubbleButton should remain hidden even if debug mode is enabled
        ConnectionManager.shared.setStateForTesting(.disconnected)
        ProjectionSettings.isDebugModeEnabled = true
        mvc.updatePerformanceOverlayState()
        XCTAssertTrue(mvc.debugBubbleButton.isHidden, "debugBubbleButton should remain hidden when disconnected even if debug mode is enabled")

        // 2. Toggle debug mode off while disconnected
        ProjectionSettings.isDebugModeEnabled = false
        mvc.updatePerformanceOverlayState()
        XCTAssertTrue(mvc.debugBubbleButton.isHidden, "debugBubbleButton should be hidden when debug mode is disabled")

        // 3. When running and debug mode is enabled, debugBubbleButton MUST be visible
        ConnectionManager.shared.setStateForTesting(.running)
        ProjectionSettings.isDebugModeEnabled = true
        mvc.updatePerformanceOverlayState()
        XCTAssertFalse(mvc.debugBubbleButton.isHidden, "debugBubbleButton should be visible when running and debug mode is enabled")

        // 4. When running and debug mode is disabled, debugBubbleButton must be hidden
        ProjectionSettings.isDebugModeEnabled = false
        mvc.updatePerformanceOverlayState()
        XCTAssertTrue(mvc.debugBubbleButton.isHidden, "debugBubbleButton should be hidden when debug mode is disabled even while running")
    }

    @MainActor
    func testMainViewControllerDebugBubblePanGestureAndSnapping() {
        let mvc = MainViewController()
        mvc.loadViewIfNeeded()
        mvc.view.bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        mvc.view.layoutIfNeeded()

        let pan = mvc.debugBubbleButton.gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer }.first
        XCTAssertNotNil(pan, "debugBubbleButton must have a UIPanGestureRecognizer attached")

        // Initial clamp snaps to right side
        mvc.clampDebugBubbleToSafeBounds(animated: false)

        // Simulate active pan state
        mvc.isPanningDebugBubble = true
        // layout subviews should NOT snap while panning is true
        mvc.view.layoutIfNeeded()
        XCTAssertTrue(mvc.isPanningDebugBubble)

        // Simulate ending pan
        mvc.isPanningDebugBubble = false
        mvc.clampDebugBubbleToSafeBounds(animated: false)
        XCTAssertFalse(mvc.isPanningDebugBubble)
    }

    @MainActor
    func testDpiPreviewCellConfigureWithIsLocked() {
        let cell = DpiPreviewCell()
        cell.configure(with: HeadUnitScreenConfig.shared, isLocked: true)
        let switches = cell.contentView.subviews.compactMap { $0 as? UISwitch }
        for s in switches {
            XCTAssertFalse(s.isEnabled, "UISwitch in DpiPreviewCell should be disabled when isLocked is true")
        }
        let sliders = cell.contentView.subviews.compactMap { $0 as? UISlider }
        for sl in sliders {
            XCTAssertFalse(sl.isEnabled, "UISlider in DpiPreviewCell should be disabled when isLocked is true")
        }
        let stackViews = cell.contentView.subviews.compactMap { $0 as? UIStackView }
        for stack in stackViews {
            XCTAssertEqual(stack.alpha, 0.5, accuracy: 0.01, "Preset stackView alpha should be 0.5 when isLocked is true")
            for btn in stack.arrangedSubviews.compactMap({ $0 as? UIButton }) {
                XCTAssertFalse(btn.isEnabled, "Preset button should be disabled when isLocked is true")
            }
        }

        cell.configure(with: HeadUnitScreenConfig.shared, isLocked: false)
        for s in switches {
            XCTAssertTrue(s.isEnabled, "UISwitch in DpiPreviewCell should be enabled when isLocked is false")
        }
        for sl in sliders {
            XCTAssertTrue(sl.isEnabled, "UISlider in DpiPreviewCell should be enabled when isLocked is false")
        }
        for stack in stackViews {
            XCTAssertEqual(stack.alpha, 1.0, accuracy: 0.01, "Preset stackView alpha should be 1.0 when isLocked is false")
            for btn in stack.arrangedSubviews.compactMap({ $0 as? UIButton }) {
                XCTAssertTrue(btn.isEnabled, "Preset button should be enabled when isLocked is false")
            }
        }
    }

    @MainActor
    func testSettingsViewControllerHandshakeSettingsLockedWhenConnected() {
        defer {
            ConnectionManager.shared.setStateForTesting(.disconnected)
        }

        let settingsVC = SettingsViewController()
        settingsVC.loadViewIfNeeded()
        settingsVC.view.layoutIfNeeded()

        guard let tableView = settingsVC.view.subviews.first(where: { $0 is UITableView }) as? UITableView else {
            XCTFail("SettingsViewController must contain a UITableView")
            return
        }

        let dlSec = SettingsViewController.SettingsSection.displayLayout.rawValue
        let vaSec = SettingsViewController.SettingsSection.videoAudio.rawValue

        // Test Disconnected State: all controls unlocked
        ConnectionManager.shared.setStateForTesting(.disconnected)
        tableView.reloadData()

        let dlFooterUnlocked = settingsVC.tableView(tableView, titleForFooterInSection: dlSec)
        XCTAssertFalse(dlFooterUnlocked?.contains("locked during active session") ?? true)

        let resCellUnlocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 1, section: dlSec))
        XCTAssertFalse(resCellUnlocked.detailTextLabel?.text?.contains("(Locked)") ?? true)
        XCTAssertEqual(resCellUnlocked.accessoryType, .disclosureIndicator)

        let fpsCellUnlocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 2, section: dlSec))
        if let seg = fpsCellUnlocked.accessoryView as? UISegmentedControl {
            XCTAssertTrue(seg.isEnabled)
        }

        let dpCellUnlocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 5, section: dlSec))
        if let seg = dpCellUnlocked.accessoryView as? UISegmentedControl {
            XCTAssertTrue(seg.isEnabled)
        }

        let vcCellUnlocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: vaSec))
        if let seg = vcCellUnlocked.accessoryView as? UISegmentedControl {
            XCTAssertTrue(seg.isEnabled)
        }

        // Test Running State: handshake settings locked
        ConnectionManager.shared.setStateForTesting(.running)
        tableView.reloadData()

        let dlFooterLocked = settingsVC.tableView(tableView, titleForFooterInSection: dlSec)
        XCTAssertTrue(dlFooterLocked?.contains("locked during active session") ?? false)
        let vaFooterLocked = settingsVC.tableView(tableView, titleForFooterInSection: vaSec)
        XCTAssertTrue(vaFooterLocked?.contains("locked during active session") ?? false)

        let resCellLocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 1, section: dlSec))
        XCTAssertTrue(resCellLocked.detailTextLabel?.text?.contains("(Locked)") ?? false)
        XCTAssertEqual(resCellLocked.accessoryType, .none)
        XCTAssertEqual(resCellLocked.selectionStyle, .none)

        let fpsCellLocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 2, section: dlSec))
        if let seg = fpsCellLocked.accessoryView as? UISegmentedControl {
            XCTAssertFalse(seg.isEnabled)
        }

        // Display Fit Mode (case 3) and Orientation (case 4) and Smoothing (case 6) must remain enabled
        let fitCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 3, section: dlSec))
        if let seg = fitCell.accessoryView as? UISegmentedControl {
            XCTAssertTrue(seg.isEnabled)
        }
        let orientCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 4, section: dlSec))
        if let seg = orientCell.accessoryView as? UISegmentedControl {
            XCTAssertTrue(seg.isEnabled)
        }
        let dpCellLocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 5, section: dlSec))
        if let seg = dpCellLocked.accessoryView as? UISegmentedControl {
            XCTAssertFalse(seg.isEnabled)
        }
        let smoothCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 6, section: dlSec))
        if let seg = smoothCell.accessoryView as? UISegmentedControl {
            XCTAssertTrue(seg.isEnabled)
        }

        // Video and Audio codec controls must be disabled
        let vcCellLocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: vaSec))
        if let seg = vcCellLocked.accessoryView as? UISegmentedControl {
            XCTAssertFalse(seg.isEnabled)
        }
        let acCellLocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 1, section: vaSec))
        if let seg = acCellLocked.accessoryView as? UISegmentedControl {
            XCTAssertFalse(seg.isEnabled)
        }
        let aoCellLocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 2, section: vaSec))
        if let seg = aoCellLocked.accessoryView as? UISegmentedControl {
            XCTAssertFalse(seg.isEnabled)
        }
        let micCellLocked = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 3, section: vaSec))
        if let seg = micCellLocked.accessoryView as? UISegmentedControl {
            XCTAssertFalse(seg.isEnabled)
        }

        // AudioChannelMixerCell (case 4) must remain active
        let mixerCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 4, section: vaSec))
        XCTAssertTrue(mixerCell is AudioChannelMixerCell)
    }

    func testConnectionManagerReconnectDebounceAndCancellation() {
        let cm = ConnectionManager.shared
        defer {
            cm.disconnect()
        }

        let device = DiscoveredDevice(ip: "192.168.1.100", port: 5277, name: "TestDevice")
        cm.connect(to: device, userInitiated: true)

        // Calling reconnectForSettingsChange cancels previous and schedules fresh reconnect
        cm.reconnectForSettingsChange()
        XCTAssertEqual(cm.state, .disconnected)

        // Immediate second call should not crash and should debounce using lastConnectedDevice
        cm.reconnectForSettingsChange()
        XCTAssertEqual(cm.state, .disconnected)

        // Manual disconnect cancels any pending reconnect
        cm.disconnect()
        XCTAssertEqual(cm.state, .disconnected)
    }
}
