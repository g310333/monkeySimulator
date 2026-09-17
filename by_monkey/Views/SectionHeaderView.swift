//
//  SectionHeaderView.swift
//  by_monkey
//

import UIKit

/// The "今天要做什麼？" divider: a centered label flanked by the pixel diamond ornament.
final class SectionHeaderView: UIView {

    init(text: String) {
        super.init(frame: .zero)
        configure(text: text)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func configure(text: String) {
        translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 20, weight: .heavy)
        label.textColor = .white

        let leadingOrnament = UIImageView(image: UIImage(named: "decoration_pixels"))
        let trailingOrnament = UIImageView(image: UIImage(named: "decoration_pixels"))
        [leadingOrnament, trailingOrnament].forEach {
            $0.contentMode = .scaleAspectFit
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.widthAnchor.constraint(equalToConstant: 16).isActive = true
            $0.heightAnchor.constraint(equalToConstant: 16).isActive = true
        }

        let stack = UIStackView(arrangedSubviews: [leadingOrnament, label, trailingOrnament])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
}
