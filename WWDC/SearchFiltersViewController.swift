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

enum FilterSegment: Int {
    case favorite
    case downloaded
    case unwatched

    init?(_ id: FilterIdentifier) {

        switch id {
        case .isFavorite:
            self = .favorite
        case .isDownloaded:
            self = .downloaded
        case .isUnwatched:
            self = .unwatched

        default:
            return nil
        }
    }
}

extension NSSegmentedControl {

    func isSelected(for segment: FilterSegment) -> Bool {
        return isSelected(forSegment: segment.rawValue)
    }

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

    var filters: [FilterType] {
        set {

            effectiveFilters = newValue

            updateUI()
        }
        get {
            return effectiveFilters
        }
    }

    private var effectiveFilters: [FilterType] = []

    weak var delegate: SearchFiltersViewControllerDelegate?

    @IBAction func eventsPopUpAction(_ sender: Any) {
        guard let filterIndex = effectiveFilters.index(where: { $0.identifier == FilterIdentifier.event.rawValue }) else { return }

        updateMultipleChoiceFilter(at: filterIndex, with: eventsPopUp)
    }

    @IBAction func focusesPopUpAction(_ sender: Any) {
        guard let filterIndex = effectiveFilters.index(where: { $0.identifier == FilterIdentifier.focus.rawValue }) else { return }

        updateMultipleChoiceFilter(at: filterIndex, with: focusesPopUp)
    }

    @IBAction func tracksPopUpAction(_ sender: Any) {
        guard let filterIndex = effectiveFilters.index(where: { $0.identifier == FilterIdentifier.track.rawValue }) else { return }

        updateMultipleChoiceFilter(at: filterIndex, with: tracksPopUp)
    }

    private var favoriteSegmentSelected = false
    private var downloadedSegmentSelected = false
    private var unwatchedSegmentSelected = false

    @IBAction func bottomSegmentedControlAction(_ sender: Any) {
        if favoriteSegmentSelected != bottomSegmentedControl.isSelected(for: .favorite) {
            if let favoriteIndex = effectiveFilters.index(where: { $0.identifier == FilterIdentifier.isFavorite.rawValue }) {
                updateToggleFilter(at: favoriteIndex, with: bottomSegmentedControl.isSelected(for: .favorite))
            }
        }

        if downloadedSegmentSelected != bottomSegmentedControl.isSelected(for: .downloaded) {
            if let downloadedIndex = effectiveFilters.index(where: { $0.identifier == FilterIdentifier.isDownloaded.rawValue }) {
                updateToggleFilter(at: downloadedIndex, with: bottomSegmentedControl.isSelected(for: .downloaded))
            }
        }

        if unwatchedSegmentSelected != bottomSegmentedControl.isSelected(for: .unwatched) {
            if let unwatchedIndex = effectiveFilters.index(where: { $0.identifier == FilterIdentifier.isUnwatched.rawValue }) {
                updateToggleFilter(at: unwatchedIndex, with: bottomSegmentedControl.isSelected(for: .unwatched))
            }
        }

        favoriteSegmentSelected = bottomSegmentedControl.isSelected(for: .favorite)
        downloadedSegmentSelected = bottomSegmentedControl.isSelected(for: .downloaded)
        unwatchedSegmentSelected = bottomSegmentedControl.isSelected(for: .unwatched)
    }

    @IBAction func searchFieldAction(_ sender: Any) {
        guard let textIndex = effectiveFilters.index(where: { $0.identifier == FilterIdentifier.text.rawValue }) else { return }

        updateTextualFilter(at: textIndex, with: searchField.stringValue)
    }

    @IBAction func filterButtonAction(_ sender: Any) {
        setFilters(hidden: !eventsPopUp.isHidden)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setFilters(hidden: true)

        updateUI()
    }

    func setFilters(hidden: Bool) {
        filterButton.state = hidden ? 0 : 1
        eventsPopUp.isHidden = hidden
        focusesPopUp.isHidden = hidden
        tracksPopUp.isHidden = hidden
        bottomSegmentedControl.isHidden = hidden
    }

    private func updateMultipleChoiceFilter(at filterIndex: Int, with popUp: NSPopUpButton) {
        guard let selectedItem = popUp.selectedItem else { return }
        guard let menu = popUp.menu else { return }
        guard var filter = effectiveFilters[filterIndex] as? MultipleChoiceFilter else { return }

        selectedItem.state = (selectedItem.state == NSOffState) ? NSOnState : NSOffState

        let selected = menu.items.filter({ $0.state == NSOnState }).flatMap({ $0.representedObject as? FilterOption })

        filter.selectedOptions = selected

        var updatedFilters = effectiveFilters
        updatedFilters[filterIndex] = filter

        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters)

        popUp.title = filter.title

        effectiveFilters = updatedFilters
    }

    private func updateToggleFilter(at filterIndex: Int, with state: Bool) {
        guard var filter = effectiveFilters[filterIndex] as? ToggleFilter else { return }

        filter.isOn = state

        var updatedFilters = effectiveFilters
        updatedFilters[filterIndex] = filter

        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters)

        effectiveFilters = updatedFilters
    }

    private func updateTextualFilter(at filterIndex: Int, with text: String) {
        guard var filter = effectiveFilters[filterIndex] as? TextualFilter else { return }
        guard filter.value != text else { return }

        filter.value = text

        var updatedFilters = effectiveFilters
        updatedFilters[filterIndex] = filter

        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters)

        effectiveFilters = updatedFilters
    }

    private func popUpButton(for filter: MultipleChoiceFilter) -> NSPopUpButton? {
        guard let filterIdentifier = FilterIdentifier(rawValue: filter.identifier) else { return nil }

        switch filterIdentifier {
        case .event:
            return eventsPopUp
        case .focus:
            return focusesPopUp
        case .track:
            return tracksPopUp
        default: return nil
        }
    }

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
                guard let popUp = popUpButton(for: filter) else { return }

                popUp.removeAllItems()

                popUp.addItem(withTitle: filter.title)

                filter.options.forEach { option in
                    let item = NSMenuItem(title: option.title, action: nil, keyEquivalent: "")
                    item.representedObject = option
                    item.state = filter.selectedOptions.contains(option) ? NSOnState : NSOffState
                    popUp.menu?.addItem(item)
                }
            case let filter as TextualFilter:
                if let value = filter.value {
                    searchField.stringValue = value
                }
            case let filter as ToggleFilter:
                guard let filterID = FilterIdentifier(rawValue: filter.identifier), let segmentIndex = FilterSegment(filterID)?.rawValue else {
                    break
                }

                bottomSegmentedControl.setSelected(filter.isOn, forSegment: segmentIndex)

            default:
                break
            }
        }

        favoriteSegmentSelected = bottomSegmentedControl.isSelected(for: .favorite)
        downloadedSegmentSelected = bottomSegmentedControl.isSelected(for: .downloaded)
        unwatchedSegmentSelected = bottomSegmentedControl.isSelected(for: .unwatched)
    }
}
