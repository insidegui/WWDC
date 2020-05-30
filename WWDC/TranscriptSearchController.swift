//
//  TranscriptSearchController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 30/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import RxSwift
import RxCocoa
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

    private(set) var searchTerm = BehaviorRelay<String?>(value: nil)

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

    private lazy var searchField: NSSearchField = {
        let f = NSSearchField()

        f.translatesAutoresizingMaskIntoConstraints = false
        f.setContentHuggingPriority(.defaultLow, for: .horizontal)

        return f
    }()

    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.searchField, self.detachButton])

        v.orientation = .horizontal
        v.spacing = 6
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

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        let throttledSearch = searchField.rx.text.throttle(.milliseconds(500), scheduler: MainScheduler.instance)

        throttledSearch.bind(to: searchTerm)
                       .disposed(by: disposeBag)

        // The skip(1) prevents us from clearing the search pasteboard on initial binding.
        throttledSearch.skip(1).ignoreNil().subscribe(onNext: { term in
            NSPasteboard(name: .find).clearContents()
            NSPasteboard(name: .find).setString(term, forType: .string)
        }).disposed(by: disposeBag)
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
            pasteboardTerm != searchTerm.value else {
            return
        }

        searchField.stringValue = pasteboardTerm
        searchTerm.accept(pasteboardTerm)
    }
    
}
