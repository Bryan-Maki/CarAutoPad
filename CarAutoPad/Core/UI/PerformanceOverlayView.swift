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
        backgroundColor = UIColor(red: 18.0 / 255.0, green: 18.0 / 255.0, blue: 22.0 / 255.0, alpha: 0.78)
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        layer.masksToBounds = true

        hudLabel.translatesAutoresizingMaskIntoConstraints = false
        hudLabel.numberOfLines = 2
        hudLabel.textColor = UIColor(white: 0.96, alpha: 0.96)
        hudLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        hudLabel.isUserInteractionEnabled = false
        addSubview(hudLabel)

        NSLayoutConstraint.activate([
            hudLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            hudLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
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
