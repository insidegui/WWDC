//
//  SessionTranscriptWindowController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 30/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore

final class SessionTranscriptWindowController: NSWindowController {

    var viewModel: SessionViewModel? {
        didSet {
            guard viewModel?.identifier != oldValue?.identifier else { return }

            updateUI()
        }
    }

    private lazy var transcriptController: SessionTranscriptViewController = {
        SessionTranscriptViewController()
    }()

    static let defaultRect = NSRect(x: 0, y: 0, width: 400, height: 560)

    init() {
        let window = NSWindow(contentRect: Self.defaultRect, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        super.init(window: window)

        window.identifier = NSUserInterfaceItemIdentifier(rawValue: "transcriptWindow")
        window.setFrameAutosaveName("transcriptWindow")
        window.minSize = NSSize(width: 360, height: 260)
        window.animationBehavior = .documentWindow

        transcriptController.showsNewWindowButton = false
        transcriptController.enforcesHeight = false
        transcriptController.searchStyle = .fullWidth

        contentViewController = transcriptController
    }

    override func showWindow(_ sender: Any?) {
        window?.center()

        super.showWindow(sender)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateUI() {
        guard let viewModel = viewModel else { return }

        window?.title = "Transcript - \(viewModel.title)"
        transcriptController.viewModel = viewModel
    }

}
