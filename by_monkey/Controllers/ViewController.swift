//
//  ViewController.swift
//  by_monkey
//
//  Created by Sunao on 2026/9/8.
//

import UIKit

class ViewController: UIViewController {

    private let viewModel = ViewControllerViewModel()
    private var actionSelectionViewController: ActionSelectionViewController!
    private var workSessionCoordinator: WorkSessionCoordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
        viewModel.viewDidLoad()
        embedActionSelection()
    }

    private func bindViewModel() {
        viewModel.onTitleChange = { [weak self] title in
            self?.title = title
        }
    }

    private func embedActionSelection() {
        let actionSelectionViewController = ActionSelectionViewController()
        actionSelectionViewController.onActionSelected = { [weak self] action in
            self?.handleActionSelected(action)
        }
        self.actionSelectionViewController = actionSelectionViewController

        addChild(actionSelectionViewController)
        actionSelectionViewController.view.frame = view.bounds
        actionSelectionViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(actionSelectionViewController.view)
        actionSelectionViewController.didMove(toParent: self)
    }

    private func handleActionSelected(_ action: PlayerAction) {
        switch action {
        case .work:
            presentWork()
        case .stocks, .touge, .shopping:
            break
        }
    }

    private func presentWork() {
        guard let actionSelectionViewController else { return }

        let coordinator = WorkSessionCoordinator(
            hudSnapshotProvider: { [weak actionSelectionViewController] in
                actionSelectionViewController?.hudSnapshot ?? .fallback
            },
            onFinished: { [weak self, weak actionSelectionViewController] message in
                guard let self else { return }
                if let actionSelectionView = actionSelectionViewController?.view {
                    UIAccessibility.post(notification: .screenChanged, argument: actionSelectionView)
                }
                self.presentPixelToast(message)
                // Release the coordinator only once the whole flow (work → optional
                // event → return) has actually finished.
                self.workSessionCoordinator = nil
            }
        )
        workSessionCoordinator = coordinator
        coordinator.start(presentingFrom: self)
    }

}

