//
//  SessionSearchAccessoryViewController.swift
//  WWDC
//
//  Created by luca on 31.07.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit

@available(macOS 26.0, *)
class SessionSearchAccessoryViewController: NSViewController {
    lazy var verticalStackView: NSStackView = {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -10)
        ])
        return stackView
    }()

    lazy var searchField: NSSearchField = {
        let searchField = NSSearchField()
        searchField.drawsBackground = false
        searchField.controlSize = .large
        searchField.translatesAutoresizingMaskIntoConstraints = false
        verticalStackView.addArrangedSubview(searchField)
        searchField.widthAnchor.constraint(equalTo: verticalStackView.widthAnchor, multiplier: 1).isActive = true
        return searchField
    }()

    lazy var horizontalFilterStackView: NSStackView = {
        let stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        verticalStackView.addArrangedSubview(stackView)
        stackView.widthAnchor.constraint(equalTo: verticalStackView.widthAnchor, multiplier: 1).isActive = true
        stackView.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return stackView
    }()

    lazy var wwdcButton: NSPopUpButton = {
        let button = NSPopUpButton(title: "All Content", pullDownMenu: NSMenu())
        button.isBordered = true
        button.bezelStyle = .glass
        button.controlSize = .large
        button.borderShape = .roundedRectangle
        button.translatesAutoresizingMaskIntoConstraints = false
        horizontalFilterStackView.addArrangedSubview(button)
        return button
    }()

    lazy var platformButton: NSPopUpButton = {
        let button = NSPopUpButton(title: "All Platforms", pullDownMenu: NSMenu())
        button.isBordered = true
        button.bezelStyle = .glass
        button.controlSize = .large
        button.borderShape = .roundedRectangle
        button.translatesAutoresizingMaskIntoConstraints = false
        horizontalFilterStackView.addArrangedSubview(button)
        return button
    }()

    lazy var topicButton: NSPopUpButton = {
        let button = NSPopUpButton(title: "All Topics", pullDownMenu: NSMenu())
        button.isBordered = true
        button.bezelStyle = .glass
        button.controlSize = .large
        button.borderShape = .roundedRectangle
        button.translatesAutoresizingMaskIntoConstraints = false
        horizontalFilterStackView.addArrangedSubview(button)
        return button
    }()

    lazy var segmentControl: NSSegmentedControl = {
        let segmentControl = NSSegmentedControl(labels: ["Favorites", "Downloaded", "Unwatched", "Bookmarkes"], trackingMode: .selectAny, target: self, action: #selector(didChangeSegmentSelection))
        segmentControl.controlSize = .large
        segmentControl.borderShape = .roundedRectangle
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        verticalStackView.addArrangedSubview(segmentControl)
        segmentControl.widthAnchor.constraint(equalTo: verticalStackView.widthAnchor, multiplier: 1).isActive = true
        return segmentControl
    }()

    override func loadView() {
        view = NSView()
        _ = verticalStackView
        _ = searchField
        _ = horizontalFilterStackView
        _ = wwdcButton
        _ = platformButton
        _ = topicButton
        _ = segmentControl
    }

    @objc private func didChangeSegmentSelection(_ control: NSSegmentedControl) {}
}
