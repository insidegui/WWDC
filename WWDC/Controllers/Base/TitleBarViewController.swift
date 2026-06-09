//
//  TitleBarViewController.swift
//  WWDC
//
//  Created by Allen Humphreys on 23/7/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class TitleBarViewController: NSTitlebarAccessoryViewController {

    private var horizontalPositioningConstraints = [NSLayoutConstraint]()

    /// Fallback leading inset used until the traffic-light buttons can be measured.
    private static let trafficLightInset: CGFloat = 76

    /// Gap between the rightmost traffic-light (zoom) button and the sidebar toggle.
    private static let trafficLightGap: CGFloat = 8

    /// Leading constraint for the toggle button; its constant tracks the traffic lights.
    private var leadingButtonConstraint: NSLayoutConstraint?

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

    private lazy var leadingContainer: NSView = {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false

        return v
    }()

    private static func makeToggleSymbol() -> NSImage {
        guard let image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Toggle Sidebar") else {
            assertionFailure("Missing system symbol: sidebar.left")
            return NSImage()
        }
        // withSymbolConfiguration returns nil if the configuration can't be applied;
        // fall back to the unconfigured symbol rather than a blank image.
        return image.withSymbolConfiguration(.init(pointSize: 15, weight: .regular)) ?? image
    }

    /// Sidebar collapse/expand toggle. Fires `toggleSidebar:` up the responder chain
    /// so it reaches the active tab's split view controller. Exposed so the coordinator
    /// can disable it on tabs that have no sidebar (Explore).
    lazy var sidebarToggleButton: NSButton = {
        let b = NSButton(image: Self.makeToggleSymbol(), target: nil, action: #selector(NSSplitViewController.toggleSidebar(_:)))
        b.translatesAutoresizingMaskIntoConstraints = false
        b.isBordered = false
        b.imagePosition = .imageOnly
        b.setButtonType(.momentaryChange)
        b.imageScaling = .scaleProportionallyDown
        b.toolTip = "Toggle Sidebar"

        return b
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

        view.addSubview(leadingContainer)
        view.addSubview(tabBarContainer)
        view.addSubview(statusContainer)

        leadingContainer.addSubview(sidebarToggleButton)

        let leadingConstraint = leadingContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Self.trafficLightInset)
        leadingConstraint.isActive = true
        leadingButtonConstraint = leadingConstraint
        leadingContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        leadingContainer.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true

        sidebarToggleButton.leadingAnchor.constraint(equalTo: leadingContainer.leadingAnchor).isActive = true
        sidebarToggleButton.trailingAnchor.constraint(equalTo: leadingContainer.trailingAnchor).isActive = true
        sidebarToggleButton.centerYAnchor.constraint(equalTo: leadingContainer.centerYAnchor).isActive = true

        let centerXConstraint = tabBarContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        centerXConstraint.isActive = true
        horizontalPositioningConstraints.append(centerXConstraint)
        tabBarContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        tabBarContainer.leadingAnchor.constraint(greaterThanOrEqualTo: leadingContainer.trailingAnchor, constant: 8).isActive = true
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

        // Tuck the sidebar toggle right up against the rightmost traffic-light (zoom) button.
        if let constraint = leadingButtonConstraint,
           let zoomButton = window.standardWindowButton(.zoomButton),
           let buttonSuperview = zoomButton.superview {
            let frameInWindow = buttonSuperview.convert(zoomButton.frame, to: nil)
            let newConstant = view.convert(frameInWindow, from: nil).maxX + Self.trafficLightGap
            if abs(constraint.constant - newConstant) > 0.5 {
                constraint.constant = newConstant
            }
        }
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
