//
//  PixelPanelView.swift
//  by_monkey
//

import UIKit

/// A dark, gold-bordered panel with notched corners in the game's pixel-art HUD style.
class PixelPanelView: UIView {

    var cornerCut: CGFloat = 8 {
        didSet { setNeedsLayout() }
    }

    var fillColor: UIColor = PixelTheme.panelFill {
        didSet { fillLayer.fillColor = fillColor.cgColor }
    }

    var borderColor: UIColor = PixelTheme.gold {
        didSet { borderLayer.strokeColor = borderColor.cgColor }
    }

    var panelBorderWidth: CGFloat = 2 {
        didSet { borderLayer.lineWidth = panelBorderWidth }
    }

    private let fillLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        fillLayer.fillColor = fillColor.cgColor
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = borderColor.cgColor
        borderLayer.lineWidth = panelBorderWidth
        layer.addSublayer(fillLayer)
        layer.addSublayer(borderLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = CutCornerPath.path(in: bounds, cut: cornerCut)
        fillLayer.path = path.cgPath
        borderLayer.path = path.cgPath
    }

    /// Briefly flashes the border to `color` and back. Only animates the presentation —
    /// `borderColor` (the model value) is untouched, so nothing needs restoring after.
    func flashBorder(to color: UIColor, duration: TimeInterval) {
        let animation = CABasicAnimation(keyPath: "strokeColor")
        animation.fromValue = borderColor.cgColor
        animation.toValue = color.cgColor
        animation.duration = duration / 2
        animation.autoreverses = true
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        borderLayer.add(animation, forKey: "flashBorder")
    }
}
