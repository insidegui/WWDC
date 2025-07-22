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
        _ controller: SearchFiltersViewModel,
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

import SwiftUI

final class SearchFiltersViewController: NSViewController {
    private let viewModel = SearchFiltersViewModel()
    var filters: [FilterType] {
        get { viewModel.filters }
        set { viewModel.filters = newValue }
    }
    var additionalPredicates: [NSPredicate] {
        get { viewModel.additionalPredicates }
        set { viewModel.additionalPredicates = newValue }
    }
    var currentPredicate: NSPredicate? {
        return viewModel.currentPredicate
    }
    var delegate: SearchFiltersViewControllerDelegate? {
        get { viewModel.delegate }
        set { viewModel.delegate = newValue }
    }
    var isSearchFieldFocused: Bool {
        get { viewModel.isSearchFieldFocused }
        set { viewModel.isSearchFieldFocused = newValue }
    }
    func clearAllFilters(reason: FilterChangeReason) {
        viewModel.clearAllFilters(reason: reason)
    }

    override func loadView() {
        view = NSHostingView(
            rootView: SearchFiltersView(viewModel: viewModel)
        )
    }
}

struct SearchFiltersView: View {
    @ObservedObject var viewModel: SearchFiltersViewModel
    @FocusState private var isSearchFieldFocused: Bool

    @State var isStatusesPopoverPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField("Search", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isSearchFieldFocused)
                    .onChange(of: isSearchFieldFocused) { oldValue, newValue in
                        viewModel.isSearchFieldFocused = newValue
                    }
                    .onChange(of: viewModel.isSearchFieldFocused) { oldValue, newValue in
                        isSearchFieldFocused = newValue
                    }

                Toggle(isOn: $viewModel.areFiltersVisible) {
                    Text("Filters")
                }
                .toggleStyle(.button)
            }

            if viewModel.areFiltersVisible {
                // TODO: Dividers need unique identifiers
                ForEach(viewModel.multipleChoiceFilters, id: \.0) { (identifier, filterMenu) in
                    let (filter, menuItems) = filterMenu

                    Menu(filter.title) {

                        //                }
                        //                Picker("Events", selection: $viewModel.selectedEvents) {
                        ForEach(menuItems) { menuItem in
                            switch menuItem {
                            case .divider:
                                Divider()
                            case .clear:
                                Button("Clear") {
//                                    var filter = viewModel.effectiveFilters[offset] as! MultipleChoiceFilter
//
//                                    filter.selectedOptions = []
//
//                                    viewModel.effectiveFilters[offset] = filter
//
//                                    viewModel.delegate?.searchFiltersViewController(viewModel, didChangeFilters: viewModel.effectiveFilters, context: .userInput)
                                }
                            case .option(let menuOption):
                                Toggle(menuOption.title, isOn: menuOption.isOn)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .menuStyle(.automatic)
                    .controlSize(.small)
                }

                let toggleFilters: [(index: Int, element: OptionalToggleFilter)] = viewModel.effectiveFilters.indexed().compactMap {
                    if let filter = $0.element as? OptionalToggleFilter {
                        return (index: $0.index, element: filter)
                    } else {
                        return nil
                    }
                }

                Button {
                    isStatusesPopoverPresented.toggle()
                } label: {
                    Label {
                        Text("Status")
                    } icon: {
                        Image(systemName: "switch.2")
                            .frame(width: 44, height: 44)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .foregroundStyle(toggleFilters.contains { $0.element.isOn != nil } ? AnyShapeStyle(.tint) : AnyShapeStyle(.foreground))
                .popover(isPresented: $isStatusesPopoverPresented) {
                    Grid {
                        ForEach(toggleFilters, id: \.element.identifier) { (offset, filter) in
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

                            GridRow {
                                Toggle("", isOn: .init(get: {
                                    filter.isOn != nil
                                }, set: { newValue in
                                    var filter = filter
                                    filter.isOn = newValue ? true : nil
                                    viewModel.effectiveFilters[offset] = filter
                                }))

                                Text(title)
                                    .gridColumnAlignment(.leading)

                                image
                                    .gridColumnAlignment(.trailing)
                            }
                        }
                    }
                    .padding()
                }
                Grid {
                    ForEach(toggleFilters, id: \.element.identifier) { (offset, filter) in
                        if filter.isOn != nil {
                            GridRow {
                                let title = switch filter.identifier {
                                case .isFavorite: "Favorites"
                                case .isDownloaded: "Downloaded"
                                case .isUnwatched: "Unwatched"
                                case .hasBookmarks: "Bookmarked"
                                default: ""
                                }
                                Text(title)
                                    .gridColumnAlignment(.trailing)

                                Picker(
                                    "",
                                    selection: .init(
                                        get: {
                                            (viewModel.effectiveFilters[offset] as! OptionalToggleFilter).isOn
                                        },
                                        set: { state in
                                            var updatedFilter = filter
                                            updatedFilter.isOn = state

                                            var updatedFilters = viewModel.effectiveFilters
                                            updatedFilters[offset] = updatedFilter

                                            //                                popUp.title = filter.title

                                            viewModel.effectiveFilters = updatedFilters

                                        }
                                    )
                                ) {
                                    //                        Text("Any").tag(nil as Bool?)
                                    Text("Yes").tag(true as Bool?)
                                    Text("No").tag(false as Bool?)
                                }
                                .pickerStyle(.segmented)
                                .gridColumnAlignment(.leading)
                                .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                }


            }
        }
        .padding()
        .background(Material.bar)
    }
}

final class SearchFiltersViewModel: ObservableObject {
    @Published var isSearchFieldFocused = false
    @Published var searchText = "" {
        didSet { searchFieldAction() }
    }
    @Published var areFiltersVisible = false
    @Published var selectedEvents: [String] = []
    var events: [String] {
        filters.compactMap { $0 as? MultipleChoiceFilter }.first { $0.identifier == .event }?.options.map(\.title) ?? []
    }

    struct MenuOption {
        let title: String
        let isOn: Binding<Bool>
    }

    enum MenuItem: Identifiable {
        case clear(UUID)
        case divider(UUID)
        case option(MenuOption)

        var id: String {
            switch self {
            case .clear(let uuid), .divider(let uuid): uuid.uuidString
            case .option(let filterOption): filterOption.title
            }
        }
    }

    var multipleChoiceFilters: [(FilterIdentifier, (MultipleChoiceFilter, [MenuItem]))] {
        let multipleChoiceFilters: [(index: Int, element: MultipleChoiceFilter)] = effectiveFilters.indexed().compactMap {
            if let filter = $0.element as? MultipleChoiceFilter {
                return (index: $0.index, element: filter)
            } else {
                return nil
            }
        }

        let keysAndValues: [(FilterIdentifier, (MultipleChoiceFilter, [MenuItem]))] = multipleChoiceFilters.map { (index, filter) in
            let options = filter.options.map { option in
                if option.isSeparator {
                    MenuItem.divider(UUID())
                } else if option.isClear {
                    MenuItem.clear(UUID())
                } else {
                    MenuItem.option(
                        MenuOption(
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

            return (filter.identifier, (filter, options))
        }

        return keysAndValues
    }

//    static func loadFromStoryboard() -> SearchFiltersViewController {
//        let storyboard = NSStoryboard(name: "Main", bundle: nil)
//
//        // swiftlint:disable:next force_cast
//        return storyboard.instantiateController(withIdentifier: "SearchFiltersViewController") as! SearchFiltersViewController
//    }

//    @IBOutlet var filterContainer: NSView!
//    @IBOutlet weak var eventsPopUp: NSPopUpButton!
//    @IBOutlet weak var focusesPopUp: NSPopUpButton!
//    @IBOutlet weak var tracksPopUp: NSPopUpButton!
//    @IBOutlet weak var favoritesSegmentedControl: NSSegmentedControl!
//    @IBOutlet weak var downloadedSegmentedControl: NSSegmentedControl!
//    @IBOutlet weak var watchedSegmentedControl: NSSegmentedControl!
//    @IBOutlet weak var bookmarksSegmentedControl: NSSegmentedControl!
//    @IBOutlet weak var filterButton: NSButton!
//    @IBOutlet weak var searchField: NSSearchField!
//    @IBOutlet weak var vfxView: NSVisualEffectView!

    var filters: [FilterType] {
        get {
            return effectiveFilters
        }
        set {

            effectiveFilters = newValue

            updateUI()
        }
    }

    @Published var effectiveFilters: [FilterType] = [] {
        didSet {
            delegate?.searchFiltersViewController(self, didChangeFilters: effectiveFilters, context: .userInput)
        }
    }

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

//        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters, context: reason)
    }

    weak var delegate: SearchFiltersViewControllerDelegate?

    @IBAction func eventsPopUpAction(_ sender: Any) {
        guard let filterIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.event }) else { return }

//        updateMultipleChoiceFilter(at: filterIndex, with: eventsPopUp)
    }

    @IBAction func focusesPopUpAction(_ sender: Any) {
        guard let filterIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.focus }) else { return }

//        updateMultipleChoiceFilter(at: filterIndex, with: focusesPopUp)
    }

    @IBAction func tracksPopUpAction(_ sender: Any) {
        guard let filterIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.track }) else { return }

//        updateMultipleChoiceFilter(at: filterIndex, with: tracksPopUp)
    }
    
    @IBAction func favoritesSegmentedControlAction(_ sender: Any) {
        if let favoriteIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.isFavorite }) {
//            updateOptionalToggleFilter(at: favoriteIndex, with: favoritesSegmentedControl.optionalToggleState)
        }
    }
    
    @IBAction func downloadedSegmentedControlAction(_ sender: Any) {
        if let downloadedIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.isDownloaded }) {
//            updateOptionalToggleFilter(at: downloadedIndex, with: downloadedSegmentedControl.optionalToggleState)
        }
    }
    
    @IBAction func watchedSegmentedControlAction(_ sender: Any) {
        if let watchedIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.isUnwatched }) {
//            updateOptionalToggleFilter(at: watchedIndex, with: watchedSegmentedControl.optionalToggleState)
        }
    }
    
    @IBAction func bookmarksSegmentedControlAction(_ sender: Any) {
        if let bookmarksIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.hasBookmarks }) {
//            updateOptionalToggleFilter(at: bookmarksIndex, with: bookmarksSegmentedControl.optionalToggleState)
        }
    }

    func searchFieldAction() {
        guard let textIndex = effectiveFilters.firstIndex(where: { $0.identifier == FilterIdentifier.text }) else { return }

        updateTextualFilter(at: textIndex, with: searchText)
    }

    @IBAction func filterButtonAction(_ sender: Any) {
//        setFilters(hidden: !filterContainer.isHidden)
    }

//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        /// Move background and content from behind the title bar.
//        vfxView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
//
//        setFilters(hidden: true)
//
//        updateUI()
//    }

    func setFilters(hidden: Bool) {
//        filterButton.state = NSControl.StateValue(rawValue: hidden ? 0 : 1)
//        filterContainer.isHidden = hidden
        self.areFiltersVisible = !hidden
    }

    private func updateMultipleChoiceFilter(at filterIndex: Int, option: FilterOption, isOn: Bool) {
        guard var filter = effectiveFilters[filterIndex] as? MultipleChoiceFilter else { return }

        if isOn {
            filter.selectedOptions.append(option)
        } else {
            filter.selectedOptions.removeAll(where: { $0 == option } )
        }

        effectiveFilters[filterIndex] = filter

        delegate?.searchFiltersViewController(self, didChangeFilters: effectiveFilters, context: .userInput)
    }

    private func updateToggleFilter(at filterIndex: Int, with state: Bool) {
        guard var filter = effectiveFilters[filterIndex] as? ToggleFilter else { return }

        filter.isOn = state

        var updatedFilters = effectiveFilters
        updatedFilters[filterIndex] = filter

        effectiveFilters = updatedFilters

//        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters, context: .userInput)
    }
    
    private func updateOptionalToggleFilter(at filterIndex: Int, with state: Bool?) {
        guard var filter = effectiveFilters[filterIndex] as? OptionalToggleFilter else { return }

        filter.isOn = state

        var updatedFilters = effectiveFilters
        updatedFilters[filterIndex] = filter

        effectiveFilters = updatedFilters

//        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters, context: .userInput)
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

//    private func popUpButton(for filter: MultipleChoiceFilter) -> NSPopUpButton? {
//        switch filter.identifier {
//        case .event:
//            return eventsPopUp
//        case .focus:
//            return focusesPopUp
//        case .track:
//            return tracksPopUp
//        default: return nil
//        }
//    }

    /// Updates the UI to match the active filters
    private func updateUI() {
//        guard isViewLoaded else { return }

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
                searchText = filter.value ?? ""
            case let filter as OptionalToggleFilter:
                updateOptionalToggle(for: filter)

            default:
                break
            }
        }
    }

    private func updatePopUp(for filter: MultipleChoiceFilter) {
//        guard let popUp = popUpButton(for: filter) else { return }
//
//        popUp.removeAllItems()
//
//        popUp.addItem(withTitle: filter.title)
//
//        filter.options.forEach { option in
//            guard !option.isSeparator else {
//                popUp.menu?.addItem(.separator())
//                return
//            }
//
//            let item = NSMenuItem(title: option.title, action: nil, keyEquivalent: "")
//            item.representedObject = option
//            item.state = filter.selectedOptions.contains(option) ? .on : .off
//            popUp.menu?.addItem(item)
//        }
    }
    
    private func updateOptionalToggle(for filter: OptionalToggleFilter) {
//        switch filter.identifier {
//        case .isDownloaded:
//            downloadedSegmentedControl.optionalToggleState = filter.isOn
//        case .hasBookmarks:
//            bookmarksSegmentedControl.optionalToggleState = filter.isOn
//        case .isFavorite:
//            favoritesSegmentedControl.optionalToggleState = filter.isOn
//        case .isUnwatched:
//            watchedSegmentedControl.optionalToggleState = filter.isOn
//        default:
//            break
//        }
    }
}
