//
//  SessionCollectionViewItem.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI

final class SessionCollectionViewItem: NSCollectionViewItem {

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    var viewModel: SessionViewModel? {
        get {
            return cellViewModel.viewModel
        }
        set {
            cellViewModel.viewModel = newValue
        }
    }

    var onClicked: ((SessionViewModel) -> Void)?

    private lazy var cellViewModel = SessionCellViewModel()
    
    private lazy var hostingView: NSHostingView<SessionCellView> = {
        let swiftUIView = SessionCellView(cellViewModel: cellViewModel, style: .rounded)
        return NSHostingView(rootView: swiftUIView)
    }()

    private func setup() {
        hostingView.autoresizingMask = [.width, .height]
        view.addSubview(hostingView)

        let click = NSClickGestureRecognizer(target: self, action: #selector(clickRecognized))
        view.addGestureRecognizer(click)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
    }

    @objc private func clickRecognized() {
        guard let viewModel = viewModel else { return }

        onClicked?(viewModel)
    }

}
