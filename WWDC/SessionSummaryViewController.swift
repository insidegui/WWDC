//
//  SessionSummaryViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class SessionSummaryViewController: NSViewController {

    init() {
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var titleLabel: NSTextField = {
        let l = NSTextField(labelWithString: "Platforms State of the Union")
        l.font = NSFont.systemFont(ofSize: 24)
        l.textColor = .primaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        
        return l
    }()
    
    private lazy var subtitleLabel: WWDCTextField = {
        let l = WWDCTextField(wrappingLabelWithString: "Join us for an unforgettable award ceremony celebrating developers and their outstanding work. The 2016 Apple Design Awards recognize state of the art iOS, macOS, watchOS, and tvOS apps that reflect excellence in design and innovation.")
        l.font = NSFont.systemFont(ofSize: 18)
        l.textColor = .secondaryText
        l.cell?.backgroundStyle = .dark

        return l
    }()
    
    private lazy var contextLabel: NSTextField = {
        let l = NSTextField(labelWithString: "WWDC 2016 · Session 102 · iOS, macOS, tvOS, watchOS")
        l.font = NSFont.systemFont(ofSize: 16)
        l.textColor = .tertiaryText
        l.cell?.backgroundStyle = .dark
        l.lineBreakMode = .byTruncatingTail
        
        return l
    }()
    
    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.titleLabel, self.subtitleLabel, self.contextLabel])
        
        v.orientation = .vertical
        v.alignment = .leading
        v.spacing = 24
        v.translatesAutoresizingMaskIntoConstraints = false
        
        return v
    }()
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: MainWindowController.defaultRect.width - 300, height: MainWindowController.defaultRect.height / 2))
        view.wantsLayer = true
        
        view.addSubview(stackView)
        stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    
}
