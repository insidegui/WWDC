//
//  VideosHeaderViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

class VideosHeaderViewController: NSViewController {
    
    var progress: Progress? {
        didSet {
            searchBar.progress = progress
        }
    }
    var searchTerm: String? {
        get {
            return searchBar.stringValue == "" ? nil : searchBar.stringValue
        }
        set {
            guard !searchBar.isFirstResponder else { return }
            searchBar.stringValue = newValue ?? ""
        }
    }
    @IBOutlet weak fileprivate var searchBar: ProgressSearchField!
    @IBOutlet weak fileprivate var searchBarBottomConstraint: NSLayoutConstraint!
    
    var performSearch: ((_ term: String) -> Void)?
    
    class func loadDefaultController() -> VideosHeaderViewController? {
        return VideosHeaderViewController(nibName: "VideosHeaderViewController", bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBar.isEnabled = false
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        let nc = NotificationCenter.default
        
        nc.addObserver(forName: NSNotification.Name.NSWindowWillEnterFullScreen, object: view.window!, queue: nil) { object in
            self.searchBarBottomConstraint.constant = 19
        }
        nc.addObserver(forName: NSNotification.Name.NSWindowWillExitFullScreen, object: view.window!, queue: nil) { object in
            self.searchBarBottomConstraint.constant = 12
        }
    }
    
    func enable() {
        searchBar.isEnabled = true
    }
    
    @IBAction func search(_ sender: NSSearchField) {
        if let callback = performSearch {
            callback(sender.stringValue)
        }
    }
    
    @IBAction func activateSearchField(_ sender: AnyObject) {
        searchBar.window?.makeFirstResponder(searchBar)
    }
}
