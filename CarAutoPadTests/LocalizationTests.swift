import XCTest
import UIKit
@testable import CarAutoPad

final class LocalizationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        L10n.testOverrideLanguage = nil
        ProjectionSettings.resetToDefaults()
        ConnectionManager.shared.setStateForTesting(.disconnected)
        ConnectionManager.shared.setStatusKindForTesting(.ready)
    }

    override func tearDown() {
        L10n.testOverrideLanguage = nil
        ProjectionSettings.resetToDefaults()
        ConnectionManager.shared.setStateForTesting(.disconnected)
        ConnectionManager.shared.setStatusKindForTesting(.ready)
        super.tearDown()
    }

    private func containsView(withAccessibilityIdentifier identifier: String, in root: UIView) -> Bool {
        if root.accessibilityIdentifier == identifier {
            return true
        }
        return root.subviews.contains { containsView(withAccessibilityIdentifier: identifier, in: $0) }
    }

    func testResolveSystemLanguageFromPreferredLanguages() {
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-Hans-MY"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-Hans-MY", "en-MY"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-SG"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-Hant-TW"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-HK"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["zh-MO"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["yue-Hant-HK"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["yue-HK"]), .traditionalChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["yue-Hans-CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ja-JP"]), .japanese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ja-MY", "en-MY"]), .japanese)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ms-MY"]), .malay)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["id-ID"]), .malay)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ko-KR"]), .korean)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ko-KR", "en-US"]), .korean)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ko"]), .korean)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ta-MY"]), .tamil)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ta-MY", "en-MY"]), .tamil)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ta-SG"]), .tamil)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["ta-IN"]), .tamil)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["en-US"]), .english)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: []), .english)
        XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: ["fr-FR", "ja-JP"]), .japanese)
    }

    func testSystemLanguageDefaultsToEnglishInUnitTestsAndBadgeTitles() {
        XCTAssertNil(L10n.testOverrideLanguage)
        XCTAssertEqual(L10n.current, .english)
        XCTAssertEqual(AppLanguage.system.resolved, .english)
        XCTAssertFalse(AppLanguage.currentSystemPreferredLanguages().isEmpty)
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
        L10n.testOverrideLanguage = .simplifiedChinese
        XCTAssertEqual(L10n.current, .simplifiedChinese)
        XCTAssertEqual(ProjectionSettings.driverPositionTitle, "左舵驾驶 (LHD)")
        XCTAssertEqual(ResolutionPreset.auto.title, "自动（适配 iPad 原生）")
        XCTAssertEqual(VideoFitMode.contain.title, "适应（保留黑边）")
        XCTAssertEqual(ConnectionIssue.wifiRadioOff.title, "搜索失败：未连接 Wi-Fi / 手机热点")
        XCTAssertEqual(DebugLogCategory.connectionHandshake.title, "连接、握手与生命周期")
        XCTAssertEqual(MicrophoneSource.ipad.title, "iPad 麦克风")

        L10n.testOverrideLanguage = .traditionalChinese
        XCTAssertEqual(L10n.current, .traditionalChinese)
        XCTAssertEqual(L10n.settingsButtonTitle, "設定")
        XCTAssertEqual(NightModeSetting.twilight.shortTitle, "晨昏")

        L10n.testOverrideLanguage = .japanese
        XCTAssertEqual(L10n.current, .japanese)
        XCTAssertEqual(L10n.settingsButtonTitle, "設定")
        XCTAssertEqual(AudioOutputTarget.phone.title, "スマートフォン（車載BT・端末側）")

        L10n.testOverrideLanguage = .malay
        XCTAssertEqual(L10n.current, .malay)
        XCTAssertEqual(L10n.settingsButtonTitle, "Tetapan")
        XCTAssertEqual(NavigationDuckingPreset.off.shortTitle, "Mati (0%)")

        L10n.testOverrideLanguage = .korean
        XCTAssertEqual(L10n.current, .korean)
        XCTAssertEqual(L10n.settingsButtonTitle, "설정")
        XCTAssertEqual(L10n.systemDefaultLanguageTitle, "시스템 기본값")
        XCTAssertEqual(AppLanguage.system.title, "시스템 기본값")
        XCTAssertEqual(ProjectionSettings.driverPositionTitle, "좌핸들 (LHD)")
        XCTAssertEqual(MicrophoneSource.ipad.title, "iPad 마이크")
        XCTAssertEqual(NightModeSetting.twilight.shortTitle, "일출몰")

        L10n.testOverrideLanguage = .tamil
        XCTAssertEqual(L10n.current, .tamil)
        XCTAssertEqual(L10n.settingsButtonTitle, "அமைப்புகள்")
        XCTAssertEqual(L10n.systemDefaultLanguageTitle, "கணினி இயல்புநிலை")
        XCTAssertEqual(AppLanguage.system.title, "கணினி இயல்புநிலை")
        XCTAssertEqual(ProjectionSettings.driverPositionTitle, "இடது கை ஓட்டுநர் (LHD)")
        XCTAssertEqual(MicrophoneSource.ipad.title, "iPad ஒலிவாங்கி")
        XCTAssertEqual(NightModeSetting.twilight.shortTitle, "அந்தி")
        XCTAssertEqual(MotionBlurMode.light.shortTitle, "மென்")

        L10n.testOverrideLanguage = .english
        XCTAssertEqual(L10n.current, .english)
        XCTAssertEqual(L10n.settingsButtonTitle, "Settings")
    }

    func testLanguageChangePostsNotification() {
        let expectation = expectation(forNotification: .appLanguageDidChange, object: nil) { note in
            return (note.object as? AppLanguage) == .japanese
        }
        L10n.testOverrideLanguage = .japanese
        wait(for: [expectation], timeout: 1.0)
    }

    func testRefreshSystemLanguageOnForegroundClearsLegacyKeyAndPostsNotification() {
        UserDefaults.standard.set("ja", forKey: "projection-app-language")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "projection-app-language"), "ja")
        let expectation = expectation(forNotification: .appLanguageDidChange, object: nil)
        L10n.refreshSystemLanguageOnForeground()
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNil(UserDefaults.standard.object(forKey: "projection-app-language"))
    }

    func testCurrentSystemPreferredLanguagesReadsCFPreferencesAppleLanguages() {
        let key = "AppleLanguages" as CFString
        let previousAppValue = CFPreferencesCopyValue(key, kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        defer {
            CFPreferencesSetValue(key, previousAppValue, kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            CFPreferencesSynchronize(kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }

        let cases: [([String], AppLanguage)] = [
            (["ja-MY", "en-MY"], .japanese),
            (["ko-KR", "en-US"], .korean),
            (["ta-MY", "en-MY"], .tamil),
            (["zh-Hans-MY", "en-MY"], .simplifiedChinese)
        ]

        for (languages, expected) in cases {
            CFPreferencesSetValue(key, languages as CFArray, kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            CFPreferencesSynchronize(kCFPreferencesCurrentApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)

            let merged = AppLanguage.currentSystemPreferredLanguages()
            XCTAssertEqual(Array(merged.prefix(languages.count)), languages)
            XCTAssertEqual(AppLanguage.resolveSystemLanguage(from: merged), expected)
        }
    }

    func testSettingsBackupManagerRoundTripAndLegacyCompatForLanguage() throws {
        L10n.testOverrideLanguage = .japanese
        let json = SettingsBackupManager.exportToJson()
        XCTAssertFalse(json.contains("appLanguage"))

        UserDefaults.standard.set("ja", forKey: "projection-app-language")
        SettingsBackupManager.resetToDefaults()
        XCTAssertNil(UserDefaults.standard.object(forKey: "projection-app-language"))
        XCTAssertNil(L10n.testOverrideLanguage)
        XCTAssertEqual(L10n.current, .english)

        let count = try SettingsBackupManager.importFromJson(json)
        XCTAssertEqual(count, 14)

        let legacyJson = """
        {
          "exportedAt" : "2026-10-17T00:00:00Z",
          "format" : "carautopad-settings",
          "settings" : {
            "appLanguage" : "ja",
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
        XCTAssertEqual(L10n.current, .english)
    }

    @MainActor
    func testMainViewControllerLiveLanguageSwitchingAndWarningStatusColor() {
        let mainVC = MainViewController()
        mainVC.loadViewIfNeeded()
        mainVC.view.layoutIfNeeded()

        XCTAssertFalse(containsView(withAccessibilityIdentifier: "languageButton", in: mainVC.view))
        if let rightHeaderStack = mainVC.settingsButton.superview as? UIStackView {
            XCTAssertEqual(rightHeaderStack.arrangedSubviews.count, 2)
            XCTAssertTrue(mainVC.statusDotView.isDescendant(of: rightHeaderStack.arrangedSubviews[0]))
            XCTAssertTrue(rightHeaderStack.arrangedSubviews.last === mainVC.settingsButton)
        } else {
            XCTFail("Expected settingsButton to live inside rightHeaderStack")
        }
        XCTAssertEqual(mainVC.guideStepsStack.arrangedSubviews.count, 4)

        // Switch to Simplified Chinese live
        L10n.testOverrideLanguage = .simplifiedChinese
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
        L10n.testOverrideLanguage = .traditionalChinese
        XCTAssertEqual(mainVC.settingsButton.configuration?.title, "設定")

        L10n.testOverrideLanguage = .japanese
        XCTAssertEqual(mainVC.settingsButton.configuration?.title, "設定")
        XCTAssertEqual(mainVC.statusDotView.backgroundColor, .systemOrange)

        L10n.testOverrideLanguage = .malay
        XCTAssertEqual(mainVC.settingsButton.configuration?.title, "Tetapan")

        L10n.testOverrideLanguage = .korean
        XCTAssertEqual(mainVC.settingsButton.configuration?.title, "설정")
        XCTAssertEqual(mainVC.hubTitleLabel.text, "무선 연결 허브")
        XCTAssertEqual(mainVC.guideTitleLabel.text, "Android 휴대폰 설정 가이드")
        XCTAssertEqual(mainVC.guideStepsStack.arrangedSubviews.count, 4)

        L10n.testOverrideLanguage = .tamil
        XCTAssertEqual(mainVC.settingsButton.configuration?.title, "அமைப்புகள்")
        XCTAssertEqual(mainVC.hubTitleLabel.text, "வயர்லெஸ் இணைப்பு மையம்")
        XCTAssertEqual(mainVC.guideTitleLabel.text, "Android தொலைபேசி அமைப்பு வழிகாட்டி")
        XCTAssertEqual(mainVC.guideStepsStack.arrangedSubviews.count, 4)

        // Verify live switching while running does NOT disconnect session
        ConnectionManager.shared.setStateForTesting(.running)
        L10n.testOverrideLanguage = .english
        XCTAssertEqual(ConnectionManager.shared.state, .running)
        XCTAssertEqual(mainVC.settingsButton.configuration?.title, "Settings")
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
        L10n.testOverrideLanguage = .simplifiedChinese

        XCTAssertEqual(settingsVC.title, "投屏设置")
        let langCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 2, section: smartSec))
        XCTAssertEqual(langCell.textLabel?.text, "界面语言")
        XCTAssertEqual(langCell.detailTextLabel?.text, L10n.current.title)
        XCTAssertEqual(langCell.detailTextLabel?.text, "简体中文")
        XCTAssertEqual(langCell.accessoryType, .disclosureIndicator)
        XCTAssertEqual(langCell.selectionStyle, .default)

        L10n.testOverrideLanguage = .english
        XCTAssertEqual(settingsVC.title, "Projection Settings")
        let langCellEn = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 2, section: smartSec))
        XCTAssertEqual(langCellEn.textLabel?.text, "Language")
        XCTAssertEqual(langCellEn.detailTextLabel?.text, L10n.current.title)
        XCTAssertEqual(langCellEn.detailTextLabel?.text, "English")

        var openedUrl: URL?
        settingsVC.openSettingsUrlHandler = { url in
            openedUrl = url
        }
        settingsVC.tableView(tableView, didSelectRowAt: IndexPath(row: 2, section: smartSec))
        XCTAssertEqual(openedUrl?.absoluteString, UIApplication.openSettingsURLString)
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

        L10n.testOverrideLanguage = .japanese
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

        L10n.testOverrideLanguage = .simplifiedChinese
        XCTAssertEqual(layoutVC.title, L10n.layoutDpiModalTitle)
        XCTAssertEqual(audioVC.title, L10n.audioDuckingModalTitle)
        XCTAssertEqual(logCatsVC.title, L10n.debugLogCategoriesTitle)
        XCTAssertEqual(logCatsVC.navigationItem.rightBarButtonItem?.title, L10n.enableAll)

        let catCell = logCatsVC.tableView(logCatsVC.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(catCell.textLabel?.text?.contains(DebugLogCategory.connectionHandshake.title) ?? false)
        XCTAssertEqual(catCell.detailTextLabel?.text, DebugLogCategory.connectionHandshake.subtitle)

        L10n.testOverrideLanguage = .malay
        XCTAssertEqual(layoutVC.title, "Konfigurasi Susun Atur & DPI")
        XCTAssertEqual(audioVC.title, "Konfigurasi Audio & Pengurangan")
        XCTAssertEqual(logCatsVC.title, "Kategori Log Nyahpepijat")
        XCTAssertEqual(logCatsVC.navigationItem.rightBarButtonItem?.title, "Aktifkan Semua")
    }

    func testConnectionStatusKindLocalizedTextAllCases() {
        L10n.testOverrideLanguage = .simplifiedChinese
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
            L10n.testOverrideLanguage = lang

            XCTAssertFalse(lang.title.isEmpty)
            XCTAssertFalse(lang.shortBadgeTitle.isEmpty)

            // MainViewController checks
            XCTAssertFalse(containsView(withAccessibilityIdentifier: "languageButton", in: mainVC.view))
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
            XCTAssertEqual(langCell.detailTextLabel?.text, L10n.current.title)
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

            XCTAssertTrue(mainVC.quickSpecsHeaderLabel.adjustsFontSizeToFitWidth)
        }

        // Verify Tamil layout bounds & truncation hardening in narrow formSheet / portrait widths
        L10n.testOverrideLanguage = .tamil
        let dpiCell = DpiPreviewCell(style: .default, reuseIdentifier: nil)
        dpiCell.frame = CGRect(x: 0, y: 0, width: 480, height: 420)
        dpiCell.configure(with: HeadUnitScreenConfig.shared, isLocked: false)
        dpiCell.layoutIfNeeded()
        let dpiLabels = dpiCell.contentView.subviews.compactMap { $0 as? UILabel }
        XCTAssertEqual(dpiLabels.count, 2)
        XCTAssertTrue(dpiLabels.allSatisfy { $0.adjustsFontSizeToFitWidth })
        if let autoSwitch = dpiCell.contentView.subviews.first(where: { $0 is UISwitch }),
           let autoLabel = dpiLabels.first(where: { $0.text == L10n.autoDpiRecommended }) {
            XCTAssertLessThanOrEqual(autoLabel.frame.maxX, autoSwitch.frame.minX)
        } else {
            XCTFail("Expected autoDpiLabel and autoDpiSwitch in DpiPreviewCell")
        }

        let mixerCell = AudioChannelMixerCell(style: .default, reuseIdentifier: nil)
        mixerCell.frame = CGRect(x: 0, y: 0, width: 480, height: 460)
        mixerCell.layoutIfNeeded()
        func findButtons(in root: UIView) -> [UIButton] {
            var res: [UIButton] = []
            for v in root.subviews {
                if let b = v as? UIButton { res.append(b) }
                res.append(contentsOf: findButtons(in: v))
            }
            return res
        }
        let mixerPresetBtns = findButtons(in: mixerCell.contentView).filter {
            $0.configuration?.title == L10n.duckingOffShort
        }
        XCTAssertEqual(mixerPresetBtns.count, 1)
        XCTAssertEqual(mixerPresetBtns.first?.configuration?.titleLineBreakMode, .byClipping)
        XCTAssertTrue(mixerPresetBtns.first?.titleLabel?.adjustsFontSizeToFitWidth ?? false)

        let logCatsVC = DebugLogCategoriesViewController()
        logCatsVC.loadViewIfNeeded()
        let logCatCell = logCatsVC.tableView(logCatsVC.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(logCatCell.textLabel?.adjustsFontSizeToFitWidth ?? false)

        // Verify SettingsViewController locked state in Korean and Tamil
        ConnectionManager.shared.setStateForTesting(.running)
        for lang in [AppLanguage.korean, AppLanguage.tamil] {
            L10n.testOverrideLanguage = lang
            let activeCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: SettingsViewController.SettingsSection.activeSession.rawValue))
            XCTAssertEqual(activeCell.textLabel?.text, L10n.connectedDeviceRow)
            let resCell = settingsVC.tableView(tableView, cellForRowAt: IndexPath(row: 1, section: displaySec))
            XCTAssertEqual(resCell.detailTextLabel?.text, L10n.lockedSuffix(ProjectionSettings.resolution.title))
        }
        ConnectionManager.shared.setStateForTesting(.disconnected)

        // Verify JSON backup does not include appLanguage and remains valid across languages
        for lang in [AppLanguage.korean, AppLanguage.tamil] {
            L10n.testOverrideLanguage = lang
            let json = SettingsBackupManager.exportToJson()
            XCTAssertFalse(json.contains("appLanguage"))
            ProjectionSettings.resetToDefaults()
            let count = try SettingsBackupManager.importFromJson(json)
            XCTAssertEqual(count, 14)
            XCTAssertEqual(L10n.current, .english)
        }
    }
}
