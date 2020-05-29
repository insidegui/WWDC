//
//  BookmarkViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import PlayerUI
import RxSwift
import RxCocoa

extension Notification.Name {
    fileprivate static let WWDCTextViewTextChanged = Notification.Name("WWDCTextViewTextChanged")
}

private final class WWDCTextView: NSTextView {

    lazy var rxText: Observable<String> = {
        return Observable<String>.create { [weak self] observer -> Disposable in
            let token = NotificationCenter.default.addObserver(forName: .WWDCTextViewTextChanged, object: self, queue: OperationQueue.main) { _ in
                observer.onNext(self?.string ?? "")
            }

            return Disposables.create {
                NotificationCenter.default.removeObserver(token)
            }
        }
    }()

    override func didChangeText() {
        super.didChangeText()

        NotificationCenter.default.post(name: .WWDCTextViewTextChanged, object: self)
    }
}

final class BookmarkViewController: NSViewController {

    let bookmark: Bookmark
    let storage: Storage

    init(bookmark: Bookmark, storage: Storage) {
        self.storage = storage
        self.bookmark = bookmark

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate lazy var imageView: WWDCImageView = {
        let v = WWDCImageView()

        v.widthAnchor.constraint(equalToConstant: 85).isActive = true
        v.heightAnchor.constraint(equalToConstant: 48).isActive = true
        v.backgroundColor = .black

        return v
    }()

    private lazy var textView: WWDCTextView = {
        let v = WWDCTextView()

        v.drawsBackground = false
        v.backgroundColor = .clear
        v.font = .systemFont(ofSize: 12)
        v.textColor = .secondaryText
        v.autoresizingMask = [.width, .height]

        return v
    }()

    private lazy var scrollView: NSScrollView = {
        let v = NSScrollView()

        v.drawsBackground = false
        v.backgroundColor = .clear
        v.borderType = .noBorder
        v.documentView = self.textView
        v.autohidesScrollers = true

        return v
    }()

    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.imageView, self.scrollView])

        v.orientation = .horizontal
        v.spacing = 8
        v.alignment = .centerY
        v.translatesAutoresizingMaskIntoConstraints = false
        v.edgeInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

        return v
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false

        view.addSubview(stackView)
        stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        imageView.image = NSImage(data: bookmark.snapshot)
        textView.string = bookmark.body

        textView.rxText.throttle(.seconds(1), scheduler: MainScheduler.instance).subscribe(onNext: { [weak self] text in
            guard let bookmark = self?.bookmark else { return }

            self?.storage.modify(bookmark) { $0.body = text }
        }).disposed(by: disposeBag)
    }

}
