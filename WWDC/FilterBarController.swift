//
//  FilterBarController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/10/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import WWDCAppKit

class FilterBarController: NSViewController, GRScrollViewDelegate {

    @IBOutlet weak fileprivate var segmentedControl: GRSegmentedControl!
    fileprivate weak var scrollView: GRScrollView?
    
    fileprivate var accessoryViewBaseY: CGFloat {
        guard let superview = scrollView?.superview else { return 0.0 }
        return (superview.frame).height-(view.frame).height-(scrollView!.contentInsets.top-(view.frame).height)
    }
    fileprivate var accessoryViewContractedY: CGFloat {
        guard let superview = scrollView?.superview else { return 0.0 }
        return (superview.frame).height - (view.frame).height
    }
    fileprivate var lastScrollOffsetY = CGFloat(0.0)
    
    init(scrollView: GRScrollView) {
        self.scrollView = scrollView
        super.init(nibName: "FilterBarController", bundle: nil)!
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @IBOutlet var yearMenu: NSMenu!
    @IBOutlet var trackMenu: NSMenu!
    @IBOutlet var focusMenu: NSMenu!
    @IBOutlet var downloadedMenu: NSMenu!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let scrollView = self.scrollView else { return }
        
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = EdgeInsets(top: scrollView.contentInsets.top+(view.frame).height, left: 0, bottom: 0, right: 0)
        
        scrollView.delegate = self
        
        segmentedControl.action = #selector(FilterBarController.segmentedControlAction(_:))
        segmentedControl.target = self
        segmentedControl.showsMenuImmediately = true
        segmentedControl.usesCocoaLook = true
        
        updateMenus()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.frame = CGRect(x: 0, y: accessoryViewBaseY, width: view.frame.width, height: 44.0)
    }
    
    func updateMenus() {
        yearMenu.removeAllItems()
        trackMenu.removeAllItems()
        focusMenu.removeAllItems()
        downloadedMenu.removeAllItems()
        
        let sessions = WWDCDatabase.sharedDatabase.standardSessionList
        var years: [Int] = []
        var tracks: [String] = []
        var focuses: [String] = []
        for session in sessions {
            if years.indexOf(session.year) == nil {
                years.append(session.year)
            }
            if tracks.indexOf(session.track) == nil {
                tracks.append(session.track)
            }
            let sessionFocuses = session.focus.componentsSeparatedByString(", ")
            for focus in sessionFocuses {
                if focuses.indexOf(focus) == nil && focus != "" {
                    focuses.append(focus)
                }
            }
        }
        
        for year in years {
            let item = NSMenuItem(title: "\(year)", action: #selector(FilterBarController.yearMenuAction(_:)), keyEquivalent: "")
            item.target = self
            item.state = yearFilter.selectedInts!.contains(year) ? NSOnState : NSOffState
            yearMenu.addItem(item)
        }
        for track in tracks {
            let item = NSMenuItem(title: "\(track)", action: #selector(FilterBarController.trackMenuAction(_:)), keyEquivalent: "")
            item.target = self
            item.state = trackFilter.selectedStrings!.contains(track) ? NSOnState : NSOffState
            trackMenu.addItem(item)
        }
        for focus in focuses {
            let item = NSMenuItem(title: "\(focus)", action: #selector(FilterBarController.focusMenuAction(_:)), keyEquivalent: "")
            item.state = focusFilter.selectedStrings!.contains(focus) ? NSOnState : NSOffState
            item.target = self
            focusMenu.addItem(item)
        }
        
        for (name,state) in [("Downloaded","yes"),("Missing","no")] {
            let item = NSMenuItem(title: "\(name)", action: #selector(FilterBarController.downloadedMenuAction(_:)), keyEquivalent: "")
            item.state = downloadedFilter.selectedStrings!.contains(state) ? NSOnState : NSOffState
            item.target = self
            item.representedObject = state
            downloadedMenu.addItem(item)
        }
        
        segmentedControl.setMenu(yearMenu, forSegment: 0)
        segmentedControl.setMenu(trackMenu, forSegment: 1)
        segmentedControl.setMenu(focusMenu, forSegment: 2)
        segmentedControl.setMenu(downloadedMenu, forSegment: 4)
    }
    
    fileprivate func toggle(_ item: NSMenuItem) {
        if item.state == NSOnState {
            item.state = NSOffState
        } else {
            item.state = NSOnState
        }
    }
    
    var filtersDidChangeCallback: (() -> Void)?
    
    var filters: SearchFilters = []
    
    var yearFilter = SearchFilter.year([])
    var trackFilter = SearchFilter.track([])
    var focusFilter = SearchFilter.focus([])
    var favoritedFilter = SearchFilter.favorited(false)
    var downloadedFilter = SearchFilter.downloaded([])
    
    func updateFilters() {
        filters = []
        
        if !yearFilter.isEmpty {
            filters.append(yearFilter)
        }
        if !trackFilter.isEmpty {
            filters.append(trackFilter)
        }
        if !focusFilter.isEmpty {
            filters.append(focusFilter)
        }
        if !favoritedFilter.isEmpty {
            filters.append(favoritedFilter)
        }
        if !downloadedFilter.isEmpty {
            filters.append(downloadedFilter)
        }
        
        filtersDidChangeCallback?()
    }
    
    func yearMenuAction(_ sender: NSMenuItem) {
        toggle(sender)
        
        var selectedYears:[Int] = []
        for item in yearMenu.items {
            let year = Int(item.title)!
            if item.state == NSOnState {
                selectedYears.append(year)
            }
        }
        yearFilter = SearchFilter.year(selectedYears)
        
        updateFilters()
    }
    
    func trackMenuAction(_ sender: NSMenuItem) {
        toggle(sender)
        
        var selectedTracks:[String] = []
        for item in trackMenu.items {
            if item.state == NSOnState {
                selectedTracks.append(item.title)
            }
        }
        trackFilter = SearchFilter.track(selectedTracks)
        
        updateFilters()
    }
    
    func focusMenuAction(_ sender: NSMenuItem) {
        toggle(sender)
        
        var selectedFocuses:[String] = []
        for item in focusMenu.items {
            if item.state == NSOnState {
                selectedFocuses.append(item.title)
            }
        }
        focusFilter = SearchFilter.focus(selectedFocuses)
        
        updateFilters()
    }
    
    func downloadedMenuAction(_ sender: NSMenuItem) {
        toggle(sender)

        var selectedDownloaded:[String] = []
        for item in downloadedMenu.items {
            if item.state == NSOnState {
                if(item == sender) {
                    selectedDownloaded.append(item.representedObject as! String)
                } else {
                    toggle(item)
                }
            }
        }
        downloadedFilter = SearchFilter.downloaded(selectedDownloaded)
        
        updateFilters()
    }
    
    var favoritedActive = false
    var downloadedActive = false
    func segmentedControlAction(_ sender: GRSegmentedControl) {
        switch(segmentedControl.selectedSegment) {
        case 0:
            segmentedControl.setSelected(false, forSegment: 0)
        case 1:
            segmentedControl.setSelected(false, forSegment: 1)
        case 2:
            segmentedControl.setSelected(false, forSegment: 2)
        case 3:
            favoritedActive = !favoritedActive
            favoritedFilter = SearchFilter.favorited(favoritedActive)
            updateFilters()
        case 4:
            segmentedControl.setSelected(false, forSegment: 4)
        default:
            print("Invalid segment!")
        }
    }
    
    // MARK: Scrolling behavior
    
    func scrollViewDidScroll(_ scrollView: GRScrollView) {
        
        let normalizedOffsetY = scrollView.contentOffset.y + scrollView.contentInsets.top
        
        // this makes sure lastScrollOffsetY is updated when the scrollview's state is restored at launch
        if lastScrollOffsetY == 0.0 {
            lastScrollOffsetY = normalizedOffsetY
        }
        
        guard (normalizedOffsetY > 0 && normalizedOffsetY != lastScrollOffsetY) else { return }
        
        var accessoryViewFrame = view.frame
        
        if normalizedOffsetY > lastScrollOffsetY {
            // going down
            if accessoryViewFrame.origin.y < accessoryViewContractedY {
                accessoryViewFrame.origin.y += (normalizedOffsetY - lastScrollOffsetY)
            } else {
                accessoryViewFrame.origin.y = accessoryViewContractedY
            }
        }
        else {
            // going up
            if accessoryViewFrame.origin.y > accessoryViewBaseY {
                accessoryViewFrame.origin.y += (normalizedOffsetY - lastScrollOffsetY)
            } else {
                accessoryViewFrame.origin.y = accessoryViewBaseY
            }
        }
        
        view.frame = accessoryViewFrame
        
        lastScrollOffsetY = normalizedOffsetY
    }
    
    func scrollViewDidEndDragging(_ scrollView: GRScrollView) {
        var accessoryViewFrame = view.frame
        
        if accessoryViewFrame.origin.y > accessoryViewBaseY && accessoryViewFrame.origin.y != accessoryViewContractedY {
            accessoryViewFrame.origin.y = accessoryViewBaseY
        }
        
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current().duration = 0.2;
        NSAnimationContext.current().timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        self.view.animator().frame = accessoryViewFrame
        NSAnimationContext.endGrouping()
    }
    
    func mouseWheelDidScroll(_ scrollView: GRScrollView) {
        var accessoryViewFrame = view.frame
        
        let normalizedOffsetY = scrollView.contentOffset.y + scrollView.contentInsets.top
        
        // this makes sure lastScrollOffsetY is updated when the scrollview's state is restored at launch
        if lastScrollOffsetY == 0.0 {
            lastScrollOffsetY = normalizedOffsetY
        }
        
        guard (normalizedOffsetY > 0 && normalizedOffsetY != lastScrollOffsetY) else { return }
        
        if normalizedOffsetY > lastScrollOffsetY {
            // going down
            accessoryViewFrame.origin.y = accessoryViewContractedY
        } else {
            // going up
            accessoryViewFrame.origin.y = accessoryViewBaseY
        }
        
        lastScrollOffsetY = normalizedOffsetY

        NSAnimationContext.beginGrouping()
        NSAnimationContext.current().duration = 0.2;
        NSAnimationContext.current().timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        self.view.animator().frame = accessoryViewFrame
        NSAnimationContext.endGrouping()
    }
    
}
