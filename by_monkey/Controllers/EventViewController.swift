//
//  EventViewController.swift
//  by_monkey
//

import UIKit

/// The post-action conversation event screen: background, character stage, top status,
/// and a bottom dialogue box. Pure presentation/interaction — dialogue progress and its
/// persistence live in `EventFlowViewModel`; deciding *whether* to show this screen at
/// all is the coordinator's job, not this view controller's.
final class EventViewController: UIViewController {

    private let viewModel: EventFlowViewModel
    private let backgroundAssetName: String
    private let locationName: String
    private let dayNumber: Int
    private let timePeriod: TimeOfDay

    /// Called exactly once, when the player has tapped through the final line and it
    /// was successfully marked complete.
    var onFinished: (() -> Void)?

    private let backgroundImageView = UIImageView()
    private let topScrimLayer = CAGradientLayer()
    private let bottomScrimLayer = CAGradientLayer()

    private let infoHeader = EventInfoHeaderView()
    private let stageView: EventCharacterStageView
    private let dialogueBox = EventDialogueBoxView()

    init(viewModel: EventFlowViewModel, backgroundAssetName: String, locationName: String, dayNumber: Int, timePeriod: TimeOfDay) {
        self.viewModel = viewModel
        self.backgroundAssetName = backgroundAssetName
        self.locationName = locationName
        self.dayNumber = dayNumber
        self.timePeriod = timePeriod
        self.stageView = EventCharacterStageView(characters: viewModel.characters)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpBackground()
        setUpInfoHeader()
        setUpStage()
        setUpDialogueBox()
        setUpLayout()

        viewModel.onStageChanged = { [weak self] in
            self?.render(animated: true)
        }
        render(animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        topScrimLayer.frame = view.bounds
        bottomScrimLayer.frame = view.bounds
    }

    private func setUpBackground() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.image = UIImage(named: backgroundAssetName)
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        view.addSubview(backgroundImageView)

        topScrimLayer.colors = [
            UIColor.black.withAlphaComponent(0.75).cgColor,
            UIColor.black.withAlphaComponent(0).cgColor,
        ]
        topScrimLayer.locations = [0, 0.3]
        view.layer.addSublayer(topScrimLayer)

        bottomScrimLayer.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.85).cgColor,
        ]
        bottomScrimLayer.locations = [0.5, 1.0]
        view.layer.addSublayer(bottomScrimLayer)
    }

    private func setUpInfoHeader() {
        infoHeader.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoHeader)

        infoHeader.configure(
            locationText: locationName,
            dayNumber: dayNumber,
            timeOfDay: timePeriod,
            contextCaption: "打工後・事件",
            eventTitle: viewModel.event.title
        )
    }

    private func setUpStage() {
        stageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stageView)
    }

    private func setUpDialogueBox() {
        dialogueBox.translatesAutoresizingMaskIntoConstraints = false
        dialogueBox.onTap = { [weak self] in
            self?.handleDialogueTap()
        }
        view.addSubview(dialogueBox)
    }

    private func setUpLayout() {
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            infoHeader.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            infoHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            infoHeader.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            dialogueBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            dialogueBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            dialogueBox.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            // The stage sits behind the dialogue box (per spec, a character's lower body
            // may extend behind it) but is pinned to a FIXED anchor, not to the dialogue
            // box's own top — the dialogue box auto-sizes with text length, and anchoring
            // the stage to it would resize/reposition the stage on every line, making
            // even a "resting" (non-speaking) character appear to drift. Faces still stay
            // clear of the box because of this fixed gap.
            stageView.topAnchor.constraint(equalTo: infoHeader.bottomAnchor, constant: 16),
            stageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            stageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            stageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -140),
        ])
    }

    private func render(animated: Bool) {
        switch viewModel.stage {
        case .line, .completionFailed:
            guard let line = viewModel.currentLine else { return }
            let speakerName = viewModel.speakerDisplayName(for: line)
            dialogueBox.setLine(
                speaker: speakerName,
                text: viewModel.resolvedText(for: line),
                progressText: viewModel.progressText,
                continuePrompt: viewModel.continuePromptText,
                animated: animated
            )
            stageView.update(stage: line.stage, speakerID: line.speakerID, animated: animated)
        case .finished:
            onFinished?()
        }
    }

    private func handleDialogueTap() {
        switch viewModel.stage {
        case .line, .completionFailed:
            viewModel.advance()
        case .finished:
            break
        }
    }
}
