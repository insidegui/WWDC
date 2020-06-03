//
//  ClipSharingViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 02/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit

final class ClipSharingViewController: NSViewController {

    struct Constants {
        // Limit shared clips to a maximum of 5 minutes.
        static let maximumDuration: Float64 = 60 * 5
        static let humanReadableMaxDuration = "5 minutes"
    }

    let assetURL: URL
    let asset: AVURLAsset
    let initialBeginTime: CMTime?
    let clipTitle: String
    let clipSubtitle: String

    var completionHandler: () -> Void = { }

    init(with assetURL: URL, initialBeginTime: CMTime?, title: String, subtitle: String) {
        assert(assetURL.isFileURL, "Clip sharing is not supported with streaming video")

        self.assetURL = assetURL
        self.asset = AVURLAsset(url: assetURL)
        self.initialBeginTime = initialBeginTime
        self.clipTitle = title
        self.clipSubtitle = subtitle

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    private lazy var player: AVPlayer = {
        AVPlayer(playerItem: AVPlayerItem(asset: asset))
    }()

    private lazy var progressIndicator: NSProgressIndicator = {
        let v = NSProgressIndicator()

        v.style = .spinning
        v.isIndeterminate = true
        v.isDisplayedWhenStopped = false
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private lazy var exportingBackgroundView: NSVisualEffectView = {
        let v = NSVisualEffectView(frame: view.bounds)

        v.autoresizingMask = [.width, .height]
        v.blendingMode = .withinWindow
        v.material = .hudWindow

        return v
    }()

    private lazy var exportingLabel: NSTextField = {
        let v = NSTextField(labelWithString: "Preparing Clip")

        v.alignment = .center
        v.textColor = .primaryText
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private lazy var cancelButton: NSButton = {
        let v = NSButton(title: "Cancel", target: self, action: #selector(cancel))

        v.translatesAutoresizingMaskIntoConstraints = false
        v.controlSize = .small

        return v
    }()

    private(set) lazy var playerView: AVPlayerView = {
        let v = AVPlayerView()

        v.player = player
        v.autoresizingMask = [.width, .height]
        v.frame = view.bounds

        return v
    }()

    private var uiMaskObservationToken: NSObjectProtocol?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        view.addSubview(progressIndicator)

        NSLayoutConstraint.activate([
            progressIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            progressIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        uiMaskObservationToken = NotificationCenter.default.addObserver(forName: .WWDCWindowWillHideUIMask, object: nil, queue: .main) { [weak self] note in
            guard let self = self else { return }
            guard self.view.window == note.object as? NSWindow else { return }

            self.hide()
        }
    }

    private var playerStatusObservation: NSKeyValueObservation?

    override func viewWillAppear() {
        super.viewWillAppear()

        progressIndicator.startAnimation(nil)

        asset.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self?.beginTrimming()
            }
        }

        playerStatusObservation = player.observe(\.status, changeHandler: { [weak self] player, _ in
            DispatchQueue.main.async {
                switch player.status {
                case .failed:
                    self?.showLoadError()
                default:
                    break
                }
            }
        })
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        NSApp.sendAction(#selector(WWDCWindow.maskUI(preserving:)), to: nil, from: view)
    }

    private func showLoadError() {
        presentError(NSError(domain: "", code: 0, userInfo: [NSLocalizedRecoverySuggestionErrorKey: "The video couldn't be loaded. Try again later."]))
    }

    func hide() {
        guard view.superview != nil else { return }

        if renderer != nil {
            cancel()
        }

        view.removeFromSuperview()
        removeFromParent()

        NSApp.sendAction(#selector(WWDCWindow.hideUIMask), to: nil, from: nil)

        completionHandler()
    }

    private func beginTrimming() {
        view.addSubview(playerView, positioned: .below, relativeTo: progressIndicator)

        guard playerView.canBeginTrimming else {
            hide()
            return
        }

        progressIndicator.stopAnimation(nil)

        if let suggestedTime = initialBeginTime {
            configureClipForSuggestedTime(suggestedTime)
        }

        playerView.beginTrimming { [weak self] result in
            DispatchQueue.main.async {
                guard result == .okButton else {
                    self?.hide()
                    return
                }

                self?.exportClip()
            }
        }

        view.window?.makeFirstResponder(playerView)
    }

    private func configureClipForSuggestedTime(_ time: CMTime) {
        let fifteenSeconds = CMTimeMakeWithSeconds(15, preferredTimescale: 9000)
        let startTime = CMTimeSubtract(time, fifteenSeconds)
        let endTime = CMTimeAdd(time, fifteenSeconds)

        if CMTIME_IS_VALID(startTime) {
            player.currentItem?.reversePlaybackEndTime = startTime
        }

        if CMTIME_IS_VALID(endTime) {
            player.currentItem?.forwardPlaybackEndTime = endTime
        }

        player.seek(to: time)
    }

    private var renderer: ClipRenderer?

    private func exportClip() {
        #if DEBUG
        if let testPath = UserDefaults.standard.string(forKey: "WWDCClipSharingShowSheetImmediatelly") {
            shareVideo(with: URL(fileURLWithPath: testPath))
            return
        }
        #endif

        guard let item = player.currentItem else { return }

        let range = CMTimeRangeFromTimeToTime(start: item.reversePlaybackEndTime, end: item.forwardPlaybackEndTime)
        guard CMTimeGetSeconds(range.duration) <= Constants.maximumDuration else {
            showTimeLimitError()
            return
        }

        showProgressUI()

        renderer = ClipRenderer(
            playerItem: item,
            title: clipTitle,
            subtitle: clipSubtitle,
            fileNameHint: clipTitle.replacingOccurrences(of: ":", with: "")
        )

        renderer?.renderClip(progress: { [weak self] progress in
            self?.updateProgress(with: progress)
        }, completion: { [weak self] result in
            self?.handleCompletion(with: result)
        })
    }

    private func showTimeLimitError() {
        guard let window = view.window else { return }

        let alert = NSAlert()
        alert.messageText = "Selection too long"
        alert.informativeText = "Sorry, shared clips are limited to a maximum duration of \(Constants.humanReadableMaxDuration). Please select a shorter segment to share."
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window) { [weak self] _ in
            self?.beginTrimming()
        }
    }

    private func showProgressUI() {
        playerView.controlsStyle = .none

        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.startAnimation(nil)

        exportingBackgroundView.frame = view.bounds
        view.addSubview(exportingBackgroundView, positioned: .below, relativeTo: progressIndicator)
        view.addSubview(exportingLabel)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            exportingLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 6),
            exportingLabel.centerXAnchor.constraint(equalTo: progressIndicator.centerXAnchor),
            cancelButton.topAnchor.constraint(equalTo: exportingLabel.bottomAnchor, constant: 6),
            cancelButton.centerXAnchor.constraint(equalTo: progressIndicator.centerXAnchor)
        ])
    }

    private func updateProgress(with progress: Float) {
        progressIndicator.doubleValue = Double(progress)

        if progress >= 0.97 {
            cancelButton.isEnabled = false
            exportingLabel.stringValue = "Done!"
            progressIndicator.stopAnimation(nil)
        }
    }

    private func handleCompletion(with result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            shareVideo(with: url)
        case .failure(let error):
            presentError(error)
        }

        renderer = nil
    }

    private func shareVideo(with url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        picker.delegate = self
        picker.show(relativeTo: NSRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1), of: view, preferredEdge: .maxY)
    }

    @objc func cancel() {
        renderer?.cancel()
        renderer = nil
        hide()
    }
    
}

extension ClipSharingViewController: NSSharingServicePickerDelegate {

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        hide()
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {
        PickerDelegate.shared.sharingServicePicker(sharingServicePicker, sharingServicesForItems: items, proposedSharingServices: proposedServices)
    }

}
