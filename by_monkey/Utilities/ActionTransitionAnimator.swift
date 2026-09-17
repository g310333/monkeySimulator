//
//  ActionTransitionAnimator.swift
//  by_monkey
//

import UIKit

/// Centralized timing / color / motion constants for the action-tap transition.
/// Total duration is ~1.2s: feedback (0.16) + icon travel (0.28) + micro-action (0.26)
/// + curtain sweep in/out (0.24 + 0.26).
enum ActionTransitionMetrics {
    // Phase 1 — button feedback (0–160ms)
    static let feedbackDuration: TimeInterval = 0.16
    static let feedbackScaleDown: CGFloat = 0.94
    static let feedbackScaleUp: CGFloat = 1.03
    static let borderFlashColor = UIColor(red: 1.0, green: 0.86, blue: 0.50, alpha: 1)

    // Phase 2 — icon to center (160–440ms)
    static let travelDuration: TimeInterval = 0.28
    static let iconTargetSize: CGFloat = 112
    static let iconCenterHeightFraction: CGFloat = 0.43
    static let overlayColor = UIColor(red: 0.05, green: 0.04, blue: 0.03, alpha: 1)
    static let overlayTargetAlpha: CGFloat = 0.86

    // Phase 3 — micro action + caption (440–700ms)
    static let microActionDuration: TimeInterval = 0.26
    static let captionRiseOffset: CGFloat = 8
    static let captionTopSpacing: CGFloat = 20
    static let workBumpScale: CGFloat = 1.08
    static let stocksHopOffset: CGFloat = -8
    static let tougeAnticipationOffset: CGFloat = -8
    static let tougeDashOffset: CGFloat = 18
    static let shoppingRotationStart: CGFloat = -7 * .pi / 180
    static let shoppingRotationMid: CGFloat = 6 * .pi / 180

    // Phase 4 — gold diagonal curtain (700–1200ms)
    static let curtainSweepInDuration: TimeInterval = 0.24
    static let curtainSweepOutDuration: TimeInterval = 0.26
    static let curtainAngle: CGFloat = 18 * .pi / 180
    static let curtainColor = PixelTheme.gold
    static let curtainLeadingEdgeColor = UIColor(red: 1.0, green: 0.95, blue: 0.78, alpha: 1)
    static let curtainLeadingEdgeWidth: CGFloat = 14
    static let curtainOversizeFactor: CGFloat = 1.4

    // Reduce Motion fallback
    static let reducedMotionDuration: TimeInterval = 0.18
}

/// Plays the ~1.2s "choose an action" transition when an `ActionCard` is tapped:
/// button feedback → icon flies to a full-screen overlay → a short per-action
/// flourish + caption → a gold diagonal curtain wipe.
///
/// This animator never touches game state itself. `onCommit` is invoked exactly
/// once, at the instant the curtain fully covers the screen, and the caller decides
/// what that "destination switch" means (today: `ActionSelectionViewModel.selectAction`).
/// If a real screen transition is ever driven from `onCommit`, it should run with
/// `animated: false` — this animator already provides the transition motion, so a
/// second, system-driven one would stack on top of it.
final class ActionTransitionAnimator {

    private(set) var isRunning = false

    /// Bumped every time a run starts or ends. Async animation-completion closures
    /// capture the token they were scheduled under and no-op if it's gone stale —
    /// otherwise a cancelled run's late-arriving completions could mutate state a
    /// subsequently-started run now owns (wrong cards re-enabled, wrong container).
    private var generation = 0

    private weak var containerView: UIView?
    private weak var sourceCard: ActionCard?
    private var relatedCards: [ActionCard] = []
    private var didCommit = false
    private var onCommit: (() -> Void)?
    private var completion: (() -> Void)?

    /// - Parameters:
    ///   - sourceCard: the tapped card; its icon is hidden and its border/scale animate.
    ///   - relatedCards: all action cards to disable for the animation's duration
    ///     (including `sourceCard`), preventing repeat taps.
    ///   - hostView: where the full-screen transition container is added. Pass the
    ///     window (not the source screen's own view) so the transition survives even
    ///     if the underlying screen were ever replaced mid-animation.
    ///   - onCommit: called exactly once, when the curtain fully covers the screen.
    ///   - completion: called once the curtain has fully exited and temp views are cleared.
    func run(action: PlayerAction,
             sourceCard: ActionCard,
             relatedCards: [ActionCard],
             hostView: UIView,
             onCommit: @escaping () -> Void,
             completion: (() -> Void)? = nil) {
        guard !isRunning else { return }
        isRunning = true
        didCommit = false
        generation += 1
        let token = generation

        self.sourceCard = sourceCard
        self.relatedCards = relatedCards
        self.onCommit = onCommit
        self.completion = completion

        relatedCards.forEach { $0.isEnabled = false }

        let container = UIView(frame: hostView.bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.backgroundColor = .clear
        hostView.addSubview(container)
        containerView = container

        if UIAccessibility.isReduceMotionEnabled {
            runReducedMotion(token: token, container: container)
        } else {
            runFullAnimation(token: token, action: action, sourceCard: sourceCard, container: container)
        }
    }

    /// Cancels a running animation (e.g. the host screen is disappearing): tears down
    /// immediately, restores the source card, and skips `completion`. If the curtain
    /// hadn't fully covered the screen yet, `onCommit` never fires — cancelling never
    /// applies the action. If it already fired, cancelling doesn't undo it.
    func cancel() {
        guard isRunning else { return }
        finish(callCompletion: false)
    }

    // MARK: - Full animation

    private func runFullAnimation(token: Int, action: PlayerAction, sourceCard: ActionCard, container: UIView) {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
        sourceCard.backgroundPanel?.flashBorder(
            to: ActionTransitionMetrics.borderFlashColor,
            duration: ActionTransitionMetrics.feedbackDuration
        )

        UIView.animateKeyframes(withDuration: ActionTransitionMetrics.feedbackDuration, delay: 0, options: [.calculationModeLinear]) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.45) {
                sourceCard.transform = CGAffineTransform(
                    scaleX: ActionTransitionMetrics.feedbackScaleDown,
                    y: ActionTransitionMetrics.feedbackScaleDown
                )
            }
            UIView.addKeyframe(withRelativeStartTime: 0.45, relativeDuration: 0.35) {
                sourceCard.transform = CGAffineTransform(
                    scaleX: ActionTransitionMetrics.feedbackScaleUp,
                    y: ActionTransitionMetrics.feedbackScaleUp
                )
            }
            UIView.addKeyframe(withRelativeStartTime: 0.80, relativeDuration: 0.20) {
                sourceCard.transform = .identity
            }
        } completion: { [weak self] _ in
            guard let self, self.generation == token else { return }
            self.flyIconToCenter(token: token, action: action, sourceCard: sourceCard, container: container)
        }
    }

    private func flyIconToCenter(token: Int, action: PlayerAction, sourceCard: ActionCard, container: UIView) {
        let overlay = UIView(frame: container.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = ActionTransitionMetrics.overlayColor
        overlay.alpha = 0
        container.addSubview(overlay)

        let sourceIcon = sourceCard.iconImageView
        let startFrame = sourceIcon.map { $0.convert($0.bounds, to: container) }
            ?? CGRect(x: container.bounds.midX - 24, y: container.bounds.midY - 24, width: 48, height: 48)
        sourceIcon?.isHidden = true

        let iconView = UIImageView(image: sourceIcon?.image ?? UIImage(named: action.iconName))
        iconView.contentMode = .scaleAspectFit
        iconView.layer.magnificationFilter = .nearest
        iconView.frame = startFrame
        container.addSubview(iconView)

        let targetSize = ActionTransitionMetrics.iconTargetSize
        let targetCenter = CGPoint(
            x: container.bounds.midX,
            y: container.bounds.height * ActionTransitionMetrics.iconCenterHeightFraction
        )

        UIView.animate(withDuration: ActionTransitionMetrics.travelDuration, delay: 0, options: [.curveEaseInOut]) {
            overlay.alpha = ActionTransitionMetrics.overlayTargetAlpha
            iconView.bounds = CGRect(x: 0, y: 0, width: targetSize, height: targetSize)
            iconView.center = targetCenter
        } completion: { [weak self] _ in
            guard let self, self.generation == token else { return }
            self.playMicroAction(token: token, action: action, container: container, iconView: iconView)
        }
    }

    private func playMicroAction(token: Int, action: PlayerAction, container: UIView, iconView: UIImageView) {
        let duration = ActionTransitionMetrics.microActionDuration

        let label = UILabel()
        label.text = Self.caption(for: action)
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.topAnchor.constraint(
                equalTo: container.topAnchor,
                constant: iconView.frame.maxY + ActionTransitionMetrics.captionTopSpacing
            ),
        ])
        container.layoutIfNeeded()
        label.transform = CGAffineTransform(translationX: 0, y: ActionTransitionMetrics.captionRiseOffset)

        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut]) {
            label.alpha = 1
            label.transform = .identity
        }

        switch action {
        case .work:
            UIView.animateKeyframes(withDuration: duration, delay: 0) {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                    iconView.transform = CGAffineTransform(scaleX: ActionTransitionMetrics.workBumpScale, y: ActionTransitionMetrics.workBumpScale)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                    iconView.transform = .identity
                }
            }
        case .stocks:
            UIView.animateKeyframes(withDuration: duration, delay: 0) {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                    iconView.transform = CGAffineTransform(translationX: 0, y: ActionTransitionMetrics.stocksHopOffset)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                    iconView.transform = .identity
                }
            }
        case .touge:
            UIView.animateKeyframes(withDuration: duration, delay: 0) {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.35) {
                    iconView.transform = CGAffineTransform(translationX: ActionTransitionMetrics.tougeAnticipationOffset, y: 0)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.35, relativeDuration: 0.65) {
                    iconView.transform = CGAffineTransform(translationX: ActionTransitionMetrics.tougeDashOffset, y: 0)
                }
            }
        case .shopping:
            UIView.animateKeyframes(withDuration: duration, delay: 0) {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.4) {
                    iconView.transform = CGAffineTransform(rotationAngle: ActionTransitionMetrics.shoppingRotationStart)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.4, relativeDuration: 0.4) {
                    iconView.transform = CGAffineTransform(rotationAngle: ActionTransitionMetrics.shoppingRotationMid)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2) {
                    iconView.transform = .identity
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.generation == token else { return }
            self.runCurtain(token: token, container: container)
        }
    }

    private func runCurtain(token: Int, container: UIView) {
        let diagonal = (pow(container.bounds.width, 2) + pow(container.bounds.height, 2)).squareRoot()
        let side = diagonal * ActionTransitionMetrics.curtainOversizeFactor

        let curtain = UIView()
        curtain.backgroundColor = ActionTransitionMetrics.curtainColor
        curtain.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        curtain.transform = CGAffineTransform(rotationAngle: ActionTransitionMetrics.curtainAngle)

        let edgeWidth = ActionTransitionMetrics.curtainLeadingEdgeWidth
        let edge = UIView(frame: CGRect(x: side - edgeWidth, y: 0, width: edgeWidth, height: side))
        edge.backgroundColor = ActionTransitionMetrics.curtainLeadingEdgeColor
        curtain.addSubview(edge)

        container.addSubview(curtain)

        let startCenter = CGPoint(x: -side / 2, y: container.bounds.midY)
        let coverCenter = CGPoint(x: container.bounds.midX, y: container.bounds.midY)
        let exitCenter = CGPoint(x: container.bounds.width + side / 2, y: container.bounds.midY)
        curtain.center = startCenter

        UIView.animate(withDuration: ActionTransitionMetrics.curtainSweepInDuration, delay: 0, options: [.curveEaseIn]) {
            curtain.center = coverCenter
        } completion: { [weak self] _ in
            guard let self, self.generation == token else { return }
            // The oversized, rotated curtain is now centered on the container, i.e.
            // fully covering all four corners — this is "the destination switch" moment.
            self.commitIfNeeded()

            UIView.animate(withDuration: ActionTransitionMetrics.curtainSweepOutDuration, delay: 0, options: [.curveEaseOut]) {
                curtain.center = exitCenter
            } completion: { [weak self] _ in
                guard let self, self.generation == token else { return }
                self.finish(callCompletion: true)
            }
        }
    }

    // MARK: - Reduce Motion

    private func runReducedMotion(token: Int, container: UIView) {
        let overlay = UIView(frame: container.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = ActionTransitionMetrics.overlayColor
        overlay.alpha = 0
        container.addSubview(overlay)

        let duration = ActionTransitionMetrics.reducedMotionDuration
        UIView.animate(withDuration: duration) {
            overlay.alpha = 1
        } completion: { [weak self] _ in
            guard let self, self.generation == token else { return }
            self.commitIfNeeded()
            UIView.animate(withDuration: duration) {
                overlay.alpha = 0
            } completion: { [weak self] _ in
                guard let self, self.generation == token else { return }
                self.finish(callCompletion: true)
            }
        }
    }

    // MARK: - Commit / cleanup

    private func commitIfNeeded() {
        guard !didCommit else { return }
        didCommit = true
        onCommit?()
    }

    private func finish(callCompletion: Bool) {
        generation += 1 // invalidate any still-in-flight completions from this run

        sourceCard?.layer.removeAllAnimations()
        sourceCard?.iconImageView?.isHidden = false
        sourceCard?.transform = .identity
        relatedCards.forEach { $0.isEnabled = true }

        containerView?.removeFromSuperview()
        containerView = nil
        sourceCard = nil
        relatedCards = []

        isRunning = false
        let completionHandler = completion
        onCommit = nil
        completion = nil

        if callCompletion {
            completionHandler?()
        }
    }

    private static func caption(for action: PlayerAction) -> String {
        switch action {
        case .work: return "前往打工"
        case .stocks: return "查看行情"
        case .touge: return "準備出發"
        case .shopping: return "出門逛逛"
        }
    }
}
