//
//  SessionCollectionViewItem.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class SessionCollectionViewItem: NSCollectionViewItem {

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    var viewModel: SessionViewModel? {
        get {
            return cellView.viewModel
        }
        set {
            cellView.viewModel = newValue
        }
    }

    var doubleClicked: ((SessionViewModel) -> Void)?

    private lazy var cellView: SessionCellView = {
        return SessionCellView(frame: view.bounds)
    }()

    private func setup() {
        cellView.autoresizingMask = [.width, .height]
        view.addSubview(cellView)
        
        cellView.layer?.masksToBounds = true
        cellView.layer?.backgroundColor = NSColor.darkGridColor.cgColor
        cellView.layer?.cornerRadius = 5

        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(doubleClickRecognized))
        doubleClick.numberOfClicksRequired = 2
        view.addGestureRecognizer(doubleClick)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }

    @objc private func doubleClickRecognized() {
        guard let viewModel = viewModel else { return }

        doubleClicked?(viewModel)
    }

}
