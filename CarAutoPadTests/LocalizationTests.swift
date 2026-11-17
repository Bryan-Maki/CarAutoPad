import XCTest
import UIKit
@testable import CarAutoPad

final class LocalizationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ProjectionSettings.resetToDefaults()
        ConnectionManager.shared.setStateForTesting(.disconnected)
        ConnectionManager.shared.setStatusKindForTesting(.ready)
    }

    override func tearDown() {
        ProjectionSettings.resetToDefaults()
        ConnectionManager.shared.setStateForTesting(.disconnected)
        ConnectionManager.shared.setStatusKindForTesting(.ready)
        super.tearDown()
    }

    func testResolveSystemLanguageFromPreferredLanguages() {
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-Hans-MY"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-SG"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-Hant-TW"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-HK"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-MO"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["yue-Hant-HK"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["yue-HK"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["yue-Hans-CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ja-JP"]), .japanese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ms-MY"]), .malay)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["id-ID"]), .malay)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ko-KR"]), .korean)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ko"]), .korean)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ta-MY"]), .tamil)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ta-SG"]), .tamil)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ta-IN"]), .tamil)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["en-US"]), .english)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: []), .english)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["fr-FR", "ja-JP"]), .japanese)
    }

    func testSystemLanguageDefaultsToEnglishInUnitTestsAndBadgeTitles() {
        XCTAssertEqual(ProjectionSettings.appLanguage, .system)
        XCTAssertEqual(AppLanguage.system.resolved, .english)
        XCTAssertEqual(AppLanguage.english.shortBadgeTitle, "EN")
        XCTAssertEqual(AppLanguage.simplifiedChinese.shortBadgeTitle, "简")
        XCTAssertEqual(AppLanguage.traditionalChinese.shortBadgeTitle, "繁")
        XCTAssertEqual(AppLanguage.japanese.shortBadgeTitle, "JA")
        XCTAssertEqual(AppLanguage.malay.shortBadgeTitle, "MS")
        XCTAssertEqual(AppLanguage.korean.shortBadgeTitle, "KO")
        XCTAssertEqual(AppLanguage.tamil.shortBadgeTitle, "TA")
        XCTAssertEqual(AppLanguage.korean.title, "한국어")
        XCTAssertEqual(AppLanguage.tamil.title, "தமிழ்")
    }

    func testExplicitLanguageSwitchingUpdatesL10nAndEnums() {
        ProjectionSettings.appLanguage = .simplifiedChinese
        XCTAssertEqual(L10n.current, .simplifiedChinese)
        XCTAssertEqual(ProjectionSettings.driverPositionTitle, "左舵驾驶 (LHD)")
        XCTAssertEqual(ResolutionPreset.auto.title, "自动（适配 iPad 原生）")
        XCTAssertEqual(VideoFitMode.contain.title, "适应（保留黑边）")
        XCTAssertEqual(ConnectionIssue.wifiRadioOff.title, "搜索失败：未连接 Wi-Fi / 手机热点")
        XCTAssertEqual(DebugLogCategory.connectionHandshake.title, "连接、握手与生命周期")
        XCTAssertEqual(MicrophoneSource.ipad.title, "iPad 麦克风")

        ProjectionSettings.appLanguage = .traditionalChinese
        XCTAssertEqual(L10n.current, .traditionalChinese)
        XCTAssertEqual(L10n.settingsButtonTitle, "設定")
        XCTAssertEqual(NightModeSetting.twilight.shortTitle, "晨昏")

        ProjectionSettings.appLanguage = .japanese
        XCTAssertEqual(L10n.current, .japanese)
        XCTAssertEqual(L10n.settingsButtonTitle, "設定")
        XCTAssertEqual(AudioOutputTarget.phone.title, "スマートフォン（車載BT・端末側）")

        ProjectionSettings.appLanguage = .malay
        XCTAssertEqual(L10n.current, .malay)
        XCTAssertEqual(L10n.settingsButtonTitle, "Tetapan")
        XCTAssertEqual(NavigationDuckingPreset.off.shortTitle, "Mati (0%)")

        ProjectionSettings.appLanguage = .korean
        XCTAssertEqual(L10n.current, .korean)
        XCTAssertEqual(L10n.settingsButtonTitle, "설정")
        XCTAssertEqual(L10n.systemDefaultLanguageTitle, "시스템 기본값")
        XCTAssertEqual(AppLanguage.system.title, "시스템 기본값")
        XCTAssertEqual(ProjectionSettings.driverPositionTitle, "좌핸들 (LHD)")
        XCTAssertEqual(MicrophoneSource.ipad.title, "iPad 마이크")
        XCTAssertEqual(NightModeSetting.twilight.shortTitle, "일출몰")

        ProjectionSettings.appLanguage = .tamil
        XCTAssertEqual(L10n.current, .tamil)
        XCTAssertEqual(L10n.settingsButtonTitle, "அமைப்புகள்")
        XCTAssertEqual(L10n.systemDefaultLanguageTitle, "கணினி இயல்புநிலை")
        XCTAssertEqual(AppLanguage.system.title, "கணினி இயல்புநிலை")
        XCTAssertEqual(ProjectionSettings.driverPositionTitle, "இடது கை ஓட்டுநர் (LHD)")
        XCTAssertEqual(MicrophoneSource.ipad.title, "iPad ஒலிவாங்கி")
        XCTAssertEqual(NightModeSetting.twilight.shortTitle, "அந்தி")

        ProjectionSettings.appLanguage = .english
        XCTAssertEqual(L10n.current, .english)
        XCTAssertEqual(L10n.settingsButtonTitle, "Settings")
    }

    func testLanguageChangePostsNotification() {
        let expectation = expectation(forNotification: .appLanguageDidChange, object: nil) { note in
            return (note.object as? AppLanguage) == .japanese
        }
        ProjectionSettings.appLanguage = .japanese
        wait(for: [expectation], timeout: 1.0)
    }

    func testSettingsBackupManagerRoundTripAndLegacyCompatForLanguage() throws {
        ProjectionSettings.appLanguage = .japanese
        let json = SettingsBackupManager.exportToJson()
        XCTAssertTrue(json.contains("\"appLanguage\" : \"ja\""))

        ProjectionSettings.resetToDefaults()
        XCTAssertEqual(ProjectionSettings.appLanguage, .system)

        let count = try SettingsBackupManager.importFromJson(json)
        XCTAssertEqual(count, 14)
        XCTAssertEqual(ProjectionSettings.appLanguage, .japanese)

        let legacyJson = """
        {
          "exportedAt" : "2026-10-17T00:00:00Z",
          "format" : "carautopad-settings",
          "settings" : {
            "audioCodecPreference" : 1,
            "audioOutputTarget" : 0,
            "autoReconnect" : true,
            "autoResumePlayback" : true,
            "dpi" : 160,
            "fitMode" : 3,
            "fpsLimit" : 1,
            "gpsSource" : 0,
            "nightMode" : 0,
            "orientation" : 2,
            "resolution" : 0,
            "rightHandDrive" : false,
            "showPerformanceOverlay" : false,
            "videoCodecPreference" : "h264"
          },
          "version" : 1
        }
        """
        let legacyCount = try SettingsBackupManager.importFromJson(legacyJson)
        XCTAssertEqual(legacyCount, 14)
        XCTAssertEqual(ProjectionSettings.appLanguage, .japanese)
    }

    @MainActor
    func testMainViewControllerLiveLanguageSwitchingAndWarningStatusColor() {
        let mainVC = MainViewController()
        mainVC.loadViewIfNeeded()
        mainVC.view.layoutIfNeeded()

        XCTAssertEqual(mainVC.languageButton.accessibilityIdentifier, "languageButton")
        XCTAssertEqual(mainVC.languageButton.configuration?.title, "EN")
        XCTAssertEqual(mainVC.guideStepsStack.arrangedSubviews.count, 4)

        // Switch to Simplified Chinese live
        ProjectionSettings.appLanguage = .simplifiedChinese
        XCTAssertEqual(mainVC.languageButton.configuration?.title, "简")
        XCTAssertEqual(mainVC.settingsButton.configuration?.title, "设置")
        XCTAssertEqual(mainVC.hubTitleLabel.text, "无线连接中心")
        XCTAssertEqual(mainVC.guideTitleLabel.text, "安卓手机开启指南")
        XCTAssertEqual(mainVC.guideStepsStack.arrangedSubviews.count, 4)

        // Verify disconnected warning uses strong-typed statusKind instead of English substring matching
        ConnectionManager.shared.setStatusKindForTesting(.noDeviceFound)
        XCTAssertTrue(ConnectionManager.shared.statusKind.isDisconnectedWarning)
        mainVC.applyLocalization()
        XCTAssertEqual(mainVC.statusDotView.backgroundColor, .systemOrange)
        XCTAssertEqual(mainVC.statusLabel.textColor, .systemOrange)
        XCTAssertEqual(mainVC.statusLabel.text, L10n.statusNoDeviceFound)

        // Verify Traditional Chinese, Japanese, Malay
        ProjectionSettings.appLanguage = .traditionalChinese
        XCTAssertEqual(mainVC.languageButton.configuration?.title, "繁")
        XCTAssertEqual(mainVC.settingsButton.configuration?.title, "設定")

        ProjectionSettings.appLanguage = .japanese
        XCTAssertEqual(mainVC.languageButton.configuration?.title, "JA")
        XCTAssertEqual(mainVC.statusDotView.backgroundColor, .systemOrange)

        ProjectionSettings.appLanguage = .malay
        XCTAssertEqual(mainVC.languageButton.configuration?.title, "MS")
        XCTAssertEqual(mainVC.settingsButton.configuration?.title, "Tetapan")

        ProjectionSettings.appLanguage = .korean
        XCTAssertEqual(mainVC.languageButton.configuration?.title, "KO")
        XCTAssertEqual(mainVC.settingsButton.configuration?.title, "설정")
        XCTAssertEqual(mainVC.hubTitleLabel.text, "무선 연결 허브")
        XCTAssertEqual(mainVC.guideTitleLabel.text, "Android 휴대폰 설정 가이드")
        XCTAssertEqual(mainVC.guideStepsStack.arrangedSubviews.count, 4)

        ProjectionSettings.appLanguage = .tamil
        XCTAssertEqual(mainVC.languageButton.configuration?.title, "TA")
        XCTAssertEqual(mainVC.settingsButton.configuration?.title, "அமைப்புகள்")
        XCTAssertEqual(mainVC.hubTitleLabel.text, "வயர்லெஸ் இணைப்பு மையம்")
        XCTAssertEqual(mainVC.guideTitleLabel.text, "Android தொலைபேசி அமைப்பு வழிகாட்டி")
        XCTAssertEqual(mainVC.guideStepsStack.arrangedSubviews.count, 4)

        // Verify live switching while running does NOT disconnect session
        ConnectionManager.shared.setStateForTesting(.running)
        ProjectionSettings.appLanguage = .english
        XCTAssertEqual(ConnectionManager.shared.state, .running)
        XCTAssertEqual(mainVC.languageButton.configuration?.title, "EN")
    }

    @MainActor
    func testSettingsViewControllerLanguageRowAndLiveReload() {
        let settingsVC = SettingsViewController()
        settingsVC.loadViewIfNeeded()
        settingsVC.view.layoutIfNeeded()

        guard let tableView = settingsVC.view.subviews.first(where: { $0 is UITableView }) as? UITableView else {
            XCTFail("SettingsViewController must contain a UITableView")
            return
        }

        let smartSec = SettingsViewController.SettingsSection.smartSensors.rawValue
        XCTAssertEqual(settingsVC.tableView(tableView, numberOfRowsInSection: smartSec), 3)

        // Even while running, language row remains selectable and updated
        ConnectionManager.shared.setStateForTesting(.running)
        ProjectionSettings.appLanguage = .simplifiedChinese

        XCTAssertEqual(settingsVC.title, "投屏设置")
        let langCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 2, section: smartSec))
        XCTAssertEqual(langCell.textLabel?.text, "界面语言")
        XCTAssertEqual(langCell.detailTextLabel?.text, "简体中文")
        XCTAssertEqual(langCell.accessoryType, .disclosureIndicator)
        XCTAssertEqual(langCell.selectionStyle, .default)

        ProjectionSettings.appLanguage = .english
        XCTAssertEqual(settingsVC.title, "Projection Settings")
        let langCellEn = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 2, section: smartSec))
        XCTAssertEqual(langCellEn.textLabel?.text, "Language")
        XCTAssertEqual(langCellEn.detailTextLabel?.text, "English")
    }

    @MainActor
    func testDisconnectedFromSessionStatusPreservedAcrossLanguageSwitch() {
        let mainVC = MainViewController()
        mainVC.loadViewIfNeeded()
        mainVC.view.layoutIfNeeded()

        ConnectionManager.shared.setStateForTesting(.disconnected)
        ConnectionManager.shared.setStatusKindForTesting(.disconnectedFromSession)
        mainVC.applyLocalization()
        XCTAssertEqual(mainVC.statusLabel.text, L10n.statusDisconnectedFromSession)
        XCTAssertEqual(mainVC.statusDotView.backgroundColor, .systemGreen)

        ProjectionSettings.appLanguage = .japanese
        XCTAssertEqual(mainVC.statusLabel.text, L10n.statusDisconnectedFromSession)
        XCTAssertEqual(mainVC.statusLabel.text, "Android Auto が切断されました")
    }

    @MainActor
    func testQuickModalsAndDebugLogCategoriesLiveLanguageSwitching() {
        let layoutVC = QuickLayoutDpiViewController()
        layoutVC.loadViewIfNeeded()
        layoutVC.view.layoutIfNeeded()

        let audioVC = QuickAudioConfigViewController()
        audioVC.loadViewIfNeeded()
        audioVC.view.layoutIfNeeded()

        let logCatsVC = DebugLogCategoriesViewController()
        logCatsVC.loadViewIfNeeded()
        logCatsVC.view.layoutIfNeeded()

        ProjectionSettings.appLanguage = .simplifiedChinese
        XCTAssertEqual(layoutVC.title, L10n.layoutDpiModalTitle)
        XCTAssertEqual(audioVC.title, L10n.audioDuckingModalTitle)
        XCTAssertEqual(logCatsVC.title, L10n.debugLogCategoriesTitle)
        XCTAssertEqual(logCatsVC.navigationItem.rightBarButtonItem?.title, L10n.enableAll)

        let catCell = logCatsVC.tableView(logCatsVC.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(catCell.textLabel?.text?.contains(DebugLogCategory.connectionHandshake.title) ?? false)
        XCTAssertEqual(catCell.detailTextLabel?.text, DebugLogCategory.connectionHandshake.subtitle)

        ProjectionSettings.appLanguage = .malay
        XCTAssertEqual(layoutVC.title, "Konfigurasi Susun Atur & DPI")
        XCTAssertEqual(audioVC.title, "Konfigurasi Audio & Pengurangan")
        XCTAssertEqual(logCatsVC.title, "Kategori Log Nyahpepijat")
        XCTAssertEqual(logCatsVC.navigationItem.rightBarButtonItem?.title, "Aktifkan Semua")
    }

    func testConnectionStatusKindLocalizedTextAllCases() {
        ProjectionSettings.appLanguage = .simplifiedChinese
        let kinds: [ConnectionStatusKind] = [
            .ready,
            .searchFailedNoWifi,
            .scanning(stationIp: "192.168.43.5"),
            .connecting(deviceName: "Pixel 9"),
            .retrying(attempt: 2, maxAttempts: 3),
            .failedAfterRetries(maxAttempts: 3),
            .noDeviceFound,
            .searchFailed(reason: "timeout"),
            .waitingForHeadunitServer,
            .handshakingTls,
            .runningWireless,
            .disconnectedFromSession,
            .customError("custom")
        ]
        for kind in kinds {
            XCTAssertFalse(kind.localizedText.isEmpty)
        }
        XCTAssertTrue(ConnectionStatusKind.searchFailedNoWifi.isDisconnectedWarning)
        XCTAssertTrue(ConnectionStatusKind.noDeviceFound.isDisconnectedWarning)
        XCTAssertTrue(ConnectionStatusKind.searchFailed(reason: "x").isDisconnectedWarning)
        XCTAssertTrue(ConnectionStatusKind.failedAfterRetries(maxAttempts: 3).isDisconnectedWarning)
        XCTAssertFalse(ConnectionStatusKind.ready.isDisconnectedWarning)
        XCTAssertFalse(ConnectionStatusKind.disconnectedFromSession.isDisconnectedWarning)
    }

    @MainActor
    func testAllLanguagesLiveSwitchingAcrossControllersAndTruncationHardening() throws {
        let mainVC = MainViewController()
        mainVC.loadViewIfNeeded()
        mainVC.view.layoutIfNeeded()

        let settingsVC = SettingsViewController()
        settingsVC.loadViewIfNeeded()
        settingsVC.view.layoutIfNeeded()

        let layoutVC = QuickLayoutDpiViewController()
        layoutVC.loadViewIfNeeded()
        layoutVC.view.layoutIfNeeded()

        let audioVC = QuickAudioConfigViewController()
        audioVC.loadViewIfNeeded()
        audioVC.view.layoutIfNeeded()

        guard let tableView = settingsVC.view.subviews.first(where: { $0 is UITableView }) as? UITableView else {
            XCTFail("SettingsViewController must contain a UITableView")
            return
        }

        let smartSec = SettingsViewController.SettingsSection.smartSensors.rawValue
        let displaySec = SettingsViewController.SettingsSection.displayLayout.rawValue
        let audioSec = SettingsViewController.SettingsSection.videoAudio.rawValue

        for lang in AppLanguage.allCases {
            ProjectionSettings.appLanguage = lang

            XCTAssertFalse(lang.title.isEmpty)
            XCTAssertFalse(lang.shortBadgeTitle.isEmpty)

            // MainViewController checks
            XCTAssertEqual(mainVC.languageButton.configuration?.title, lang.shortBadgeTitle)
            XCTAssertEqual(mainVC.settingsButton.configuration?.title, L10n.settingsButtonTitle)
            XCTAssertFalse(mainVC.settingsButton.configuration?.title?.isEmpty ?? true)
            XCTAssertEqual(mainVC.hubTitleLabel.text, L10n.wirelessConnectionHub)
            XCTAssertFalse(mainVC.hubTitleLabel.text?.isEmpty ?? true)
            XCTAssertEqual(mainVC.guideTitleLabel.text, L10n.androidPhoneSetupGuide)
            XCTAssertFalse(mainVC.guideTitleLabel.text?.isEmpty ?? true)
            XCTAssertEqual(mainVC.directConnectButton.configuration?.title, L10n.directConnectButton)
            XCTAssertEqual(mainVC.connectButton.configuration?.title, L10n.scanForHeadunitServer)
            XCTAssertEqual(mainVC.guideStepsStack.arrangedSubviews.count, 4)

            // SettingsViewController checks + truncation hardening checks
            XCTAssertEqual(settingsVC.title, L10n.projectionSettingsTitle)
            XCTAssertFalse(settingsVC.title?.isEmpty ?? true)

            let langCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 2, section: smartSec))
            XCTAssertEqual(langCell.textLabel?.text, L10n.languageRowTitle)
            XCTAssertEqual(langCell.detailTextLabel?.text, lang.title)
            XCTAssertTrue(langCell.textLabel?.adjustsFontSizeToFitWidth ?? false)
            XCTAssertEqual(Double(langCell.textLabel?.minimumScaleFactor ?? 0), 0.75, accuracy: 0.001)

            let nightCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: smartSec))
            XCTAssertTrue(nightCell.textLabel?.adjustsFontSizeToFitWidth ?? false)
            if let seg = nightCell.accessoryView as? UISegmentedControl {
                XCTAssertTrue(seg.apportionsSegmentWidthsByContent)
            } else {
                XCTFail("Expected UISegmentedControl for nightModeRow")
            }

            let fitCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 3, section: displaySec))
            if let seg = fitCell.accessoryView as? UISegmentedControl {
                XCTAssertTrue(seg.apportionsSegmentWidthsByContent)
            } else {
                XCTFail("Expected UISegmentedControl for displayFitMode")
            }

            let micCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 3, section: audioSec))
            if let seg = micCell.accessoryView as? UISegmentedControl {
                XCTAssertTrue(seg.apportionsSegmentWidthsByContent)
            } else {
                XCTFail("Expected UISegmentedControl for microphoneSourceRow")
            }

            // QuickLayoutDpiViewController & QuickAudioConfigViewController checks
            XCTAssertEqual(layoutVC.title, L10n.layoutDpiModalTitle)
            XCTAssertFalse(layoutVC.title?.isEmpty ?? true)
            XCTAssertEqual(audioVC.title, L10n.audioDuckingModalTitle)
            XCTAssertFalse(audioVC.title?.isEmpty ?? true)
        }

        // Verify JSON backup round-trip for Korean and Tamil
        for lang in [AppLanguage.korean, AppLanguage.tamil] {
            ProjectionSettings.appLanguage = lang
            let json = SettingsBackupManager.exportToJson()
            XCTAssertTrue(json.contains("\"appLanguage\" : \"\(lang.rawValue)\""))
            ProjectionSettings.resetToDefaults()
            _ = try SettingsBackupManager.importFromJson(json)
            XCTAssertEqual(ProjectionSettings.appLanguage, lang)
        }
    }
}
