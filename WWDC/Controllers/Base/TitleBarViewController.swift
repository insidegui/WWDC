//
//  TitleBarViewController.swift
//  WWDC
//
//  Created by Allen Humphreys on 23/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Foundation

final class TitleBarViewController: NSTitlebarAccessoryViewController {

    private var horizontalPositioningConstraints = [NSLayoutConstraint]()

    private var centerOffset: CGFloat = 0 {
        didSet {
            horizontalPositioningConstraints.forEach { $0.constant = centerOffset }
        }
    }

    private lazy var tabBarContainer: NSView = {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private lazy var statusContainer: NSView = {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    var statusViewController: NSViewController? {
        didSet {
            replace(child: oldValue, with: statusViewController, inContainer: statusContainer)
        }
    }

    var tabBar: WWDCTabViewControllerTabBar? {
        didSet {
            replace(mangedView: oldValue, with: tabBar, inContainer: tabBarContainer)
        }
    }

    init() {
        super.init(nibName: nil, bundle: nil)

        layoutAttribute = .top
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let view = NSView()

        view.addSubview(tabBarContainer)
        view.addSubview(statusContainer)

        let centerXConstraint = tabBarContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        centerXConstraint.isActive = true
        horizontalPositioningConstraints.append(centerXConstraint)
        tabBarContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        tabBarContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor).isActive = true
        tabBarContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor).isActive = true

        statusContainer.leadingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor).isActive = true
        statusContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        statusContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        statusContainer.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true

        self.view = view
    }

    override func viewWillLayout() {
        super.viewWillLayout()

        guard let window = view.window else { return }

        // Convert horizontal window midX into our view's cooridinate space to
        // allow for window-based centering
        let windowBounds = window.convertFromScreen(window.frame)
        let localWindowBounds = view.convert(windowBounds, from: nil)
        centerOffset = localWindowBounds.midX - view.bounds.midX
    }

    func replace(child: NSViewController?, with newChild: NSViewController?, inContainer container: NSView) {
        child?.view.removeFromSuperview()
        child?.removeFromParent()

        guard let newChild = newChild else { return }

        addChild(newChild)
        newChild.view.frame = container.bounds
        newChild.view.autoresizingMask = [.width, .height]
        container.addSubview(newChild.view)
    }

    func replace(mangedView: NSView?, with newView: NSView?, inContainer container: NSView) {
        mangedView?.removeFromSuperview()
        guard let newView = newView else { return }

        newView.frame = container.bounds
        newView.autoresizingMask = [.width, .height]
        container.addSubview(newView)
    }
}
