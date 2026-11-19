import UIKit

public enum AppSidebarTab: Int, CaseIterable {
    case wirelessConnection = 0
    case displayLayout = 1
    case audioMixer = 2
    case smartLanguage = 3
    case about = 4

    public var title: String {
        switch self {
        case .wirelessConnection: return L10n.sidebarWirelessConnection
        case .displayLayout: return L10n.sidebarDisplayLayout
        case .audioMixer: return L10n.sidebarAudioMixer
        case .smartLanguage: return L10n.sidebarSmartLanguage
        case .about: return L10n.sidebarAbout
        }
    }

    public var symbolName: String {
        switch self {
        case .wirelessConnection: return "wifi"
        case .displayLayout: return "display"
        case .audioMixer: return "slider.vertical.3"
        case .smartLanguage: return "moon"
        case .about: return "info.circle"
        }
    }

    public var accessibilityIdentifier: String {
        switch self {
        case .wirelessConnection: return "sidebarTab.wirelessConnection"
        case .displayLayout: return "sidebarTab.displayLayout"
        case .audioMixer: return "sidebarTab.audioMixer"
        case .smartLanguage: return "sidebarTab.smartLanguage"
        case .about: return "sidebarTab.about"
        }
    }
}

final class SidebarNavigationView: UIView {
    var onSelectTab: ((AppSidebarTab) -> Void)?
    var onToggleCollapse: (() -> Void)?
    var onDisconnectTapped: (() -> Void)?

    private(set) var selectedTab: AppSidebarTab = .wirelessConnection

    private let brandTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = CarAutoPadDeviceInfo.appName
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .label
        return label
    }()

    let collapseButton: UIButton = CarAutoPadTheme.makeLiquidGlassCircleButton(
        symbolName: "sidebar.left",
        size: 34,
        pointSize: 15,
        accessibilityIdentifier: "sidebarCollapseButton"
    )

    // Compact IP pill (shown when disconnected / scanning — NO trailing "Ready" text)
    let ipIndicatorView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = CarAutoPadTheme.card
        v.layer.cornerRadius = 12
        v.layer.cornerCurve = .continuous
        return v
    }()

    let statusDotView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 3.5
        v.backgroundColor = CarAutoPadTheme.accentGreen
        return v
    }()

    let ipIndicatorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    // Active session card (shown when connected / running, matching Figma 09)
    let activeSessionCard: UIView = {
        let v = CarAutoPadTheme.makeCard(cornerRadius: 16)
        v.isHidden = true
        return v
    }()

    private let sessionDotView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 3.5
        v.backgroundColor = CarAutoPadTheme.accentGreen
        return v
    }()

    private let sessionDeviceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .label
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let sessionSubtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabel
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let sessionDisconnectButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.accessibilityIdentifier = "sidebarDisconnectButton"
        btn.setTitleColor(CarAutoPadTheme.accentRed, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        btn.titleLabel?.adjustsFontSizeToFitWidth = true
        btn.titleLabel?.minimumScaleFactor = 0.75
        return btn
    }()

    let navStackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .fill
        return stack
    }()

    private var navButtons: [AppSidebarTab: SidebarRowButton] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        applyLocalization()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        applyLocalization()
    }

    private func setupUI() {
        backgroundColor = CarAutoPadTheme.sidebar

        let rootStack = UIStackView()
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.axis = .vertical
        rootStack.spacing = 16
        rootStack.alignment = .fill
        addSubview(rootStack)

        // Pure Brand Header (text-only CarAutoPad + Liquid Glass collapse button per user's Figma edit)
        let headerRow = UIStackView(arrangedSubviews: [brandTitleLabel, collapseButton])
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.distribution = .equalSpacing
        headerRow.isLayoutMarginsRelativeArrangement = true
        headerRow.layoutMargins = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
        collapseButton.addTarget(self, action: #selector(collapseTapped), for: .touchUpInside)
        rootStack.addArrangedSubview(headerRow)

        // Status Pill (Disconnected / Scanning)
        let ipStack = UIStackView(arrangedSubviews: [statusDotView, ipIndicatorLabel])
        ipStack.translatesAutoresizingMaskIntoConstraints = false
        ipStack.axis = .horizontal
        ipStack.spacing = 8
        ipStack.alignment = .center
        ipIndicatorView.addSubview(ipStack)
        NSLayoutConstraint.activate([
            statusDotView.widthAnchor.constraint(equalToConstant: 7),
            statusDotView.heightAnchor.constraint(equalToConstant: 7),
            ipStack.topAnchor.constraint(equalTo: ipIndicatorView.topAnchor, constant: 9),
            ipStack.bottomAnchor.constraint(equalTo: ipIndicatorView.bottomAnchor, constant: -9),
            ipStack.leadingAnchor.constraint(equalTo: ipIndicatorView.leadingAnchor, constant: 12),
            ipStack.trailingAnchor.constraint(equalTo: ipIndicatorView.trailingAnchor, constant: -12)
        ])
        rootStack.addArrangedSubview(ipIndicatorView)

        // Active Session Card (Connected / Running)
        let sessTopStack = UIStackView()
        sessTopStack.axis = .vertical
        sessTopStack.spacing = 3
        sessTopStack.isLayoutMarginsRelativeArrangement = true
        sessTopStack.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)

        let devRow = UIStackView(arrangedSubviews: [sessionDotView, sessionDeviceLabel])
        devRow.axis = .horizontal
        devRow.spacing = 8
        devRow.alignment = .center
        NSLayoutConstraint.activate([
            sessionDotView.widthAnchor.constraint(equalToConstant: 7),
            sessionDotView.heightAnchor.constraint(equalToConstant: 7)
        ])
        sessTopStack.addArrangedSubview(devRow)
        sessTopStack.addArrangedSubview(sessionSubtitleLabel)

        let sessStack = UIStackView(arrangedSubviews: [
            sessTopStack,
            CarAutoPadTheme.makeHairline(),
            sessionDisconnectButton
        ])
        sessStack.translatesAutoresizingMaskIntoConstraints = false
        sessStack.axis = .vertical
        sessStack.alignment = .fill
        activeSessionCard.addSubview(sessStack)
        sessionDisconnectButton.addTarget(self, action: #selector(disconnectTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            sessStack.topAnchor.constraint(equalTo: activeSessionCard.topAnchor),
            sessStack.bottomAnchor.constraint(equalTo: activeSessionCard.bottomAnchor),
            sessStack.leadingAnchor.constraint(equalTo: activeSessionCard.leadingAnchor),
            sessStack.trailingAnchor.constraint(equalTo: activeSessionCard.trailingAnchor),
            sessionDisconnectButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        rootStack.addArrangedSubview(activeSessionCard)

        // 5-Item Clean Navigation Stack (strictly [Icon + Title], ZERO trailing mini-text!)
        for tab in AppSidebarTab.allCases {
            let row = SidebarRowButton(tab: tab)
            row.addTarget(self, action: #selector(navRowTapped(_:)), for: .touchUpInside)
            navButtons[tab] = row
            navStackView.addArrangedSubview(row)
        }
        rootStack.addArrangedSubview(navStackView)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 14),
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            rootStack.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        setSelectedTab(.wirelessConnection)
    }

    func setSelectedTab(_ tab: AppSidebarTab) {
        selectedTab = tab
        for (item, btn) in navButtons {
            btn.setSelected(item == tab)
        }
    }

    func applyLocalization() {
        brandTitleLabel.text = CarAutoPadDeviceInfo.appName
        sessionDisconnectButton.setTitle(L10n.disconnectAndroidAutoRow, for: .normal)
        for (tab, btn) in navButtons {
            btn.updateTitle(tab.title)
        }
    }

    func updateConnectionState(
        _ state: ConnectionState,
        statusKind: ConnectionStatusKind,
        localIp: String,
        peerName: String,
        peerEndpoint: String
    ) {
        let isSessionActive = (state == .running)
        activeSessionCard.isHidden = !isSessionActive
        ipIndicatorView.isHidden = isSessionActive

        if isSessionActive {
            sessionDeviceLabel.text = peerName
            let fpsText = ProjectionSettings.effectiveFpsLimit.title
            sessionSubtitleLabel.text = peerEndpoint.isEmpty ? fpsText : "\(peerEndpoint) · \(fpsText)"
            sessionDisconnectButton.setTitle(L10n.disconnectAndroidAutoRow, for: .normal)
        } else {
            switch state {
            case .discovering, .waitingForWirelessHelper, .connecting, .handshaking:
                statusDotView.backgroundColor = CarAutoPadTheme.accentOrange
                ipIndicatorLabel.text = L10n.sidebarScanningPort5277
                ipIndicatorLabel.textColor = .secondaryLabel
            case .error:
                statusDotView.backgroundColor = CarAutoPadTheme.accentOrange
                ipIndicatorLabel.text = localIp
                ipIndicatorLabel.textColor = CarAutoPadTheme.accentOrange
            case .disconnected, .disconnecting:
                if statusKind.isDisconnectedWarning {
                    statusDotView.backgroundColor = CarAutoPadTheme.accentOrange
                    ipIndicatorLabel.textColor = CarAutoPadTheme.accentOrange
                } else {
                    statusDotView.backgroundColor = CarAutoPadTheme.accentGreen
                    ipIndicatorLabel.textColor = .secondaryLabel
                }
                ipIndicatorLabel.text = localIp
            case .running:
                break
            }
        }
    }

    func rowButton(for tab: AppSidebarTab) -> UIControl? {
        return navButtons[tab]
    }

    @objc private func navRowTapped(_ sender: SidebarRowButton) {
        setSelectedTab(sender.tab)
        onSelectTab?(sender.tab)
    }

    @objc private func collapseTapped() {
        onToggleCollapse?()
    }

    @objc private func disconnectTapped() {
        onDisconnectTapped?()
    }
}

private final class SidebarRowButton: UIControl {
    let tab: AppSidebarTab

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.78
        return label
    }()

    init(tab: AppSidebarTab) {
        self.tab = tab
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        accessibilityIdentifier = tab.accessibilityIdentifier
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous

        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        iconView.image = UIImage(systemName: tab.symbolName, withConfiguration: cfg)
        titleLabel.text = tab.title

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateTitle(_ title: String) {
        titleLabel.text = title
    }

    func setSelected(_ selected: Bool) {
        isSelected = selected
        backgroundColor = selected ? CarAutoPadTheme.sidebarSelected : .clear
        iconView.tintColor = selected ? CarAutoPadTheme.accentBlue : .secondaryLabel
        titleLabel.font = .systemFont(ofSize: 15, weight: selected ? .semibold : .regular)
        titleLabel.textColor = selected ? .label : UIColor.label.withAlphaComponent(0.86)
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.65 : 1.0
        }
    }
}
