//
//  PUIExternalPlaybackStatusViewController.swift
//  PlayerUI
//
//  Created by Guilherme Rambo on 13/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class PUIExternalPlaybackStatusViewController: NSViewController {

    var snapshot: NSImage? {
        didSet {
            snapshotLayer.contents = snapshot
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

        view.layerUsesCoreImageFilters = true

        snapshotLayer.frame = view.bounds
        view.layer?.addSublayer(snapshotLayer)

        if let blur = CIFilter(name: "CIGaussianBlur"), let sat = CIFilter(name: "CIColorControls") {
            sat.setDefaults()
            sat.setValue(2, forKey: "inputSaturation")
            blur.setValue(100, forKey: "inputRadius")
            snapshotLayer.filters = [sat, blur]
        }

        view.addSubview(stackView)
        stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

}
