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

protocol ShelfViewControllerDelegate: class {
    func shelfViewControllerDidSelectPlay(_ controller: ShelfViewController)
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
        super.init(nibName: nil, bundle: nil)!
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
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateBindings()
    }

    private var currentImageDownloadOperation: Operation?

    private func updateBindings() {
        self.disposeBag = DisposeBag()

        guard let viewModel = viewModel else { return }

        viewModel.rxCanBePlayed.map({ !$0 }).bind(to: playButton.rx.isHidden).addDisposableTo(self.disposeBag)

        viewModel.rxImageUrl.subscribe(onNext: { [weak self] imageUrl in
            self?.currentImageDownloadOperation?.cancel()
            self?.currentImageDownloadOperation = nil

            guard let imageUrl = imageUrl else {
                self?.shelfView.image = #imageLiteral(resourceName: "noimage")
                return
            }

            self?.currentImageDownloadOperation = ImageDownloadCenter.shared.downloadImage(from: imageUrl, thumbnailHeight: Constants.thumbnailHeight) { url, original, _ in
                guard url == imageUrl else { return }

                self?.shelfView.image = original
            }
        }).addDisposableTo(self.disposeBag)
    }

    @objc private func play(_ sender: Any?) {
        delegate?.shelfViewControllerDidSelectPlay(self)
    }
    
}
