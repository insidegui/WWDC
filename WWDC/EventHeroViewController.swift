//
//  ScheduleUnavailableViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import Combine

public final class EventHeroViewController: NSViewController {

    @Published
    var hero: EventHero?

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

    private lazy var cancellables: Set<AnyCancellable> = []

    private func bindViews() {
        $hero
            .drop(while: { $0 == nil })
            .sink
        { [weak self] hero in
            guard let self else { return }

            /// A lack of event hero is handled by the app coordinator / schedule controller by hiding this view controller,
            /// so there's no special handling required when the hero is not available.
            guard let hero else { return }

            setupBackground(with: hero)
            setupText(with: hero)
        }
        .store(in: &cancellables)
    }

    private func setupBackground(with hero: EventHero) {
        guard let imageUrl = URL(string: hero.backgroundImage) else { return }

        placeholderImageView.isHidden = true

        backgroundImageView.alphaValue = hero.textComponents.count > 1 ? 0.5 : 1
        backgroundImageView.isHidden = false

        imageDownloadOperation?.cancel()

        imageDownloadOperation = ImageDownloadCenter.shared.downloadImage(from: imageUrl, thumbnailHeight: Constants.thumbnailHeight) { result in
            guard result.sourceURL == imageUrl, result.original != nil else { return }

            self.backgroundImageView.image = result.original
        }
    }

    private func setupText(with hero: EventHero) {
        titleLabel.stringValue = hero.title
        if hero.textComponents.isEmpty {
            bodyLabel.stringValue = hero.body
        } else {
            bodyLabel.stringValue = hero.textComponents.joined(separator: "\n\n")
        }
        titleLabel.textColor = hero.titleColor.flatMap { NSColor.fromHexString(hexString: $0) }
        bodyLabel.textColor = hero.bodyColor.flatMap { NSColor.fromHexString(hexString: $0) }
    }

}
