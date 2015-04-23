//
//  VideosHeaderViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class VideosHeaderViewController: NSViewController {
    
    @IBOutlet weak var searchBar: NSSearchField!
    @IBOutlet weak var searchBarBottomConstraint: NSLayoutConstraint!
    
    var performSearch: ((term: String) -> Void)?
    
    class func loadDefaultController() -> VideosHeaderViewController? {
        return VideosHeaderViewController(nibName: "VideosHeaderViewController", bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.enabled = false
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        let nc = NSNotificationCenter.defaultCenter()
        
        nc.addObserverForName(NSWindowWillEnterFullScreenNotification, object: view.window!, queue: nil) { object in
            self.searchBarBottomConstraint.constant = 19
        }
        nc.addObserverForName(NSWindowWillExitFullScreenNotification, object: view.window!, queue: nil) { object in
            self.searchBarBottomConstraint.constant = 12
        }
    }
    
    func enable() {
        searchBar.enabled = true
    }
    
    @IBAction func search(sender: NSSearchField) {
        if let callback = performSearch {
            callback(term: sender.stringValue)
        }
    }
}
