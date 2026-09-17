//
//  WorkCharacterView.swift
//  by_monkey
//

import UIKit

/// The player sprite standing in the aisle: a looping talk-frame animation over a soft
/// foot shadow. Frames are 50x50 and drawn with nearest-neighbor filtering so pixel
/// edges stay crisp at any integer scale.
final class WorkCharacterView: UIView {

    /// A true ellipse (not a rounded-rect "pill") for the foot shadow.
    private final class OvalView: UIView {
        override class var layerClass: AnyClass { CAShapeLayer.self }
        private var shapeLayer: CAShapeLayer { layer as! CAShapeLayer }

        override init(frame: CGRect) {
            super.init(frame: frame)
            shapeLayer.fillColor = UIColor.black.withAlphaComponent(0.32).cgColor
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            shapeLayer.path = UIBezierPath(ovalIn: bounds).cgPath
        }
    }

    private let frameDuration: TimeInterval = 0.18

    private let shadowView = OvalView()
    private let imageView = UIImageView()
    private let frames: [UIImage]

    override init(frame: CGRect) {
        frames = Self.loadFrames()
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        frames = Self.loadFrames()
        super.init(coder: coder)
        configure()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        shadowView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(shadowView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.layer.magnificationFilter = .nearest
        imageView.image = frames.first
        addSubview(imageView)

        applyReduceMotionState()

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            shadowView.centerXAnchor.constraint(equalTo: centerXAnchor),
            shadowView.bottomAnchor.constraint(equalTo: bottomAnchor),
            shadowView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.55),
            shadowView.heightAnchor.constraint(equalToConstant: 12),
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionStatusChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    /// Starts (or resumes) the loop. No-ops under Reduce Motion, where only the first
    /// frame is ever shown.
    func startIfNeeded() {
        guard !UIAccessibility.isReduceMotionEnabled, imageView.animationImages != nil, !imageView.isAnimating else { return }
        imageView.startAnimating()
    }

    /// Stops the loop. Safe to call any time — screen disappearing, app backgrounding,
    /// or the settlement sheet coming up.
    func stop() {
        imageView.stopAnimating()
    }

    @objc private func reduceMotionStatusChanged() {
        applyReduceMotionState()
    }

    private func applyReduceMotionState() {
        if UIAccessibility.isReduceMotionEnabled {
            imageView.stopAnimating()
            imageView.animationImages = nil
            imageView.image = frames.first
        } else if imageView.animationImages == nil {
            imageView.animationImages = frames
            imageView.animationDuration = frameDuration * Double(max(frames.count, 1))
            imageView.animationRepeatCount = 0
        }
    }

    /// Enumerates "talk_0", "talk_1", … rather than assuming a fixed frame count, per
    /// project convention — however many frames actually exist in the asset catalog is
    /// however many get played.
    private static func loadFrames() -> [UIImage] {
        var frames: [UIImage] = []
        var index = 0
        while frames.count < 12, let image = UIImage(named: "talk_\(index)") {
            frames.append(image)
            index += 1
        }
        return frames
    }
}
