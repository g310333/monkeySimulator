//
//  EventCharacterStageView.swift
//  by_monkey
//

import UIKit
import CoreImage

/// Up to three character portraits in left/center/right slots, driven entirely by each
/// dialogue line's `stage: [EventStageActor]` — which slot holds which character is
/// JSON data, not something this view decides. A well-formed event keeps the same
/// character in the same slot across all its lines (that's a data-authoring
/// convention, not something this view enforces), so positions read as stable even
/// though every render is a plain, literal reflection of that line's `stage`.
///
/// The current speaker lifts 6pt above its own rest position and is shown in full
/// color with a soft gold highlight glow; everyone else sits at rest, desaturated to
/// grayscale (not merely darkened or made transparent, so the background never shows
/// through a "dimmed" body).
final class EventCharacterStageView: UIView {

    private final class Slot {
        let container = UIView()
        let imageView = UIImageView()
        var characterID: String?
        var colorImage: UIImage?
        var grayscaleImage: UIImage?
        var presentation = EventCharacterPresentation(sampling: .nearest, scale: 1, offsetX: 0, offsetY: 0)

        /// This character's fixed rest position for its current presentation values —
        /// every non-speaking frame must return exactly here.
        var originTransform: CGAffineTransform {
            let scale = CGAffineTransform(scaleX: presentation.scale, y: presentation.scale)
            let dx = presentation.offsetX * container.bounds.width
            let dy = presentation.offsetY * container.bounds.height
            return scale.concatenating(CGAffineTransform(translationX: dx, y: dy))
        }

        init() {
            container.translatesAutoresizingMaskIntoConstraints = false
            container.isHidden = true
            container.clipsToBounds = false

            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.layer.shadowColor = PixelTheme.gold.cgColor
            imageView.layer.shadowRadius = 10
            imageView.layer.shadowOffset = .zero
            imageView.layer.shadowOpacity = 0
            container.addSubview(imageView)

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                imageView.topAnchor.constraint(equalTo: container.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
    }

    /// Points the current speaker lifts above its own rest position.
    private static let speakerLiftOffset: CGFloat = 6
    private static let ciContext = CIContext(options: nil)

    private let characterLookup: (String) -> EventCharacter?
    private let stack = UIStackView()
    private let leftSlot = Slot()
    private let centerSlot = Slot()
    private let rightSlot = Slot()
    private var slotsByPosition: [EventStageSlot: Slot] { [.left: leftSlot, .center: centerSlot, .right: rightSlot] }

    init(characters: [EventCharacter]) {
        self.characterLookup = { characterID in characters.first { $0.id == characterID } }
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .bottom
        stack.distribution = .fillEqually
        // A small negative spacing lets shoulders touch/overlap slightly at 3-up instead
        // of forcing a gap that would shrink every portrait to avoid ever overlapping.
        stack.spacing = -16
        stack.addArrangedSubview(leftSlot.container)
        stack.addArrangedSubview(centerSlot.container)
        stack.addArrangedSubview(rightSlot.container)
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    /// Renders one dialogue line's staging: exactly the characters/slots/speaker its
    /// `stage` says, nothing inferred or carried over from the previous line.
    func update(stage: [EventStageActor], speakerID: String, animated: Bool) {
        let bySlot = Dictionary(uniqueKeysWithValues: stage.map { ($0.slot, $0.characterID) })
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let duration = reduceMotion ? 0.12 : 0.22

        for (position, slot) in slotsByPosition {
            guard let characterID = bySlot[position], let character = characterLookup(characterID) else {
                slot.container.isHidden = true
                slot.characterID = nil
                continue
            }
            configureSlotIfNeeded(slot, characterID: characterID, character: character)
            slot.container.isHidden = false
            applySpeakerState(to: slot, isSpeaker: characterID == speakerID, reduceMotion: reduceMotion, animated: animated, duration: duration)
        }
    }

    private func configureSlotIfNeeded(_ slot: Slot, characterID: String, character: EventCharacter) {
        guard slot.characterID != characterID else { return }
        slot.characterID = characterID
        slot.presentation = character.presentation
        let image = UIImage(named: character.portraitAsset)
        slot.colorImage = image
        slot.grayscaleImage = image.flatMap(Self.grayscaleVersion)
        slot.imageView.image = image
        slot.imageView.layer.magnificationFilter = character.presentation.sampling == .nearest ? .nearest : .linear
    }

    private func applySpeakerState(to slot: Slot, isSpeaker: Bool, reduceMotion: Bool, animated: Bool, duration: TimeInterval) {
        slot.container.layer.zPosition = isSpeaker ? 10 : 0

        // Grayscale for anyone not currently speaking, full color for the speaker —
        // desaturating (not lowering alpha) keeps the silhouette fully opaque so the
        // background never shows through.
        let targetImage = isSpeaker ? slot.colorImage : slot.grayscaleImage
        if slot.imageView.image !== targetImage {
            if animated {
                UIView.transition(with: slot.imageView, duration: duration, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                    slot.imageView.image = targetImage
                }
            } else {
                slot.imageView.image = targetImage
            }
        }

        // Every non-speaker returns exactly to its origin; the speaker lifts above it.
        let origin = slot.originTransform
        let target = (isSpeaker && !reduceMotion)
            ? origin.concatenating(CGAffineTransform(translationX: 0, y: -Self.speakerLiftOffset))
            : origin

        let applyMotionAndGlow = {
            slot.imageView.transform = target
            slot.imageView.layer.shadowOpacity = isSpeaker ? 0.85 : 0
        }

        if animated {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut], animations: applyMotionAndGlow)
        } else {
            applyMotionAndGlow()
        }
    }

    private static func grayscaleVersion(of image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image),
              let filter = CIFilter(name: "CIColorControls") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(0.0, forKey: kCIInputSaturationKey)
        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
