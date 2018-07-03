//
//  WWDCTabViewControllerTabBar.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/23/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

class WWDCTabViewControllerTabBar: NSView {

    private(set) var items = [TabItemView]()

    private lazy var stackView: NSStackView = {
        let stackView = NSStackView()
        stackView.frame = bounds
        stackView.autoresizingMask = [.width, .height]
        self.addSubview(stackView)

        return stackView
    }()

    func addItem(_ item: TabItemView) {
        stackView.addView(item, in: .center)
        items.append(item)
    }
}
