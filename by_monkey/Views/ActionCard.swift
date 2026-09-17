//
//  ActionCard.swift
//  by_monkey
//

import UIKit

/// A tappable pixel-art card: icon on the leading edge, bold title + muted subtitle stacked on the trailing side.
final class ActionCard: UIButton {

    private var baseConfiguration: UIButton.Configuration!

    /// The live icon view UIButton.Configuration renders (still populated even though
    /// content is configuration-driven). Used by the transition animator as the flight
    /// start point / to hide the original while a temporary copy flies to center screen.
    var iconImageView: UIImageView? { imageView }

    /// The pixel-art background panel set via `configuration.background.customView`,
    /// exposed so the transition animator can flash its border on tap.
    var backgroundPanel: PixelPanelView? { configuration?.background.customView as? PixelPanelView }

    init(action: PlayerAction) {
        super.init(frame: .zero)
        configure(action: action)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // UIButton.Configuration re-derives colors/dimming on every state change by default
    // (that's what was painting the card black). Pinning it to our fixed base config on
    // every update means state changes can never alter its look.
    override func updateConfiguration() {
        configuration = baseConfiguration
    }

    override var isHighlighted: Bool {
        didSet {
            // Only a scale nudge for press feedback — no darkening, so the card
            // doesn't read as disabled while being tapped.
            UIView.animate(withDuration: 0.12) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    private func configure(action: PlayerAction) {
        translatesAutoresizingMaskIntoConstraints = false

        var config = UIButton.Configuration.plain()
        config.image = UIImage(named: action.iconName)?.withRenderingMode(.alwaysOriginal)
        config.imagePlacement = .leading
        config.imagePadding = 12
        config.title = action.title
        config.subtitle = action.subtitle
        config.titleAlignment = .leading
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 18, weight: .bold)
            outgoing.foregroundColor = .white
            return outgoing
        }
        config.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 12, weight: .regular)
            outgoing.foregroundColor = UIColor(white: 1, alpha: 0.6)
            return outgoing
        }
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 10)

        // Route the pixel-art panel through UIButton.Configuration's own background
        // slot (rather than a manually inserted subview/sublayer) — that's the
        // supported way to sit a custom view behind the configuration's content,
        // and it's what was silently swallowing the icon/title/subtitle before.
        var background = UIBackgroundConfiguration.clear()
        let panel = PixelPanelView()
        panel.isUserInteractionEnabled = false
        panel.cornerCut = 10
        panel.fillColor = PixelTheme.cardFill
        background.customView = panel
        config.background = background

        baseConfiguration = config
        configuration = config

        heightAnchor.constraint(equalToConstant: 88).isActive = true
    }
}
