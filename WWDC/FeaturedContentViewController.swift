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

        v.autoresizingMask = [.width, .height]
        v.contentView = FlippedClipView()
        v.hasVerticalScroller = true
        v.backgroundColor = .contentBackground
        v.autohidesScrollers = true
        v.horizontalScrollElasticity = .none
        v.automaticallyAdjustsContentInsets = false
        v.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: FeaturedSectionViewController.Metrics.padding, right: 0)
        v.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: -FeaturedSectionViewController.Metrics.padding, right: 0)

        return v
    }()

    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [])

        v.spacing = 24
        v.orientation = .vertical
        v.alignment = .leading
        v.distribution = .fill

        return v
    }()

    override func loadView() {
        // This is a visual effect view to allow the scrollers to appear correctly
        view = NSVisualEffectView()
        view.wantsLayer = true

        view.addSubview(scrollView)

        scrollView.documentView = stackView

        let clipView = scrollView.contentView
        stackView.topAnchor.constraint(equalTo: clipView.topAnchor).isActive = true
        stackView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor).isActive = true
        stackView.widthAnchor.constraint(equalTo: clipView.widthAnchor).isActive = true
        stackView.translatesAutoresizingMaskIntoConstraints = false
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
            child.removeFromParent()
        }
        sectionControllers.removeAll()

        sections.map({ FeaturedSectionViewController(viewModel: $0) }).forEach { sectionController in
            sectionController.delegate = self

            addChild(sectionController)
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
