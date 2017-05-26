//
//  SearchFiltersViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

protocol SearchFiltersViewControllerDelegate: class {
    
    func searchFiltersViewController(_ controller: SearchFiltersViewController, didChangeFilters filters: [FilterType])
    
}

final class SearchFiltersViewController: NSViewController {
   
    static func loadFromStoryboard() -> SearchFiltersViewController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        
        return storyboard.instantiateController(withIdentifier: "SearchFiltersViewController") as! SearchFiltersViewController
    }
    
    @IBOutlet weak var eventsPopUp: NSPopUpButton!
    @IBOutlet weak var focusesPopUp: NSPopUpButton!
    @IBOutlet weak var tracksPopUp: NSPopUpButton!
    @IBOutlet weak var bottomSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var filterButton: NSButton!
    @IBOutlet weak var searchField: NSSearchField!
    
    var filters: [FilterType] = [] {
        didSet {
            effectiveFilters = filters
            
            updateUI()
        }
    }
    
    private var effectiveFilters: [FilterType] = []
    
    weak var delegate: SearchFiltersViewControllerDelegate?
    
    @IBAction func eventsPopUpAction(_ sender: Any) {
        guard let filterIndex = effectiveFilters.index(where: { $0.modelKey == "eventIdentifier" }) else { return }

        updateFilter(at: filterIndex, with: eventsPopUp)
    }
    
    @IBAction func focusesPopUpAction(_ sender: Any) {
        guard let filterIndex = effectiveFilters.index(where: { $0.collectionKey == "focuses" && $0.modelKey == "name" }) else { return }
        
        updateFilter(at: filterIndex, with: focusesPopUp)
    }
    
    @IBAction func tracksPopUpAction(_ sender: Any) {
        guard let filterIndex = effectiveFilters.index(where: { $0.modelKey == "trackName" }) else { return }
        
        updateFilter(at: filterIndex, with: tracksPopUp)
    }
    
    @IBAction func bottomSegmentedControlAction(_ sender: Any) {
    }
    
    @IBAction func searchFieldAction(_ sender: Any) {
    }
    
    @IBAction func filterButtonAction(_ sender: Any) {
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUI()
    }
    
    private func updateFilter(at filterIndex: Int, with popUp: NSPopUpButton) {
        guard let selectedItem = popUp.selectedItem else { return }
        guard let menu = popUp.menu else { return }
        
        selectedItem.state = (selectedItem.state == NSOffState) ? NSOnState : NSOffState
        
        let selected = menu.items.filter({ $0.state == NSOnState }).flatMap({ $0.representedObject as? FilterOption })
        
        var updatedFilters = effectiveFilters
        updatedFilters[filterIndex].selectedOptions = selected
        
        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters)
        
        popUp.title = updatedFilters[filterIndex].title
        
        effectiveFilters = updatedFilters
    }
    
    private func popUpButton(for filter: FilterType) -> NSPopUpButton? {
        switch (filter.collectionKey, filter.modelKey) {
        case ("","eventIdentifier"):
            return eventsPopUp
        case ("focuses", "name"):
            return focusesPopUp
        case ("", "trackName"):
            return tracksPopUp
        default: return nil
        }
    }
    
    private func updateUI() {
        guard isViewLoaded else { return }
        
        filters.forEach { filter in
            guard let popUp = popUpButton(for: filter) else { return }
            
            popUp.removeAllItems()
            
            popUp.addItem(withTitle: filter.title)
            
            filter.options.forEach { option in
                let item = NSMenuItem(title: option.title, action: nil, keyEquivalent: "")
                item.representedObject = option
                item.state = filter.selectedOptions.contains(option) ? NSOnState : NSOffState
                popUp.menu?.addItem(item)
            }
        }
    }
    
    
}
