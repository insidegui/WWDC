//
//  LiveEventBannerViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 09/06/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa


public let LiveEventBannerVisibilityChangedNotification = "LiveEventBannerVisibilityChangedNotification"
private let _SharedBannerVC = LiveEventBannerViewController(nibName: "LiveEventBannerViewController", bundle: nil)

class LiveEventBannerViewController: NSViewController {

    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!

    var barHeight: CGFloat {
        get {
            if view.hidden {
                return 0.0
            } else {
                return view.frame.size.height
            }
        }
    }
    
    var event: LiveEvent? {
        didSet {
            updateUI()
        }
    }
    
    class var DefaultController: LiveEventBannerViewController? {
        return _SharedBannerVC
    }
    
    func prepareForParentView(parentView: NSView) {
        view.frame = NSMakeRect(0, 0, NSWidth(parentView.frame), NSHeight(view.frame))
        view.translatesAutoresizingMaskIntoConstraints = true
        view.autoresizingMask = .ViewMaxYMargin | .ViewWidthSizable
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    private func updateUI() {
        if let event = event {
            view.hidden = false
            NSNotificationCenter.defaultCenter().postNotificationName(LiveEventBannerVisibilityChangedNotification, object: nil)
            if let date = event.startsAt {
                let formatter = NSDateFormatter()
                formatter.dateFormat = NSLocalizedString("MM-dd @ HH:mm", comment: "date format")
              
                titleLabel.stringValue = "\(event.title) (\(formatter.stringFromDate(date)))"
            } else {
                titleLabel.stringValue = "\(event.title)"
            }
            descriptionLabel.stringValue = event.description
        } else {
            view.hidden = true
            NSNotificationCenter.defaultCenter().postNotificationName(LiveEventBannerVisibilityChangedNotification, object: nil)
        }
    }
    
}
