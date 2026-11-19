import UIKit

public final class PerformanceOverlayView: UIView {
    private let hudLabel = UILabel()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        isUserInteractionEnabled = false
        backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.11, alpha: 0.76)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderWidth = 0.8
        layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        layer.masksToBounds = true

        hudLabel.translatesAutoresizingMaskIntoConstraints = false
        hudLabel.numberOfLines = 2
        hudLabel.textColor = .systemYellow
        hudLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        hudLabel.isUserInteractionEnabled = false
        addSubview(hudLabel)

        NSLayoutConstraint.activate([
            hudLabel.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            hudLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
            hudLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            hudLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
    }

    public func update(snapshot: PerformanceSnapshot) {
        DispatchQueue.main.async { [weak self] in
            self?.hudLabel.text = PerformanceOverlayPolicy.formatHudText(snapshot)
        }
    }
}
