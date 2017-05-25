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
    
    var filters: [FilterType] = [] {
        didSet {
            
        }
    }
    
    weak var delegate: SearchFiltersViewControllerDelegate?
    
    @IBAction func eventsPopUpAction(_ sender: Any) {
    }
    
    @IBAction func focusesPopUpAction(_ sender: Any) {
    }
    
    @IBAction func tracksPopUpAction(_ sender: Any) {
    }
    
    @IBAction func bottomSegmentedControlAction(_ sender: Any) {
    }
    
    
}
