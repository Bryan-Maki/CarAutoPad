import UIKit
import AVFoundation
import CoreLocation

final class MainViewController: UIViewController {

    private let connectionManager = ConnectionManager.shared
    private let videoRenderer = H264VideoRendererView()
    private let audioPlayer = PCMAudioPlayer.shared
    private var videoWatchdogTimer: Timer?
    private var runningSinceTs: TimeInterval = 0
    private var lastVideoFrameTs: TimeInterval = 0
    private var hasReceivedFirstVideoFrame = false
    private var lastVideoRecoveryTs: TimeInterval = 0
    private var dismissedIssueEpochMs: Int64 = 0

    // MARK: - Fullscreen Active Projection Views (Direct Subviews Preserved for Touch & HUD Contracts)

    private let videoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let touchOverlayView: TouchInputView = {
        let view = TouchInputView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let performanceOverlayBlurView: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = false
        blur.layer.cornerRadius = 12
        blur.layer.cornerCurve = .continuous
        blur.clipsToBounds = true
        blur.isHidden = true
        return blur
    }()

    private let performanceOverlayView = PerformanceOverlayView()
    private var performanceTimer: Timer?

    // Liquid Glass Draggable Debug Bubble (Figma 10 — ZERO neon halo!)
    private var debugBubbleCenterXConstraint: NSLayoutConstraint?
    private var debugBubbleCenterYConstraint: NSLayoutConstraint?
    private var debugBubblePanStartCenter: CGPoint = .zero
    var isPanningDebugBubble = false
    private var debugBubbleSnappedToRight: Bool = true

    public private(set) lazy var debugBubbleButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "debugBubbleButton"
        button.layer.cornerRadius = 24
        button.layer.cornerCurve = .continuous
        button.layer.masksToBounds = false
        button.backgroundColor = UIColor(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0, alpha: 0.72)
        button.layer.borderWidth = 0.75
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.42
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        button.layer.shadowRadius = 14.0

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = false
        blur.layer.cornerRadius = 24
        blur.layer.cornerCurve = .continuous
        blur.clipsToBounds = true
        button.insertSubview(blur, at: 0)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: button.topAnchor),
            blur.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: button.trailingAnchor)
        ])

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)
        let icon = UIImage(systemName: "wrench.and.screwdriver", withConfiguration: symbolConfig)
        button.setImage(icon, for: .normal)
        button.tintColor = .white
        if let iv = button.imageView {
            button.bringSubviewToFront(iv)
        }
        button.isHidden = true

        button.addTarget(self, action: #selector(debugBubbleTapped), for: .touchUpInside)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDebugBubblePan(_:)))
        button.addGestureRecognizer(panGesture)
        return button
    }()

    private(set) var quickMenuOverlay: ProjectionQuickMenuView?

    // MARK: - iPadOS 27 Adaptive Split View Shell (Figma 01 - 09)

    private let appShellView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = CarAutoPadTheme.canvas
        return view
    }()

    let sidebarView: SidebarNavigationView = {
        let sb = SidebarNavigationView()
        sb.translatesAutoresizingMaskIntoConstraints = false
        return sb
    }()

    private let sidebarDividerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = CarAutoPadTheme.edgeDivider
        return v
    }()

    private let mainDetailColumn: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = CarAutoPadTheme.canvas
        return v
    }()

    // Portrait / Collapsed Sidebar Top Bar (Figma 03)
    let compactTopBarView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = CarAutoPadTheme.canvas
        v.isHidden = true
        return v
    }()

    let compactMenuButton: UIButton = CarAutoPadTheme.makeLiquidGlassCircleButton(
        symbolName: "sidebar.left",
        size: 38,
        pointSize: 16,
        accessibilityIdentifier: "compactMenuButton"
    )

    private let compactBrandLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = CarAutoPadDeviceInfo.appName
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .label
        return l
    }()

    private let compactIpPill: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = CarAutoPadTheme.card
        v.layer.cornerRadius = 15
        v.layer.cornerCurve = .continuous
        return v
    }()

    private let compactStatusDot: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 3.5
        v.backgroundColor = CarAutoPadTheme.accentGreen
        return v
    }()

    private let compactIpLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        l.textColor = .secondaryLabel
        return l
    }()

    private let detailContentContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = CarAutoPadTheme.canvas
        return v
    }()

    // Slide-over Drawer for Portrait / Collapsed Mode
    private let drawerOverlayView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let drawerScrimButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        return b
    }()

    private let drawerSidebarView: SidebarNavigationView = {
        let sb = SidebarNavigationView()
        sb.translatesAutoresizingMaskIntoConstraints = false
        sb.layer.shadowColor = UIColor.black.cgColor
        sb.layer.shadowOpacity = 0.45
        sb.layer.shadowOffset = CGSize(width: 8, height: 0)
        sb.layer.shadowRadius = 24
        return sb
    }()

    private var sidebarWidthConstraint: NSLayoutConstraint?
    private var compactTopBarHeightConstraint: NSLayoutConstraint?
    private var drawerLeadingConstraint: NSLayoutConstraint?
    private(set) var isSidebarCollapsed: Bool = false
    private(set) var selectedSidebarTab: AppSidebarTab = .wirelessConnection

    // Embedded Tab Child View Controllers
    let wirelessPanelVC = WirelessConnectionPanelViewController()
    let displayPanelVC = DisplayLayoutPanelViewController()
    let audioPanelVC = AudioMixerPanelViewController()
    let smartPanelVC = SmartLanguagePanelViewController()
    let aboutPanelVC = AboutAndDiagnosticsViewController()
    private var activePanelVC: UIViewController?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CarAutoPadTheme.canvas
        HeadUnitScreenConfig.shared.videoFitMode = ProjectionSettings.videoFitMode

        setupProjectionStage()
        setupAdaptiveShell()
        wireChildPanels()
        selectSidebarTab(.wirelessConnection)

        connectionManager.delegate = self
        Discovery.triggerLocalNetworkPermission()

        wireVideoAndGeometryCallbacks()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkReachabilityChanged(_:)),
            name: .carAutoPadNetworkReachabilityDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyLocalization),
            name: .appLanguageDidChange,
            object: nil
        )

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: MainViewController, _: UITraitCollection) in
            if self.connectionManager.state == .running && ProjectionSettings.nightMode == .system {
                self.connectionManager.updateNightMode(userInterfaceStyle: self.traitCollection.userInterfaceStyle, force: true)
            }
        }

        applyLocalization()
        updateUIForConnectionState(connectionManager.state)
        videoRenderer.motionBlurMode = ProjectionSettings.motionBlurMode
        syncVideoAndTouchGeometry()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        performanceTimer?.invalidate()
        videoWatchdogTimer?.invalidate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyOrientationLock()
        refreshAllPanels()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        touchOverlayView.frame = videoContainerView.bounds
        touchOverlayView.isUserInteractionEnabled = true

        updateSidebarPresentationMode()

        let screen = view.window?.screen ?? UIScreen.main
        let nativeScale = screen.nativeScale
        let w: Int
        let h: Int
        switch ProjectionSettings.orientation {
        case .landscape:
            w = Int((max(view.bounds.width, view.bounds.height) * nativeScale).rounded())
            h = Int((min(view.bounds.width, view.bounds.height) * nativeScale).rounded())
        case .portrait:
            w = Int((min(view.bounds.width, view.bounds.height) * nativeScale).rounded())
            h = Int((max(view.bounds.width, view.bounds.height) * nativeScale).rounded())
        case .system:
            w = Int((view.bounds.width * nativeScale).rounded())
            h = Int((view.bounds.height * nativeScale).rounded())
        }
        if w > 0 && h > 0 {
            _ = HeadUnitScreenConfig.shared.updateDimensions(width: w, height: h)
        }
        syncVideoAndTouchGeometry()
        if !videoContainerView.isHidden {
            videoContainerView.bringSubviewToFront(touchOverlayView)
            videoContainerView.bringSubviewToFront(performanceOverlayBlurView)
            videoContainerView.bringSubviewToFront(performanceOverlayView)
        }
        view.bringSubviewToFront(debugBubbleButton)
        if let menu = quickMenuOverlay {
            view.bringSubviewToFront(menu)
        }
        clampDebugBubbleToSafeBounds(animated: false)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }
            let scale = (self.view.window?.screen ?? UIScreen.main).nativeScale
            let w = Int((size.width * scale).rounded())
            let h = Int((size.height * scale).rounded())
            if w > 0 && h > 0 {
                _ = HeadUnitScreenConfig.shared.updateDimensions(width: w, height: h)
            }
            self.syncVideoAndTouchGeometry()
            self.videoRenderer.applyGeometry()
            self.updateSidebarPresentationMode(forWidth: size.width)
        }, completion: { [weak self] _ in
            guard let self = self else { return }
            let scale = (self.view.window?.screen ?? UIScreen.main).nativeScale
            let w = Int((self.view.bounds.width * scale).rounded())
            let h = Int((self.view.bounds.height * scale).rounded())
            if w > 0 && h > 0 {
                _ = HeadUnitScreenConfig.shared.updateDimensions(width: w, height: h)
            }
            self.syncVideoAndTouchGeometry()
            self.videoRenderer.applyGeometry()
            self.displayPanelVC.syncWithCurrentSettings()
        })
    }

    // MARK: - Setup Projection Stage & Adaptive Split View Shell

    private func setupProjectionStage() {
        view.addSubview(videoContainerView)

        videoRenderer.translatesAutoresizingMaskIntoConstraints = false
        videoContainerView.addSubview(videoRenderer)

        touchOverlayView.isMultipleTouchEnabled = true
        touchOverlayView.onTouchWithTimestamp = { [weak self] pointers, action, actionIndex, touchTs in
            self?.connectionManager.sendTouchEvent(
                pointers: pointers,
                action: action,
                actionIndex: actionIndex,
                touchTimestamp: touchTs
            )
        }
        videoContainerView.addSubview(touchOverlayView)

        performanceOverlayView.translatesAutoresizingMaskIntoConstraints = false
        performanceOverlayView.isHidden = true
        videoContainerView.addSubview(performanceOverlayBlurView)
        videoContainerView.addSubview(performanceOverlayView)

        view.addSubview(debugBubbleButton)

        let bubbleCenterX = debugBubbleButton.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: 40)
        let bubbleCenterY = debugBubbleButton.centerYAnchor.constraint(equalTo: view.topAnchor, constant: 140)
        debugBubbleCenterXConstraint = bubbleCenterX
        debugBubbleCenterYConstraint = bubbleCenterY

        NSLayoutConstraint.activate([
            videoContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            videoContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            videoContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            videoRenderer.topAnchor.constraint(equalTo: videoContainerView.topAnchor),
            videoRenderer.bottomAnchor.constraint(equalTo: videoContainerView.bottomAnchor),
            videoRenderer.leadingAnchor.constraint(equalTo: videoContainerView.leadingAnchor),
            videoRenderer.trailingAnchor.constraint(equalTo: videoContainerView.trailingAnchor),

            performanceOverlayView.topAnchor.constraint(equalTo: videoContainerView.safeAreaLayoutGuide.topAnchor, constant: 16),
            performanceOverlayView.leadingAnchor.constraint(equalTo: videoContainerView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            performanceOverlayBlurView.topAnchor.constraint(equalTo: performanceOverlayView.topAnchor),
            performanceOverlayBlurView.bottomAnchor.constraint(equalTo: performanceOverlayView.bottomAnchor),
            performanceOverlayBlurView.leadingAnchor.constraint(equalTo: performanceOverlayView.leadingAnchor),
            performanceOverlayBlurView.trailingAnchor.constraint(equalTo: performanceOverlayView.trailingAnchor),

            debugBubbleButton.widthAnchor.constraint(equalToConstant: 48),
            debugBubbleButton.heightAnchor.constraint(equalToConstant: 48),
            bubbleCenterX,
            bubbleCenterY
        ])
    }

    private func setupAdaptiveShell() {
        view.addSubview(appShellView)
        appShellView.addSubview(sidebarView)
        appShellView.addSubview(sidebarDividerView)
        appShellView.addSubview(mainDetailColumn)

        mainDetailColumn.addSubview(compactTopBarView)
        mainDetailColumn.addSubview(detailContentContainer)

        // Compact Top Bar (Portrait / Collapsed Sidebar)
        compactMenuButton.addTarget(self, action: #selector(compactMenuButtonTapped), for: .touchUpInside)
        let compactLeft = UIStackView(arrangedSubviews: [compactMenuButton, compactBrandLabel])
        compactLeft.axis = .horizontal
        compactLeft.spacing = 12
        compactLeft.alignment = .center

        let ipInner = UIStackView(arrangedSubviews: [compactStatusDot, compactIpLabel])
        ipInner.translatesAutoresizingMaskIntoConstraints = false
        ipInner.axis = .horizontal
        ipInner.spacing = 7
        ipInner.alignment = .center
        compactIpPill.addSubview(ipInner)
        NSLayoutConstraint.activate([
            compactStatusDot.widthAnchor.constraint(equalToConstant: 7),
            compactStatusDot.heightAnchor.constraint(equalToConstant: 7),
            ipInner.topAnchor.constraint(equalTo: compactIpPill.topAnchor, constant: 7),
            ipInner.bottomAnchor.constraint(equalTo: compactIpPill.bottomAnchor, constant: -7),
            ipInner.leadingAnchor.constraint(equalTo: compactIpPill.leadingAnchor, constant: 12),
            ipInner.trailingAnchor.constraint(equalTo: compactIpPill.trailingAnchor, constant: -12)
        ])

        let topBarRow = UIStackView(arrangedSubviews: [compactLeft, compactIpPill])
        topBarRow.translatesAutoresizingMaskIntoConstraints = false
        topBarRow.axis = .horizontal
        topBarRow.distribution = .equalSpacing
        topBarRow.alignment = .center
        compactTopBarView.addSubview(topBarRow)

        let sbWidth = sidebarView.widthAnchor.constraint(equalToConstant: 276)
        sidebarWidthConstraint = sbWidth
        let topBarH = compactTopBarView.heightAnchor.constraint(equalToConstant: 0)
        compactTopBarHeightConstraint = topBarH

        NSLayoutConstraint.activate([
            appShellView.topAnchor.constraint(equalTo: view.topAnchor),
            appShellView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            appShellView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            appShellView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            sidebarView.topAnchor.constraint(equalTo: appShellView.topAnchor),
            sidebarView.bottomAnchor.constraint(equalTo: appShellView.bottomAnchor),
            sidebarView.leadingAnchor.constraint(equalTo: appShellView.leadingAnchor),
            sbWidth,

            sidebarDividerView.topAnchor.constraint(equalTo: appShellView.topAnchor),
            sidebarDividerView.bottomAnchor.constraint(equalTo: appShellView.bottomAnchor),
            sidebarDividerView.leadingAnchor.constraint(equalTo: sidebarView.trailingAnchor),
            sidebarDividerView.widthAnchor.constraint(equalToConstant: 1),

            mainDetailColumn.topAnchor.constraint(equalTo: appShellView.topAnchor),
            mainDetailColumn.bottomAnchor.constraint(equalTo: appShellView.bottomAnchor),
            mainDetailColumn.leadingAnchor.constraint(equalTo: sidebarDividerView.trailingAnchor),
            mainDetailColumn.trailingAnchor.constraint(equalTo: appShellView.trailingAnchor),

            compactTopBarView.topAnchor.constraint(equalTo: mainDetailColumn.safeAreaLayoutGuide.topAnchor),
            compactTopBarView.leadingAnchor.constraint(equalTo: mainDetailColumn.leadingAnchor),
            compactTopBarView.trailingAnchor.constraint(equalTo: mainDetailColumn.trailingAnchor),
            topBarH,

            topBarRow.leadingAnchor.constraint(equalTo: compactTopBarView.leadingAnchor, constant: 24),
            topBarRow.trailingAnchor.constraint(equalTo: compactTopBarView.trailingAnchor, constant: -24),
            topBarRow.centerYAnchor.constraint(equalTo: compactTopBarView.centerYAnchor),

            detailContentContainer.topAnchor.constraint(equalTo: compactTopBarView.bottomAnchor),
            detailContentContainer.leadingAnchor.constraint(equalTo: mainDetailColumn.leadingAnchor),
            detailContentContainer.trailingAnchor.constraint(equalTo: mainDetailColumn.trailingAnchor),
            detailContentContainer.bottomAnchor.constraint(equalTo: mainDetailColumn.bottomAnchor)
        ])

        // Slide-over Drawer Overlay for Portrait / Collapsed Mode
        appShellView.addSubview(drawerOverlayView)
        drawerOverlayView.addSubview(drawerScrimButton)
        drawerOverlayView.addSubview(drawerSidebarView)
        drawerScrimButton.addTarget(self, action: #selector(closeDrawerTapped), for: .touchUpInside)

        let drawerLead = drawerSidebarView.leadingAnchor.constraint(equalTo: drawerOverlayView.leadingAnchor, constant: -290)
        drawerLeadingConstraint = drawerLead

        NSLayoutConstraint.activate([
            drawerOverlayView.topAnchor.constraint(equalTo: appShellView.topAnchor),
            drawerOverlayView.bottomAnchor.constraint(equalTo: appShellView.bottomAnchor),
            drawerOverlayView.leadingAnchor.constraint(equalTo: appShellView.leadingAnchor),
            drawerOverlayView.trailingAnchor.constraint(equalTo: appShellView.trailingAnchor),

            drawerScrimButton.topAnchor.constraint(equalTo: drawerOverlayView.topAnchor),
            drawerScrimButton.bottomAnchor.constraint(equalTo: drawerOverlayView.bottomAnchor),
            drawerScrimButton.leadingAnchor.constraint(equalTo: drawerOverlayView.leadingAnchor),
            drawerScrimButton.trailingAnchor.constraint(equalTo: drawerOverlayView.trailingAnchor),

            drawerSidebarView.topAnchor.constraint(equalTo: drawerOverlayView.topAnchor),
            drawerSidebarView.bottomAnchor.constraint(equalTo: drawerOverlayView.bottomAnchor),
            drawerSidebarView.widthAnchor.constraint(equalToConstant: 276),
            drawerLead
        ])

        // Wire Both Persistent & Drawer Sidebars
        sidebarView.onSelectTab = { [weak self] tab in
            self?.selectSidebarTab(tab)
        }
        sidebarView.onToggleCollapse = { [weak self] in
            self?.setSidebarCollapsed(true, animated: true)
        }
        sidebarView.onDisconnectTapped = { [weak self] in
            self?.disconnectSession()
        }

        drawerSidebarView.onSelectTab = { [weak self] tab in
            self?.selectSidebarTab(tab)
            self?.setDrawerOpen(false, animated: true)
        }
        drawerSidebarView.onToggleCollapse = { [weak self] in
            self?.setDrawerOpen(false, animated: true)
        }
        drawerSidebarView.onDisconnectTapped = { [weak self] in
            self?.setDrawerOpen(false, animated: true)
            self?.disconnectSession()
        }
    }

    private func wireChildPanels() {
        wirelessPanelVC.onStartDiscovery = { [weak self] in
            self?.connectionManager.startDiscovery()
        }
        wirelessPanelVC.onCancelDiscovery = { [weak self] in
            guard let self = self else { return }
            if self.connectionManager.state == .discovering {
                self.connectionManager.stopDiscovery()
            } else {
                self.disconnectSession()
            }
        }
        wirelessPanelVC.onDirectConnect = { [weak self] ip in
            self?.connectionManager.connect(to: ip, port: Discovery.headunitPort)
        }
        wirelessPanelVC.onDismissIssueBanner = { [weak self] in
            self?.dismissConnectionIssueBanner()
        }

        displayPanelVC.connectionManager = connectionManager
        displayPanelVC.onSettingsChanged = { [weak self] impact in
            self?.handleSettingsImpact(impact)
        }

        audioPanelVC.connectionManager = connectionManager
        audioPanelVC.onSettingsChanged = { [weak self] impact in
            self?.handleSettingsImpact(impact)
        }

        smartPanelVC.onSettingsChanged = { [weak self] impact in
            self?.handleSettingsImpact(impact)
        }

        aboutPanelVC.connectionManager = connectionManager
        aboutPanelVC.onSettingsChanged = { [weak self] impact in
            self?.handleSettingsImpact(impact)
        }
        aboutPanelVC.onProvideDiagnosticLines = { [weak self] in
            self?.combinedDiagnosticLines() ?? []
        }
        aboutPanelVC.onProvideVideoDiagnostics = { [weak self] in
            let codec = ProjectionSettings.videoCodecPreference == .hevc ? "HEVC" : "H.264"
            return (codec, self?.videoRenderer.droppedFrames ?? 0)
        }
    }

    private func wireVideoAndGeometryCallbacks() {
        videoRenderer.onFrameDisplayed = { [weak self] in
            guard let self = self else { return }
            guard !self.hasReceivedFirstVideoFrame else { return }
            let block = {
                guard !self.hasReceivedFirstVideoFrame else { return }
                self.hasReceivedFirstVideoFrame = true
                self.lastVideoFrameTs = Date().timeIntervalSince1970
                self.stopVideoWatchdog()
            }
            if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
        }
        videoRenderer.onKeyframeRequested = { [weak self] in
            self?.connectionManager.requestVideoRecovery()
        }
        videoRenderer.onProvideNetStats = { [weak self] in
            self?.connectionManager.takeVideo1sNetStats() ?? (0, 0, 0.0)
        }
        videoRenderer.onVideoSizeResolved = { [weak self] size in
            let w = Int(size.width)
            let h = Int(size.height)
            if w > 0 && h > 0 {
                AppLog.i("MainViewController: Video size resolved from SPS: \(w)x\(h)", tag: "MainViewController")
                self?.videoRenderer.setNeedsLayout()
            }
        }
        HeadUnitScreenConfig.shared.onMarginsDivergedDetailed = { [weak self] left, top, right, bottom in
            self?.connectionManager.sendUpdateUiConfigRequest(left: left, top: top, right: right, bottom: bottom)
            self?.syncVideoAndTouchGeometry()
            self?.videoRenderer.applyGeometry()
        }
        HeadUnitScreenConfig.shared.onFallbackAdopted = { [weak self] in
            self?.syncVideoAndTouchGeometry()
            self?.videoRenderer.applyGeometry()
        }
        videoRenderer.onDecoderFallbackRequested = { [weak self] width, height, reason in
            guard let self = self else { return }
            AppLog.w("MainViewController: Decoder fallback requested: resolution=\(ProjectionSettings.resolution.title), stream=\(width)x\(height), reason=\(reason)", tag: "MainViewController")
            if let fallback = DecoderConfigLadder.fallbackPreset(from: ProjectionSettings.resolution, currentWidth: width, currentHeight: height) {
                AppLog.i("MainViewController: Stepping down resolution from \(ProjectionSettings.resolution.title) to \(fallback.title)", tag: "MainViewController")
                ProjectionSettings.resolution = fallback
                self.displayPanelVC.syncWithCurrentSettings()
                if self.connectionManager.state == .running {
                    self.connectionManager.reconnectForSettingsChange()
                }
            }
        }
    }

    // MARK: - Sidebar Navigation & Responsive Layout

    func selectSidebarTab(_ tab: AppSidebarTab) {
        selectedSidebarTab = tab
        sidebarView.setSelectedTab(tab)
        drawerSidebarView.setSelectedTab(tab)

        let targetVC: UIViewController
        switch tab {
        case .wirelessConnection:
            targetVC = wirelessPanelVC
        case .displayLayout:
            displayPanelVC.syncWithCurrentSettings()
            targetVC = displayPanelVC
        case .audioMixer:
            audioPanelVC.syncWithCurrentSettings()
            targetVC = audioPanelVC
        case .smartLanguage:
            smartPanelVC.syncWithCurrentSettings()
            targetVC = smartPanelVC
        case .about:
            if aboutPanelVC.isShowingDiagnosticsSubpage && !ProjectionSettings.isHiddenDiagnosticsUnlocked {
                aboutPanelVC.showAboutView(animated: false)
            } else {
                aboutPanelVC.refreshDynamicData()
            }
            targetVC = aboutPanelVC
        }

        guard activePanelVC !== targetVC else { return }

        if let prev = activePanelVC {
            prev.willMove(toParent: nil)
            prev.view.removeFromSuperview()
            prev.removeFromParent()
        }

        addChild(targetVC)
        targetVC.view.translatesAutoresizingMaskIntoConstraints = false
        detailContentContainer.addSubview(targetVC.view)
        NSLayoutConstraint.activate([
            targetVC.view.topAnchor.constraint(equalTo: detailContentContainer.topAnchor),
            targetVC.view.bottomAnchor.constraint(equalTo: detailContentContainer.bottomAnchor),
            targetVC.view.leadingAnchor.constraint(equalTo: detailContentContainer.leadingAnchor),
            targetVC.view.trailingAnchor.constraint(equalTo: detailContentContainer.trailingAnchor)
        ])
        targetVC.didMove(toParent: self)
        activePanelVC = targetVC
    }

    func setSidebarCollapsed(_ collapsed: Bool, animated: Bool) {
        isSidebarCollapsed = collapsed
        updateSidebarPresentationMode(animated: animated)
    }

    private func updateSidebarPresentationMode(forWidth explicitWidth: CGFloat? = nil, animated: Bool = false) {
        let w = explicitWidth ?? view.bounds.width
        let isWideEnough = w >= 768
        let showPersistentSidebar = isWideEnough && !isSidebarCollapsed

        let targetSidebarWidth: CGFloat = showPersistentSidebar ? 276 : 0
        let targetTopBarHeight: CGFloat = showPersistentSidebar ? 0 : 54

        if sidebarWidthConstraint?.constant == targetSidebarWidth && compactTopBarHeightConstraint?.constant == targetTopBarHeight {
            return
        }

        sidebarWidthConstraint?.constant = targetSidebarWidth
        compactTopBarHeightConstraint?.constant = targetTopBarHeight
        sidebarView.isHidden = !showPersistentSidebar
        sidebarDividerView.isHidden = !showPersistentSidebar
        compactTopBarView.isHidden = showPersistentSidebar

        if showPersistentSidebar && !drawerOverlayView.isHidden {
            setDrawerOpen(false, animated: false)
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.2) {
                self.appShellView.layoutIfNeeded()
            }
        }
    }

    private func setDrawerOpen(_ open: Bool, animated: Bool) {
        if open {
            drawerOverlayView.isHidden = false
            appShellView.bringSubviewToFront(drawerOverlayView)
            drawerLeadingConstraint?.constant = 0
            if animated {
                drawerScrimButton.alpha = 0
                UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.88, initialSpringVelocity: 0.3) {
                    self.drawerScrimButton.alpha = 1
                    self.drawerOverlayView.layoutIfNeeded()
                }
            } else {
                drawerScrimButton.alpha = 1
                drawerOverlayView.layoutIfNeeded()
            }
        } else {
            drawerLeadingConstraint?.constant = -290
            if animated {
                UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseIn]) {
                    self.drawerScrimButton.alpha = 0
                    self.drawerOverlayView.layoutIfNeeded()
                } completion: { _ in
                    self.drawerOverlayView.isHidden = true
                }
            } else {
                drawerScrimButton.alpha = 0
                drawerOverlayView.isHidden = true
            }
        }
    }

    @objc private func compactMenuButtonTapped() {
        let isWide = view.bounds.width >= 768
        if isWide && isSidebarCollapsed {
            setSidebarCollapsed(false, animated: true)
        } else {
            setDrawerOpen(true, animated: true)
        }
    }

    @objc private func closeDrawerTapped() {
        setDrawerOpen(false, animated: true)
    }

    // MARK: - Localization & Panel Sync

    @objc func applyLocalization() {
        compactBrandLabel.text = CarAutoPadDeviceInfo.appName
        sidebarView.applyLocalization()
        drawerSidebarView.applyLocalization()
        wirelessPanelVC.applyLocalization()
        displayPanelVC.applyLocalization()
        audioPanelVC.applyLocalization()
        smartPanelVC.applyLocalization()
        aboutPanelVC.applyLocalization()
        quickMenuOverlay?.applyLocalization()
        updateSidebarAndCompactStatus()
    }

    func refreshAllPanels() {
        displayPanelVC.syncWithCurrentSettings()
        audioPanelVC.syncWithCurrentSettings()
        smartPanelVC.syncWithCurrentSettings()
        aboutPanelVC.refreshDynamicData()
        updateSidebarAndCompactStatus()
    }

    private func updateSidebarAndCompactStatus() {
        let localIp = CarAutoPadDeviceInfo.localIpDisplayName
        let state = connectionManager.state
        let kind = connectionManager.statusKind
        let peerName = connectionManager.connectedPeerDisplayName
        let peerEndpoint = connectionManager.connectedPeerEndpointText

        sidebarView.updateConnectionState(state, statusKind: kind, localIp: localIp, peerName: peerName, peerEndpoint: peerEndpoint)
        drawerSidebarView.updateConnectionState(state, statusKind: kind, localIp: localIp, peerName: peerName, peerEndpoint: peerEndpoint)

        switch state {
        case .discovering, .waitingForWirelessHelper, .connecting, .handshaking:
            compactStatusDot.backgroundColor = CarAutoPadTheme.accentOrange
            compactIpLabel.text = L10n.sidebarScanningPort5277
            compactIpLabel.textColor = .secondaryLabel
        case .error:
            compactStatusDot.backgroundColor = CarAutoPadTheme.accentOrange
            compactIpLabel.text = localIp
            compactIpLabel.textColor = CarAutoPadTheme.accentOrange
        case .disconnected, .disconnecting:
            if kind.isDisconnectedWarning {
                compactStatusDot.backgroundColor = CarAutoPadTheme.accentOrange
                compactIpLabel.textColor = CarAutoPadTheme.accentOrange
            } else {
                compactStatusDot.backgroundColor = CarAutoPadTheme.accentGreen
                compactIpLabel.textColor = .secondaryLabel
            }
            compactIpLabel.text = localIp
        case .running:
            compactStatusDot.backgroundColor = CarAutoPadTheme.accentGreen
            compactIpLabel.text = peerName
            compactIpLabel.textColor = .label
        }
    }

    // MARK: - Settings Change Impact Handler

    private func handleSettingsImpact(_ impact: SettingsViewController.ChangeImpact) {
        refreshAllPanels()
        quickMenuOverlay?.syncWithCurrentSettings()
        switch impact {
        case .uiOnly:
            updatePerformanceOverlayState()
            refreshSystemGestureDeferral()
        case .nightModeChanged:
            connectionManager.updateNightMode(userInterfaceStyle: traitCollection.userInterfaceStyle, force: true)
        case .geometryChanged:
            applyOrientationLock()
            syncVideoAndTouchGeometry()
            videoRenderer.applyGeometry()
        case .motionBlurChanged:
            videoRenderer.motionBlurMode = ProjectionSettings.motionBlurMode
        case .audioVolumeOrDuckingChanged:
            PCMAudioPlayer.shared.refreshVolumes()
        case .requiresReconnect:
            if connectionManager.state == .running {
                connectionManager.reconnectForSettingsChange()
            }
        }
    }

    // MARK: - Debug Bubble & Liquid Glass Quick Menu Popover (Figma 10)

    @objc private func debugBubbleTapped() {
        if quickMenuOverlay != nil {
            dismissProjectionQuickMenu(animated: true)
        } else {
            presentProjectionQuickMenu()
        }
    }

    func presentProjectionQuickMenu() {
        guard quickMenuOverlay == nil else { return }
        let menu = ProjectionQuickMenuView()
        menu.updateSessionInfo(
            peerName: connectionManager.connectedPeerDisplayName,
            endpoint: connectionManager.connectedPeerEndpointText,
            fps: videoRenderer.currentFps > 0 ? Double(videoRenderer.currentFps) : Double(ProjectionSettings.effectiveFpsLimit == .fps60 ? 60 : 30),
            decodeMs: videoRenderer.decodeLatency.medianMs
        )
        menu.onNightModeChanged = { [weak self] in
            self?.handleSettingsImpact(.nightModeChanged)
        }
        menu.onHudToggled = { [weak self] isOn in
            guard let self = self else { return }
            self.performanceOverlayView.isHidden = !isOn
            self.performanceOverlayBlurView.isHidden = !isOn
        }
        menu.onAudioChanged = { [weak self] in
            self?.handleSettingsImpact(.audioVolumeOrDuckingChanged)
        }
        menu.onOpenFullSettings = { [weak self] in
            self?.dismissProjectionQuickMenu(animated: true)
            self?.presentSettingsMenu()
        }
        menu.onDisconnectTapped = { [weak self] in
            self?.dismissProjectionQuickMenu(animated: true)
            self?.disconnectSession()
        }
        menu.onDismissRequested = { [weak self] in
            self?.dismissProjectionQuickMenu(animated: true)
        }

        view.addSubview(menu)
        NSLayoutConstraint.activate([
            menu.topAnchor.constraint(equalTo: view.topAnchor),
            menu.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            menu.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            menu.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        menu.position(relativeTo: debugBubbleButton, snappedToRight: debugBubbleSnappedToRight)
        view.bringSubviewToFront(menu)
        view.bringSubviewToFront(debugBubbleButton)
        quickMenuOverlay = menu
        menu.animateIn(snappedToRight: debugBubbleSnappedToRight)
    }

    func dismissProjectionQuickMenu(animated: Bool) {
        guard let menu = quickMenuOverlay else { return }
        quickMenuOverlay = nil
        if animated {
            menu.animateOut(snappedToRight: debugBubbleSnappedToRight) {
                menu.removeFromSuperview()
            }
        } else {
            menu.removeFromSuperview()
        }
    }

    @objc func handleDebugBubblePan(_ gesture: UIPanGestureRecognizer) {
        if quickMenuOverlay != nil {
            dismissProjectionQuickMenu(animated: false)
        }
        let translation = gesture.translation(in: view)
        switch gesture.state {
        case .began:
            isPanningDebugBubble = true
            debugBubblePanStartCenter = CGPoint(
                x: debugBubbleCenterXConstraint?.constant ?? debugBubbleButton.center.x,
                y: debugBubbleCenterYConstraint?.constant ?? debugBubbleButton.center.y
            )
        case .changed:
            guard view.bounds.width > 0 && view.bounds.height > 0 else { return }
            let bubbleRadius: CGFloat = 24.0
            let rawX = debugBubblePanStartCenter.x + translation.x
            let rawY = debugBubblePanStartCenter.y + translation.y
            let boundedX = min(view.bounds.width - bubbleRadius, max(bubbleRadius, rawX))
            let boundedY = min(view.bounds.height - bubbleRadius, max(bubbleRadius, rawY))
            debugBubbleCenterXConstraint?.constant = boundedX
            debugBubbleCenterYConstraint?.constant = boundedY
            view.layoutIfNeeded()
        case .ended, .cancelled:
            isPanningDebugBubble = false
            clampDebugBubbleToSafeBounds(animated: true)
        default:
            isPanningDebugBubble = false
        }
    }

    func clampDebugBubbleToSafeBounds(animated: Bool) {
        guard !isPanningDebugBubble else { return }
        guard view.bounds.width > 0 && view.bounds.height > 0 else { return }
        let safeArea = view.safeAreaInsets
        let bubbleRadius: CGFloat = 24.0
        let margin: CGFloat = 12.0

        let minX = safeArea.left + bubbleRadius + margin
        let maxX = view.bounds.width - safeArea.right - bubbleRadius - margin
        let minY = safeArea.top + bubbleRadius + margin
        let maxY = view.bounds.height - safeArea.bottom - bubbleRadius - margin

        let currentX = debugBubbleCenterXConstraint?.constant ?? maxX
        let currentY = debugBubbleCenterYConstraint?.constant ?? (minY + 120)

        let snapToRight = (currentX >= (view.bounds.width / 2.0))
        debugBubbleSnappedToRight = snapToRight

        let snapX: CGFloat = snapToRight ? maxX : minX
        let clampedY = min(maxY, max(minY, currentY))

        let diffX = abs((debugBubbleCenterXConstraint?.constant ?? snapX) - snapX)
        let diffY = abs((debugBubbleCenterYConstraint?.constant ?? clampedY) - clampedY)
        if diffX < 0.5 && diffY < 0.5 && !animated {
            return
        }

        debugBubbleCenterXConstraint?.constant = snapX
        debugBubbleCenterYConstraint?.constant = clampedY

        if animated {
            UIView.animate(
                withDuration: 0.35,
                delay: 0,
                usingSpringWithDamping: 0.78,
                initialSpringVelocity: 0.5,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                self.view.layoutIfNeeded()
            }
        } else {
            view.layoutIfNeeded()
        }
    }

    // MARK: - Full Settings FormSheet (from Quick Menu during Active Projection)

    func presentSettingsMenu() {
        guard presentedViewController == nil else { return }
        let settingsVC = SettingsViewController()
        settingsVC.connectionManager = connectionManager
        settingsVC.onSettingsChanged = { [weak self] impact in
            self?.handleSettingsImpact(impact)
        }
        settingsVC.onProvideDiagnosticLines = { [weak self] in
            self?.combinedDiagnosticLines() ?? []
        }

        let nav = UINavigationController(rootViewController: settingsVC)
        nav.modalPresentationStyle = .formSheet
        nav.preferredContentSize = CGSize(width: 680, height: 760)
        present(nav, animated: true)
    }

    private func disconnectSession() {
        connectionManager.screenConfig.clearCustomNegotiatedResolution()
        connectionManager.disconnect()
    }

    private func combinedDiagnosticLines() -> [String] {
        return connectionManager.diagnosticLines() + [""] + videoRenderer.diagnosticLines()
    }

    // MARK: - Connection State & HUD Management

    private func updateUIForConnectionState(_ state: ConnectionState) {
        UIApplication.shared.isIdleTimerDisabled = (state == .running)

        switch state {
        case .disconnected:
            stopVideoWatchdog()
            dismissProjectionQuickMenu(animated: false)
            hasReceivedFirstVideoFrame = false
            videoContainerView.isHidden = true
            appShellView.isHidden = false
            view.bringSubviewToFront(appShellView)
            connectionManager.screenConfig.clearCustomNegotiatedResolution()
            videoRenderer.reset()
            audioPlayer.reset()
            refreshSystemGestureDeferral()

        case .discovering, .waitingForWirelessHelper, .connecting, .handshaking:
            stopVideoWatchdog()
            dismissProjectionQuickMenu(animated: false)
            videoContainerView.isHidden = true
            appShellView.isHidden = false
            view.bringSubviewToFront(appShellView)
            refreshSystemGestureDeferral()

        case .running:
            ConnectionIssueStore.shared.clearAll()
            startVideoWatchdog()
            appShellView.isHidden = true
            videoContainerView.isHidden = false
            view.bringSubviewToFront(videoContainerView)
            view.layoutIfNeeded()
            videoContainerView.layoutIfNeeded()
            syncVideoAndTouchGeometry()
            videoRenderer.applyGeometry()
            refreshSystemGestureDeferral()

        case .disconnecting:
            stopVideoWatchdog()
            dismissProjectionQuickMenu(animated: false)
            videoContainerView.isHidden = true
            appShellView.isHidden = false
            view.bringSubviewToFront(appShellView)
            audioPlayer.reset()
            refreshSystemGestureDeferral()

        case .error(let message):
            let lower = message.lowercased()
            if lower.contains("5277") || lower.contains("refused") {
                ConnectionIssueStore.shared.raise(issue: .connectionRefused5277)
            } else if lower.contains("tls") || lower.contains("handshake") {
                ConnectionIssueStore.shared.raise(issue: .tlsHandshakeFailed)
            }
            stopVideoWatchdog()
            dismissProjectionQuickMenu(animated: false)
            videoContainerView.isHidden = true
            appShellView.isHidden = false
            view.bringSubviewToFront(appShellView)
            audioPlayer.reset()
            refreshSystemGestureDeferral()
        }

        wirelessPanelVC.updateConnectionState(state, statusDetail: connectionManager.statusDetail)
        updateSidebarAndCompactStatus()
        displayPanelVC.syncWithCurrentSettings()
        audioPanelVC.syncWithCurrentSettings()
        aboutPanelVC.refreshDynamicData()
        updatePerformanceOverlayState()
        updateConnectionIssueBanner()
    }

    func updatePerformanceOverlayState() {
        let shouldShow = ProjectionSettings.isDebugModeEnabled && connectionManager.state == .running
        performanceOverlayView.isHidden = !shouldShow
        performanceOverlayBlurView.isHidden = !shouldShow
        debugBubbleButton.isHidden = !shouldShow
        if shouldShow {
            view.bringSubviewToFront(debugBubbleButton)
            videoContainerView.bringSubviewToFront(performanceOverlayBlurView)
            videoContainerView.bringSubviewToFront(performanceOverlayView)
            if performanceTimer == nil {
                performanceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    self?.refreshPerformanceOverlay()
                }
            }
            refreshPerformanceOverlay()
        } else {
            dismissProjectionQuickMenu(animated: false)
            performanceTimer?.invalidate()
            performanceTimer = nil
        }
    }

    private func refreshPerformanceOverlay() {
        guard !performanceOverlayView.isHidden || quickMenuOverlay != nil else { return }
        let fps = videoRenderer.currentFps
        let mbps = connectionManager.currentRxMbps
        let lat = videoRenderer.decodeLatency
        let pcmMs = audioPlayer.mediaBufferDepthMs
        let kf = videoRenderer.keyframeRepairs
        let drop = videoRenderer.droppedFrames
        let activeW = max(1, videoRenderer.codecWidth - videoRenderer.widthMargin)
        let activeH = max(1, videoRenderer.codecHeight - videoRenderer.heightMargin)
        let resText = (videoRenderer.widthMargin > 0 || videoRenderer.heightMargin > 0)
            ? "\(activeW)x\(activeH) (\(videoRenderer.codecWidth)x\(videoRenderer.codecHeight))"
            : "\(videoRenderer.codecWidth)x\(videoRenderer.codecHeight)"

        let snapshot = PerformanceSnapshot(
            fps: fps,
            rxMbps: mbps,
            decodeMedianMs: lat.medianMs,
            decodeP95Ms: lat.p95Ms,
            audioBufferMs: pcmMs,
            keyframeRepairs: kf,
            droppedFrames: drop,
            resolutionText: resText
        )
        performanceOverlayView.update(snapshot: snapshot)
        quickMenuOverlay?.updateSessionInfo(
            peerName: connectionManager.connectedPeerDisplayName,
            endpoint: connectionManager.connectedPeerEndpointText,
            fps: fps > 0 ? Double(fps) : Double(ProjectionSettings.effectiveFpsLimit == .fps60 ? 60 : 30),
            decodeMs: lat.medianMs
        )
    }

    func updateConnectionIssueBanner() {
        let standing = ConnectionIssueStore.shared.currentIssues()
        let isConnected = (connectionManager.state == .running)
        let active = ConnectionIssueBannerPolicy.bannerFor(
            standing: standing,
            sessionConnected: isConnected,
            dismissedAtEpochMs: dismissedIssueEpochMs
        )
        wirelessPanelVC.updateIssueBanner(issue: active?.issue)
    }

    private func dismissConnectionIssueBanner() {
        if let latest = ConnectionIssueStore.shared.currentIssues().max(by: { $0.raisedAtEpochMs < $1.raisedAtEpochMs }) {
            dismissedIssueEpochMs = latest.raisedAtEpochMs
        } else {
            dismissedIssueEpochMs = Int64(Date().timeIntervalSince1970 * 1000)
        }
        updateConnectionIssueBanner()
    }

    @objc private func handleNetworkReachabilityChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let snapshot = NetworkReachabilityMonitor.shared.currentSnapshot
            if let gw = snapshot.gatewayIpv4, !gw.isEmpty {
                self.wirelessPanelVC.updateSuggestedGateway(gw)
            }
            self.updateSidebarAndCompactStatus()
            self.aboutPanelVC.refreshDynamicData()
            self.updateConnectionIssueBanner()
        }
    }

    // MARK: - Orientation, Status Bar, Edge Swipe Deferral, Geometry & Watchdog

    override var prefersStatusBarHidden: Bool {
        return connectionManager.state == .running
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return false
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return (connectionManager.state == .running && ProjectionSettings.isEdgeSwipeProtectionEnabled) ? .all : []
    }

    func refreshSystemGestureDeferral() {
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }

    override var shouldAutorotate: Bool {
        return ProjectionSettings.orientation == .system
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        switch ProjectionSettings.orientation {
        case .landscape: return .landscape
        case .portrait: return .portrait
        case .system: return .all
        }
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        switch ProjectionSettings.orientation {
        case .landscape: return .landscapeRight
        case .portrait: return .portrait
        case .system: return .unknown
        }
    }

    private func applyOrientationLock() {
        setNeedsUpdateOfSupportedInterfaceOrientations()
        touchOverlayView.isMultipleTouchEnabled = true

        let targetMask = supportedInterfaceOrientations
        guard let window = view.window, let scene = window.windowScene else { return }
        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: targetMask)
        scene.requestGeometryUpdate(prefs) { error in
            AppLog.e("MainViewController: Failed to apply orientation lock: \(error)", tag: "MainViewController")
        }
    }

    private func syncVideoAndTouchGeometry() {
        let cfg = connectionManager.screenConfig
        let wMargin = (cfg.announcedWidthMargin >= 0) ? cfg.announcedWidthMargin : cfg.getWidthMargin()
        let hMargin = (cfg.announcedHeightMargin >= 0) ? cfg.announcedHeightMargin : cfg.getHeightMargin()

        videoRenderer.codecWidth = cfg.negotiatedWidth
        videoRenderer.codecHeight = cfg.negotiatedHeight
        videoRenderer.widthMargin = wMargin
        videoRenderer.heightMargin = hMargin
        videoRenderer.fitMode = cfg.videoFitMode

        touchOverlayView.surfaceSize = touchOverlayView.bounds.size
        touchOverlayView.screenConfig = cfg
        touchOverlayView.videoFitMode = cfg.videoFitMode
        touchOverlayView.codecWidth = cfg.negotiatedWidth
        touchOverlayView.codecHeight = cfg.negotiatedHeight
        touchOverlayView.widthMargin = wMargin
        touchOverlayView.heightMargin = hMargin
    }

    private func startVideoWatchdog() {
        if videoWatchdogTimer != nil { return }
        runningSinceTs = Date().timeIntervalSince1970
        lastVideoFrameTs = runningSinceTs
        hasReceivedFirstVideoFrame = false
        videoWatchdogTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            self?.checkVideoWatchdog()
        }
    }

    private func stopVideoWatchdog() {
        videoWatchdogTimer?.invalidate()
        videoWatchdogTimer = nil
    }

    private func checkVideoWatchdog() {
        guard connectionManager.state == .running else { return }
        let now = Date().timeIntervalSince1970
        if !hasReceivedFirstVideoFrame {
            if (now - runningSinceTs) > 1.8 && (now - lastVideoRecoveryTs) > 2.0 {
                lastVideoRecoveryTs = now
                AppLog.w("Watchdog: no first video frame after \(String(format: "%.1f", now - runningSinceTs))s - triggering video focus cycle", tag: "MainViewController")
                connectionManager.requestVideoFocusCycle(reason: "watchdog-no-first-frame")
            }
        } else {
            stopVideoWatchdog()
        }
    }

    // MARK: - Physical Keyboard & Steering Wheel Keymap Forwarding

    override var canBecomeFirstResponder: Bool { true }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard connectionManager.state == .running, !wirelessPanelVC.directIpTextField.isFirstResponder else {
            super.pressesBegan(presses, with: event)
            return
        }
        var handled = false
        for press in presses {
            if let keyCode = KeymapManager.androidKeyCode(for: press) {
                connectionManager.sendKeyEvent(keyCode: keyCode, isDown: true)
                handled = true
            }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard connectionManager.state == .running, !wirelessPanelVC.directIpTextField.isFirstResponder else {
            super.pressesEnded(presses, with: event)
            return
        }
        var handled = false
        for press in presses {
            if let keyCode = KeymapManager.androidKeyCode(for: press) {
                connectionManager.sendKeyEvent(keyCode: keyCode, isDown: false)
                handled = true
            }
        }
        if !handled { super.pressesEnded(presses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard connectionManager.state == .running, !wirelessPanelVC.directIpTextField.isFirstResponder else {
            super.pressesCancelled(presses, with: event)
            return
        }
        var handled = false
        for press in presses {
            if let keyCode = KeymapManager.androidKeyCode(for: press) {
                connectionManager.sendKeyEvent(keyCode: keyCode, isDown: false)
                handled = true
            }
        }
        if !handled { super.pressesCancelled(presses, with: event) }
    }
}

// MARK: - ConnectionManagerDelegate

extension MainViewController: ConnectionManagerDelegate {
    func connectionManager(_ manager: ConnectionManager, didChangeState state: ConnectionState) {
        if Thread.isMainThread {
            updateUIForConnectionState(state)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.updateUIForConnectionState(state)
            }
        }
    }

    func connectionManager(_ manager: ConnectionManager, didUpdateStatus status: String) {
        let update = { [weak self] in
            guard let self = self else { return }
            self.wirelessPanelVC.updateConnectionState(self.connectionManager.state, statusDetail: status)
            self.updateSidebarAndCompactStatus()
        }
        if Thread.isMainThread { update() } else { DispatchQueue.main.async(execute: update) }
    }

    func connectionManager(_ manager: ConnectionManager, didDiscoverDevice device: DiscoveredDevice) {
        let update = { [weak self] in
            guard let self = self else { return }
            self.wirelessPanelVC.updateConnectionState(
                self.connectionManager.state,
                statusDetail: L10n.statusFoundDeviceConnecting(device.displayName)
            )
            self.updateConnectionIssueBanner()
        }
        if Thread.isMainThread { update() } else { DispatchQueue.main.async(execute: update) }
    }

    func connectionManager(_ manager: ConnectionManager, didReceiveVideoData data: Data) {
        videoRenderer.enqueueAnnexBFrame(data)
    }

    func connectionManager(_ manager: ConnectionManager, didReceiveAudioData data: Data, on channel: UInt8) {
        audioPlayer.playPCM(data, on: channel)
    }

    func connectionManager(_ manager: ConnectionManager, didReceiveAudioData data: Data, on channel: UInt8, isAac: Bool) {
        audioPlayer.playAudio(data, on: channel, isAac: isAac)
    }

    func connectionManager(_ manager: ConnectionManager, didReceiveAudioCodecConfig data: Data, on channel: UInt8) {
        audioPlayer.configureCodec(channel: channel, csd: data)
    }

    func connectionManagerDidEnterBackground(_ manager: ConnectionManager) {
        videoRenderer.enterBackground()
    }

    func connectionManagerWillEnterForeground(_ manager: ConnectionManager) {
        videoRenderer.enterForeground()
    }
}
