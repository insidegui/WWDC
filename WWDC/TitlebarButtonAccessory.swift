//
//  TitlebarButtonAccessory.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/03/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

class TitlebarButtonAccessory: NSTitlebarAccessoryViewController {

    let buttonTitle: String
    let buttonAction: () -> Void
    
    init(buttonTitle: String, buttonAction: @escaping () -> Void) {
        self.buttonTitle = buttonTitle
        self.buttonAction = buttonAction
        
        super.init(nibName: nil, bundle: nil)!
    }

    required init?(coder: NSCoder) {
        buttonTitle = ""
        buttonAction = {}
        
        super.init(coder: coder)
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0.0, y: 0.0, width: 100.0, height: 22.0))
        
        let button = NSButton(frame: view.bounds)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .roundRect
        button.controlSize = .small
        button.font = NSFont.controlContentFont(ofSize: 11.0)
        button.title = buttonTitle
        button.target = self
        button.action = #selector(TitlebarButtonAccessory.runButtonAction(_:))
        
        button.sizeToFit()
        view.setFrameSize(NSSize(width: button.bounds.size.width + 10.0, height: button.bounds.size.height))
        view.addSubview(button)
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "[button]-(6)-|", options: [], metrics: nil, views: ["button": button]))
        view.addConstraint(NSLayoutConstraint(item: button, attribute: .centerY, relatedBy: .equal, toItem: view, attribute: .centerY, multiplier: 1.0, constant: 0.0))
    }
    
    @objc fileprivate func runButtonAction(_ sender: AnyObject) {
        buttonAction()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}
