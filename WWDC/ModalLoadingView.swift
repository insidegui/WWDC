//
//  ModalLoadingView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 20/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class ModalLoadingView: NSView {

    private lazy var backgroundView: NSVisualEffectView = {
        let v = NSVisualEffectView()

        v.material = .ultraDark
        v.blendingMode = .withinWindow
        v.translatesAutoresizingMaskIntoConstraints = false
        v.state = .active

        return v
    }()

    private lazy var spinner: NSProgressIndicator = {
        let p = NSProgressIndicator()

        p.isIndeterminate = true
        p.style = .spinning
        p.translatesAutoresizingMaskIntoConstraints = false

        return p
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true

        addSubview(backgroundView)
        backgroundView.addSubview(spinner)

        backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        backgroundView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        spinner.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor).isActive = true
        spinner.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func show(attachedTo view: NSView) -> ModalLoadingView {
        let v = ModalLoadingView(frame: view.bounds)

        v.show(in: view)

        return v
    }

    func show(in view: NSView) {
        alphaValue = 0
        autoresizingMask = [.width, .height]
        spinner.startAnimation(nil)

        view.addSubview(self)

        NSAnimationContext.runAnimationGroup({ _ in
            self.alphaValue = 1
        }, completionHandler: nil)
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ _ in
            self.spinner.stopAnimation(nil)
            self.alphaValue = 0
        }, completionHandler: {
            self.removeFromSuperview()
        })
    }

}
