//
//  FeaturedCommunityCollectionViewItem.swift
//  WWDC
//
//  Created by Guilherme Rambo on 01/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class FeaturedCommunityCollectionViewItem: NSCollectionViewItem {

    var clickHandler: () -> Void = { }

    var newsItem: CommunityNewsItemViewModel? {
        didSet {
            guard newsItem != oldValue else { return }

            updateUI()
        }
    }

    private lazy var titleLabel: NSTextField = {
        let v = NSTextField(labelWithString: "")

        v.font = NSFont.wwdcRoundedSystemFont(ofSize: 24, weight: .semibold)
        v.textColor = .primaryText
        v.setContentCompressionResistancePriority(.required, for: .vertical)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.allowsDefaultTighteningForTruncation = true
        v.maximumNumberOfLines = 1
        v.lineBreakMode = .byTruncatingTail
        v.isSelectable = false

        return v
    }()

    private static let placeholderImage: NSImage? = {
        NSImage(named: .init("featured-placeholder"))
    }()

    private lazy var imageContainerView: NSView = {
        let v = NSView()

        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private lazy var imageLayer: CALayer = {
        let l = CALayer()

        l.contentsGravity = .resizeAspectFill
        l.contents = Self.placeholderImage

        return l
    }()

    private var imageDownloadOperation: Operation?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.contentBackground.cgColor

        view.addSubview(titleLabel)
        view.addSubview(imageContainerView)

        imageLayer.frame = imageContainerView.bounds
        imageContainerView.wantsLayer = true
        imageContainerView.layer?.cornerRadius = 8
        imageContainerView.layer?.masksToBounds = true
        imageContainerView.layer?.cornerCurve = .continuous
        imageContainerView.layer?.addSublayer(imageLayer)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor),
            imageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            imageContainerView.heightAnchor.constraint(equalToConstant: 166)
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        view.addGestureRecognizer(click)
    }

    @objc private func clicked() {
        clickHandler()
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        imageLayer.frame = imageContainerView.bounds
    }

    private func updateUI() {
        guard let item = newsItem, let imageUrl = item.image else { return }

        imageLayer.contents = Self.placeholderImage

        imageDownloadOperation?.cancel()

        imageDownloadOperation = ImageDownloadCenter.shared.downloadImage(from: imageUrl, thumbnailHeight: Constants.thumbnailHeight) { [weak self] url, result in
            guard let self = self else { return }

            guard url == imageUrl, result.original != nil else { return }

            self.imageLayer.contents = result.original
        }

        titleLabel.stringValue = item.title
        titleLabel.toolTip = item.title
    }

}
