//
//  FeaturedContentCollectionViewCell.swift
//  WWDC
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa
import ConfCore

final class FeaturedContentCollectionViewItem: NSCollectionViewItem {

    private var disposeBag = DisposeBag()

    var onClicked: ((FeaturedContentViewModel) -> Void)?

    var viewModel: FeaturedContentViewModel? {
        didSet {
            guard viewModel !== oldValue else { return }

            thumbnailImageView.image = #imageLiteral(resourceName: "noimage")
            bindUI()
        }
    }

    var sessionViewModel: SessionViewModel? {
        return viewModel?.sessionViewModel
    }

    struct Metrics {
        static let width: CGFloat = 340
        static let height: CGFloat = 264
        static let imageAspectRatio: CGFloat = 9 / 16
    }

    override func loadView() {
        view = NSView(frame: .zero)
        view.wantsLayer = true

        buildUI()

        let click = NSClickGestureRecognizer(target: self, action: #selector(clickRecognized))
        view.addGestureRecognizer(click)
    }

    private lazy var thumbnailImageView: WWDCImageView = {
        let v = WWDCImageView()

        let aspectRatioConstraint = v.heightAnchor.constraint(equalTo: v.widthAnchor, multiplier: Metrics.imageAspectRatio)
        aspectRatioConstraint.priority = NSLayoutConstraint.Priority(rawValue: 750)
        aspectRatioConstraint.isActive = true
        v.backgroundColor = .black
        v.cornerRadius = 0
        
        return v
    }()

    private lazy var titleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = .primaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail

        return l
    }()

    private lazy var subtitleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail

        return l
    }()

    private lazy var contextLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.font = .systemFont(ofSize: 12)
        l.textColor = .tertiaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail

        return l
    }()

    private lazy var textStackView: NSStackView = {
        let v = NSStackView(views: [self.titleLabel, self.subtitleLabel, self.contextLabel])

        v.orientation = .vertical
        v.alignment = .leading
        v.distribution = .equalSpacing
        v.spacing = 2

        return v
    }()

    private lazy var favoritedImageView: WWDCImageView = {
        let v = WWDCImageView()

        v.heightAnchor.constraint(equalToConstant: 14).isActive = true
        v.drawsBackground = false
        v.image = #imageLiteral(resourceName: "star-small")

        return v
    }()

    private lazy var downloadedImageView: WWDCImageView = {
        let v = WWDCImageView()

        v.heightAnchor.constraint(equalToConstant: 11).isActive = true
        v.drawsBackground = false
        v.image = #imageLiteral(resourceName: "download-small")

        return v
    }()

    private lazy var iconsStackView: NSStackView = {
        let v = NSStackView(views: [])

        v.distribution = .gravityAreas
        v.orientation = .vertical
        v.spacing = 4
        v.addView(self.favoritedImageView, in: .top)
        v.addView(self.downloadedImageView, in: .bottom)
        v.translatesAutoresizingMaskIntoConstraints = false

        v.widthAnchor.constraint(equalToConstant: 12).isActive = true

        return v
    }()

    private func buildUI() {
        view.wantsLayer = true
        view.layer?.cornerCurve = .continuous
        view.layer?.cornerRadius = 8
        view.layer?.backgroundColor = NSColor.roundedCellBackground.cgColor

        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        textStackView.translatesAutoresizingMaskIntoConstraints = false
        iconsStackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(thumbnailImageView)
        view.addSubview(textStackView)
        view.addSubview(iconsStackView)

        thumbnailImageView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        thumbnailImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        thumbnailImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

        textStackView.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 10).isActive = true
        textStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12).isActive = true
        textStackView.trailingAnchor.constraint(equalTo: iconsStackView.leadingAnchor).isActive = true

        iconsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4).isActive = true
        iconsStackView.topAnchor.constraint(equalTo: textStackView.topAnchor).isActive = true
        iconsStackView.bottomAnchor.constraint(equalTo: textStackView.bottomAnchor, constant: -12).isActive = true

        downloadedImageView.isHidden = true
        favoritedImageView.isHidden = true
    }

    private weak var imageDownloadOperation: Operation?

    private func bindUI() {
        disposeBag = DisposeBag()

        guard let viewModel = sessionViewModel else { return }

        viewModel.rxTitle.distinctUntilChanged().asDriver(onErrorJustReturn: "").drive(titleLabel.rx.text).disposed(by: disposeBag)
        viewModel.rxSubtitle.distinctUntilChanged().asDriver(onErrorJustReturn: "").drive(subtitleLabel.rx.text).disposed(by: disposeBag)
        viewModel.rxContext.distinctUntilChanged().asDriver(onErrorJustReturn: "").drive(contextLabel.rx.text).disposed(by: disposeBag)

        viewModel.rxIsFavorite.distinctUntilChanged().map({ !$0 }).bind(to: favoritedImageView.rx.isHidden).disposed(by: disposeBag)
        viewModel.rxIsDownloaded.distinctUntilChanged().map({ !$0 }).bind(to: downloadedImageView.rx.isHidden).disposed(by: disposeBag)

        viewModel.rxImageUrl.distinctUntilChanged({ $0 != $1 }).subscribe(onNext: { [weak self] imageUrl in
            guard let imageUrl = imageUrl else { return }

            self?.imageDownloadOperation?.cancel()

            self?.imageDownloadOperation = ImageDownloadCenter.shared.downloadImage(from: imageUrl, thumbnailHeight: Constants.thumbnailHeight) { [weak self] url, result in
                guard url == imageUrl else { return }

                self?.thumbnailImageView.image = result.original
            }
        }).disposed(by: disposeBag)
    }

    @objc private func clickRecognized() {
        guard let viewModel = viewModel else { return }

        onClicked?(viewModel)
    }

}
