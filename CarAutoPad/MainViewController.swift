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

    private let videoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let touchOverlayView: TouchInputView = {
        let view = TouchInputView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let performanceOverlayView = PerformanceOverlayView()
    private var performanceTimer: Timer?

    private let homeScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private let homeContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let dashboardContentContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let headerContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let appIconImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 10
        iv.clipsToBounds = true
        if let icon = UIImage(named: "AppIcon") {
            iv.image = icon
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)
            iv.image = UIImage(systemName: "car.fill", withConfiguration: config)
            iv.tintColor = .systemBlue
            iv.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        }
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "CarAutoPad"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Wireless Android Auto Receiver"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusPillView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.cgColor
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let statusDotView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 4
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Ready to connect"
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var settingsButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = "Settings"
        config.titleLineBreakMode = .byClipping
        config.image = UIImage(systemName: "slider.horizontal.3")
        config.imagePadding = 6
        config.cornerStyle = .capsule
        config.buttonSize = .medium
        config.baseBackgroundColor = UIColor.systemGray5
        config.baseForegroundColor = .label

        let button = UIButton(configuration: config)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
        return button
    }()

    private let connectionIssueBannerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.15)
        v.layer.cornerRadius = 14
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.4).cgColor
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let connectionIssueTitleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .systemOrange
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let connectionIssueAdviceLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var connectionIssueDismissButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Dismiss", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: #selector(dismissConnectionIssueBanner), for: .touchUpInside)
        return b
    }()

    private var dismissedIssueEpochMs: Int64?
    private var bannerZeroHeightConstraint: NSLayoutConstraint?

    private let dashboardGridStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = 20
        return stack
    }()

    private let connectionHubCard: UIView = {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.separator.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }()

    private let hubTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Wireless Connection Hub"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .left
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let hubIconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "wifi"))
        iv.tintColor = .systemBlue
        iv.contentMode = .scaleAspectFit
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let directIpLabel: UILabel = {
        let label = UILabel()
        label.text = "Direct Connect (Phone Hotspot IP)"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let directIpTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "192.168.43.1"
        textField.text = NetworkAddresses.currentHotspotGatewayIpv4()
        textField.textAlignment = .center
        textField.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        textField.backgroundColor = .tertiarySystemBackground
        textField.layer.cornerRadius = 10
        textField.keyboardType = .numbersAndPunctuation
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.clearButtonMode = .whileEditing
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private lazy var resetGatewayIpButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "arrow.counterclockwise")
        config.buttonSize = .medium
        let button = UIButton(configuration: config)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addAction(UIAction { [weak self] _ in
            self?.directIpTextField.text = NetworkAddresses.currentHotspotGatewayIpv4()
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }, for: .touchUpInside)
        return button
    }()

    private lazy var directConnectButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Direct Connect"
        config.image = UIImage(systemName: "arrow.right.circle.fill")
        config.imagePadding = 6
        config.cornerStyle = .large
        config.buttonSize = .large
        config.baseBackgroundColor = .systemBlue

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(directConnectButtonTapped), for: .touchUpInside)
        return button
    }()

    private let orDividerLabel: UILabel = {
        let label = UILabel()
        label.text = "— OR AUTO-DISCOVER —"
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var connectButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Scan for Headunit Server (Port 5277)"
        config.image = UIImage(systemName: "antenna.radiowaves.left.and.right")
        config.imagePadding = 8
        config.cornerStyle = .large
        config.buttonSize = .large
        config.baseBackgroundColor = .systemIndigo

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(connectButtonTapped), for: .touchUpInside)
        return button
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private lazy var disconnectButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Cancel / Disconnect"
        config.cornerStyle = .large
        config.buttonSize = .large
        config.baseBackgroundColor = .systemRed

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(disconnectButtonTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private let serverGuideCard: UIView = {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.separator.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }()

    private let guideTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Android Phone Setup Guide"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .left
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let guideIconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "info.circle.fill"))
        iv.tintColor = .systemTeal
        iv.contentMode = .scaleAspectFit
        iv.setContentHuggingPriority(.required, for: .horizontal)
        iv.setContentCompressionResistancePriority(.required, for: .horizontal)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let guideStepsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let quickSpecsHeaderLabel: UILabel = {
        let label = UILabel()
        label.text = "CURRENT CONFIGURATION (TAP TO CONFIGURE)"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let quickSpecsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var displayTile: QuickSpecTileView!
    private var layoutTile: QuickSpecTileView!
    private var codecsTile: QuickSpecTileView!
    private var audioTile: QuickSpecTileView!
    private var micTile: QuickSpecTileView!
    private var modeTile: QuickSpecTileView!

    override func viewDidLoad() {
        super.viewDidLoad()
        HeadUnitScreenConfig.shared.videoFitMode = ProjectionSettings.videoFitMode
        setupUI()
        setupConstraints()
        connectionManager.delegate = self

        Discovery.triggerLocalNetworkPermission()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        homeScrollView.addGestureRecognizer(tap)

        videoRenderer.onFrameDisplayed = { [weak self] in
            guard let self = self else { return }
            guard !self.hasReceivedFirstVideoFrame else { return }
            let block = {
                guard !self.hasReceivedFirstVideoFrame else { return }
                self.hasReceivedFirstVideoFrame = true
                self.lastVideoFrameTs = Date().timeIntervalSince1970
                self.stopVideoWatchdog()
            }
            if Thread.isMainThread {
                block()
            } else {
                DispatchQueue.main.async(execute: block)
            }
        }
        videoRenderer.onKeyframeRequested = { [weak self] in
            self?.connectionManager.requestVideoRecovery()
        }
        videoRenderer.onProvideNetStats = { [weak self] in
            self?.connectionManager.takeVideo1sNetStats() ?? (0, 0, 0.0)
        }
        videoRenderer.onVideoSizeResolved = { [weak self] size in
            guard let self = self else { return }
            let w = Int(size.width)
            let h = Int(size.height)
            if w > 0 && h > 0 {
                AppLog.i("MainViewController: Video size resolved from SPS: \(w)x\(h)", tag: "MainViewController")
                self.videoRenderer.setNeedsLayout()
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
                self.refreshQuickSpecTiles()
                if self.connectionManager.state == .running {
                    self.connectionManager.reconnectForSettingsChange()
                }
            }
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkReachabilityChanged(_:)),
            name: .carAutoPadNetworkReachabilityDidChange,
            object: nil
        )
        updateUIForConnectionState(.disconnected)
        syncVideoAndTouchGeometry()
        refreshQuickSpecTiles()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyOrientationLock()
        refreshQuickSpecTiles()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        touchOverlayView.frame = videoContainerView.bounds
        touchOverlayView.isUserInteractionEnabled = true

        let isLandscape = view.bounds.width > view.bounds.height
        if dashboardGridStack.axis != (isLandscape ? .horizontal : .vertical) {
            dashboardGridStack.axis = isLandscape ? .horizontal : .vertical
            dashboardGridStack.distribution = isLandscape ? .fillEqually : .fill
        }

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
            videoContainerView.bringSubviewToFront(performanceOverlayView)
        }
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
        })
    }

    override var shouldAutorotate: Bool {
        return ProjectionSettings.orientation == .system
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        switch ProjectionSettings.orientation {
        case .landscape:
            return .landscape
        case .portrait:
            return .portrait
        case .system:
            return .all
        }
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        switch ProjectionSettings.orientation {
        case .landscape:
            return .landscapeRight
        case .portrait:
            return .portrait
        case .system:
            return .unknown
        }
    }

    private func applyOrientationLock() {
        setNeedsUpdateOfSupportedInterfaceOrientations()
        touchOverlayView.isMultipleTouchEnabled = true

        let targetMask = supportedInterfaceOrientations
        if #available(iOS 16.0, *) {
            guard let window = view.window, let scene = window.windowScene else { return }
            let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: targetMask)
            scene.requestGeometryUpdate(prefs) { error in
                AppLog.e("MainViewController: Failed to apply orientation lock: \(error)", tag: "MainViewController")
            }
        } else {
            let orientation: UIInterfaceOrientation
            switch ProjectionSettings.orientation {
            case .landscape: orientation = .landscapeRight
            case .portrait: orientation = .portrait
            case .system: orientation = .unknown
            }
            if orientation != .unknown {
                UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
                UIViewController.attemptRotationToDeviceOrientation()
            }
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

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        videoRenderer.isUserInteractionEnabled = false
        touchOverlayView.isUserInteractionEnabled = true

        videoContainerView.addSubview(videoRenderer)
        videoContainerView.addSubview(touchOverlayView)
        videoContainerView.addSubview(performanceOverlayView)
        videoRenderer.translatesAutoresizingMaskIntoConstraints = false
        touchOverlayView.translatesAutoresizingMaskIntoConstraints = false
        performanceOverlayView.translatesAutoresizingMaskIntoConstraints = false

        touchOverlayView.onTouchWithTimestamp = { [weak self] pointers, action, actionIndex, timestamp in
            self?.connectionManager.sendTouchEvent(pointers: pointers, action: action, actionIndex: actionIndex, touchTimestamp: timestamp)
        }

        let appTitleStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        appTitleStack.axis = .vertical
        appTitleStack.spacing = 2
        appTitleStack.translatesAutoresizingMaskIntoConstraints = false

        let appBrandStack = UIStackView(arrangedSubviews: [appIconImageView, appTitleStack])
        appBrandStack.axis = .horizontal
        appBrandStack.spacing = 12
        appBrandStack.alignment = .center
        appBrandStack.translatesAutoresizingMaskIntoConstraints = false

        statusPillView.addSubview(statusDotView)
        statusPillView.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusDotView.leadingAnchor.constraint(equalTo: statusPillView.leadingAnchor, constant: 10),
            statusDotView.centerYAnchor.constraint(equalTo: statusPillView.centerYAnchor),
            statusDotView.widthAnchor.constraint(equalToConstant: 8),
            statusDotView.heightAnchor.constraint(equalToConstant: 8),

            statusLabel.leadingAnchor.constraint(equalTo: statusDotView.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: statusPillView.trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: statusPillView.centerYAnchor)
        ])

        let rightHeaderStack = UIStackView(arrangedSubviews: [statusPillView, settingsButton])
        rightHeaderStack.axis = .horizontal
        rightHeaderStack.spacing = 10
        rightHeaderStack.alignment = .center
        rightHeaderStack.translatesAutoresizingMaskIntoConstraints = false

        headerContainerView.addSubview(appBrandStack)
        headerContainerView.addSubview(rightHeaderStack)

        connectionIssueBannerView.addSubview(connectionIssueTitleLabel)
        connectionIssueBannerView.addSubview(connectionIssueAdviceLabel)
        connectionIssueBannerView.addSubview(connectionIssueDismissButton)

        let hubHeaderSpacer = UIView()
        hubHeaderSpacer.translatesAutoresizingMaskIntoConstraints = false
        let hubHeaderStack = UIStackView(arrangedSubviews: [hubIconView, hubTitleLabel, hubHeaderSpacer])
        hubHeaderStack.axis = .horizontal
        hubHeaderStack.spacing = 8
        hubHeaderStack.alignment = .center
        hubHeaderStack.translatesAutoresizingMaskIntoConstraints = false

        let ipInputContainer = UIStackView(arrangedSubviews: [directIpTextField, resetGatewayIpButton])
        ipInputContainer.axis = .horizontal
        ipInputContainer.spacing = 6
        ipInputContainer.alignment = .fill
        ipInputContainer.translatesAutoresizingMaskIntoConstraints = false

        let indicatorStack = UIStackView(arrangedSubviews: [activityIndicator, disconnectButton])
        indicatorStack.axis = .vertical
        indicatorStack.spacing = 10
        indicatorStack.alignment = .center
        indicatorStack.translatesAutoresizingMaskIntoConstraints = false

        let hubContentStack = UIStackView(arrangedSubviews: [
            hubHeaderStack,
            directIpLabel,
            ipInputContainer,
            directConnectButton,
            orDividerLabel,
            connectButton,
            indicatorStack
        ])
        hubContentStack.axis = .vertical
        hubContentStack.spacing = 12
        hubContentStack.alignment = .fill
        hubContentStack.translatesAutoresizingMaskIntoConstraints = false
        connectionHubCard.addSubview(hubContentStack)

        let guideHeaderSpacer = UIView()
        guideHeaderSpacer.translatesAutoresizingMaskIntoConstraints = false
        let guideHeaderStack = UIStackView(arrangedSubviews: [guideIconView, guideTitleLabel, guideHeaderSpacer])
        guideHeaderStack.axis = .horizontal
        guideHeaderStack.spacing = 8
        guideHeaderStack.alignment = .center
        guideHeaderStack.translatesAutoresizingMaskIntoConstraints = false

        setupGuideSteps()

        let guideContentStack = UIStackView(arrangedSubviews: [guideHeaderStack, guideStepsStack])
        guideContentStack.axis = .vertical
        guideContentStack.spacing = 16
        guideContentStack.alignment = .fill
        guideContentStack.translatesAutoresizingMaskIntoConstraints = false
        serverGuideCard.addSubview(guideContentStack)

        dashboardGridStack.addArrangedSubview(connectionHubCard)
        dashboardGridStack.addArrangedSubview(serverGuideCard)

        setupQuickSpecTiles()

        dashboardContentContainer.addSubview(headerContainerView)
        dashboardContentContainer.addSubview(connectionIssueBannerView)
        dashboardContentContainer.addSubview(dashboardGridStack)
        dashboardContentContainer.addSubview(quickSpecsHeaderLabel)
        dashboardContentContainer.addSubview(quickSpecsStack)

        homeContentView.addSubview(dashboardContentContainer)
        homeScrollView.addSubview(homeContentView)

        view.addSubview(videoContainerView)
        view.addSubview(homeScrollView)

        videoContainerView.isHidden = true
        homeScrollView.isHidden = false
    }

    private func setupGuideSteps() {
        let steps = [
            (icon: "gearshape.2.fill", tint: UIColor.systemIndigo, title: "1. Open Android Auto Settings", detail: "In phone Settings → Connected devices → Android Auto"),
            (icon: "checkmark.seal.fill", tint: UIColor.systemBlue, title: "2. Enable Developer Mode", detail: "Scroll down, tap 'Version' 10 times and confirm OK"),
            (icon: "play.tv.fill", tint: UIColor.systemGreen, title: "3. Start Head Unit Server", detail: "Tap top-right '⋮' menu in Android Auto & start server"),
            (icon: "personalhotspot", tint: UIColor.systemOrange, title: "4. Connect Hotspot & Launch", detail: "Connect iPad to phone hotspot Wi-Fi & tap Connect")
        ]

        for step in steps {
            let row = makeGuideStepRow(icon: step.icon, iconTint: step.tint, title: step.title, detail: step.detail)
            guideStepsStack.addArrangedSubview(row)
        }
    }

    private func makeGuideStepRow(icon: String, iconTint: UIColor, title: String, detail: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let badge = UIView()
        badge.backgroundColor = iconTint.withAlphaComponent(0.15)
        badge.layer.cornerRadius = 8
        badge.translatesAutoresizingMaskIntoConstraints = false

        let iv = UIImageView(image: UIImage(systemName: icon))
        iv.tintColor = iconTint
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(iv)

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLbl.textColor = .label
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        let detailLbl = UILabel()
        detailLbl.text = detail
        detailLbl.font = .systemFont(ofSize: 11, weight: .regular)
        detailLbl.textColor = .secondaryLabel
        detailLbl.numberOfLines = 2
        detailLbl.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLbl, detailLbl])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(badge)
        container.addSubview(textStack)

        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            badge.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 32),
            badge.heightAnchor.constraint(equalToConstant: 32),

            iv.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            iv.widthAnchor.constraint(equalToConstant: 18),
            iv.heightAnchor.constraint(equalToConstant: 18),

            textStack.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textStack.topAnchor.constraint(equalTo: container.topAnchor),
            textStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func setupQuickSpecTiles() {
        displayTile = QuickSpecTileView(icon: "display", title: "Display", tint: .systemBlue)
        displayTile.tag = 0
        displayTile.onTap = { [weak self, weak displayTile] _ in
            guard let self = self, let sender = displayTile else { return }
            self.presentQuickDisplayConfig(from: sender)
        }

        layoutTile = QuickSpecTileView(icon: "aspectratio", title: "Layout & DPI", tint: .systemPurple)
        layoutTile.tag = 1
        layoutTile.onTap = { [weak self, weak layoutTile] _ in
            guard let self = self, let sender = layoutTile else { return }
            self.presentQuickLayoutAndDpiModal(from: sender)
        }

        codecsTile = QuickSpecTileView(icon: "waveform.path.ecg", title: "Codecs", tint: .systemPink)
        codecsTile.tag = 2
        codecsTile.onTap = { [weak self, weak codecsTile] _ in
            guard let self = self, let sender = codecsTile else { return }
            self.presentQuickCodecsConfig(from: sender)
        }

        audioTile = QuickSpecTileView(icon: "speaker.wave.2.fill", title: "Audio Output", tint: .systemGreen)
        audioTile.tag = 3
        audioTile.onTap = { [weak self, weak audioTile] _ in
            guard let self = self, let sender = audioTile else { return }
            self.presentQuickAudioOutputConfig(from: sender)
        }

        micTile = QuickSpecTileView(icon: "mic.fill", title: "Microphone", tint: .systemTeal)
        micTile.tag = 4
        micTile.onTap = { [weak self, weak micTile] _ in
            guard let self = self, let sender = micTile else { return }
            self.presentQuickMicrophoneConfig(from: sender)
        }

        modeTile = QuickSpecTileView(icon: "moon.stars.fill", title: "Smart Mode", tint: .systemOrange)
        modeTile.tag = 5
        modeTile.onTap = { [weak self, weak modeTile] _ in
            guard let self = self, let sender = modeTile else { return }
            self.presentQuickSmartModeConfig(from: sender)
        }

        let topRow = UIStackView(arrangedSubviews: [displayTile, layoutTile, codecsTile])
        topRow.axis = .horizontal
        topRow.spacing = 10
        topRow.distribution = .fillEqually

        let bottomRow = UIStackView(arrangedSubviews: [audioTile, micTile, modeTile])
        bottomRow.axis = .horizontal
        bottomRow.spacing = 10
        bottomRow.distribution = .fillEqually

        quickSpecsStack.addArrangedSubview(topRow)
        quickSpecsStack.addArrangedSubview(bottomRow)
    }

    private func setupConstraints() {
        let containerMaxWidthConstraint = dashboardContentContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 1320)
        let containerWidthConstraint = dashboardContentContainer.widthAnchor.constraint(equalTo: homeContentView.safeAreaLayoutGuide.widthAnchor, constant: -64)
        containerWidthConstraint.priority = .defaultHigh

        let containerCenterY = dashboardContentContainer.centerYAnchor.constraint(equalTo: homeContentView.centerYAnchor)
        containerCenterY.priority = .defaultHigh

        NSLayoutConstraint.activate([
            videoContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            videoContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            videoRenderer.leadingAnchor.constraint(equalTo: videoContainerView.leadingAnchor),
            videoRenderer.trailingAnchor.constraint(equalTo: videoContainerView.trailingAnchor),
            videoRenderer.topAnchor.constraint(equalTo: videoContainerView.topAnchor),
            videoRenderer.bottomAnchor.constraint(equalTo: videoContainerView.bottomAnchor),

            touchOverlayView.leadingAnchor.constraint(equalTo: videoContainerView.leadingAnchor),
            touchOverlayView.trailingAnchor.constraint(equalTo: videoContainerView.trailingAnchor),
            touchOverlayView.topAnchor.constraint(equalTo: videoContainerView.topAnchor),
            touchOverlayView.bottomAnchor.constraint(equalTo: videoContainerView.bottomAnchor),

            performanceOverlayView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            performanceOverlayView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),

            homeScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            homeScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            homeScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            homeScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            homeContentView.leadingAnchor.constraint(equalTo: homeScrollView.contentLayoutGuide.leadingAnchor),
            homeContentView.trailingAnchor.constraint(equalTo: homeScrollView.contentLayoutGuide.trailingAnchor),
            homeContentView.topAnchor.constraint(equalTo: homeScrollView.contentLayoutGuide.topAnchor),
            homeContentView.bottomAnchor.constraint(equalTo: homeScrollView.contentLayoutGuide.bottomAnchor),
            homeContentView.widthAnchor.constraint(equalTo: homeScrollView.frameLayoutGuide.widthAnchor),
            homeContentView.heightAnchor.constraint(greaterThanOrEqualTo: homeScrollView.frameLayoutGuide.heightAnchor),

            dashboardContentContainer.centerXAnchor.constraint(equalTo: homeContentView.centerXAnchor),
            dashboardContentContainer.leadingAnchor.constraint(greaterThanOrEqualTo: homeContentView.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            dashboardContentContainer.trailingAnchor.constraint(lessThanOrEqualTo: homeContentView.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            dashboardContentContainer.topAnchor.constraint(greaterThanOrEqualTo: homeContentView.safeAreaLayoutGuide.topAnchor, constant: 24),
            dashboardContentContainer.bottomAnchor.constraint(lessThanOrEqualTo: homeContentView.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            homeContentView.bottomAnchor.constraint(greaterThanOrEqualTo: dashboardContentContainer.bottomAnchor, constant: 24),
            containerMaxWidthConstraint,
            containerWidthConstraint,
            containerCenterY,

            headerContainerView.topAnchor.constraint(equalTo: dashboardContentContainer.topAnchor),
            headerContainerView.leadingAnchor.constraint(equalTo: dashboardContentContainer.leadingAnchor),
            headerContainerView.trailingAnchor.constraint(equalTo: dashboardContentContainer.trailingAnchor),
            headerContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),

            appIconImageView.widthAnchor.constraint(equalToConstant: 44),
            appIconImageView.heightAnchor.constraint(equalToConstant: 44),
            statusPillView.heightAnchor.constraint(equalToConstant: 34),
            settingsButton.heightAnchor.constraint(equalToConstant: 34),
            settingsButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 112),

            hubIconView.widthAnchor.constraint(equalToConstant: 22),
            hubIconView.heightAnchor.constraint(equalToConstant: 22),
            guideIconView.widthAnchor.constraint(equalToConstant: 22),
            guideIconView.heightAnchor.constraint(equalToConstant: 22),

            headerContainerView.subviews[0].leadingAnchor.constraint(equalTo: headerContainerView.leadingAnchor),
            headerContainerView.subviews[0].centerYAnchor.constraint(equalTo: headerContainerView.centerYAnchor),
            headerContainerView.subviews[1].trailingAnchor.constraint(equalTo: headerContainerView.trailingAnchor),
            headerContainerView.subviews[1].centerYAnchor.constraint(equalTo: headerContainerView.centerYAnchor),
            headerContainerView.subviews[0].trailingAnchor.constraint(lessThanOrEqualTo: headerContainerView.subviews[1].leadingAnchor, constant: -8),

            connectionIssueBannerView.topAnchor.constraint(equalTo: headerContainerView.bottomAnchor, constant: 14),
            connectionIssueBannerView.leadingAnchor.constraint(equalTo: dashboardContentContainer.leadingAnchor),
            connectionIssueBannerView.trailingAnchor.constraint(equalTo: dashboardContentContainer.trailingAnchor),

            connectionIssueTitleLabel.topAnchor.constraint(equalTo: connectionIssueBannerView.topAnchor, constant: 12),
            connectionIssueTitleLabel.leadingAnchor.constraint(equalTo: connectionIssueBannerView.leadingAnchor, constant: 14),
            connectionIssueTitleLabel.trailingAnchor.constraint(equalTo: connectionIssueDismissButton.leadingAnchor, constant: -8),

            connectionIssueDismissButton.centerYAnchor.constraint(equalTo: connectionIssueTitleLabel.centerYAnchor),
            connectionIssueDismissButton.trailingAnchor.constraint(equalTo: connectionIssueBannerView.trailingAnchor, constant: -14),

            connectionIssueAdviceLabel.topAnchor.constraint(equalTo: connectionIssueTitleLabel.bottomAnchor, constant: 6),
            connectionIssueAdviceLabel.leadingAnchor.constraint(equalTo: connectionIssueBannerView.leadingAnchor, constant: 14),
            connectionIssueAdviceLabel.trailingAnchor.constraint(equalTo: connectionIssueBannerView.trailingAnchor, constant: -14),
            connectionIssueAdviceLabel.bottomAnchor.constraint(equalTo: connectionIssueBannerView.bottomAnchor, constant: -12),

            dashboardGridStack.topAnchor.constraint(equalTo: connectionIssueBannerView.bottomAnchor, constant: 16),
            dashboardGridStack.leadingAnchor.constraint(equalTo: dashboardContentContainer.leadingAnchor),
            dashboardGridStack.trailingAnchor.constraint(equalTo: dashboardContentContainer.trailingAnchor),
            dashboardGridStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 320),

            connectionHubCard.subviews[0].topAnchor.constraint(equalTo: connectionHubCard.topAnchor, constant: 20),
            connectionHubCard.subviews[0].leadingAnchor.constraint(equalTo: connectionHubCard.leadingAnchor, constant: 20),
            connectionHubCard.subviews[0].trailingAnchor.constraint(equalTo: connectionHubCard.trailingAnchor, constant: -20),
            connectionHubCard.subviews[0].bottomAnchor.constraint(equalTo: connectionHubCard.bottomAnchor, constant: -20),

            directIpTextField.heightAnchor.constraint(equalToConstant: 50),
            resetGatewayIpButton.widthAnchor.constraint(equalToConstant: 50),
            directConnectButton.heightAnchor.constraint(equalToConstant: 54),
            connectButton.heightAnchor.constraint(equalToConstant: 54),
            disconnectButton.heightAnchor.constraint(equalToConstant: 50),
            disconnectButton.widthAnchor.constraint(equalToConstant: 240),

            serverGuideCard.subviews[0].topAnchor.constraint(equalTo: serverGuideCard.topAnchor, constant: 20),
            serverGuideCard.subviews[0].leadingAnchor.constraint(equalTo: serverGuideCard.leadingAnchor, constant: 20),
            serverGuideCard.subviews[0].trailingAnchor.constraint(equalTo: serverGuideCard.trailingAnchor, constant: -20),
            serverGuideCard.subviews[0].bottomAnchor.constraint(equalTo: serverGuideCard.bottomAnchor, constant: -20),

            quickSpecsHeaderLabel.topAnchor.constraint(equalTo: dashboardGridStack.bottomAnchor, constant: 24),
            quickSpecsHeaderLabel.leadingAnchor.constraint(equalTo: dashboardContentContainer.leadingAnchor, constant: 4),
            quickSpecsHeaderLabel.trailingAnchor.constraint(equalTo: dashboardContentContainer.trailingAnchor),

            quickSpecsStack.topAnchor.constraint(equalTo: quickSpecsHeaderLabel.bottomAnchor, constant: 10),
            quickSpecsStack.leadingAnchor.constraint(equalTo: dashboardContentContainer.leadingAnchor),
            quickSpecsStack.trailingAnchor.constraint(equalTo: dashboardContentContainer.trailingAnchor),
            quickSpecsStack.bottomAnchor.constraint(equalTo: dashboardContentContainer.bottomAnchor, constant: -12)
        ])

        bannerZeroHeightConstraint = connectionIssueBannerView.heightAnchor.constraint(equalToConstant: 0)
        bannerZeroHeightConstraint?.isActive = true
    }

    func refreshQuickSpecTiles() {
        let res = ProjectionSettings.resolution.title
        let fps = ProjectionSettings.fpsLimit.title
        displayTile?.value = "\(res) • \(fps)"

        let fit = ProjectionSettings.videoFitMode.title
        let dpi = ProjectionSettings.isAutoDpi ? "Auto (\(ProjectionSettings.effectiveDpi))" : "\(ProjectionSettings.dpi) DPI"
        layoutTile?.value = "\(fit) • \(dpi)"

        let vCodec = ProjectionSettings.videoCodecPreference.title
        let aCodec = ProjectionSettings.audioCodecPreference.title
        codecsTile?.value = "\(vCodec) • \(aCodec)"

        let aOut = ProjectionSettings.audioOutputTarget.title
        audioTile?.value = "\(aOut)"

        let mic = ProjectionSettings.microphoneSource.title
        micTile?.value = "\(mic)"

        let night = ProjectionSettings.nightMode.title
        let rhd = (ProjectionSettings.driverPosition == .right) ? "RHD" : "LHD"
        modeTile?.value = "\(night) • \(rhd)"
    }

    private func updateUIForConnectionState(_ state: ConnectionState) {
        UIApplication.shared.isIdleTimerDisabled = (state == .running)

        let currentIp = NetworkAddresses.stationIpv4() ?? "No Wi-Fi"
        switch state {
        case .disconnected:
            stopVideoWatchdog()
            hasReceivedFirstVideoFrame = false
            videoContainerView.isHidden = true
            homeScrollView.isHidden = false
            view.bringSubviewToFront(homeScrollView)
            connectionManager.screenConfig.clearCustomNegotiatedResolution()
            videoRenderer.reset()
            audioPlayer.reset()
            settingsButton.isHidden = false
            if directIpTextField.text?.isEmpty ?? true {
                directIpTextField.text = NetworkAddresses.currentHotspotGatewayIpv4()
            }

            if connectionManager.isAutoReconnectScheduled {
                statusDotView.backgroundColor = .systemOrange
                statusLabel.text = connectionManager.statusDetail
                statusLabel.textColor = .systemOrange
                connectButton.isEnabled = false
                directConnectButton.isEnabled = false
                disconnectButton.isHidden = false
                activityIndicator.startAnimating()
            } else {
                let detail = connectionManager.statusDetail
                if detail.contains("No device found") || detail.contains("Search failed") || detail.contains("Failed after 3 retries") {
                    statusDotView.backgroundColor = .systemOrange
                    statusLabel.text = detail
                    statusLabel.textColor = .systemOrange
                } else {
                    statusDotView.backgroundColor = .systemGreen
                    statusLabel.text = "iPad IP: \(currentIp) • Ready"
                    statusLabel.textColor = .secondaryLabel
                }
                connectButton.isEnabled = true
                directConnectButton.isEnabled = true
                disconnectButton.isHidden = true
                activityIndicator.stopAnimating()
            }
            setNeedsStatusBarAppearanceUpdate()
            setNeedsUpdateOfHomeIndicatorAutoHidden()

        case .discovering:
            stopVideoWatchdog()
            videoContainerView.isHidden = true
            homeScrollView.isHidden = false
            view.bringSubviewToFront(homeScrollView)
            settingsButton.isHidden = false
            statusDotView.backgroundColor = .systemIndigo
            statusLabel.text = "Scanning Port 5277..."
            statusLabel.textColor = .systemIndigo
            connectButton.isEnabled = false
            directConnectButton.isEnabled = false
            disconnectButton.isHidden = false
            activityIndicator.startAnimating()
            setNeedsStatusBarAppearanceUpdate()
            setNeedsUpdateOfHomeIndicatorAutoHidden()

        case .waitingForWirelessHelper:
            stopVideoWatchdog()
            videoContainerView.isHidden = true
            homeScrollView.isHidden = false
            view.bringSubviewToFront(homeScrollView)
            settingsButton.isHidden = false
            statusDotView.backgroundColor = .systemOrange
            statusLabel.text = connectionManager.statusDetail.isEmpty ? "Waiting for wireless..." : connectionManager.statusDetail
            statusLabel.textColor = .systemOrange
            connectButton.isEnabled = false
            directConnectButton.isEnabled = false
            disconnectButton.isHidden = false
            activityIndicator.startAnimating()
            setNeedsStatusBarAppearanceUpdate()
            setNeedsUpdateOfHomeIndicatorAutoHidden()

        case .connecting:
            stopVideoWatchdog()
            videoContainerView.isHidden = true
            homeScrollView.isHidden = false
            view.bringSubviewToFront(homeScrollView)
            settingsButton.isHidden = false
            statusDotView.backgroundColor = .systemBlue
            statusLabel.text = "Connecting to \(connectionManager.connectedDevice?.displayName ?? "Phone")..."
            statusLabel.textColor = .systemBlue
            connectButton.isEnabled = false
            directConnectButton.isEnabled = false
            disconnectButton.isHidden = false
            activityIndicator.startAnimating()
            setNeedsStatusBarAppearanceUpdate()
            setNeedsUpdateOfHomeIndicatorAutoHidden()

        case .handshaking:
            stopVideoWatchdog()
            videoContainerView.isHidden = true
            homeScrollView.isHidden = false
            view.bringSubviewToFront(homeScrollView)
            settingsButton.isHidden = false
            statusDotView.backgroundColor = .systemBlue
            statusLabel.text = "Handshaking..."
            statusLabel.textColor = .systemBlue
            connectButton.isEnabled = false
            directConnectButton.isEnabled = false
            disconnectButton.isHidden = false
            activityIndicator.startAnimating()
            setNeedsStatusBarAppearanceUpdate()
            setNeedsUpdateOfHomeIndicatorAutoHidden()

        case .running:
            ConnectionIssueStore.shared.clearAll()
            startVideoWatchdog()
            homeScrollView.isHidden = true
            videoContainerView.isHidden = false
            view.bringSubviewToFront(videoContainerView)
            activityIndicator.stopAnimating()
            disconnectButton.isHidden = true
            view.layoutIfNeeded()
            videoContainerView.layoutIfNeeded()
            syncVideoAndTouchGeometry()
            videoRenderer.applyGeometry()
            setNeedsStatusBarAppearanceUpdate()
            setNeedsUpdateOfHomeIndicatorAutoHidden()

        case .disconnecting:
            stopVideoWatchdog()
            videoContainerView.isHidden = true
            homeScrollView.isHidden = false
            view.bringSubviewToFront(homeScrollView)
            audioPlayer.reset()
            settingsButton.isHidden = false
            statusDotView.backgroundColor = .systemGray
            statusLabel.text = "Disconnecting..."
            statusLabel.textColor = .secondaryLabel
            connectButton.isEnabled = false
            directConnectButton.isEnabled = false
            disconnectButton.isHidden = true
            activityIndicator.startAnimating()
            setNeedsStatusBarAppearanceUpdate()
            setNeedsUpdateOfHomeIndicatorAutoHidden()

        case .error(let message):
            let lower = message.lowercased()
            if lower.contains("5277") || lower.contains("refused") {
                ConnectionIssueStore.shared.raise(issue: .connectionRefused5277)
            } else if lower.contains("tls") || lower.contains("handshake") {
                ConnectionIssueStore.shared.raise(issue: .tlsHandshakeFailed)
            }
            stopVideoWatchdog()
            videoContainerView.isHidden = true
            homeScrollView.isHidden = false
            view.bringSubviewToFront(homeScrollView)
            audioPlayer.reset()
            settingsButton.isHidden = false

            if connectionManager.isAutoReconnectScheduled {
                statusDotView.backgroundColor = .systemOrange
                statusLabel.text = connectionManager.statusDetail
                statusLabel.textColor = .systemOrange
                connectButton.isEnabled = false
                directConnectButton.isEnabled = false
                disconnectButton.isHidden = false
                activityIndicator.startAnimating()
            } else {
                statusDotView.backgroundColor = .systemRed
                statusLabel.text = connectionManager.statusDetail.isEmpty ? message : connectionManager.statusDetail
                statusLabel.textColor = .systemRed
                connectButton.isEnabled = true
                directConnectButton.isEnabled = true
                disconnectButton.isHidden = true
                activityIndicator.stopAnimating()
            }
            setNeedsStatusBarAppearanceUpdate()
            setNeedsUpdateOfHomeIndicatorAutoHidden()
        }

        updatePerformanceOverlayState()
        updateConnectionIssueBanner()
        refreshQuickSpecTiles()
    }

    override var prefersStatusBarHidden: Bool {
        return connectionManager.state == .running
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return connectionManager.state == .running
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

    @objc private func connectButtonTapped() {
        connectionManager.startDiscovery()
    }

    @objc private func directConnectButtonTapped() {
        guard let targetIp = directIpTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !targetIp.isEmpty else {
            return
        }
        connectionManager.connect(to: targetIp, port: Discovery.headunitPort)
    }

    @objc private func disconnectButtonTapped() {
        connectionManager.screenConfig.clearCustomNegotiatedResolution()
        connectionManager.disconnect()
    }

    @objc func settingsButtonTapped() {
        presentSettingsMenu()
    }

    func presentSettingsMenu() {
        let settingsVC = SettingsViewController()
        settingsVC.connectionManager = connectionManager
        settingsVC.onSettingsChanged = { [weak self] impact in
            guard let self = self else { return }
            self.refreshQuickSpecTiles()
            switch impact {
            case .uiOnly:
                self.updatePerformanceOverlayState()
            case .nightModeChanged:
                self.connectionManager.updateNightMode(userInterfaceStyle: self.traitCollection.userInterfaceStyle, force: true)
            case .geometryChanged:
                self.applyOrientationLock()
                self.syncVideoAndTouchGeometry()
                self.videoRenderer.applyGeometry()
            case .requiresReconnect:
                if self.connectionManager.state == .running {
                    self.connectionManager.reconnectForSettingsChange()
                }
            }
        }
        settingsVC.onProvideDiagnosticLines = { [weak self] in
            self?.combinedDiagnosticLines() ?? []
        }

        let nav = UINavigationController(rootViewController: settingsVC)
        nav.modalPresentationStyle = .formSheet
        nav.preferredContentSize = CGSize(width: 640, height: 740)
        present(nav, animated: true)
    }

    private func combinedDiagnosticLines() -> [String] {
        connectionManager.diagnosticLines()
            + [""]
            + videoRenderer.diagnosticLines()
    }

    func presentQuickDisplayConfig(from sender: UIView) {
        let alert = UIAlertController(
            title: "Display Configuration",
            message: "Choose video resolution and maximum frame rate.",
            preferredStyle: .actionSheet
        )
        alert.popoverPresentationController?.sourceView = sender
        alert.popoverPresentationController?.sourceRect = sender.bounds

        let resolutions: [(title: String, res: ResolutionPreset)] = [
            ("Auto (Recommended)", .auto),
            ("720p (1280×720)", .r1280x720),
            ("1080p (1920×1080)", .r1920x1080),
            ("1440p (2560×1440)", .r2560x1440),
            ("4K (3840×2160)", .r3840x2160)
        ]

        for item in resolutions {
            let isCurrent = (ProjectionSettings.resolution == item.res)
            let prefix = isCurrent ? "✓ " : ""
            alert.addAction(UIAlertAction(title: "\(prefix)\(item.title)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                ProjectionSettings.resolution = item.res
                self.refreshQuickSpecTiles()
                if self.connectionManager.state == .running {
                    self.connectionManager.reconnectForSettingsChange()
                }
            })
        }

        let fpsOptions: [(title: String, fps: ProjectionFpsLimit)] = [
            ("Frame Rate: 60 FPS", .fps60),
            ("Frame Rate: 30 FPS", .fps30)
        ]
        for item in fpsOptions {
            let isCurrent = (ProjectionSettings.fpsLimit == item.fps)
            let prefix = isCurrent ? "✓ " : ""
            alert.addAction(UIAlertAction(title: "\(prefix)\(item.title)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                ProjectionSettings.fpsLimit = item.fps
                self.refreshQuickSpecTiles()
                if self.connectionManager.state == .running {
                    self.connectionManager.reconnectForSettingsChange()
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func presentQuickLayoutAndDpiModal(from sender: UIView? = nil) {
        let vc = QuickLayoutDpiViewController()
        vc.connectionManager = connectionManager
        vc.onSettingsChanged = { [weak self] in
            guard let self = self else { return }
            self.refreshQuickSpecTiles()
            self.syncVideoAndTouchGeometry()
            self.videoRenderer.applyGeometry()
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        nav.preferredContentSize = CGSize(width: 560, height: 500)
        if let pop = nav.popoverPresentationController, let source = sender {
            pop.sourceView = source
            pop.sourceRect = source.bounds
        }
        present(nav, animated: true)
    }

    func presentQuickCodecsConfig(from sender: UIView) {
        let alert = UIAlertController(
            title: "Codecs Configuration",
            message: "Select video decoding and audio stream codecs.",
            preferredStyle: .actionSheet
        )
        alert.popoverPresentationController?.sourceView = sender
        alert.popoverPresentationController?.sourceRect = sender.bounds

        let videoOptions: [(title: String, val: VideoCodecPreference)] = [
            ("Video: H.264 (AVC - Standard)", .h264),
            ("Video: HEVC (H.265 - Efficient)", .hevc)
        ]
        for item in videoOptions {
            let isCurrent = (ProjectionSettings.videoCodecPreference == item.val)
            let prefix = isCurrent ? "✓ " : ""
            alert.addAction(UIAlertAction(title: "\(prefix)\(item.title)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                ProjectionSettings.videoCodecPreference = item.val
                self.refreshQuickSpecTiles()
                if self.connectionManager.state == .running {
                    self.connectionManager.reconnectForSettingsChange()
                }
            })
        }

        let audioOptions: [(title: String, val: AudioCodecPreference)] = [
            ("Audio: AAC-LC (Compressed)", .aac),
            ("Audio: PCM (Uncompressed)", .pcm)
        ]
        for item in audioOptions {
            let isCurrent = (ProjectionSettings.audioCodecPreference == item.val)
            let prefix = isCurrent ? "✓ " : ""
            alert.addAction(UIAlertAction(title: "\(prefix)\(item.title)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                ProjectionSettings.audioCodecPreference = item.val
                self.refreshQuickSpecTiles()
                if self.connectionManager.state == .running {
                    self.connectionManager.reconnectForSettingsChange()
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func presentQuickAudioOutputConfig(from sender: UIView) {
        let alert = UIAlertController(
            title: "Audio Output Destination",
            message: "Choose where Android Auto audio plays.",
            preferredStyle: .actionSheet
        )
        alert.popoverPresentationController?.sourceView = sender
        alert.popoverPresentationController?.sourceRect = sender.bounds

        let targets: [(title: String, target: AudioOutputTarget)] = [
            ("iPad (Speaker / iPad BT Headset)", .ipad),
            ("Phone (Original Device / Car BT)", .phone)
        ]
        for item in targets {
            let isCurrent = (ProjectionSettings.audioOutputTarget == item.target)
            let prefix = isCurrent ? "✓ " : ""
            alert.addAction(UIAlertAction(title: "\(prefix)\(item.title)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                ProjectionSettings.audioOutputTarget = item.target
                if !item.target.isAudioSinkEnabled {
                    PCMAudioPlayer.shared.reset()
                }
                self.refreshQuickSpecTiles()
                if self.connectionManager.state == .running {
                    self.connectionManager.reconnectForSettingsChange()
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func presentQuickMicrophoneConfig(from sender: UIView) {
        let alert = UIAlertController(
            title: "Microphone Source",
            message: "Select audio capture device for Google Voice Assistant.",
            preferredStyle: .actionSheet
        )
        alert.popoverPresentationController?.sourceView = sender
        alert.popoverPresentationController?.sourceRect = sender.bounds

        let sources: [(title: String, src: MicrophoneSource)] = [
            ("Follow Audio Output (Automatic)", .followAudioOutput),
            ("iPad Microphone", .ipad),
            ("Phone / Car BT Mic", .phone)
        ]
        for item in sources {
            let isCurrent = (ProjectionSettings.microphoneSource == item.src)
            let prefix = isCurrent ? "✓ " : ""
            alert.addAction(UIAlertAction(title: "\(prefix)\(item.title)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                ProjectionSettings.microphoneSource = item.src
                self.refreshQuickSpecTiles()
                if self.connectionManager.state == .running {
                    self.connectionManager.reconnectForSettingsChange()
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func presentQuickSmartModeConfig(from sender: UIView) {
        let alert = UIAlertController(
            title: "Smart Mode & Driver Position",
            message: "Configure Day/Night theme and cockpit orientation.",
            preferredStyle: .actionSheet
        )
        alert.popoverPresentationController?.sourceView = sender
        alert.popoverPresentationController?.sourceRect = sender.bounds

        let nightModes: [(title: String, mode: NightModeSetting)] = [
            ("Auto Day/Night (07:00–19:00)", .auto),
            ("Twilight (Sunrise / Sunset)", .twilight),
            ("Always Day Mode", .day),
            ("Always Night Mode", .night),
            ("Follow iOS System Appearance", .system)
        ]
        for item in nightModes {
            let isCurrent = (ProjectionSettings.nightMode == item.mode)
            let prefix = isCurrent ? "✓ " : ""
            alert.addAction(UIAlertAction(title: "\(prefix)\(item.title)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                ProjectionSettings.nightMode = item.mode
                self.connectionManager.updateNightMode(userInterfaceStyle: self.traitCollection.userInterfaceStyle, force: true)
                self.refreshQuickSpecTiles()
            })
        }

        let positions: [(title: String, isRhd: Bool)] = [
            ("Driver: Left Hand Drive (LHD)", false),
            ("Driver: Right Hand Drive (RHD)", true)
        ]
        for item in positions {
            let isCurrent = (ProjectionSettings.driverPosition == (item.isRhd ? .right : .left))
            let prefix = isCurrent ? "✓ " : ""
            alert.addAction(UIAlertAction(title: "\(prefix)\(item.title)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                ProjectionSettings.driverPosition = item.isRhd ? .right : .left
                self.refreshQuickSpecTiles()
                if self.connectionManager.state == .running {
                    self.connectionManager.reconnectForSettingsChange()
                }
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func updatePerformanceOverlayState() {
        let shouldShow = ProjectionSettings.showPerformanceOverlay && connectionManager.state == .running
        performanceOverlayView.isHidden = !shouldShow
        if shouldShow {
            if performanceTimer == nil {
                performanceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    self?.refreshPerformanceOverlay()
                }
            }
            refreshPerformanceOverlay()
        } else {
            performanceTimer?.invalidate()
            performanceTimer = nil
        }
    }

    private func refreshPerformanceOverlay() {
        guard !performanceOverlayView.isHidden else { return }
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
    }

    private func updateConnectionIssueBanner() {
        let standing = ConnectionIssueStore.shared.currentIssues()
        let isConnected = (connectionManager.state == .running)
        if let issue = ConnectionIssueBannerPolicy.bannerFor(
            standing: standing,
            sessionConnected: isConnected,
            dismissedAtEpochMs: dismissedIssueEpochMs
        ) {
            connectionIssueTitleLabel.text = issue.issue.title
            connectionIssueAdviceLabel.text = issue.issue.resolutionAdvice
            connectionIssueBannerView.isHidden = false
            bannerZeroHeightConstraint?.isActive = false
        } else {
            connectionIssueBannerView.isHidden = true
            bannerZeroHeightConstraint?.isActive = true
        }
    }

    @objc private func dismissConnectionIssueBanner() {
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
            let ipText = snapshot.stationIpv4 ?? "No Wi-Fi"
            if self.connectionManager.state == .disconnected && !self.connectionManager.isAutoReconnectScheduled {
                let detail = self.connectionManager.statusDetail
                if detail.contains("No device found") || detail.contains("Search failed") || detail.contains("Failed after 3 retries") {
                    // Keep failure advice
                } else {
                    self.statusLabel.text = "iPad IP: \(ipText) • Ready"
                }
            }
            if let gw = snapshot.gatewayIpv4, !gw.isEmpty {
                let current = self.directIpTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if current.isEmpty || current.hasSuffix(".1") || current == "192.168.43.1" {
                    self.directIpTextField.text = gw
                }
            }
            self.updateConnectionIssueBanner()
        }
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard connectionManager.state == .running else {
            super.pressesBegan(presses, with: event)
            return
        }
        if directIpTextField.isFirstResponder {
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
        if !handled {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard connectionManager.state == .running else {
            super.pressesEnded(presses, with: event)
            return
        }
        if directIpTextField.isFirstResponder {
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
        if !handled {
            super.pressesEnded(presses, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard connectionManager.state == .running else {
            super.pressesCancelled(presses, with: event)
            return
        }
        if directIpTextField.isFirstResponder {
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
        if !handled {
            super.pressesCancelled(presses, with: event)
        }
    }
}

extension MainViewController: ConnectionManagerDelegate {
    func connectionManager(_ manager: ConnectionManager, didChangeState state: ConnectionState) {
        if Thread.isMainThread {
            self.updateUIForConnectionState(state)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.updateUIForConnectionState(state)
            }
        }
    }

    func connectionManager(_ manager: ConnectionManager, didUpdateStatus status: String) {
        let update = { [weak self] in
            guard let self = self else { return }
            if self.connectionManager.state != .running {
                self.statusLabel.text = status
            }
        }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    func connectionManager(_ manager: ConnectionManager, didDiscoverDevice device: DiscoveredDevice) {
        let update = { [weak self] in
            guard let self = self else { return }
            self.statusLabel.text = "Found \(device.displayName), connecting..."
            self.updateConnectionIssueBanner()
        }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
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

final class QuickSpecTileView: UIControl {

    var onTap: ((UIView) -> Void)?

    var value: String = "" {
        didSet {
            valueLabel.text = value
        }
    }

    private let iconBadgeView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 10
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .bold)
        l.textColor = .label
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.8
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    init(icon: String, title: String, tint: UIColor) {
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = UIColor.separator.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        iconBadgeView.backgroundColor = tint.withAlphaComponent(0.15)
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = tint
        titleLabel.text = title

        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        iconBadgeView.addSubview(iconImageView)
        let textStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let rowStack = UIStackView(arrangedSubviews: [iconBadgeView, textStack])
        rowStack.axis = .horizontal
        rowStack.spacing = 12
        rowStack.alignment = .center
        rowStack.isUserInteractionEnabled = false
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(rowStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 78),

            iconBadgeView.widthAnchor.constraint(equalToConstant: 38),
            iconBadgeView.heightAnchor.constraint(equalToConstant: 38),

            iconImageView.centerXAnchor.constraint(equalTo: iconBadgeView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBadgeView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),

            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])

        addTarget(self, action: #selector(tileTapped), for: .touchUpInside)
    }

    @objc private func tileTapped() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        onTap?(self)
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.alpha = self.isHighlighted ? 0.7 : 1.0
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            }
        }
    }
}

final class QuickLayoutDpiViewController: UIViewController {

    var onSettingsChanged: (() -> Void)?
    var connectionManager: ConnectionManager = ConnectionManager.shared

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceVertical = false
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let previewView: DpiPreviewView = {
        let v = DpiPreviewView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let fitModeSegmentedControl: UISegmentedControl = {
        let seg = UISegmentedControl(items: ["Fill Margin", "Fit (Letterbox)", "Stretch"])
        seg.translatesAutoresizingMaskIntoConstraints = false
        return seg
    }()

    private let driverPositionSegmentedControl: UISegmentedControl = {
        let seg = UISegmentedControl(items: ["LHD (Left)", "RHD (Right)"])
        seg.translatesAutoresizingMaskIntoConstraints = false
        return seg
    }()

    private let autoDpiLabel: UILabel = {
        let l = UILabel()
        l.text = "Auto Recommended DPI"
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let autoDpiSwitch: UISwitch = {
        let s = UISwitch()
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let dpiValueLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        l.textColor = .label
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let dpiSlider: UISlider = {
        let s = UISlider()
        s.minimumValue = 100
        s.maximumValue = 320
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let presetStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        syncWithCurrentSettings()
    }

    private func setupUI() {
        title = "Layout & DPI Configuration"
        view.backgroundColor = .systemGroupedBackground
        preferredContentSize = CGSize(width: 560, height: 500)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            previewView.heightAnchor.constraint(equalToConstant: 260)
        ])

        contentStack.addArrangedSubview(previewView)

        let fitLabel = UILabel()
        fitLabel.text = "Display Fit Mode"
        fitLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        fitLabel.textColor = .secondaryLabel
        contentStack.addArrangedSubview(fitLabel)
        contentStack.addArrangedSubview(fitModeSegmentedControl)

        let driverLabel = UILabel()
        driverLabel.text = "Driving Position"
        driverLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        driverLabel.textColor = .secondaryLabel
        contentStack.addArrangedSubview(driverLabel)
        contentStack.addArrangedSubview(driverPositionSegmentedControl)

        let autoDpiRow = UIStackView(arrangedSubviews: [autoDpiLabel, autoDpiSwitch])
        autoDpiRow.axis = .horizontal
        autoDpiRow.alignment = .center
        autoDpiRow.distribution = .equalSpacing
        contentStack.addArrangedSubview(autoDpiRow)

        contentStack.addArrangedSubview(dpiValueLabel)
        contentStack.addArrangedSubview(dpiSlider)

        contentStack.addArrangedSubview(presetStackView)
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

        fitModeSegmentedControl.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let modes: [VideoFitMode] = [.fillMargin, .contain, .stretch]
            let chosen = modes[self.fitModeSegmentedControl.selectedSegmentIndex]
            ProjectionSettings.videoFitMode = chosen
            HeadUnitScreenConfig.shared.videoFitMode = chosen
            HeadUnitScreenConfig.shared.recalculate()
            HeadUnitScreenConfig.shared.checkAndNotifyMarginDivergence()
            self.previewView.fitMode = chosen
            self.onSettingsChanged?()
            if self.connectionManager.state == .running {
                self.connectionManager.reconnectForSettingsChange()
            }
        }, for: .valueChanged)

        driverPositionSegmentedControl.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            let isRhd = self.driverPositionSegmentedControl.selectedSegmentIndex == 1
            ProjectionSettings.driverPosition = isRhd ? .right : .left
            self.previewView.isRightHandDrive = isRhd
            self.onSettingsChanged?()
            if self.connectionManager.state == .running {
                self.connectionManager.reconnectForSettingsChange()
            }
        }, for: .valueChanged)

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
    }

    private func syncWithCurrentSettings() {
        let dims = HeadUnitScreenConfig.currentIpadDimensions()
        previewView.panelWidthPx = dims.width > 0 ? dims.width : 1920
        previewView.panelHeightPx = dims.height > 0 ? dims.height : 1080
        let cfg = HeadUnitScreenConfig.shared
        previewView.activeWidthPx = cfg.negotiatedWidth
        previewView.activeHeightPx = cfg.negotiatedHeight
        previewView.marginWidthPx = cfg.announcedWidthMargin >= 0 ? cfg.announcedWidthMargin : cfg.getWidthMargin()
        previewView.marginHeightPx = cfg.announcedHeightMargin >= 0 ? cfg.announcedHeightMargin : cfg.getHeightMargin()
        previewView.fitMode = ProjectionSettings.videoFitMode
        previewView.isRightHandDrive = (ProjectionSettings.driverPosition == .right)
        previewView.dpi = ProjectionSettings.effectiveDpi

        switch ProjectionSettings.videoFitMode {
        case .fillMargin:
            fitModeSegmentedControl.selectedSegmentIndex = 0
        case .contain, .fill, .cover:
            fitModeSegmentedControl.selectedSegmentIndex = 1
        case .stretch:
            fitModeSegmentedControl.selectedSegmentIndex = 2
        }

        driverPositionSegmentedControl.selectedSegmentIndex = (ProjectionSettings.driverPosition == .right) ? 1 : 0
        autoDpiSwitch.isOn = ProjectionSettings.isAutoDpi
        let currentDpi = ProjectionSettings.effectiveDpi
        dpiSlider.value = Float(currentDpi)
        updateDpiLabel(val: currentDpi, isAuto: ProjectionSettings.isAutoDpi)
    }

    private func applyDpi(val: Int, isAuto: Bool) {
        ProjectionSettings.isAutoDpi = isAuto
        ProjectionSettings.dpi = val
        autoDpiSwitch.isOn = isAuto
        dpiSlider.value = Float(val)
        previewView.dpi = val
        updateDpiLabel(val: val, isAuto: isAuto)
        onSettingsChanged?()
        if connectionManager.state == .running {
            connectionManager.reconnectForSettingsChange()
        }
    }

    private func updateDpiLabel(val: Int, isAuto: Bool) {
        let wDp = previewView.virtualWidthDp
        let hDp = previewView.virtualHeightDp
        let coolwalkStr = previewView.isCoolwalkSplitScreen ? "Split Screen" : "Single Card"
        if isAuto {
            dpiValueLabel.text = "\(val) DPI (Auto) • \(wDp)×\(hDp) dp • \(coolwalkStr)"
        } else {
            dpiValueLabel.text = "\(val) DPI • \(wDp)×\(hDp) dp • \(coolwalkStr)"
        }
    }

    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
}
