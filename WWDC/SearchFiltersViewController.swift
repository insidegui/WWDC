//
//  SearchFiltersViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import SwiftUI

enum FilterChangeReason: Equatable {
    case initialValue
    case configurationChange
    case userDefaultsChange
    case userInput
    case allowSelection
}

protocol SearchFiltersViewControllerDelegate: AnyObject {

    func searchFiltersViewController(
        _ controller: SearchFiltersViewModel,
        didChangeFilters filters: [FilterType],
        context: FilterChangeReason
    )
}

final class SearchFiltersViewModel: ObservableObject {
    @Published var isSearchFieldFocused = false
    @Published var searchText = ""
    @Published var areFiltersVisible = false
    /// note: probably not really needed anymore
    var isInWindow = false

    /// External representation of the filters. Historically, the separation of internal/external
    /// is likely not needed anymore, but it's kept for now to avoid unintended consequences.
    ///
    /// It's existence is tied up in the SearchCoordinator, filter state persistence, the async nature
    /// of app startup, etc, etc
    var filters: [FilterType] {
        get { effectiveFilters }
        set {
            effectiveFilters = newValue

            handleExternalUpdatesToFilters()
        }
    }

    /// This is an internal, side effect-free representation of the filters
    @Published private var effectiveFilters: [FilterType] = []

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

    weak var delegate: SearchFiltersViewControllerDelegate?

    func clearAllFilters(reason: FilterChangeReason) {
        let updatedFilters = filters.map {
            var resetFilter = $0
            resetFilter.reset()

            return resetFilter
        }

        filters = updatedFilters

        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters, context: reason)
    }

    func clearMultipleChoiceFilter(id: FilterIdentifier) {
        guard let indexAndFilter = effectiveFilters.findIndexed(MultipleChoiceFilter.self, byID: id) else { return }
        let index = indexAndFilter.0
        var filter = indexAndFilter.1

        filter.selectedOptions = []

        effectiveFilters[index] = filter

        delegate?.searchFiltersViewController(self, didChangeFilters: effectiveFilters, context: .userInput)
    }

    private func updateMultipleChoiceFilter(at filterIndex: Int, option: FilterOption, isOn: Bool) {
        guard var filter = effectiveFilters[filterIndex] as? MultipleChoiceFilter else { return }

        if isOn {
            filter.selectedOptions.append(option)
        } else {
            filter.selectedOptions.removeAll { $0 == option }
        }

        effectiveFilters[filterIndex] = filter

        delegate?.searchFiltersViewController(self, didChangeFilters: effectiveFilters, context: .userInput)
    }

    func performTextSearch() {
        guard let indexAndFilter = effectiveFilters.findIndexed(TextualFilter.self, byID: .text) else { return }
        let filterIndex = indexAndFilter.0
        var filter = indexAndFilter.1
        let text = self.searchText
        guard filter.value != text else { return }

        filter.value = text

        var updatedFilters = effectiveFilters
        updatedFilters[filterIndex] = filter

        effectiveFilters = updatedFilters

        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters, context: .userInput)

        NSPasteboard(name: .find).clearContents()
        NSPasteboard(name: .find).setString(text, forType: .string)
    }

    /// Primary purpose is that is shows the filters if needed as part of filter restoration
    /// and also updates the textual filter. The textual filter binding could be changed to allow the UI
    /// to be bound directly to the filter struct just like the toggles and pull downs are.
    private func handleExternalUpdatesToFilters() {
        let activeFilters = filters.filter { !$0.isEmpty }
        let count = activeFilters.count
        if count == 0 {
            areFiltersVisible = false
        } else if count == 1 && activeFilters[0] is TextualFilter {
            areFiltersVisible = false
        } else {
            areFiltersVisible = true
        }

        if let textualFilter = effectiveFilters.find(TextualFilter.self, byID: .text) {
            searchText = textualFilter.value ?? ""
        }
    }

}

// MARK: - Transformations for menus, toggles, etc

extension SearchFiltersViewModel {
    var pullDownMenus: [PullDownMenu] {
        let multipleChoiceFilters: [(index: Int, element: MultipleChoiceFilter)] = effectiveFilters.indexed().compactMap {
            if let filter = $0.element as? MultipleChoiceFilter {
                return (index: $0.index, element: filter)
            } else {
                return nil
            }
        }

        let menus: [PullDownMenu] = multipleChoiceFilters.map { (index, filter) in
            let items: [PullDownMenu.Item] = filter.options.map { option in
                if option.isSeparator {
                    .divider(UUID())
                } else if option.isClear {
                    .clear(UUID())
                } else {
                    .option(
                        PullDownMenu.Option(
                            title: option.title,
                            isOn: Binding {
                                guard let filter = self.effectiveFilters[index] as? MultipleChoiceFilter else { return false }

                                return filter.selectedOptions.contains(option)
                            } set: { isOn in
                                self.updateMultipleChoiceFilter(at: index, option: option, isOn: isOn)
                            }
                        )
                    )
                }
            }

            return PullDownMenu(filter: filter, items: items)
        }

        return menus
    }

    var toggles: [Toggle] {
        let toggleFilters = effectiveFilters.indexed().compactMap {
            if let filter = $0.element as? OptionalToggleFilter {
                return (index: $0.index, element: filter)
            } else {
                return nil
            }
        }

        let toggles = toggleFilters.map { (index, filter) in
            let title = switch filter.identifier {
            case .isFavorite: "Favorites"
            case .isDownloaded: "Downloaded"
            case .isUnwatched: "Unwatched"
            case .hasBookmarks: "Bookmarked"
            default: ""
            }

            let image: SwiftUI.Image = switch filter.identifier {
            case .isFavorite: Image(systemName: "star")
            case .isDownloaded: Image(systemName: "arrow.down.square")
            case .isUnwatched: Image(systemName: "eyeglasses")
            case .hasBookmarks: Image(systemName: "bookmark")
            default: Image(.account)
            }

            let isAffirmative = Binding<Bool>(
                get: {
                    self.effectiveFilters.find(OptionalToggleFilter.self, byID: filter.identifier)?.isOn ?? true
                },
                set: { state in
                    var updatedFilter = filter
                    updatedFilter.isOn = state

                    var updatedFilters = self.effectiveFilters
                    updatedFilters[index] = updatedFilter

                    CATransaction.begin()
                    CATransaction.setCompletionBlock {
                        self.effectiveFilters = updatedFilters
                        self.delegate?.searchFiltersViewController(self, didChangeFilters: self.effectiveFilters, context: .userInput)
                    }
                    CATransaction.commit()
                }
            )

            let isEnabled = Binding<Bool>(
                get: {
                    filter.isOn != nil
                },
                set: { newValue in
                    var filter = filter
                    filter.isOn = newValue ? true : nil
                    self.effectiveFilters[index] = filter

                    self.delegate?.searchFiltersViewController(self, didChangeFilters: self.effectiveFilters, context: .userInput)

                    // If the filters are collapsed, and a property filter is being enabled,
                    // expand the filters so the user can see what they did
                    if newValue && !self.areFiltersVisible {
                        self.areFiltersVisible = true
                    }
                }
            )

            return Toggle(
                title: title,
                image: image,
                filter: filter,
                isEnabled: isEnabled,
                isAffirmative: isAffirmative
            )
        }

        return toggles
    }

    /// Model for multiple choice filters that are presented as pull-down menus
    struct PullDownMenu: Identifiable {
        var id: FilterIdentifier { filter.identifier }

        var filter: MultipleChoiceFilter
        var items: [Item]

        enum Item: Identifiable {
            case clear(UUID)
            case divider(UUID)
            case option(Option)

            var id: String {
                switch self {
                case .clear(let uuid), .divider(let uuid): uuid.uuidString
                case .option(let filterOption): filterOption.title
                }
            }
        }

        struct Option {
            let title: String
            let isOn: Binding<Bool>
        }
    }

    /// Model for true/false/any filters that are presented as checkboxes in the popover and
    /// segmented controls in the main view when enabled
    struct Toggle: Identifiable {
        var id: FilterIdentifier { filter.identifier }
        var title: String
        var image: Image
        var filter: OptionalToggleFilter
        var isEnabled: Binding<Bool>
        var isAffirmative: Binding<Bool>
    }
}
