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
import Combine

@MainActor
protocol SessionActionsViewControllerDelegate: AnyObject {
    func sessionActionsDidSelectSlides(_ sender: NSView?)
    func sessionActionsDidSelectFavorite(_ sender: NSView?)
    func sessionActionsDidSelectDownload(_ sender: NSView?)
    func sessionActionsDidSelectCalendar(_ sender: NSView?)
    func sessionActionsDidSelectDeleteDownload(_ sender: NSView?)
    func sessionActionsDidSelectCancelDownload(_ sender: NSView?)
    func sessionActionsDidSelectShare(_ sender: NSView?)
    func sessionActionsDidSelectShareClip(_ sender: NSView?)
}

class SessionActionsViewController: NSViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var cancellables: Set<AnyCancellable> = []

    var viewModel: SessionViewModel? {
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

    private lazy var downloadIndicator: WWDCProgressIndicator = {
        let pi = WWDCProgressIndicator(frame: NSRect(x: 0, y: 0, width: 24, height: 24))

        pi.isIndeterminate = false
        pi.translatesAutoresizingMaskIntoConstraints = false
        pi.widthAnchor.constraint(equalToConstant: 24).isActive = true
        pi.heightAnchor.constraint(equalToConstant: 24).isActive = true
        pi.isHidden = true
        pi.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(cancelDownload)))
        pi.toolTip = "Click to cancel"

        return pi
    }()

    private lazy var clipButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = #imageLiteral(resourceName: "clip")
        b.target = self
        b.action = #selector(shareClip)
        b.shouldAlwaysDrawHighlighted = true
        b.sendsActionOnMouseDown = true
        b.toolTip = "Share a Clip"

        return b
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
            self.clipButton,
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

    private struct DownloadButtonConfig {
        var hasDownloadableContent: Bool
        var isDownloaded: Bool
        var inFlightDownload: MediaDownload?
    }

    private func updateBindings() {
        cancellables = []
        downloadStateCancellable = nil

        guard let viewModel = viewModel else { return }

        slidesButton.isHidden = (viewModel.session.asset(ofType: .slides) == nil)
        calendarButton.isHidden = (viewModel.sessionInstance.startTime < today())

        viewModel.rxIsFavorite.replaceError(with: false).sink { [weak self] isFavorite in
            self?.favoriteButton.state = isFavorite ? .on : .off

            if isFavorite {
                self?.favoriteButton.toolTip = "Remove from favorites"
            } else {
                self?.favoriteButton.toolTip = "Add to favorites"
            }
        }
        .store(in: &cancellables)

        let downloadID = viewModel.session.downloadIdentifier

        /// Download state for existing in-flight download, or `nil` if there's no in-flight download for the session.
        let inFlightDownloadSignal: AnyPublisher<MediaDownload?, Never> = MediaDownloadManager.shared.$downloads
            .map { $0.first(where: { $0.id == downloadID }) }
            .eraseToAnyPublisher()
        
        /// `true` if the session has already been downloaded.
        let alreadyDownloaded: AnyPublisher<Session, Never> = viewModel.session
            .valuePublisher(keyPaths: ["isDownloaded"])
            .replaceErrorWithEmpty()
            .eraseToAnyPublisher()

        /// This publisher includes a flag indicating whether the session can be downloaded, as well as the current download state, if any.
        let downloadButtonConfig: AnyPublisher<DownloadButtonConfig, Never> = Publishers.CombineLatest(inFlightDownloadSignal, alreadyDownloaded)
            .map { inFlightDownload, session in
                if session.isDownloaded, MediaDownloadManager.shared.hasDownloadedMedia(for: session) {
                    return DownloadButtonConfig(hasDownloadableContent: true, isDownloaded: true)
                } else {
                    guard !session.assets(matching: Session.mediaDownloadVariants).isEmpty else {
                        return DownloadButtonConfig(hasDownloadableContent: false, isDownloaded: false)
                    }
                    if let inFlightDownload {
                        return DownloadButtonConfig(hasDownloadableContent: true, isDownloaded: false, inFlightDownload: inFlightDownload)
                    } else {
                        return DownloadButtonConfig(hasDownloadableContent: true, isDownloaded: false)
                    }
                }
            }
            .eraseToAnyPublisher()

        downloadButtonConfig
            .throttle(for: .milliseconds(800), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] config in
                self?.configureDownloadButton(with: config)
            }
            .store(in: &cancellables)
    }

    private var downloadStateCancellable: AnyCancellable?

    private func configureDownloadButton(with config: DownloadButtonConfig) {
        downloadStateCancellable = nil
        
        guard config.hasDownloadableContent else {
            /// Session can't be downloaded (maybe Lab or download not available yet)
            downloadIndicator.isHidden = true
            downloadButton.isHidden = true
            clipButton.isHidden = true
            resetDownloadButton()
            return
        }

        guard !config.isDownloaded else {
            updateDownloadButton(with: .completed)
            return
        }

        guard let inFlightDownload = config.inFlightDownload else {
            updateDownloadButton(with: nil)
            return
        }

        downloadStateCancellable = inFlightDownload.$state.receive(on: DispatchQueue.main).sink { [weak self] state in
            self?.updateDownloadButton(with: state)
        }
    }

    private func updateDownloadButton(with state: MediaDownloadState?) {
        guard let session = viewModel?.session else { return }

        func applyStartDownloadState() {
            resetDownloadButton()
            downloadIndicator.isHidden = true
            downloadButton.isHidden = false
            clipButton.isHidden = true
            if case .failed(let message) = state {
                downloadButton.toolTip = message
            } else {
                downloadButton.toolTip = nil
            }
        }

        /// We may have a download that's in completed state, but where the file has already been deleted,
        /// in which case we show the button state to start the download.
        if case .completed = state {
            guard MediaDownloadManager.shared.hasDownloadedMedia(for: session) else {
                applyStartDownloadState()
                return
            }
        }

        switch state {
        case .waiting:
            downloadIndicator.isHidden = false
            downloadButton.isHidden = true
            downloadButton.toolTip = "Preparing download"
            clipButton.isHidden = true
            downloadIndicator.isIndeterminate = true
            downloadIndicator.startAnimating()
        case .downloading(let progress):
            downloadButton.toolTip = "Downloading: \(progress.formattedDownloadPercentage())"
            downloadIndicator.isHidden = false
            downloadButton.isHidden = true
            clipButton.isHidden = true

            if progress < 0 {
                downloadIndicator.isIndeterminate = true
                downloadIndicator.startAnimating()
            } else {
                downloadIndicator.isIndeterminate = false
                downloadIndicator.progress = Float(progress)
            }
        case .paused, .cancelled, .none, .failed:
            applyStartDownloadState()
        case .completed:
            downloadButton.toolTip = "Delete downloaded video"
            downloadButton.isHidden = false
            downloadIndicator.isHidden = true
            downloadButton.image = #imageLiteral(resourceName: "trash")
            downloadButton.action = #selector(SessionActionsViewController.deleteDownload)
            clipButton.isHidden = false
        }
    }

    private func resetDownloadButton() {
        downloadButton.toolTip = "Download video for offline watching"
        downloadButton.image = #imageLiteral(resourceName: "download")
        downloadButton.action = #selector(SessionActionsViewController.download)
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
        downloadIndicator.startAnimating()
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

    @IBAction func shareClip(_ sender: NSView?) {
        delegate?.sessionActionsDidSelectShareClip(sender)
    }

    @IBAction func cancelDownload(_ sender: NSView?) {
        delegate?.sessionActionsDidSelectCancelDownload(sender)
    }
}

extension NumberFormatter {
    static let downloadPercent: NumberFormatter = {
        let f = NumberFormatter()
        f.maximumFractionDigits = 0
        f.numberStyle = .percent
        return f
    }()
}

extension Double {
    func formattedDownloadPercentage() -> String {
        NumberFormatter.downloadPercent.string(from: NSNumber(value: self)) ?? ""
    }
}
