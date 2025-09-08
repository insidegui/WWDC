//
//  ShelfViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import Combine
import CoreMedia
import PlayerUI
import AVFoundation
import SwiftUI

@MainActor
protocol ShelfViewControllerDelegate: AnyObject {
    func shelfViewControllerDidSelectPlay(_ controller: ShelfViewController)
    func shelfViewController(_ controller: ShelfViewController, didBeginClipSharingWithHost hostView: NSView)
    func suggestedBeginTimeForClipSharingInShelfViewController(_ controller: ShelfViewController) -> CMTime?
    func shelfViewControllerDidEndClipSharing(_ controller: ShelfViewController)
}

final class ShelfViewController: NSViewController, PUIPlayerViewDetachedStatusPresenter {

    weak var delegate: ShelfViewControllerDelegate?

    private lazy var cancellables: Set<AnyCancellable> = []

    var viewModel: SessionViewModel? {
        didSet {
            updateBindings()
        }
    }

    lazy var shelfView: ShelfView = {
        let v = ShelfView()

        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    lazy var playerContainer: NSView = {
        let v = NSView()

        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    lazy var playButton: VibrantButton = {
        let b = VibrantButton(frame: .zero)

        b.title = "Play"
        b.translatesAutoresizingMaskIntoConstraints = false
        b.target = self
        b.action = #selector(play)
        b.isHidden = true

        return b
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height / 2))
        view.wantsLayer = true

        view.addSubview(shelfView)
        shelfView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        shelfView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        shelfView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        shelfView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        view.addSubview(playButton)
        playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        playButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true

        view.addSubview(playerContainer)
        playerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        playerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        playerContainer.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        playerContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateBindings()
    }

    override func viewWillLayout() {
        updateVideoLayoutGuide()

        super.viewWillLayout()
    }

    private var currentImageSessionIdentifier: String?

    private func updateBindings() {
        cancellables = []

        if detachedSessionID != nil {
            UILog("📚 Selected session: \(viewModel?.sessionIdentifier ?? "<nil>"), detached session: \(detachedSessionID ?? "<nil>")")
        }

        if viewModel?.sessionIdentifier != detachedSessionID {
            hideDetachedStatus()
        } else if let detachedSessionID, viewModel?.sessionIdentifier == detachedSessionID {
            showDetachedStatus()
        }

        guard let viewModel else {
            shelfView.image = nil
            currentImageSessionIdentifier = nil
            return
        }
        viewModel.connect()

        viewModel.$canBePlayed.toggled().driveUI(\.isHidden, on: playButton).store(in: &cancellables)
        viewModel.$imageURL.removeDuplicates()
            .sink { [sessionIdentifier = viewModel.session.identifier, weak self] imageUrl in
                self?.loadSessionImage(at: imageUrl, for: sessionIdentifier)
            }
            .store(in: &cancellables)
    }

    /// The logic/bookkeeping around the current image session identifier is to allow
    /// images to be updated continuously while quickly navigating through sessions via arrow keys.
    ///
    /// Since the loads are concurrent, it means in order to achieve the effect of the image updating live
    /// while navigating, but still ensure that an out-of-order image load doesn't clobber the _correct_ image,
    /// we need to know the session ID for the image that is currently being displayed.
    private func loadSessionImage(at imageUrl: URL?, for sessionIdentifier: String) {
        guard let imageUrl else {
            shelfView.image = NSImage(resource: .noImageAvailable)
            currentImageSessionIdentifier = nil
            return
        }

        // TODO: Use Task.immediate when available
        let task = Task { [weak self] in
            guard let self else { return }

            let result = await ImageDownloadCenter.shared.downloadImage(from: imageUrl, thumbnailHeight: Constants.thumbnailHeight)

            guard let image = result.original else { return }

            @MainActor func setImage() {
                shelfView.image = image
                currentImageSessionIdentifier = sessionIdentifier
            }

            guard let currentImageSessionIdentifier else {
                // No image for the current session, might be placeholder
                setImage()
                return
            }

            // Current image is for a session that is not currently selected, so it's safe to update it.
            if currentImageSessionIdentifier != self.viewModel?.session.identifier {
                setImage()
            } else {
                // The current image is for the currently selected session, so we don't update it.
            }
        }

        cancellables.insert(AnyCancellable(task.cancel))
    }

    @objc func play(_ sender: Any?) {
        self.delegate?.shelfViewControllerDidSelectPlay(self)
    }

    private var sharingController: ClipSharingViewController?

    func showClipUI() {
        guard let session = viewModel?.session else { return }
        guard let url = MediaDownloadManager.shared.downloadedFileURL(for: session) else { return }

        let subtitle = session.event.first?.name ?? "Apple Developer"

        let suggestedTime = delegate?.suggestedBeginTimeForClipSharingInShelfViewController(self)

        let controller = ClipSharingViewController(
            with: url,
            initialBeginTime: suggestedTime,
            title: session.title,
            subtitle: subtitle
        )

        addChild(controller)
        controller.view.autoresizingMask = [.width, .height]
        controller.view.frame = playerContainer.bounds
        playerContainer.addSubview(controller.view)

        sharingController = controller

        delegate?.shelfViewController(self, didBeginClipSharingWithHost: controller.playerView)

        controller.completionHandler = { [weak self] in
            guard let self = self else { return }

            self.delegate?.shelfViewControllerDidEndClipSharing(self)
        }
    }

    // MARK: - Detached Playback Status

    /// ID of the session being displayed by the shelf when the player was detached.
    private var detachedSessionID: String?
    private weak var detachedPlayer: AVPlayer?
    private var currentDetachedStatusID: DetachedPlaybackStatus.ID?

    /// Shows detached status view without modifying state.
    func showDetachedStatus() {
        guard detachedStatusController.parent != nil else { return }

        detachedStatusController.show()

        shelfView.isHidden = true

        view.needsLayout = true
    }

    /// Hides detached status view without resetting state.
    func hideDetachedStatus() {
        guard detachedStatusController.parent != nil else { return }

        detachedStatusController.hide()

        shelfView.isHidden = false
    }

    func presentDetachedStatus(_ status: DetachedPlaybackStatus, for playerView: PUIPlayerView) {
        guard let player = playerView.player else { return }

        /// We can't present multiple detached statuses at once, so the first detachment wins.
        /// This can happen for example if PiP is initiated in the full screen window,
        /// we want to keep showing the full screen status, rather than overriding it with PiP.
        guard currentDetachedStatusID == nil else { return }

        UILog("📚 Detaching with \(viewModel?.sessionIdentifier ?? "<nil>")")

        self.currentDetachedStatusID = status.id
        self.detachedSessionID = viewModel?.sessionIdentifier
        self.detachedPlayer = player

        installDetachedStatusControllerIfNeeded()

        detachedStatusController.status = status
        
        showDetachedStatus()
    }

    func dismissDetachedStatus(_ status: DetachedPlaybackStatus, for playerView: PUIPlayerView) {
        /// We only dismiss the detached status that's currently being presented.
        /// Example: if playing in full screen, user can enter PiP, but exiting PiP won't clear the detached status for full screen.
        guard status.id == currentDetachedStatusID else { return }

        hideDetachedStatus()

        self.currentDetachedStatusID = nil
        self.detachedSessionID = nil
        self.detachedPlayer = nil
    }

    private lazy var detachedStatusController = PUIDetachedPlaybackStatusViewController()

    private func installDetachedStatusControllerIfNeeded() {
        guard detachedStatusController.parent == nil else { return }

        updateVideoLayoutGuide()

        addChild(detachedStatusController)

        let statusView = detachedStatusController.view
        statusView.wantsLayer = true
        statusView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusView, positioned: .above, relativeTo: view.subviews.first)

        statusView.layer?.zPosition = 9

        NSLayoutConstraint.activate([
            statusView.leadingAnchor.constraint(equalTo: videoLayoutGuide.leadingAnchor),
            statusView.trailingAnchor.constraint(equalTo: videoLayoutGuide.trailingAnchor),
            statusView.topAnchor.constraint(equalTo: videoLayoutGuide.topAnchor),
            statusView.bottomAnchor.constraint(equalTo: videoLayoutGuide.bottomAnchor)
        ])
    }

    private lazy var videoLayoutGuide = NSLayoutGuide()
    private lazy var videoLayoutGuideConstraints = [NSLayoutConstraint]()

    private func updateVideoLayoutGuide() {
        guard let detachedPlayer else { return }

        detachedPlayer.updateLayout(guide: videoLayoutGuide, container: view, constraints: &videoLayoutGuideConstraints)
    }

}

struct ShelfViewControllerWrapper: NSViewControllerRepresentable {
    let controller: ShelfViewController

    func makeNSViewController(context: Context) -> ShelfViewController {
        return controller
    }

    func updateNSViewController(_ nsViewController: ShelfViewController, context: Context) {
        // No updates needed - controller manages its own state
    }
}
