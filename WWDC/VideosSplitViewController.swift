//
//  VideosSplitViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

final class VideosSplitViewController: NSSplitViewController {
    
    var listViewController: VideosTableViewController
    var detailViewController: SessionDetailsViewController
    
    init() {
        listViewController = VideosTableViewController()
        detailViewController = SessionDetailsViewController()
        
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.wantsLayer = true
        
        let listItem = NSSplitViewItem(contentListWithViewController: listViewController)
        let detailItem = NSSplitViewItem(viewController: detailViewController)
        
        addSplitViewItem(listItem)
        addSplitViewItem(detailItem)
    }
    
}

