//
//  FilterBarController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/10/15.
//  Copyright © 2015 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ViewUtils

class FilterBarController: NSViewController, GRScrollViewDelegate {

    @IBOutlet weak private var segmentedControl: GRSegmentedControl!
    private weak var scrollView: GRScrollView?
    
    private var accessoryViewBaseY: CGFloat {
        guard let superview = scrollView?.superview else { return 0.0 }
        return CGRectGetHeight(superview.frame)-CGRectGetHeight(view.frame)-(scrollView!.contentInsets.top-CGRectGetHeight(view.frame))
    }
    private var accessoryViewContractedY: CGFloat {
        guard let superview = scrollView?.superview else { return 0.0 }
        return CGRectGetHeight(superview.frame) - CGRectGetHeight(view.frame)
    }
    private var lastScrollOffsetY = CGFloat(0.0)
    
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
        scrollView.contentInsets = NSEdgeInsets(top: scrollView.contentInsets.top+CGRectGetHeight(view.frame), left: 0, bottom: 0, right: 0)
        
        scrollView.delegate = self
        
        segmentedControl.action = "segmentedControlAction:"
        segmentedControl.target = self
        segmentedControl.showsMenuImmediately = true
        segmentedControl.usesCocoaLook = true
        
        updateMenus()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.frame = CGRectMake(0, accessoryViewBaseY, CGRectGetWidth(view.frame), 44.0)
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
            let item = NSMenuItem(title: "\(year)", action: "yearMenuAction:", keyEquivalent: "")
            item.target = self
            item.state = yearFilter.selectedInts!.contains(year) ? NSOnState : NSOffState
            yearMenu.addItem(item)
        }
        for track in tracks {
            let item = NSMenuItem(title: "\(track)", action: "trackMenuAction:", keyEquivalent: "")
            item.target = self
            item.state = trackFilter.selectedStrings!.contains(track) ? NSOnState : NSOffState
            trackMenu.addItem(item)
        }
        for focus in focuses {
            let item = NSMenuItem(title: "\(focus)", action: "focusMenuAction:", keyEquivalent: "")
            item.state = focusFilter.selectedStrings!.contains(focus) ? NSOnState : NSOffState
            item.target = self
            focusMenu.addItem(item)
        }
        
        for (name,state) in [("Downloaded","yes"),("Missing","no")] {
            let item = NSMenuItem(title: "\(name)", action: "downloadedMenuAction:", keyEquivalent: "")
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
    
    private func toggle(item: NSMenuItem) {
        if item.state == NSOnState {
            item.state = NSOffState
        } else {
            item.state = NSOnState
        }
    }
    
    var filtersDidChangeCallback: (() -> Void)?
    
    var filters: SearchFilters = []
    
    var yearFilter = SearchFilter.Year([])
    var trackFilter = SearchFilter.Track([])
    var focusFilter = SearchFilter.Focus([])
    var favoritedFilter = SearchFilter.Favorited(false)
    var downloadedFilter = SearchFilter.Downloaded([])
    
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
    
    func yearMenuAction(sender: NSMenuItem) {
        toggle(sender)
        
        var selectedYears:[Int] = []
        for item in yearMenu.itemArray {
            let year = Int(item.title)!
            if item.state == NSOnState {
                selectedYears.append(year)
            }
        }
        yearFilter = SearchFilter.Year(selectedYears)
        
        updateFilters()
    }
    
    func trackMenuAction(sender: NSMenuItem) {
        toggle(sender)
        
        var selectedTracks:[String] = []
        for item in trackMenu.itemArray {
            if item.state == NSOnState {
                selectedTracks.append(item.title)
            }
        }
        trackFilter = SearchFilter.Track(selectedTracks)
        
        updateFilters()
    }
    
    func focusMenuAction(sender: NSMenuItem) {
        toggle(sender)
        
        var selectedFocuses:[String] = []
        for item in focusMenu.itemArray {
            if item.state == NSOnState {
                selectedFocuses.append(item.title)
            }
        }
        focusFilter = SearchFilter.Focus(selectedFocuses)
        
        updateFilters()
    }
    
    func downloadedMenuAction(sender: NSMenuItem) {
        toggle(sender)

        var selectedDownloaded:[String] = []
        for item in downloadedMenu.itemArray {
            if item.state == NSOnState {
                if(item == sender) {
                    selectedDownloaded.append(item.representedObject as! String)
                } else {
                    toggle(item)
                }
            }
        }
        downloadedFilter = SearchFilter.Downloaded(selectedDownloaded)
        
        updateFilters()
    }
    
    var favoritedActive = false
    var downloadedActive = false
    func segmentedControlAction(sender: GRSegmentedControl) {
        switch(segmentedControl.selectedSegment) {
        case 0:
            segmentedControl.setSelected(false, forSegment: 0)
        case 1:
            segmentedControl.setSelected(false, forSegment: 1)
        case 2:
            segmentedControl.setSelected(false, forSegment: 2)
        case 3:
            favoritedActive = !favoritedActive
            favoritedFilter = SearchFilter.Favorited(favoritedActive)
            updateFilters()
        case 4:
            segmentedControl.setSelected(false, forSegment: 4)
        default:
            print("Invalid segment!")
        }
    }
    
    // MARK: Scrolling behavior
    
    func scrollViewDidScroll(scrollView: GRScrollView) {
        
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
    
    func scrollViewDidEndDragging(scrollView: GRScrollView) {
        var accessoryViewFrame = view.frame
        
        if accessoryViewFrame.origin.y > accessoryViewBaseY && accessoryViewFrame.origin.y != accessoryViewContractedY {
            accessoryViewFrame.origin.y = accessoryViewBaseY
        }
        
        NSAnimationContext.beginGrouping()
        NSAnimationContext.currentContext().duration = 0.2;
        NSAnimationContext.currentContext().timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        self.view.animator().frame = accessoryViewFrame
        NSAnimationContext.endGrouping()
    }
    
    func mouseWheelDidScroll(scrollView: GRScrollView) {
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
        NSAnimationContext.currentContext().duration = 0.2;
        NSAnimationContext.currentContext().timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        self.view.animator().frame = accessoryViewFrame
        NSAnimationContext.endGrouping()
    }
    
}
