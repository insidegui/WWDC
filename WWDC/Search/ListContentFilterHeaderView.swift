//
//  ListContentFilterHeaderView.swift
//  WWDC
//
//  Created by luca on 02.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//
import SwiftUI

@available(macOS 26.0, *)
struct ListContentFilterHeaderView: View {
    @State private var isExpanded: Bool = false
    @State private var controlSize: CGSize? = CGSize(width: 0, height: 20)
    @Environment(NewGlobalSearchCoordinator.self) var coordinator

    @State private var selectedEventOptions = [ContentFilterOption]()
    @State private var selectedFocusOptions = [ContentFilterOption]()
    @State private var selectedTrackOptions = [ContentFilterOption]()
    @State private var selectedToggleOptions = [OptionalToggleFilter]()

    let stateKeyPath: ReferenceWritableKeyPath<NewGlobalSearchCoordinator, GlobalSearchTabState>
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if isExpanded, let filter = coordinator[keyPath: stateKeyPath].eventFilter {
                PickAnyMenuPicker(title: filter.emptyTitle, options: filter.pickerOptions, selectedItems: $selectedEventOptions)
                    .frame(height: controlSize?.height)
            }
            if isExpanded, let filter = coordinator[keyPath: stateKeyPath].focusFilter {
                PickAnyMenuPicker(title: filter.emptyTitle, options: filter.pickerOptions, selectedItems: $selectedFocusOptions)
                    .frame(height: controlSize?.height)
            }
            if isExpanded, let filter = coordinator[keyPath: stateKeyPath].trackFilter {
                PickAnyMenuPicker(title: filter.emptyTitle, options: filter.pickerOptions, selectedItems: $selectedTrackOptions)
                    .frame(height: controlSize?.height)
            }

            if isExpanded, let toggleFilters = coordinator[keyPath: stateKeyPath].bottomFilters {
                PickAnyPicker(options: toggleFilters, selectedItems: $selectedToggleOptions, controlSize: $controlSize)
            }
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity)
        .onChange(of: selectedEventOptions) { oldValue, newValue in
            guard newValue != oldValue else { return }
            updateEffectiveFilters()
        }
        .onChange(of: selectedFocusOptions) { oldValue, newValue in
            guard newValue != oldValue else { return }
            updateEffectiveFilters()
        }
        .onChange(of: selectedTrackOptions) { oldValue, newValue in
            guard newValue != oldValue else { return }
            updateEffectiveFilters()
        }
        .onChange(of: selectedToggleOptions) { oldValue, newValue in
            guard newValue != oldValue else { return }
            updateEffectiveFilters()
        }
        .task {
            withAnimation {
                isExpanded = true
            }
        }
        .onDisappear {
            withAnimation {
                isExpanded = false
            }
        }
    }

    private func updateEffectiveFilters() {
        var currentFilters = coordinator[keyPath: stateKeyPath].effectiveFilters
        for idx in currentFilters.indices {
            if currentFilters[idx].identifier == .event, var eventFilter = currentFilters[idx] as? MultipleChoiceFilter {
                eventFilter.selectedOptions = eventFilter.options.filter({ selectedEventOptions.compactMap(\.label).contains($0.title) })
                currentFilters[idx] = eventFilter
            }
            if currentFilters[idx].identifier == .focus, var eventFilter = currentFilters[idx] as? MultipleChoiceFilter {
                eventFilter.selectedOptions = eventFilter.options.filter({ selectedFocusOptions.compactMap(\.label).contains($0.title) })
                currentFilters[idx] = eventFilter
            }
            if currentFilters[idx].identifier == .track, var eventFilter = currentFilters[idx] as? MultipleChoiceFilter {
                eventFilter.selectedOptions = eventFilter.options.filter({ selectedTrackOptions.compactMap(\.label).contains($0.title) })
                currentFilters[idx] = eventFilter
            }
            if [.isFavorite, .isDownloaded, .isUnwatched, .hasBookmarks].contains(currentFilters[idx].identifier), var eventFilter = currentFilters[idx] as? OptionalToggleFilter {
                eventFilter.isOn = selectedToggleOptions.first(where: { $0.identifier == eventFilter.identifier })?.isOn
                currentFilters[idx] = eventFilter
            }
        }

        coordinator[keyPath: stateKeyPath].effectiveFilters = currentFilters
        coordinator[keyPath: stateKeyPath].updatePredicate(.userInput)
    }
}

private extension GlobalSearchTabState {
    var eventFilter: MultipleChoiceFilter? {
        effectiveFilters.first(where: { $0.identifier == .event }) as? MultipleChoiceFilter
    }

    var focusFilter: MultipleChoiceFilter? {
        effectiveFilters.first(where: { $0.identifier == .focus }) as? MultipleChoiceFilter
    }

    var trackFilter: MultipleChoiceFilter? {
        effectiveFilters.first(where: { $0.identifier == .track }) as? MultipleChoiceFilter
    }

    var bottomFilters: [OptionalToggleFilter]? {
        let filters = effectiveFilters.filter {
            [.isFavorite, .isDownloaded, .isUnwatched, .hasBookmarks].contains($0.identifier)
        }.compactMap {
            $0 as? OptionalToggleFilter
        }
        return filters.isEmpty ? nil : filters
    }
}

extension OptionalToggleFilter: PickAnyPickerItem {
    static func == (lhs: OptionalToggleFilter, rhs: OptionalToggleFilter) -> Bool {
        lhs.identifier == rhs.identifier && lhs.isOn == rhs.isOn
    }

    var label: String? {
        switch identifier {
        case .isFavorite: return "Favorites"
        case .isDownloaded: return "Downloaded"
        case .isUnwatched: return "Unwatched"
        case .hasBookmarks: return "Bookmarks"
        default:
            return nil
        }
    }

    var isSelected: Bool {
        get { isOn == true }
        set {
            isOn = newValue
        }
    }

    var id: FilterIdentifier {
        identifier
    }
}

private extension MultipleChoiceFilter {
    var pickerOptions: [ContentFilterOption] {
        options.filter { !$0.isClear }.map {
            if $0.isSeparator {
                return .divider
            } else {
                return "\($0.title)"
            }
        }
    }
}
