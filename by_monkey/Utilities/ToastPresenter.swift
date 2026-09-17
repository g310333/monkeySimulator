//
//  ToastPresenter.swift
//  by_monkey
//

import UIKit

extension UIViewController {
    /// Shows a small pixel-art toast near the bottom of the screen, then fades it out.
    /// Used for short, non-blocking confirmations (e.g. a payout landing in the wallet).
    func presentPixelToast(_ message: String, duration: TimeInterval = 2.0) {
        let panel = PixelPanelView()
        panel.cornerCut = 8
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.isUserInteractionEnabled = false
        panel.alpha = 0

        let label = UILabel()
        label.text = message
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(label)

        view.addSubview(panel)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: panel.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),

            panel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            panel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            panel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            panel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])

        UIAccessibility.post(notification: .announcement, argument: message)

        UIView.animate(withDuration: 0.2) {
            panel.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.2, delay: duration, options: []) {
                panel.alpha = 0
            } completion: { _ in
                panel.removeFromSuperview()
            }
        }
    }
}
