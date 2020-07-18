//
//  ShelfViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa
import CoreMedia

protocol ShelfViewControllerDelegate: class {
    func shelfViewControllerDidSelectPlay(_ controller: ShelfViewController)
    func shelfViewController(_ controller: ShelfViewController, didBeginClipSharingWithHost hostView: NSView)
    func suggestedBeginTimeForClipSharingInShelfViewController(_ controller: ShelfViewController) -> CMTime?
    func shelfViewControllerDidEndClipSharing(_ controller: ShelfViewController)
}

class ShelfViewController: NSViewController {

    weak var delegate: ShelfViewControllerDelegate?

    private var disposeBag = DisposeBag()

    var viewModel: SessionViewModel? = nil {
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

    private weak var currentImageDownloadOperation: Operation?

    private func updateBindings() {
        disposeBag = DisposeBag()

        guard let viewModel = viewModel else {
            shelfView.image = nil
            return
        }

        viewModel.rxCanBePlayed.map({ !$0 }).bind(to: playButton.rx.isHidden).disposed(by: disposeBag)

        viewModel.rxImageUrl.subscribe(onNext: { [weak self] imageUrl in
            self?.currentImageDownloadOperation?.cancel()
            self?.currentImageDownloadOperation = nil

            guard let imageUrl = imageUrl else {
                self?.shelfView.image = #imageLiteral(resourceName: "noimage")
                return
            }

            self?.currentImageDownloadOperation = ImageDownloadCenter.shared.downloadImage(from: imageUrl, thumbnailHeight: Constants.thumbnailHeight) { url, result in
                self?.shelfView.image = result.original
            }
        }).disposed(by: disposeBag)
    }

    @objc private func play(_ sender: Any?) {

        self.delegate?.shelfViewControllerDidSelectPlay(self)
    }

    private var sharingController: ClipSharingViewController?

    func showClipUI() {
        guard let session = viewModel?.session else { return }
        guard let url = DownloadManager.shared.downloadedFileURL(for: session) else { return }

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

}
