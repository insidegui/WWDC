//
//  ViewMenuController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 30/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa

class ViewMenuController: NSObject {

    @IBOutlet weak var viewMenuItem: NSMenuItem?
    @IBOutlet weak var featuredItem: NSMenuItem?
    @IBOutlet weak var scheduleItem: NSMenuItem?
    @IBOutlet weak var videosItem: NSMenuItem?

    override func awakeFromNib() {
        super.awakeFromNib()

        guard let featuredItem = featuredItem else { return }

        guard !FeatureSwitches.isFeaturedTabEnabled else { return }

        viewMenuItem?.submenu?.removeItem(featuredItem)

        scheduleItem?.keyEquivalentModifierMask = .command
        scheduleItem?.keyEquivalent = "1"

        videosItem?.keyEquivalentModifierMask = .command
        videosItem?.keyEquivalent = "2"
    }
}
