//
//  SessionTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa

final class SessionTableCellView: NSTableCellView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setup()
    }

    var viewModel: SessionViewModel? {
        get {
            return cellView.viewModel
        }
        set {
            cellView.viewModel = newValue
        }
    }

    required init?(coder decoder: NSCoder) {
        fatalError()
    }

    private lazy var cellView: SessionCellView = {
        return SessionCellView(frame: bounds)
    }()

    private func setup() {
        cellView.autoresizingMask = [.width, .height]
        addSubview(cellView)
    }

}
