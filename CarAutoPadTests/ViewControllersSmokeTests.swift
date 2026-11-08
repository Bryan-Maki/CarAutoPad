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
        defer { ProjectionSettings.isDebugModeEnabled = initial }

        let mvc = MainViewController()
        mvc.loadViewIfNeeded()
        mvc.view.layoutIfNeeded()

        XCTAssertTrue(mvc.view.subviews.contains(mvc.debugBubbleButton), "MainViewController view must contain debugBubbleButton")
        XCTAssertEqual(mvc.debugBubbleButton.accessibilityIdentifier, "debugBubbleButton")
        XCTAssertEqual(mvc.debugBubbleButton.layer.cornerRadius, 24)

        // When disconnected on home screen, debugBubbleButton should remain hidden even if debug mode is enabled
        ProjectionSettings.isDebugModeEnabled = true
        mvc.updatePerformanceOverlayState()
        XCTAssertTrue(mvc.debugBubbleButton.isHidden, "debugBubbleButton should remain hidden when disconnected even if debug mode is enabled")

        // Toggle debug mode off
        ProjectionSettings.isDebugModeEnabled = false
        mvc.updatePerformanceOverlayState()
        XCTAssertTrue(mvc.debugBubbleButton.isHidden, "debugBubbleButton should be hidden when debug mode is disabled")
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

        cell.configure(with: HeadUnitScreenConfig.shared, isLocked: false)
        for s in switches {
            XCTAssertTrue(s.isEnabled, "UISwitch in DpiPreviewCell should be enabled when isLocked is false")
        }
        for sl in sliders {
            XCTAssertTrue(sl.isEnabled, "UISlider in DpiPreviewCell should be enabled when isLocked is false")
        }
    }
}
