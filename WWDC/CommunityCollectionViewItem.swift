//
//  CommunityCollectionViewItem.swift
//  WWDC
//
//  Created by Guilherme Rambo on 31/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class CommunityCollectionViewItem: NSCollectionViewItem {

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.cornerCurve = .continuous
        view.layer?.cornerRadius = 18
        view.layer?.backgroundColor = NSColor.roundedCellBackground.cgColor
    }
    
}
