//
//  SearchFiltersViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore

enum FilterChangeReason: Equatable {
    case initialValue
    case configurationChange
    case userInput
    case allowSelection
}

protocol SearchFiltersViewControllerDelegate: AnyObject {

    func searchFiltersViewController(
        _ controller: SearchFiltersViewController,
        didChangeFilters filters: [FilterType],
        context: FilterChangeReason
    )
}

extension NSSegmentedControl {

    var optionalToggleState: Bool? {
        get { 
            switch selectedSegment {
            case 1: 
                return true
            case 2:
                return false
            default:
                return nil
            }
        }
        set { 
            switch newValue {
            case true: 
                selectedSegment = 1
            case false:
                selectedSegment = 2
            default:
                selectedSegment = 0
            }
        }
    }

}

final class SearchFiltersViewController: NSViewController {

    static func loadFromStoryboard() -> SearchFiltersViewController {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)

        // swiftlint:disable:next force_cast
        return storyboard.instantiateController(withIdentifier: "SearchFiltersViewController") as! SearchFiltersViewController
    }
    var showFilterButton = true

    @IBOutlet var filterContainer: NSView!
    @IBOutlet weak var eventsPopUp: NSPopUpButton!
    @IBOutlet weak var focusesPopUp: NSPopUpButton!
    @IBOutlet weak var tracksPopUp: NSPopUpButton!
    @IBOutlet weak var favoritesSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var downloadedSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var watchedSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var bookmarksSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var filterButton: NSButton!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var vfxView: NSVisualEffectView!

    var filters: [FilterType] {
        get {
            return effectiveFilters
        }
        set {

            effectiveFilters = newValue

            updateUI()
        }
    }

    private var effectiveFilters: [FilterType] = []

    var additionalPredicates: [NSPredicate] = []
    var currentPredicate: NSPredicate? {
        let filters = filters
        guard filters.contains(where: { !$0.isEmpty }) || !additionalPredicates.isEmpty else {
            return nil
        }

        let subpredicates = filters.compactMap { $0.predicate } + additionalPredicates

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)

        return predicate
    }

    func clearAllFilters(reason: FilterChangeReason) {
        let updatedFilters = filters.map {
            var resetFilter = $0
            resetFilter.reset()

            return resetFilter
        }

        filters = updatedFilters

        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters, context: reason)
    }

    weak var delegate: SearchFiltersViewControllerDelegate?

    @IBAction func eventsPopUpAction(_ sender: Any) {
        guard let filterIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.event }) else { return }

        updateMultipleChoiceFilter(at: filterIndex, with: eventsPopUp)
    }

    @IBAction func focusesPopUpAction(_ sender: Any) {
        guard let filterIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.focus }) else { return }

        updateMultipleChoiceFilter(at: filterIndex, with: focusesPopUp)
    }

    @IBAction func tracksPopUpAction(_ sender: Any) {
        guard let filterIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.track }) else { return }

        updateMultipleChoiceFilter(at: filterIndex, with: tracksPopUp)
    }
    
    @IBAction func favoritesSegmentedControlAction(_ sender: Any) {
        if let favoriteIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.isFavorite }) {
            updateOptionalToggleFilter(at: favoriteIndex, with: favoritesSegmentedControl.optionalToggleState)
        }
    }
    
    @IBAction func downloadedSegmentedControlAction(_ sender: Any) {
        if let downloadedIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.isDownloaded }) {
            updateOptionalToggleFilter(at: downloadedIndex, with: downloadedSegmentedControl.optionalToggleState)
        }
    }
    
    @IBAction func watchedSegmentedControlAction(_ sender: Any) {
        if let watchedIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.isUnwatched }) {
            updateOptionalToggleFilter(at: watchedIndex, with: watchedSegmentedControl.optionalToggleState)
        }
    }
    
    @IBAction func bookmarksSegmentedControlAction(_ sender: Any) {
        if let bookmarksIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.hasBookmarks }) {
            updateOptionalToggleFilter(at: bookmarksIndex, with: bookmarksSegmentedControl.optionalToggleState)
        }
    }

    @IBAction func searchFieldAction(_ sender: Any) {
        guard let textIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.text }) else { return }

        updateTextualFilter(at: textIndex, with: searchField.stringValue)
    }

    @IBAction func filterButtonAction(_ sender: Any) {
        setFilters(hidden: !filterContainer.isHidden)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        filterButton.isHidden = !showFilterButton
        /// Move background and content from behind the title bar.
        vfxView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        vfxView.blendingMode = .behindWindow
        vfxView.material = .menu

        setFilters(hidden: true)

        updateUI()
    }

    func setFilters(hidden: Bool) {
        guard !filterButton.isHidden else {
            return
        }
        filterButton.state = NSControl.StateValue(rawValue: hidden ? 0 : 1)
        filterContainer.isHidden = hidden
    }

    private func updateMultipleChoiceFilter(at filterIndex: Int, with popUp: NSPopUpButton) {
        guard let selectedItem = popUp.selectedItem else { return }
        guard let menu = popUp.menu else { return }
        guard var filter = effectiveFilters[filterIndex] as? MultipleChoiceFilter else { return }

        if let option = selectedItem.representedObject as? FilterOption, option.isClear {
            filter.selectedOptions = []
            menu.items.forEach { $0.state = .off }
        } else {
            selectedItem.state = (selectedItem.state == .off) ? .on : .off

            let selected = menu.items.filter({ $0.state == .on }).compactMap({ $0.representedObject as? FilterOption })

            filter.selectedOptions = selected
        }

        var updatedFilters = effectiveFilters
        updatedFilters[filterIndex] = filter

        popUp.title = filter.title

        effectiveFilters = updatedFilters

        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters, context: .userInput)
    }

    private func updateToggleFilter(at filterIndex: Int, with state: Bool) {
        guard var filter = effectiveFilters[filterIndex] as? ToggleFilter else { return }

        filter.isOn = state

        var updatedFilters = effectiveFilters
        updatedFilters[filterIndex] = filter

        effectiveFilters = updatedFilters

        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters, context: .userInput)
    }
    
    private func updateOptionalToggleFilter(at filterIndex: Int, with state: Bool?) {
        guard var filter = effectiveFilters[filterIndex] as? OptionalToggleFilter else { return }

        filter.isOn = state

        var updatedFilters = effectiveFilters
        updatedFilters[filterIndex] = filter

        effectiveFilters = updatedFilters

        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters, context: .userInput)
    }

    private func updateTextualFilter(at filterIndex: Int, with text: String) {
        guard var filter = effectiveFilters[filterIndex] as? TextualFilter else { return }
        guard filter.value != text else { return }

        filter.value = text

        var updatedFilters = effectiveFilters
        updatedFilters[filterIndex] = filter

        effectiveFilters = updatedFilters

        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters, context: .userInput)

        NSPasteboard(name: .find).clearContents()
        NSPasteboard(name: .find).setString(text, forType: .string)
    }

    private func popUpButton(for filter: MultipleChoiceFilter) -> NSPopUpButton? {
        switch filter.identifier {
        case .event:
            return eventsPopUp
        case .focus:
            return focusesPopUp
        case .track:
            return tracksPopUp
        default: return nil
        }
    }

    /// Updates the UI to match the active filters
    private func updateUI() {
        guard isViewLoaded else { return }

        let activeFilters = filters.filter { !$0.isEmpty }
        let count = activeFilters.count
        if count == 0 {
            setFilters(hidden: true)

        } else if count == 1 && activeFilters[0] is TextualFilter {

            setFilters(hidden: true)
        } else {
            setFilters(hidden: false)
        }

        for filter in filters {

            switch filter {

            case let filter as MultipleChoiceFilter:
                updatePopUp(for: filter)
            case let filter as TextualFilter:
                searchField.stringValue = filter.value ?? ""
            case let filter as OptionalToggleFilter:
                updateOptionalToggle(for: filter)

            default:
                break
            }
        }
    }

    private func updatePopUp(for filter: MultipleChoiceFilter) {
        guard let popUp = popUpButton(for: filter) else { return }

        popUp.removeAllItems()

        popUp.addItem(withTitle: filter.title)

        filter.options.forEach { option in
            guard !option.isSeparator else {
                popUp.menu?.addItem(.separator())
                return
            }

            let item = NSMenuItem(title: option.title, action: nil, keyEquivalent: "")
            item.representedObject = option
            item.state = filter.selectedOptions.contains(option) ? .on : .off
            popUp.menu?.addItem(item)
        }
    }
    
    private func updateOptionalToggle(for filter: OptionalToggleFilter) {
        switch filter.identifier {
        case .isDownloaded:
            downloadedSegmentedControl.optionalToggleState = filter.isOn
        case .hasBookmarks:
            bookmarksSegmentedControl.optionalToggleState = filter.isOn
        case .isFavorite:
            favoritesSegmentedControl.optionalToggleState = filter.isOn
        case .isUnwatched:
            watchedSegmentedControl.optionalToggleState = filter.isOn
        default:
            break
        }
    }
}
