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

    private lazy var titleLabel: NSTextField = {
        let l = NSTextField(wrappingLabelWithString: "")

        l.font = NSFont.systemFont(ofSize: 24, weight: .medium)
        l.textColor = .primaryText
        l.alignment = .center

        return l
    }()

    private lazy var bodyLabel: NSTextField = {
        let l = NSTextField(wrappingLabelWithString: "")

        l.font = NSFont.systemFont(ofSize: 14)
        l.textColor = .secondaryText
        l.alignment = .center

        return l
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

        view.addSubview(textStack)

        NSLayoutConstraint.activate([
            textStack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 120),
            textStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            textStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 220),
            textStack.trailingAnchor.constraint(greaterThanOrEqualTo: view.trailingAnchor, constant: -220)
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

            self.imageDownloadOperation = ImageDownloadCenter.shared.downloadImage(from: imageUrl, thumbnailHeight: Constants.thumbnailHeight) { url, image, _ in
                guard url == imageUrl, image != nil else { return }

                self.backgroundImageView.image = image
            }
        }).disposed(by: disposeBag)

        let heroUnavailable = hero.map({ $0 == nil })
        heroUnavailable.bind(to: backgroundImageView.rx.isHidden).disposed(by: disposeBag)
        heroUnavailable.map({ !$0 }).bind(to: placeholderImageView.rx.isHidden).disposed(by: disposeBag)

        hero.map({ $0?.title ?? "Schedule not available" }).bind(to: titleLabel.rx.text).disposed(by: disposeBag)
        hero.map({ $0?.body ?? "The schedule is not currently available. Check back later." }).bind(to: bodyLabel.rx.text).disposed(by: disposeBag)

        hero.compactMap({ $0?.titleColor }).subscribe(onNext: { [weak self] colorHex in
            guard let self = self else { return }
            self.titleLabel.textColor = NSColor.fromHexString(hexString: colorHex)
        }).disposed(by: disposeBag)

        hero.compactMap({ $0?.bodyColor }).subscribe(onNext: { [weak self] colorHex in
            guard let self = self else { return }
            self.bodyLabel.textColor = NSColor.fromHexString(hexString: colorHex)
        }).disposed(by: disposeBag)
    }

}
