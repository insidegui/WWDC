//
//  PUIDetachedPlaybackStatusViewController.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class PUIDetachedPlaybackStatusViewController: NSViewController {

    private lazy var context = CIContext(options: [.useSoftwareRenderer: true])

    var snapshot: CGImage? {
        didSet {
            updateSnapshot(with: snapshot)
        }
    }
    var providerIcon: NSImage? {
        didSet {
            iconImageView.image = providerIcon
        }
    }
    var providerName: String = "" {
        didSet {
            titleLabel.stringValue = providerName
        }
    }
    var providerDescription: String = "" {
        didSet {
            descriptionLabel.stringValue = providerDescription
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var iconImageView: NSImageView = {
        let v = NSImageView()

        v.imageScaling = .scaleProportionallyUpOrDown
        v.widthAnchor.constraint(equalToConstant: 74).isActive = true
        v.heightAnchor.constraint(equalToConstant: 74).isActive = true

        return v
    }()

    private lazy var titleLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")

        f.font = .systemFont(ofSize: 20, weight: .medium)
        f.textColor = .labelColor
        f.alignment = .center

        return f
    }()

    private lazy var descriptionLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")

        f.font = .systemFont(ofSize: 16)
        f.textColor = .secondaryLabelColor
        f.alignment = .center

        return f
    }()

    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.iconImageView, self.titleLabel, self.descriptionLabel])

        v.translatesAutoresizingMaskIntoConstraints = false
        v.orientation = .vertical
        v.spacing = 6

        return v
    }()

    private lazy var snapshotLayer: PUIBoringLayer = {
        let l = PUIBoringLayer()

        l.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        l.backgroundColor = NSColor.black.cgColor

        return l
    }()

    private lazy var contrastLayer: PUIBoringLayer = {
        let l = PUIBoringLayer()

        l.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        l.backgroundColor = NSColor.gray.cgColor
        l.opacity = 0.2

        return l
    }()

    private lazy var blackoutLayer: CALayer = {
        let l = CALayer()

        l.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        l.backgroundColor = NSColor.black.cgColor
        l.opacity = 0
        l.zPosition = 10

        return l
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        
        let container = CALayer()
        container.masksToBounds = true
        container.backgroundColor = NSColor.black.cgColor
        view.layer = container

        snapshotLayer.frame = view.bounds
        container.addSublayer(snapshotLayer)

        contrastLayer.frame = view.bounds
        container.addSublayer(contrastLayer)

        view.addSubview(stackView)
        stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true

        blackoutLayer.frame = view.bounds
        container.addSublayer(blackoutLayer)
    }

    func show() {
        view.isHidden = false
    }

    func hide() {
        view.isHidden = true
    }

    private lazy var blurFilter: CIFilter? = {
        let f = CIFilter(name: "CIGaussianBlur")
        f?.setValue(100, forKey: kCIInputRadiusKey)
        return f
    }()

    private lazy var saturationFilter: CIFilter? = {
        let f = CIFilter(name: "CIColorControls")
        f?.setDefaults()
        f?.setValue(1.5, forKey: kCIInputSaturationKey)
        f?.setValue(-0.25, forKey: kCIInputBrightnessKey)
        return f
    }()

    private func updateSnapshot(with cgImage: CGImage?) {
        guard let cgImage else { return }

        let targetSize = snapshotLayer.bounds
        let transform = CGAffineTransform(scaleX: targetSize.width / CGFloat(cgImage.width),
                                          y: targetSize.height / CGFloat(cgImage.height))

        let ciImage = CIImage(cgImage: cgImage).transformed(by: transform)
        let filters = [saturationFilter, blurFilter].compactMap { $0 }

        guard let filteredImage = ciImage.filtered(with: filters) else { return }

        snapshotLayer.contents = context.createCGImage(filteredImage, from: ciImage.extent)
    }
}

extension CIImage {

    func filtered(with ciFilters: [CIFilter]) -> CIImage? {

        var inputImage = self.clampedToExtent()

        var finalFilter: CIFilter?
        for filter in ciFilters {
            finalFilter = filter

            filter.setValue(inputImage, forKey: kCIInputImageKey)

            if let output = filter.outputImage {
                inputImage = output
            }
        }

        return finalFilter?.outputImage
    }
}
