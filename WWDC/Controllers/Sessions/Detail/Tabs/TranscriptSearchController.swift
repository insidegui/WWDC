//
//  TranscriptSearchController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 30/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import Combine
import PlayerUI

final class TranscriptSearchController: NSViewController {

    enum Style: Int {
        case fullWidth
        case corner
    }

    var style: Style = .corner {
        didSet {
            guard style != oldValue else { return }

            updateStyle()
        }
    }

    var showsNewWindowButton: Bool {
        get { !detachButton.isHidden }
        set { detachButton.isHidden = !newValue }
    }

    var didSelectOpenInNewWindow: () -> Void = { }
    var didSelectExportTranscript: () -> Void = { }

    @Published
    private(set) var searchTerm: String = ""

    private lazy var detachButton: PUIButton = {
        let b = PUIButton(frame: .zero)

        b.image = #imageLiteral(resourceName: "window")
        b.target = self
        b.action = #selector(openInNewWindow)
        b.toolTip = "Open Transcript in New Window"
        b.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        b.widthAnchor.constraint(equalToConstant: 18).isActive = true
        b.heightAnchor.constraint(equalToConstant: 14).isActive = true

        return b
    }()
    
    private lazy var exportButton: NSView = {
        let b = PUIButton(frame: .zero)
        
        b.image = #imageLiteral(resourceName: "share")
        b.target = self
        b.action = #selector(exportTranscript)
        b.toolTip = "Export Transcript"
        b.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        b.translatesAutoresizingMaskIntoConstraints = false
        
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(b)
        
        NSLayoutConstraint.activate([
            b.widthAnchor.constraint(equalToConstant: 14),
            b.heightAnchor.constraint(equalToConstant: 18),
            container.widthAnchor.constraint(equalToConstant: 14),
            container.heightAnchor.constraint(equalToConstant: 22),
            b.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            b.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -2)
        ])
        
        return container
    }()

    private lazy var searchField: NSSearchField = {
        let f = NSSearchField()

        f.translatesAutoresizingMaskIntoConstraints = false
        f.setContentHuggingPriority(.defaultLow, for: .horizontal)

        return f
    }()

    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.searchField, self.exportButton, self.detachButton])

        v.orientation = .horizontal
        v.spacing = 8
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private lazy var widthConstraint: NSLayoutConstraint = {
        view.widthAnchor.constraint(equalToConstant: 226)
    }()

    static let height: CGFloat = 40

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerCurve = .continuous
        view.layer?.backgroundColor = NSColor.roundedCellBackground.cgColor

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: Self.height),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])

        updateStyle()
    }

    private lazy var cancellables: Set<AnyCancellable> = []

    override func viewDidLoad() {
        super.viewDidLoad()

        let throttledSearch = NotificationCenter.default.publisher(for: NSControl.textDidChangeNotification, object: searchField)
            .map {
                ($0.object as? NSSearchField)?.stringValue ?? ""
            }
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .share()
        
        throttledSearch.assign(to: &$searchTerm)

        // The dropFirst(1) prevents us from clearing the search pasteboard on initial binding.
        throttledSearch
            .dropFirst(1)
            .sink { term in
                NSPasteboard(name: .find).clearContents()
                NSPasteboard(name: .find).setString(term, forType: .string)
            }
            .store(in: &cancellables)
    }

    @objc private func openInNewWindow() {
        didSelectOpenInNewWindow()
    }

    private func updateStyle() {
        widthConstraint.isActive = style == .corner
        view.layer?.cornerRadius = style == .corner ? 6 : 0
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        guard let pasteboardTerm = NSPasteboard(name: .find).string(forType: .string),
            pasteboardTerm != searchTerm else {
            return
        }

        searchField.stringValue = pasteboardTerm
        searchTerm = pasteboardTerm
    }
    
    @objc private func exportTranscript() {
        didSelectExportTranscript()
    }
    
}
