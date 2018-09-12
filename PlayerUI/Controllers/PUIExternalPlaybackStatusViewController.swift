//
//  PUIExternalPlaybackStatusViewController.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class PUIExternalPlaybackStatusViewController: NSViewController {

    private let blurFilter: CIFilter = {
        let f = CIFilter(name: "CIGaussianBlur")!
        f.setValue(100, forKey: kCIInputRadiusKey)
        return f
    }()

    private let saturationFilter: CIFilter = {
        let f = CIFilter(name: "CIColorControls")!
        f.setDefaults()
        f.setValue(2, forKey: kCIInputSaturationKey)
        return f
    }()

    private lazy var context = CIContext(options: [.useSoftwareRenderer: true])

    var snapshot: CGImage? {
        didSet {
            snapshotLayer.contents = snapshot.flatMap { cgImage in

                let targetSize = snapshotLayer.bounds
                let transform = CGAffineTransform(scaleX: targetSize.width / CGFloat(cgImage.width),
                                                  y: targetSize.height / CGFloat(cgImage.height))

                let ciImage = CIImage(cgImage: cgImage).transformed(by: transform)
                let filters = [saturationFilter, blurFilter]

                guard let filteredImage = ciImage.filtered(with: filters) else { return nil }

                return context.createCGImage(filteredImage, from: ciImage.extent)
            }
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

        v.widthAnchor.constraint(equalToConstant: 74).isActive = true
        v.heightAnchor.constraint(equalToConstant: 74).isActive = true

        return v
    }()

    private lazy var titleLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")

        f.font = .systemFont(ofSize: 20, weight: .medium)
        f.textColor = .externalPlaybackText
        f.alignment = .center

        return f
    }()

    private lazy var descriptionLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")

        f.font = .systemFont(ofSize: 16)
        f.textColor = .timeLabel
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

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer = PUIBoringLayer()
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.black.cgColor

        snapshotLayer.frame = view.bounds
        view.layer?.addSublayer(snapshotLayer)

        view.addSubview(stackView)
        stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
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
