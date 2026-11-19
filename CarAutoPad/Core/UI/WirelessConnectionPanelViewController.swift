import UIKit

/// Tab 0: Wireless Connection Entry Page (Figma 01 Ready, 02 Scanning + Issue + Expanded Steps, 03 Portrait)
final class WirelessConnectionPanelViewController: UIViewController {
    var onStartDiscovery: (() -> Void)?
    var onCancelDiscovery: (() -> Void)?
    var onDirectConnect: ((String) -> Void)?
    var onDismissIssueBanner: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    let pageTitleLabel = CarAutoPadTheme.makePageTitleLabel(L10n.sidebarWirelessConnection, size: 30)

    // Warm Restrained Diagnostic Issue Banner (Figma 02)
    let issueBannerCard: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.accessibilityIdentifier = "connectionIssueBanner"
        v.backgroundColor = CarAutoPadTheme.warningSurface
        v.layer.cornerRadius = 16
        v.layer.cornerCurve = .continuous
        v.isHidden = true
        return v
    }()
    let issueTitleLabel = UILabel()
    let issueAdviceLabel = UILabel()
    private let issueDismissButton = UIButton(type: .system)

    // Hero Entry Card with 68pt Big Primary CTA (Figma 01 / 02 / 03)
    let heroCard = CarAutoPadTheme.makeCard(cornerRadius: 24)
    let heroTitleLabel = UILabel()
    let heroSubtitleLabel = UILabel()
    let heroPrimaryButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.accessibilityIdentifier = "scanHeadunitPrimaryButton"
        btn.layer.cornerRadius = 18
        btn.layer.cornerCurve = .continuous
        return btn
    }()

    // Scanning State Bar (exact same 68pt height — zero layout jump!)
    let scanningBarContainer = UIStackView()
    private let scanningStatusPill = UIView()
    let scanningSpinner = UIActivityIndicatorView(style: .medium)
    let scanningStatusLabel = UILabel()
    let cancelScanButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.accessibilityIdentifier = "cancelScanButton"
        btn.layer.cornerRadius = 18
        btn.layer.cornerCurve = .continuous
        btn.backgroundColor = CarAutoPadTheme.accentRed.withAlphaComponent(0.16)
        btn.setTitleColor(CarAutoPadTheme.accentRed, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        btn.titleLabel?.adjustsFontSizeToFitWidth = true
        btn.titleLabel?.minimumScaleFactor = 0.75
        return btn
    }()

    // Compact Hotspot Direct IP Card
    private let directIpCard = CarAutoPadTheme.makeCard(cornerRadius: 20)
    private let directIpLayoutStack = UIStackView()
    let directIpTitleLabel = UILabel()
    let directIpSubtitleLabel = UILabel()
    let directIpTextField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.accessibilityIdentifier = "directIpTextField"
        tf.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        tf.textColor = .label
        tf.keyboardType = .numbersAndPunctuation
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.returnKeyType = .go
        tf.text = NetworkAddresses.currentHotspotGatewayIpv4()
        return tf
    }()
    private let resetIpButton = UIButton(type: .system)
    let directConnectButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.accessibilityIdentifier = "directConnectButton"
        btn.layer.cornerRadius = 12
        btn.layer.cornerCurve = .continuous
        return btn
    }()

    // Collapsible Android Phone Setup Steps Disclosure Card (default collapsed per Figma 01/03; expanded on 02)
    let guideDisclosureCard = CarAutoPadTheme.makeCard(cornerRadius: 20)
    let guideHeaderControl = UIControl()
    let guideTitleLabel = UILabel()
    let guideCountBadgeLabel = UILabel()
    private let guideChevronView = UIImageView()
    let guideStepsContainer = UIStackView()
    let guideStepsStack = UIStackView()

    private(set) var isGuideStepsExpanded: Bool = false
    private var didUserManuallyToggleGuide: Bool = false
    private var lastState: ConnectionState = .disconnected
    private var contentLeadingConstraint: NSLayoutConstraint?
    private var contentTrailingConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = CarAutoPadTheme.canvas
        setupUI()
        applyLocalization()
        setGuideStepsExpanded(false, animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let compact = view.bounds.width < 600
        let sideInset: CGFloat = compact ? 24 : 48
        if contentLeadingConstraint?.constant != sideInset {
            contentLeadingConstraint?.constant = sideInset
            contentTrailingConstraint?.constant = -sideInset
        }
        let targetAxis: NSLayoutConstraint.Axis = compact ? .vertical : .horizontal
        if directIpLayoutStack.axis != targetAxis {
            directIpLayoutStack.axis = targetAxis
            directIpLayoutStack.alignment = compact ? .fill : .center
        }
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 20
        contentStack.alignment = .fill
        scrollView.addSubview(contentStack)

        let leading = contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 48)
        let trailing = contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -48)
        contentLeadingConstraint = leading
        contentTrailingConstraint = trailing

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 34),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -36),
            leading,
            trailing
        ])

        contentStack.addArrangedSubview(pageTitleLabel)
        setupIssueBanner()
        setupHeroEntryCard()
        setupDirectIpCard()
        setupCollapsibleGuideCard()
    }

    private func setupIssueBanner() {
        let warnIcon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)))
        warnIcon.tintColor = CarAutoPadTheme.accentOrange
        warnIcon.setContentHuggingPriority(.required, for: .horizontal)

        issueTitleLabel.font = .systemFont(ofSize: 14, weight: .bold)
        issueTitleLabel.textColor = CarAutoPadTheme.warningTitle
        issueTitleLabel.numberOfLines = 0

        issueAdviceLabel.font = .systemFont(ofSize: 12, weight: .regular)
        issueAdviceLabel.textColor = UIColor.label.withAlphaComponent(0.75)
        issueAdviceLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [issueTitleLabel, issueAdviceLabel])
        textStack.axis = .vertical
        textStack.spacing = 3

        issueDismissButton.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)), for: .normal)
        issueDismissButton.tintColor = .secondaryLabel
        issueDismissButton.setContentHuggingPriority(.required, for: .horizontal)
        issueDismissButton.addTarget(self, action: #selector(dismissIssueTapped), for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [warnIcon, textStack, issueDismissButton])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        issueBannerCard.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: issueBannerCard.topAnchor, constant: 13),
            row.bottomAnchor.constraint(equalTo: issueBannerCard.bottomAnchor, constant: -13),
            row.leadingAnchor.constraint(equalTo: issueBannerCard.leadingAnchor, constant: 18),
            row.trailingAnchor.constraint(equalTo: issueBannerCard.trailingAnchor, constant: -16)
        ])

        contentStack.addArrangedSubview(issueBannerCard)
    }

    private func setupHeroEntryCard() {
        heroTitleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        heroTitleLabel.textColor = .label
        heroTitleLabel.adjustsFontSizeToFitWidth = true
        heroTitleLabel.minimumScaleFactor = 0.8

        heroSubtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        heroSubtitleLabel.textColor = .secondaryLabel
        heroSubtitleLabel.numberOfLines = 0

        let headerStack = UIStackView(arrangedSubviews: [heroTitleLabel, heroSubtitleLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 5

        // Big 68pt Ready Primary CTA Button
        var ctaCfg = UIButton.Configuration.filled()
        ctaCfg.baseBackgroundColor = CarAutoPadTheme.accentBlue
        ctaCfg.baseForegroundColor = .white
        ctaCfg.cornerStyle = .fixed
        ctaCfg.background.cornerRadius = 18
        ctaCfg.image = UIImage(systemName: "dot.radiowaves.left.and.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .semibold))
        ctaCfg.imagePadding = 10
        ctaCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 19, weight: .bold)
            return out
        }
        heroPrimaryButton.configuration = ctaCfg
        heroPrimaryButton.addTarget(self, action: #selector(primaryScanTapped), for: .touchUpInside)
        heroPrimaryButton.heightAnchor.constraint(equalToConstant: 68).isActive = true

        // Scanning 68pt Row (Progress Pill + Cancel Button)
        scanningBarContainer.axis = .horizontal
        scanningBarContainer.spacing = 12
        scanningBarContainer.alignment = .fill
        scanningBarContainer.isHidden = true

        scanningStatusPill.translatesAutoresizingMaskIntoConstraints = false
        scanningStatusPill.backgroundColor = CarAutoPadTheme.elevated
        scanningStatusPill.layer.cornerRadius = 18
        scanningStatusPill.layer.cornerCurve = .continuous

        scanningSpinner.color = .secondaryLabel
        scanningSpinner.hidesWhenStopped = true

        scanningStatusLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        scanningStatusLabel.textColor = .label
        scanningStatusLabel.adjustsFontSizeToFitWidth = true
        scanningStatusLabel.minimumScaleFactor = 0.72

        let pillInner = UIStackView(arrangedSubviews: [scanningSpinner, scanningStatusLabel])
        pillInner.translatesAutoresizingMaskIntoConstraints = false
        pillInner.axis = .horizontal
        pillInner.spacing = 12
        pillInner.alignment = .center
        scanningStatusPill.addSubview(pillInner)
        NSLayoutConstraint.activate([
            scanningStatusPill.heightAnchor.constraint(equalToConstant: 68),
            pillInner.centerXAnchor.constraint(equalTo: scanningStatusPill.centerXAnchor),
            pillInner.centerYAnchor.constraint(equalTo: scanningStatusPill.centerYAnchor),
            pillInner.leadingAnchor.constraint(greaterThanOrEqualTo: scanningStatusPill.leadingAnchor, constant: 16),
            pillInner.trailingAnchor.constraint(lessThanOrEqualTo: scanningStatusPill.trailingAnchor, constant: -16)
        ])

        cancelScanButton.addTarget(self, action: #selector(cancelScanTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            cancelScanButton.heightAnchor.constraint(equalToConstant: 68),
            cancelScanButton.widthAnchor.constraint(equalToConstant: 132)
        ])

        scanningBarContainer.addArrangedSubview(scanningStatusPill)
        scanningBarContainer.addArrangedSubview(cancelScanButton)

        let heroStack = UIStackView(arrangedSubviews: [headerStack, heroPrimaryButton, scanningBarContainer])
        heroStack.translatesAutoresizingMaskIntoConstraints = false
        heroStack.axis = .vertical
        heroStack.spacing = 20
        heroCard.addSubview(heroStack)

        NSLayoutConstraint.activate([
            heroStack.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 26),
            heroStack.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -26),
            heroStack.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 26),
            heroStack.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -26)
        ])

        contentStack.addArrangedSubview(heroCard)
    }

    private func setupDirectIpCard() {
        directIpTitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        directIpTitleLabel.textColor = .label

        directIpSubtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        directIpSubtitleLabel.textColor = .secondaryLabel
        directIpSubtitleLabel.numberOfLines = 0

        let leftStack = UIStackView(arrangedSubviews: [directIpTitleLabel, directIpSubtitleLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 3

        let ipFieldPill = UIView()
        ipFieldPill.translatesAutoresizingMaskIntoConstraints = false
        ipFieldPill.backgroundColor = CarAutoPadTheme.elevated
        ipFieldPill.layer.cornerRadius = 12
        ipFieldPill.layer.cornerCurve = .continuous

        resetIpButton.setImage(UIImage(systemName: "arrow.counterclockwise", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)), for: .normal)
        resetIpButton.tintColor = .secondaryLabel
        resetIpButton.setContentHuggingPriority(.required, for: .horizontal)
        resetIpButton.addTarget(self, action: #selector(resetGatewayIpTapped), for: .touchUpInside)

        directIpTextField.addTarget(self, action: #selector(directConnectTapped), for: .editingDidEndOnExit)

        let fieldInner = UIStackView(arrangedSubviews: [directIpTextField, resetIpButton])
        fieldInner.translatesAutoresizingMaskIntoConstraints = false
        fieldInner.axis = .horizontal
        fieldInner.spacing = 8
        fieldInner.alignment = .center
        ipFieldPill.addSubview(fieldInner)
        NSLayoutConstraint.activate([
            ipFieldPill.heightAnchor.constraint(equalToConstant: 40),
            ipFieldPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 162),
            fieldInner.leadingAnchor.constraint(equalTo: ipFieldPill.leadingAnchor, constant: 14),
            fieldInner.trailingAnchor.constraint(equalTo: ipFieldPill.trailingAnchor, constant: -10),
            fieldInner.centerYAnchor.constraint(equalTo: ipFieldPill.centerYAnchor)
        ])

        var goCfg = UIButton.Configuration.filled()
        goCfg.baseBackgroundColor = CarAutoPadTheme.pill
        goCfg.baseForegroundColor = .label
        goCfg.cornerStyle = .fixed
        goCfg.background.cornerRadius = 12
        goCfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
        goCfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 14, weight: .medium)
            return out
        }
        directConnectButton.configuration = goCfg
        directConnectButton.setContentHuggingPriority(.required, for: .horizontal)
        directConnectButton.addTarget(self, action: #selector(directConnectTapped), for: .touchUpInside)
        directConnectButton.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let rightStack = UIStackView(arrangedSubviews: [ipFieldPill, directConnectButton])
        rightStack.axis = .horizontal
        rightStack.spacing = 10
        rightStack.alignment = .center

        directIpLayoutStack.translatesAutoresizingMaskIntoConstraints = false
        directIpLayoutStack.axis = .horizontal
        directIpLayoutStack.spacing = 16
        directIpLayoutStack.alignment = .center
        directIpLayoutStack.addArrangedSubview(leftStack)
        directIpLayoutStack.addArrangedSubview(rightStack)
        directIpCard.addSubview(directIpLayoutStack)

        NSLayoutConstraint.activate([
            directIpLayoutStack.topAnchor.constraint(equalTo: directIpCard.topAnchor, constant: 16),
            directIpLayoutStack.bottomAnchor.constraint(equalTo: directIpCard.bottomAnchor, constant: -16),
            directIpLayoutStack.leadingAnchor.constraint(equalTo: directIpCard.leadingAnchor, constant: 20),
            directIpLayoutStack.trailingAnchor.constraint(equalTo: directIpCard.trailingAnchor, constant: -20)
        ])

        contentStack.addArrangedSubview(directIpCard)
    }

    private func setupCollapsibleGuideCard() {
        let cardStack = UIStackView()
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardStack.axis = .vertical
        cardStack.spacing = 0
        guideDisclosureCard.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.topAnchor.constraint(equalTo: guideDisclosureCard.topAnchor),
            cardStack.bottomAnchor.constraint(equalTo: guideDisclosureCard.bottomAnchor),
            cardStack.leadingAnchor.constraint(equalTo: guideDisclosureCard.leadingAnchor),
            cardStack.trailingAnchor.constraint(equalTo: guideDisclosureCard.trailingAnchor)
        ])

        guideHeaderControl.translatesAutoresizingMaskIntoConstraints = false
        guideHeaderControl.accessibilityIdentifier = "androidGuideDisclosureHeader"
        guideHeaderControl.addTarget(self, action: #selector(toggleGuideStepsTapped), for: .touchUpInside)

        let phoneIcon = UIImageView(image: UIImage(systemName: "iphone", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)))
        phoneIcon.tintColor = .secondaryLabel
        phoneIcon.setContentHuggingPriority(.required, for: .horizontal)

        guideTitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        guideTitleLabel.textColor = .label
        guideTitleLabel.adjustsFontSizeToFitWidth = true
        guideTitleLabel.minimumScaleFactor = 0.75

        guideCountBadgeLabel.font = .systemFont(ofSize: 13, weight: .regular)
        guideCountBadgeLabel.textColor = .tertiaryLabel
        guideCountBadgeLabel.isHidden = true // Shown ONLY when expanded (Figma 02); hidden when collapsed (user's Figma 01 edit!)

        guideChevronView.image = UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        guideChevronView.tintColor = .secondaryLabel
        guideChevronView.setContentHuggingPriority(.required, for: .horizontal)

        let leftTitleStack = UIStackView(arrangedSubviews: [phoneIcon, guideTitleLabel, guideCountBadgeLabel])
        leftTitleStack.axis = .horizontal
        leftTitleStack.spacing = 10
        leftTitleStack.alignment = .center
        leftTitleStack.isUserInteractionEnabled = false

        let headerRow = UIStackView(arrangedSubviews: [leftTitleStack, guideChevronView])
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.axis = .horizontal
        headerRow.distribution = .equalSpacing
        headerRow.alignment = .center
        headerRow.isUserInteractionEnabled = false
        guideHeaderControl.addSubview(headerRow)

        NSLayoutConstraint.activate([
            guideHeaderControl.heightAnchor.constraint(equalToConstant: 54),
            headerRow.leadingAnchor.constraint(equalTo: guideHeaderControl.leadingAnchor, constant: 20),
            headerRow.trailingAnchor.constraint(equalTo: guideHeaderControl.trailingAnchor, constant: -20),
            headerRow.centerYAnchor.constraint(equalTo: guideHeaderControl.centerYAnchor)
        ])
        cardStack.addArrangedSubview(guideHeaderControl)

        guideStepsContainer.axis = .vertical
        guideStepsContainer.spacing = 0
        guideStepsStack.axis = .vertical
        guideStepsStack.spacing = 0
        guideStepsContainer.addArrangedSubview(guideStepsStack)
        cardStack.addArrangedSubview(guideStepsContainer)

        contentStack.addArrangedSubview(guideDisclosureCard)
    }

    private func rebuildGuideSteps() {
        for sub in guideStepsStack.arrangedSubviews {
            guideStepsStack.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }
        let steps: [(String, String, String)] = [
            ("1", L10n.guideStep1Title, L10n.guideStep1Detail),
            ("2", L10n.guideStep2Title, L10n.guideStep2Detail),
            ("3", L10n.guideStep3Title, L10n.guideStep3Detail),
            ("4", L10n.guideStep4Title, L10n.guideStep4Detail)
        ]

        for (num, title, detail) in steps {
            let rowWrapper = UIStackView()
            rowWrapper.axis = .vertical
            rowWrapper.spacing = 0
            rowWrapper.addArrangedSubview(CarAutoPadTheme.makeHairline(leadingInset: 20))

            let badge = UILabel()
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.text = num
            badge.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            badge.textColor = .secondaryLabel
            badge.textAlignment = .center
            badge.backgroundColor = CarAutoPadTheme.pill
            badge.layer.cornerRadius = 11
            badge.clipsToBounds = true
            NSLayoutConstraint.activate([
                badge.widthAnchor.constraint(equalToConstant: 22),
                badge.heightAnchor.constraint(equalToConstant: 22)
            ])

            let titleLbl = UILabel()
            titleLbl.text = title
            titleLbl.font = .systemFont(ofSize: 14, weight: .medium)
            titleLbl.textColor = .label
            titleLbl.setContentCompressionResistancePriority(.required, for: .horizontal)

            let detailLbl = UILabel()
            detailLbl.text = detail
            detailLbl.font = .systemFont(ofSize: 13, weight: .regular)
            detailLbl.textColor = .secondaryLabel
            detailLbl.textAlignment = .right
            detailLbl.numberOfLines = 0

            let left = UIStackView(arrangedSubviews: [badge, titleLbl])
            left.axis = .horizontal
            left.spacing = 12
            left.alignment = .center

            let row = UIStackView(arrangedSubviews: [left, detailLbl])
            row.axis = .horizontal
            row.spacing = 14
            row.alignment = .center
            row.isLayoutMarginsRelativeArrangement = true
            row.layoutMargins = UIEdgeInsets(top: 13, left: 20, bottom: 13, right: 20)

            rowWrapper.addArrangedSubview(row)
            guideStepsStack.addArrangedSubview(rowWrapper)
        }
    }

    func setGuideStepsExpanded(_ expanded: Bool, animated: Bool) {
        isGuideStepsExpanded = expanded
        guideCountBadgeLabel.isHidden = !expanded
        let chevronName = expanded ? "chevron.up" : "chevron.down"
        guideChevronView.image = UIImage(systemName: chevronName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium))

        let apply = {
            self.guideStepsContainer.isHidden = !expanded
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.2, options: [.allowUserInteraction]) {
                apply()
            }
        } else {
            guideStepsContainer.isHidden = !expanded
        }
    }

    func applyLocalization() {
        pageTitleLabel.text = L10n.sidebarWirelessConnection
        directIpTitleLabel.text = L10n.hotspotDirectConnectTitle
        directIpSubtitleLabel.text = L10n.hotspotDirectConnectSubtitle
        if var goCfg = directConnectButton.configuration {
            goCfg.title = L10n.directConnectShortButton
            directConnectButton.configuration = goCfg
        }
        if var ctaCfg = heroPrimaryButton.configuration {
            ctaCfg.title = L10n.wirelessHeroPrimaryScanButton
            heroPrimaryButton.configuration = ctaCfg
        }
        cancelScanButton.setTitle(L10n.cancelScanButton, for: .normal)
        guideTitleLabel.text = L10n.androidSetupStepsTitle
        guideCountBadgeLabel.text = L10n.androidSetupStepsCountBadge
        rebuildGuideSteps()
        updateConnectionState(lastState, statusDetail: ConnectionManager.shared.statusDetail)
    }

    func updateConnectionState(_ state: ConnectionState, statusDetail: String) {
        lastState = state
        let isScanningOrConnecting: Bool
        switch state {
        case .discovering, .waitingForWirelessHelper, .connecting, .handshaking:
            isScanningOrConnecting = true
        default:
            isScanningOrConnecting = false
        }

        heroPrimaryButton.isHidden = isScanningOrConnecting
        scanningBarContainer.isHidden = !isScanningOrConnecting

        if isScanningOrConnecting {
            heroTitleLabel.text = L10n.wirelessHeroTitleScanning
            heroSubtitleLabel.text = L10n.wirelessHeroSubtitleScanning
            let gateway = NetworkAddresses.currentHotspotGatewayIpv4()
            let prefix = gateway.split(separator: ".").prefix(3).joined(separator: ".")
            let hint = prefix.isEmpty ? "192.168.43.x" : "\(prefix).x"
            scanningStatusLabel.text = (state == .discovering) ? L10n.wirelessScanningSubnet(hint) : statusDetail
            scanningSpinner.startAnimating()
        } else {
            heroTitleLabel.text = L10n.wirelessHeroTitleReady
            heroSubtitleLabel.text = L10n.wirelessHeroSubtitleReady
            scanningSpinner.stopAnimating()
        }

        if directIpTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            directIpTextField.text = NetworkAddresses.currentHotspotGatewayIpv4()
        }
    }

    func updateIssueBanner(issue: ConnectionIssue?) {
        if let issue = issue {
            issueTitleLabel.text = issue.title
            issueAdviceLabel.text = issue.resolutionAdvice
            issueBannerCard.isHidden = false
            // Auto-expand setup steps when an issue banner appears (unless user explicitly collapsed it)
            if !didUserManuallyToggleGuide && !isGuideStepsExpanded {
                setGuideStepsExpanded(true, animated: true)
            }
        } else {
            issueBannerCard.isHidden = true
            didUserManuallyToggleGuide = false
        }
    }

    func updateSuggestedGateway(_ gatewayIp: String) {
        let current = directIpTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if current.isEmpty || current.hasSuffix(".1") || current == "192.168.43.1" {
            directIpTextField.text = gatewayIp
        }
    }

    // MARK: - Actions

    @objc private func primaryScanTapped() {
        view.endEditing(true)
        onStartDiscovery?()
    }

    @objc private func cancelScanTapped() {
        onCancelDiscovery?()
    }

    @objc private func directConnectTapped() {
        view.endEditing(true)
        let ip = directIpTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !ip.isEmpty else { return }
        onDirectConnect?(ip)
    }

    @objc private func resetGatewayIpTapped() {
        directIpTextField.text = NetworkAddresses.currentHotspotGatewayIpv4()
    }

    @objc private func toggleGuideStepsTapped() {
        didUserManuallyToggleGuide = true
        setGuideStepsExpanded(!isGuideStepsExpanded, animated: true)
    }

    @objc private func dismissIssueTapped() {
        onDismissIssueBanner?()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}
