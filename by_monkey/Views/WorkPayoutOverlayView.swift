//
//  WorkPayoutOverlayView.swift
//  by_monkey
//

import UIKit

/// Full-screen settlement sheet shown once a work shift's dialogue finishes: dim scrim +
/// centered gold-bordered panel with the payout amount and a claim button. Tapping the
/// scrim intentionally does nothing — the only way out is claiming (or its retry path),
/// so a pending payout can never be lost by an accidental tap.
final class WorkPayoutOverlayView: UIView {

    private let dimView = UIView()
    private let panel = PixelPanelView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let amountLabel = UILabel()
    private let currentMoneyValueLabel = UILabel()
    private let projectedMoneyValueLabel = UILabel()
    private let errorLabel = UILabel()
    private let claimButton = UIButton(configuration: .filled())

    var onClaimTapped: (() -> Void)?

    init(currentMoneyText: String, payoutAmountText: String, projectedMoneyText: String) {
        super.init(frame: .zero)
        configure(currentMoneyText: currentMoneyText, payoutAmountText: payoutAmountText, projectedMoneyText: projectedMoneyText)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func configure(currentMoneyText: String, payoutAmountText: String, projectedMoneyText: String) {
        backgroundColor = .clear

        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.backgroundColor = PixelTheme.overlayScrim
        addSubview(dimView)

        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.cornerCut = 14
        panel.fillColor = PixelTheme.dialoguePanelFill
        panel.panelBorderWidth = 3
        addSubview(panel)

        titleLabel.text = "打工完成"
        titleLabel.font = .systemFont(ofSize: 24, weight: .heavy)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        subtitleLabel.text = "辛苦了！這是本次打工收入。"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIColor(white: 1, alpha: 0.7)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        amountLabel.text = payoutAmountText
        amountLabel.font = .systemFont(ofSize: 36, weight: .heavy)
        amountLabel.textColor = PixelTheme.gold
        amountLabel.textAlignment = .center

        let currentRow = summaryRow(caption: "目前金錢", valueLabel: currentMoneyValueLabel, value: currentMoneyText)
        let projectedRow = summaryRow(caption: "領取後金錢", valueLabel: projectedMoneyValueLabel, value: projectedMoneyText)

        errorLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        errorLabel.textColor = UIColor(red: 0.95, green: 0.45, blue: 0.4, alpha: 1)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.title = "領取收入"
        buttonConfig.baseBackgroundColor = PixelTheme.gold
        buttonConfig.baseForegroundColor = .black
        buttonConfig.cornerStyle = .medium
        buttonConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 17, weight: .bold)
            return outgoing
        }
        claimButton.configuration = buttonConfig
        claimButton.addTarget(self, action: #selector(handleClaimTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel, amountLabel, currentRow, projectedRow, errorLabel, claimButton,
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 12
        stack.setCustomSpacing(4, after: titleLabel)
        stack.setCustomSpacing(18, after: subtitleLabel)
        stack.setCustomSpacing(20, after: amountLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),

            panel.centerXAnchor.constraint(equalTo: centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: centerYAnchor),
            panel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            panel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            panel.widthAnchor.constraint(lessThanOrEqualToConstant: 340),

            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -24),
            claimButton.heightAnchor.constraint(equalToConstant: 48),
        ])

        isAccessibilityElement = false
        accessibilityViewIsModal = true
    }

    private func summaryRow(caption: String, valueLabel: UILabel, value: String) -> UIView {
        let captionLabel = UILabel()
        captionLabel.text = caption
        captionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        captionLabel.textColor = UIColor(white: 1, alpha: 0.6)

        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 16, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.textAlignment = .right

        let row = UIStackView(arrangedSubviews: [captionLabel, valueLabel])
        row.axis = .horizontal
        row.distribution = .equalSpacing
        return row
    }

    @objc private func handleClaimTapped() {
        // Belt-and-braces: disable immediately so a second tap in the gap before the
        // model callback runs can't fire twice. `WorkViewModel.claimPayout` is the
        // authoritative guard; this just avoids a visible double-fire at the UI layer.
        claimButton.isEnabled = false
        onClaimTapped?()
    }

    /// Entrance animation: dim fades in over ~180ms; the panel drops in from +14pt /
    /// scale 0.96 over ~260ms. Reduce Motion keeps only a short fade.
    func present(reduceMotion: Bool) {
        alpha = 0
        if reduceMotion {
            UIView.animate(withDuration: 0.12) {
                self.alpha = 1
            }
        } else {
            panel.transform = CGAffineTransform(translationX: 0, y: 14).scaledBy(x: 0.96, y: 0.96)
            panel.alpha = 0
            UIView.animate(withDuration: 0.18) {
                self.alpha = 1
            }
            UIView.animate(
                withDuration: 0.26, delay: 0,
                usingSpringWithDamping: 0.86, initialSpringVelocity: 0.4,
                options: [.curveEaseOut]
            ) {
                self.panel.alpha = 1
                self.panel.transform = .identity
            }
        }
        UIAccessibility.post(notification: .screenChanged, argument: panel)
    }

    func setBusy(title: String = "領取中…") {
        claimButton.isEnabled = false
        claimButton.configuration?.title = title
        errorLabel.isHidden = true
    }

    func showRetryable(message: String, buttonTitle: String = "重試領取") {
        claimButton.isEnabled = true
        claimButton.configuration?.title = buttonTitle
        errorLabel.text = message
        errorLabel.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
