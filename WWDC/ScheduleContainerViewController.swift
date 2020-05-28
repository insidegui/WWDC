//
//  ScheduleContainerViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class ScheduleContainerViewController: NSViewController {

    let splitViewController: SessionsSplitViewController

    init(windowController: MainWindowController, listStyle: SessionsListStyle) {
        self.splitViewController = SessionsSplitViewController(windowController: windowController, listStyle: listStyle)

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func loadView() {
        view = NSView()

        splitViewController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(splitViewController)
        view.addSubview(splitViewController.view)
        
        NSLayoutConstraint.activate([
            splitViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            splitViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
}
