//
//  FeaturedContentViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 26/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import RxSwift
import RxCocoa

protocol FeaturedContentViewControllerDelegate: class {
    func featuredContentViewController(_ controller: FeaturedContentViewController, didSelectContent content: FeaturedContentViewModel)
}

final class FeaturedContentViewController: NSViewController {

    weak var delegate: FeaturedContentViewControllerDelegate?

    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }

    var sections: [FeaturedSectionViewModel] = [] {
        didSet {
            reload()
        }
    }

    private lazy var scrollView: NSScrollView = {
        let v = NSScrollView(frame: view.bounds)

        v.hasVerticalScroller = true
        v.hasHorizontalScroller = false
        v.automaticallyAdjustsContentInsets = false
        v.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: FeaturedSectionViewController.Metrics.padding, right: 0)

        return v
    }()

    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [])

        v.autoresizingMask = [.width, .height]
        v.spacing = 24
        v.orientation = .vertical
        v.alignment = .leading
        v.distribution = .fill

        return v
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.listBackground.cgColor

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.width, .height]
        view.addSubview(scrollView)

        stackView.frame = scrollView.bounds
        scrollView.contentView = FlippedClipView()
        scrollView.backgroundColor = .listBackground
        scrollView.documentView = stackView

        stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        reload()
    }

    private var sectionControllers: [FeaturedSectionViewController] = []

    private func reload() {
        guard isViewLoaded else { return }

        sectionControllers.forEach { child in
            child.view.removeFromSuperview()
            child.removeFromParentViewController()
        }
        sectionControllers.removeAll()

        sections.map({ FeaturedSectionViewController(viewModel: $0) }).forEach { sectionController in
            sectionController.delegate = self

            addChildViewController(sectionController)
            sectionControllers.append(sectionController)
            sectionController.view.heightAnchor.constraint(equalToConstant: FeaturedSectionViewController.Metrics.height).isActive = true
            stackView.addArrangedSubview(sectionController.view)
        }
    }

}

extension FeaturedContentViewController: FeaturedSectionViewControllerDelegate {

    func featuredSectionViewController(_ controller: FeaturedSectionViewController, didSelectContent viewModel: FeaturedContentViewModel) {
        delegate?.featuredContentViewController(self, didSelectContent: viewModel)
    }

}
