//
//  PUIDetachedPlaybackStatusViewController.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

public typealias PUISnapshotClosure = (@escaping (CGImage?) -> Void) -> Void

@MainActor
public struct DetachedPlaybackStatus: Identifiable {
    public internal(set) var id: String
    var icon: NSImage
    var title: String
    var subtitle: String
    var snapshot: PUISnapshotClosure?
}

public extension DetachedPlaybackStatus {
    static let pictureInPicture = DetachedPlaybackStatus(
        id: "pictureInPicture",
        icon: .PUIPictureInPictureLarge.withPlayerMetrics(.large),
        title: "Picture in Picture",
        subtitle: "Playing in Picture in Picture"
    )
    
    static let fullScreen = DetachedPlaybackStatus(
        id: "fullScreen",
        icon: .PUIFullScreen.withPlayerMetrics(.large),
        title: "Full Screen",
        subtitle: "Playing in Full Screen"
    )
    
    func snapshot(using closure: @escaping PUISnapshotClosure) -> Self {
        var mSelf = self
        mSelf.snapshot = closure
        return mSelf
    }
}

public final class PUIDetachedPlaybackStatusViewController: NSViewController {

    private lazy var context = CIContext(options: [.useSoftwareRenderer: true])

    public var status: DetachedPlaybackStatus? {
        didSet {
            guard let status else { return }
            update(with: status)
        }
    }

    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
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

    private lazy var subtitleLabel: NSTextField = {
        let f = NSTextField(labelWithString: "")

        f.font = .systemFont(ofSize: 16)
        f.textColor = .secondaryLabelColor
        f.alignment = .center

        return f
    }()

    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.iconImageView, self.titleLabel, self.subtitleLabel])

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

    public override func loadView() {
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

        hide()
    }

    private func update(with status: DetachedPlaybackStatus) {
        status.snapshot? { [weak self] image in
            guard let self else { return }
            updateSnapshot(with: image)
        }

        iconImageView.image = status.icon
        titleLabel.stringValue = status.title
        subtitleLabel.stringValue = status.subtitle
    }

    public func show() {
        view.isHidden = false
    }

    public func hide() {
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
