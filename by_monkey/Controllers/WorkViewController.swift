//
//  WorkViewController.swift
//  by_monkey
//

import UIKit

/// The convenience-store work mini-game: dialogue, then a payout settlement sheet.
/// Pure presentation/interaction here — dialogue progress, shift state, and the payout
/// itself all live in `WorkViewModel` / `PlayerProfileStore`.
final class WorkViewController: UIViewController {

    private let hudSnapshotProvider: () -> PlayerHUDSnapshot
    private let viewModel: WorkViewModel

    /// Called once, right after the payout has been successfully claimed and saved —
    /// carries the payout amount, this shift's unique instance ID (its `actionInstanceID`
    /// for the event system), and a freshly-minted `settlementID` identifying this
    /// specific settlement. What happens next (decide an event or return directly) is
    /// entirely the coordinator's call; this view controller doesn't decide events,
    /// persist decisions, or navigate on its own.
    var onPayoutClaimed: ((_ payout: Int, _ actionInstanceID: UUID, _ settlementID: UUID) -> Void)?

    private let backgroundImageView = UIImageView()
    private let bottomScrimLayer = CAGradientLayer()

    private let hudHeader = PlayerHUDHeader()
    private let timeOfDayControl = TimeOfDaySegmentedControl()
    private let locationBadge = LocationBadgeView(text: "便利商店・打工")

    private let characterView = WorkCharacterView()
    private let dialogueBox = DialogueBoxView()
    private var payoutOverlay: WorkPayoutOverlayView?
    private var eventViewController: UIViewController?

    /// Set only while the overlay's primary button is standing in for "retry saving the
    /// event decision" instead of its usual "claim payout" action.
    private var pendingEventDecisionRetry: (() -> Void)?

    private var characterWidthConstraint: NSLayoutConstraint!
    private var characterHeightConstraint: NSLayoutConstraint!
    private var characterBottomConstraint: NSLayoutConstraint!

    init(hudSnapshotProvider: @escaping () -> PlayerHUDSnapshot,
         payout: Int = WorkPayoutRules.convenienceStoreShiftPayout) {
        self.hudSnapshotProvider = hudSnapshotProvider
        self.viewModel = WorkViewModel(payout: payout)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        // A pending, unclaimed payout must never be lost to an interactive swipe-dismiss.
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpBackground()
        setUpHUD()
        setUpCharacter()
        setUpDialogueBox()
        setUpLayout()

        viewModel.onStageChanged = { [weak self] in
            self?.render()
        }
        render()

        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bottomScrimLayer.frame = view.bounds
        updateCharacterScale()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        resumeCharacterAnimationIfAppropriate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        characterView.stop()
    }

    @objc private func appDidEnterBackground() {
        characterView.stop()
    }

    @objc private func appWillEnterForeground() {
        resumeCharacterAnimationIfAppropriate()
    }

    private func resumeCharacterAnimationIfAppropriate() {
        guard payoutOverlay == nil, isViewLoaded, view.window != nil else { return }
        characterView.startIfNeeded()
    }

    // MARK: - Set up

    private func setUpBackground() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.image = UIImage(named: "shop")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        view.addSubview(backgroundImageView)

        bottomScrimLayer.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.85).cgColor,
        ]
        bottomScrimLayer.locations = [0.45, 1.0]
        view.layer.addSublayer(bottomScrimLayer)
    }

    private func setUpHUD() {
        hudHeader.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hudHeader)

        timeOfDayControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timeOfDayControl)

        locationBadge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(locationBadge)

        let snapshot = hudSnapshotProvider()
        hudHeader.configure(
            avatarImageName: snapshot.avatarImageName,
            name: snapshot.name,
            nameCaption: snapshot.nameCaption,
            moneyCaption: snapshot.moneyCaption,
            moneyText: snapshot.moneyText,
            dayNumber: snapshot.dayNumber,
            actionPointsCurrent: snapshot.actionPointsCurrent,
            actionPointsMax: snapshot.actionPointsMax
        )
        timeOfDayControl.setSelected(snapshot.selectedTimeOfDay)
    }

    private func setUpCharacter() {
        characterView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(characterView)

        characterWidthConstraint = characterView.widthAnchor.constraint(equalToConstant: 150)
        characterHeightConstraint = characterView.heightAnchor.constraint(equalToConstant: 150)
    }

    private func setUpDialogueBox() {
        dialogueBox.translatesAutoresizingMaskIntoConstraints = false
        dialogueBox.onTap = { [weak self] in
            self?.handleDialogueTap()
        }
        view.addSubview(dialogueBox)

        characterBottomConstraint = characterView.bottomAnchor.constraint(equalTo: dialogueBox.topAnchor, constant: -6)
    }

    private func setUpLayout() {
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            hudHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            hudHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hudHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            timeOfDayControl.topAnchor.constraint(equalTo: hudHeader.bottomAnchor, constant: 10),
            timeOfDayControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            timeOfDayControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            locationBadge.topAnchor.constraint(equalTo: timeOfDayControl.bottomAnchor, constant: 10),
            locationBadge.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            dialogueBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            dialogueBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            dialogueBox.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            characterView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            characterBottomConstraint,
            characterWidthConstraint,
            characterHeightConstraint,
        ])
    }

    private func updateCharacterScale() {
        let availableHeight = dialogueBox.frame.minY - locationBadge.frame.maxY - 24
        let availableWidth = view.bounds.width * 0.6
        let maxSide = max(min(availableHeight, availableWidth), 100)

        var multiplier = 3
        while multiplier > 2, CGFloat(multiplier) * 50 > maxSide {
            multiplier -= 1
        }
        while multiplier < 4, CGFloat(multiplier + 1) * 50 <= maxSide {
            multiplier += 1
        }

        let newSide = CGFloat(multiplier) * 50
        guard characterWidthConstraint.constant != newSide else { return }
        characterWidthConstraint.constant = newSide
        characterHeightConstraint.constant = newSide
    }

    // MARK: - Dialogue

    private func render() {
        switch viewModel.stage {
        case .dialogue:
            renderDialogue(animated: true)
        case .awaitingClaim:
            presentPayoutOverlay()
        case .claiming, .claimed:
            break
        }
    }

    private func renderDialogue(animated: Bool) {
        guard let line = viewModel.currentLine else { return }
        dialogueBox.setLine(
            speaker: line.speaker,
            text: line.text,
            progressText: viewModel.progressText,
            continuePrompt: viewModel.continuePromptText,
            animated: animated
        )
    }

    private func handleDialogueTap() {
        guard case .dialogue = viewModel.stage else { return }
        viewModel.advance()
    }

    // MARK: - Settlement

    private func presentPayoutOverlay() {
        guard payoutOverlay == nil else { return }
        characterView.stop()

        let overlay = WorkPayoutOverlayView(
            currentMoneyText: viewModel.currentMoneyText,
            payoutAmountText: viewModel.payoutAmountText,
            projectedMoneyText: viewModel.projectedMoneyText
        )
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.onClaimTapped = { [weak self] in
            self?.handleOverlayPrimaryButtonTapped()
        }
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        payoutOverlay = overlay
        overlay.present(reduceMotion: UIAccessibility.isReduceMotionEnabled)
    }

    private func handleOverlayPrimaryButtonTapped() {
        if let retry = pendingEventDecisionRetry {
            pendingEventDecisionRetry = nil
            payoutOverlay?.setBusy(title: "記錄中…")
            retry()
            return
        }
        handleClaimTapped()
    }

    private func handleClaimTapped() {
        payoutOverlay?.setBusy()
        viewModel.claimPayout { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .success(let payout, _):
                // Payout is safely committed. What happens next (an event, or straight
                // back to action selection) is the coordinator's decision, not this
                // screen's — and the pending payout stays protected (`isModalInPresentation`
                // remains true) until that whole flow actually finishes.
                self.onPayoutClaimed?(payout, self.viewModel.shift.id, UUID())
            case .failure:
                self.payoutOverlay?.showRetryable(message: "收入儲存失敗，請重試一次")
            }
        }
    }

    // MARK: - Coordinator-driven navigation

    /// Embeds the event screen on top of this one's own content — no dismiss/represent
    /// round trip, so action selection is never visible in between.
    func embedEvent(_ eventViewController: UIViewController) {
        addChild(eventViewController)
        eventViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(eventViewController.view)
        NSLayoutConstraint.activate([
            eventViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            eventViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            eventViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            eventViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        eventViewController.didMove(toParent: self)
        self.eventViewController = eventViewController
        UIAccessibility.post(notification: .screenChanged, argument: eventViewController.view)
    }

    /// Shows the payout overlay's button as a "retry saving the event decision" action
    /// instead of "claim payout" — payout money is already safely committed by this
    /// point, so this never risks paying out twice.
    func showEventDecisionSaveFailure(retry: @escaping () -> Void) {
        pendingEventDecisionRetry = retry
        payoutOverlay?.showRetryable(message: "事件記錄失敗，請重試一次", buttonTitle: "重試")
    }

    /// Ends this whole screen (work + any embedded event) and dismisses back to
    /// whatever presented it, only now safe to interactively dismiss.
    func finishAndReturn(completion: @escaping () -> Void) {
        isModalInPresentation = false
        dismiss(animated: true, completion: completion)
    }
}
