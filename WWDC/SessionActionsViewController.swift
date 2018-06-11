//
//  SessionActionsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import PlayerUI
import ConfCore
import RxSwift
import RxCocoa

protocol SessionActionsViewControllerDelegate: class {

    func sessionActionsDidSelectSlides(_ sender: NSView?)
    func sessionActionsDidSelectFavorite(_ sender: NSView?)
    func sessionActionsDidSelectDownload(_ sender: NSView?)
    func sessionActionsDidSelectCalendar(_ sender: NSView?)
    func sessionActionsDidSelectDeleteDownload(_ sender: NSView?)
    func sessionActionsDidSelectCancelDownload(_ sender: NSView?)
    func sessionActionsDidSelectShare(_ sender: NSView?)
}

class SessionActionsViewController: NSViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var disposeBag = DisposeBag()

    var viewModel: SessionViewModel? = nil {
        didSet {
            resetDownloadButton()
            updateBindings()
        }
    }

    weak var delegate: SessionActionsViewControllerDelegate?

    private lazy var favoriteButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = #imageLiteral(resourceName: "favorite")
        b.alternateImage = #imageLiteral(resourceName: "favorite-filled")
        b.target = self
        b.action = #selector(toggleFavorite)
        b.isToggle = true
        b.shouldAlwaysDrawHighlighted = true

        return b
    }()

    private lazy var slidesButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = #imageLiteral(resourceName: "slides")
        b.target = self
        b.action = #selector(showSlides)
        b.shouldAlwaysDrawHighlighted = true
        b.toolTip = "Open slides"

        return b
    }()

    private lazy var downloadButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = #imageLiteral(resourceName: "download")
        b.target = self
        b.action = #selector(download)
        b.shouldAlwaysDrawHighlighted = true

        return b
    }()

    private lazy var calendarButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = #imageLiteral(resourceName: "calendar")
        b.target = self
        b.action = #selector(addCalendar(_:))
        b.shouldAlwaysDrawHighlighted = true
        b.toolTip = "Add to Calendar"

        return b
    }()

    private lazy var downloadIndicator: NSProgressIndicator = {
        let pi = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 24, height: 24))

        pi.style = .spinning
        pi.isIndeterminate = false
        pi.minValue = 0
        pi.maxValue = 1
        pi.doubleValue = 0
        pi.translatesAutoresizingMaskIntoConstraints = false
        pi.widthAnchor.constraint(equalToConstant: 24).isActive = true
        pi.heightAnchor.constraint(equalToConstant: 24).isActive = true
        pi.isHidden = true
        pi.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(cancelDownload)))
        pi.toolTip = "Click to cancel"

        return pi
    }()

    private lazy var shareButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = #imageLiteral(resourceName: "share")
        b.target = self
        b.action = #selector(share)
        b.shouldAlwaysDrawHighlighted = true
        b.sendsActionOnMouseDown = true
        b.toolTip = "Share session"

        return b
    }()

    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [
            self.slidesButton,
            self.favoriteButton,
            self.downloadButton,
            self.downloadIndicator,
            self.shareButton,
            self.calendarButton
            ])

        v.orientation = .horizontal
        v.spacing = 22
        v.alignment = .centerY
        v.distribution = .equalSpacing

        return v
    }()

    override func loadView() {
        view = stackView
        view.wantsLayer = true
        view.translatesAutoresizingMaskIntoConstraints = false

        view.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateBindings()
    }

    private func updateBindings() {
        disposeBag = DisposeBag()

        guard let viewModel = viewModel else { return }

        slidesButton.isHidden = (viewModel.session.asset(of: .slides) == nil)
        calendarButton.isHidden = (viewModel.sessionInstance.startTime < today())

        viewModel.rxIsFavorite.subscribe(onNext: { [weak self] isFavorite in
            self?.favoriteButton.state = isFavorite ? .on : .off

            if isFavorite {
                self?.favoriteButton.toolTip = "Remove from favorites"
            } else {
                self?.favoriteButton.toolTip = "Add to favorites"
            }
        }).disposed(by: disposeBag)

        if let rxDownloadState = DownloadManager.shared.downloadStatusObservable(for: viewModel.session) {
            rxDownloadState.throttle(0.8, scheduler: MainScheduler.instance).subscribe(onNext: { [weak self] status in
                switch status {
                case .downloading(let progress):
                    self?.downloadIndicator.isHidden = false
                    self?.downloadButton.isHidden = true

                    if progress < 0 {
                        self?.downloadIndicator.isIndeterminate = true
                        self?.downloadIndicator.startAnimation(nil)
                    } else {
                        self?.downloadIndicator.isIndeterminate = false
                        self?.downloadIndicator.doubleValue = progress
                    }
                case .paused, .cancelled, .none, .failed:
                    self?.resetDownloadButton()
                    self?.downloadIndicator.isHidden = true
                    self?.downloadButton.isHidden = false
                case .finished:
                    self?.downloadButton.toolTip = "Delete downloaded video"
                    self?.downloadButton.isHidden = false
                    self?.downloadIndicator.isHidden = true
                    self?.downloadButton.image = #imageLiteral(resourceName: "trash")
                    self?.downloadButton.action = #selector(SessionActionsViewController.deleteDownload)
                }
            }).disposed(by: disposeBag)
        } else {
            // session can't be downloaded (maybe Lab or download not available yet)
            downloadIndicator.isHidden = true
            downloadButton.isHidden = true
            resetDownloadButton()
        }
    }

    private func resetDownloadButton() {
        downloadButton.toolTip = "Download video for offline watching"
        downloadButton.image = #imageLiteral(resourceName: "download")
        downloadButton.action = #selector(download)
    }

    @IBAction func toggleFavorite(_ sender: NSView?) {
        delegate?.sessionActionsDidSelectFavorite(sender)
    }

    @IBAction func showSlides(_ sender: NSView?) {
        delegate?.sessionActionsDidSelectSlides(sender)
    }

    @IBAction func download(_ sender: NSView?) {
        downloadButton.isHidden = true
        downloadIndicator.isIndeterminate = true
        downloadIndicator.startAnimation(nil)
        downloadIndicator.isHidden = false

        delegate?.sessionActionsDidSelectDownload(sender)
    }

    @IBAction func addCalendar(_ sender: NSView?) {
        delegate?.sessionActionsDidSelectCalendar(sender)
    }

    @IBAction func deleteDownload(_ sender: NSView?) {
        delegate?.sessionActionsDidSelectDeleteDownload(sender)
    }

    @IBAction func share(_ sender: NSView?) {
        delegate?.sessionActionsDidSelectShare(sender)
    }

    @IBAction func cancelDownload(_ sender: NSView?) {
        delegate?.sessionActionsDidSelectCancelDownload(sender)
    }
}
