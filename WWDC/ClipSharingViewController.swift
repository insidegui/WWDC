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

    let assetURL: URL
    let asset: AVURLAsset
    let initialBeginTime: CMTime?

    var completionHandler: () -> Void = { }

    init(with assetURL: URL, initialBeginTime: CMTime?) {
        assert(assetURL.isFileURL, "Clip sharing is not supported with streaming video")

        self.assetURL = assetURL
        self.asset = AVURLAsset(url: assetURL)
        self.initialBeginTime = initialBeginTime

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
            player.currentItem?.reversePlaybackEndTime = suggestedTime
            player.seek(to: suggestedTime)
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

    private var renderer: ClipRenderer?

    private func exportClip() {
        #if DEBUG
        if let testPath = UserDefaults.standard.string(forKey: "WWDCClipSharingShowSheetImmediatelly") {
            shareVideo(with: URL(fileURLWithPath: testPath))
            return
        }
        #endif

        guard let item = player.currentItem else { return }

        showProgressUI()

        renderer = ClipRenderer(playerItem: item, fileNameHint: nil)
        renderer?.renderClip(progress: { [weak self] progress in
            self?.updateProgress(with: progress)
        }, completion: { [weak self] result in
            self?.handleCompletion(with: result)
        })
    }

    private func showProgressUI() {
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.startAnimation(nil)

        exportingBackgroundView.frame = view.bounds
        view.addSubview(exportingBackgroundView, positioned: .below, relativeTo: progressIndicator)
        view.addSubview(exportingLabel)

        NSLayoutConstraint.activate([
            exportingLabel.topAnchor.constraint(equalTo: progressIndicator.bottomAnchor, constant: 6),
            exportingLabel.centerXAnchor.constraint(equalTo: progressIndicator.centerXAnchor)
        ])
    }

    private func updateProgress(with progress: Float) {
        progressIndicator.doubleValue = Double(progress)

        if progress >= 0.97 {
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
    }

    private func shareVideo(with url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        picker.delegate = self
        picker.show(relativeTo: NSRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1), of: view, preferredEdge: .maxY)
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
