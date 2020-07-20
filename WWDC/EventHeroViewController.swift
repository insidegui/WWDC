//
//  ScheduleUnavailableViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import RxSwift
import RxCocoa

public final class EventHeroViewController: NSViewController {

    private(set) var hero = BehaviorRelay<EventHero?>(value: nil)

    private lazy var backgroundImageView: FullBleedImageView = {
        let v = FullBleedImageView()

        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private lazy var placeholderImageView: FullBleedImageView = {
        let v = FullBleedImageView()

        v.translatesAutoresizingMaskIntoConstraints = false
        v.image = NSImage(named: .init("schedule-placeholder"))

        return v
    }()

    private func makeShadow() -> NSShadow {
        let shadow = NSShadow()

        shadow.shadowBlurRadius = 1
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.7)
        shadow.shadowOffset = NSSize(width: 1, height: 1)

        return shadow
    }

    private lazy var titleLabel: NSTextField = {
        let l = NSTextField(wrappingLabelWithString: "")

        l.font = .boldTitleFont
        l.textColor = .primaryText
        l.alignment = .center
        l.shadow = makeShadow()

        return l
    }()

    private lazy var bodyLabel: NSTextField = {
        let l = NSTextField(wrappingLabelWithString: "")

        l.font = NSFont.systemFont(ofSize: 14)
        l.textColor = .secondaryText
        l.alignment = .center
        l.shadow = makeShadow()

        return l
    }()

    private lazy var scrollView: NSScrollView = {
        let v = NSScrollView()

        v.contentView = FlippedClipView()
        v.drawsBackground = false
        v.backgroundColor = .clear
        v.borderType = .noBorder
        v.documentView = self.textStack
        v.autohidesScrollers = true
        v.translatesAutoresizingMaskIntoConstraints = false
        v.automaticallyAdjustsContentInsets = false
        v.contentInsets = NSEdgeInsets(top: 120, left: 0, bottom: 0, right: 0)

        return v
    }()

    private lazy var textStack: NSStackView = {
        let v = NSStackView(views: [titleLabel, bodyLabel])

        v.translatesAutoresizingMaskIntoConstraints = false
        v.orientation = .vertical
        v.spacing = 12

        return v
    }()

    public override func loadView() {
        view = NSView()
        view.wantsLayer = true

        view.addSubview(placeholderImageView)

        NSLayoutConstraint.activate([
            placeholderImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            placeholderImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            placeholderImageView.topAnchor.constraint(equalTo: view.topAnchor),
            placeholderImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.addSubview(backgroundImageView)

        NSLayoutConstraint.activate([
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scrollView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 220),
            scrollView.trailingAnchor.constraint(greaterThanOrEqualTo: view.trailingAnchor, constant: -220)
        ])

        NSLayoutConstraint.activate([
            textStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            textStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            textStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            textStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            textStack.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        bindViews()
    }

    private var imageDownloadOperation: Operation?

    private let disposeBag = DisposeBag()

    private func bindViews() {
        let image = hero.compactMap({ $0?.backgroundImage }).compactMap(URL.init)

        image.distinctUntilChanged().subscribe(onNext: { [weak self] imageUrl in
            guard let self = self else { return }

            self.imageDownloadOperation?.cancel()

            self.imageDownloadOperation = ImageDownloadCenter.shared.downloadImage(from: imageUrl, thumbnailHeight: Constants.thumbnailHeight) { url, result in
                guard url == imageUrl, result.original != nil else { return }

                self.backgroundImageView.image = result.original
            }
        }).disposed(by: disposeBag)

        let heroUnavailable = hero.map({ $0 == nil })
        heroUnavailable.bind(to: backgroundImageView.rx.isHidden).disposed(by: disposeBag)
        heroUnavailable.map({ !$0 }).bind(to: placeholderImageView.rx.isHidden).disposed(by: disposeBag)

        hero.map({ $0?.title ?? "Schedule not available" }).bind(to: titleLabel.rx.text).disposed(by: disposeBag)
        hero.map({ hero in
            let unavailable = "The schedule is not currently available. Check back later."
            guard let hero = hero else { return unavailable }
            if hero.textComponents.isEmpty {
                return hero.body
            } else {
                return hero.textComponents.joined(separator: "\n\n")
            }
        }).bind(to: bodyLabel.rx.text).disposed(by: disposeBag)

        hero.compactMap({ $0?.titleColor }).subscribe(onNext: { [weak self] colorHex in
            guard let self = self else { return }
            self.titleLabel.textColor = NSColor.fromHexString(hexString: colorHex)
        }).disposed(by: disposeBag)

        // Dim background when there's a lot of text to show
        hero.compactMap({ $0 }).map({ $0.textComponents.count > 2 }).subscribe(onNext: { [weak self] largeText in
            self?.backgroundImageView.alphaValue = 0.5
        }).disposed(by: disposeBag)

        hero.compactMap({ $0?.bodyColor }).subscribe(onNext: { [weak self] colorHex in
            guard let self = self else { return }
            self.bodyLabel.textColor = NSColor.fromHexString(hexString: colorHex)
        }).disposed(by: disposeBag)
    }

}
