//
//  ActionSelectionViewController.swift
//  by_monkey
//

import UIKit

final class ActionSelectionViewController: UIViewController {

    private let viewModel = ActionSelectionViewModel()

    var onActionSelected: ((PlayerAction) -> Void)? {
        get { viewModel.onActionSelected }
        set { viewModel.onActionSelected = newValue }
    }

    /// Read-only status snapshot for another screen (e.g. the work mini-game) to render
    /// the same real HUD values without holding its own reference to this view model.
    var hudSnapshot: PlayerHUDSnapshot { viewModel.hudSnapshot }

    private let backgroundImageView = UIImageView()
    private let topScrimLayer = CAGradientLayer()
    private let bottomScrimLayer = CAGradientLayer()

    private let hudHeader = PlayerHUDHeader()
    private let timeOfDayControl = TimeOfDaySegmentedControl()
    private let sectionHeader = SectionHeaderView(text: "今天要做什麼？")
    private let actionGrid = UIStackView()

    private let transitionAnimator = ActionTransitionAnimator()
    private var actionCards: [ActionCard] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpBackground()
        setUpHUD()
        setUpActionGrid()
        setUpLayout()

        viewModel.onStateChanged = { [weak self] in
            self?.refreshHUD()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        topScrimLayer.frame = view.bounds
        bottomScrimLayer.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Interrupted mid-transition: tear down cleanly so the action never partially
        // applies and the cards are re-enabled for the next time this screen appears.
        transitionAnimator.cancel()
    }

    private func setUpBackground() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.image = UIImage(named: viewModel.backgroundImageName)
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        view.addSubview(backgroundImageView)

        topScrimLayer.colors = [
            UIColor.black.withAlphaComponent(0.8).cgColor,
            UIColor.black.withAlphaComponent(0).cgColor,
        ]
        topScrimLayer.locations = [0, 0.32]
        view.layer.addSublayer(topScrimLayer)

        bottomScrimLayer.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.9).cgColor,
        ]
        bottomScrimLayer.locations = [0.55, 1.0]
        view.layer.addSublayer(bottomScrimLayer)
    }

    private func setUpHUD() {
        hudHeader.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hudHeader)

        timeOfDayControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timeOfDayControl)

        refreshHUD()
    }

    private func refreshHUD() {
        hudHeader.configure(
            avatarImageName: viewModel.avatarImageName,
            name: viewModel.playerName,
            nameCaption: viewModel.playerNameCaption,
            moneyCaption: viewModel.moneyCaption,
            moneyText: viewModel.moneyText,
            dayNumber: viewModel.dayNumber,
            actionPointsCurrent: viewModel.actionPointsCurrent,
            actionPointsMax: viewModel.actionPointsMax
        )
        timeOfDayControl.setSelected(viewModel.selectedTimeOfDay)
    }

    private func setUpActionGrid() {
        sectionHeader.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sectionHeader)

        actionGrid.translatesAutoresizingMaskIntoConstraints = false
        actionGrid.axis = .vertical
        actionGrid.spacing = 12

        let actions = viewModel.actions
        let rows = stride(from: 0, to: actions.count, by: 2).map { Array(actions[$0..<min($0 + 2, actions.count)]) }

        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 12
            rowStack.distribution = .fillEqually

            for action in row {
                let card = ActionCard(action: action)
                card.addAction(UIAction { [weak self, weak card] _ in
                    guard let self, let card else { return }
                    self.handleActionTap(action, card: card)
                }, for: .touchUpInside)
                actionCards.append(card)
                rowStack.addArrangedSubview(card)
            }

            actionGrid.addArrangedSubview(rowStack)
        }

        view.addSubview(actionGrid)
    }

    private func handleActionTap(_ action: PlayerAction, card: ActionCard) {
        // Prefer the window so the transition overlay survives even if this screen
        // were ever replaced mid-animation — it isn't parented to `view`.
        let hostView: UIView = view.window ?? view

        transitionAnimator.run(
            action: action,
            sourceCard: card,
            relatedCards: actionCards,
            hostView: hostView,
            onCommit: { [weak self] in
                // The existing, unmodified action-handling path — the animator never
                // decides game state itself.
                self?.viewModel.selectAction(action)
            }
        )
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

            actionGrid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            actionGrid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            actionGrid.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            sectionHeader.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sectionHeader.bottomAnchor.constraint(equalTo: actionGrid.topAnchor, constant: -16),
        ])
    }
}
