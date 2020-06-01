//
//  FeaturedCommunityCollectionViewItem.swift
//  WWDC
//
//  Created by Guilherme Rambo on 01/06/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class FeaturedCommunityCollectionViewItem: NSCollectionViewItem {

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerCurve = .continuous
        view.layer?.cornerRadius = 8
        view.layer?.backgroundColor = NSColor.systemRed.cgColor
    }
    
}
