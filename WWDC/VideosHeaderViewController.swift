//
//  VideosHeaderViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/04/15.
//  Copyright (c) 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa

enum SearchFilter: Int {
    case All = 0
    case Unwatched
    case Watched
}

class VideosHeaderViewController: NSViewController {
    
    @IBOutlet weak var searchBar: NSSearchField!
    @IBOutlet weak var segmentedControl: NSSegmentedControl!
    @IBOutlet weak var segmentBottomConstraint: NSLayoutConstraint!
    
    var performSearch: ((term: String, filter: SearchFilter) -> Void)?
    
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
            self.segmentBottomConstraint.constant = 19
        }
        nc.addObserverForName(NSWindowWillExitFullScreenNotification, object: view.window!, queue: nil) { object in
            self.segmentBottomConstraint.constant = 12
        }
    }
    
    func enable() {
        searchBar.enabled = true
    }
    
    @IBAction func search(sender: NSSearchField) {
        updateSearch()
    }

    @IBAction func filterChanged(sender: NSSegmentedControl) {
        updateSearch()
    }

    private func updateSearch() {
        if let callback = performSearch {
            var filter = SearchFilter.All

            switch segmentedControl.selectedSegment {
            case 1:
                filter = .Unwatched
            case 2:
                filter = .Watched
            default:
                break
            }

            callback(term: searchBar.stringValue, filter: filter)
        }
    }
}
