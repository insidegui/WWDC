//
//  SearchFiltersViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 25/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
//import ConfCore

struct SizeReader: View {
    var onChange: (CGSize) -> Void
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    report(Geometry(proxy))
                }
                .onChange(of: Geometry(proxy)) { _, new in report(new) }
        }
    }

    func report(_ geometry: Geometry) {
        var size = geometry.size
        size.height += geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom
        size.width += geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing

        onChange(size)
    }

    struct Geometry: Equatable {
        var size: CGSize
        var safeAreaInsets: EdgeInsets

        init(_ proxy: GeometryProxy) {
            self.size = proxy.size
            self.safeAreaInsets = proxy.safeAreaInsets
        }
    }
}

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

import SwiftUI

final class MyNSHostingView<Content>: NSHostingView<Content> where Content: View {
    override var frame: NSRect {
        didSet {
            print("didSet frame: \(frame)")
        }
    }
}

final class SearchFiltersViewController: NSHostingController<SearchFiltersView> {
    let viewModel = SearchFiltersViewModel()

    init() {
        super.init(
            rootView: SearchFiltersView(viewModel: viewModel) { size in
                //                self?.updateHeight(to: size.height)
            }
        )

        view.wantsLayer = true
        view.layer?.borderWidth = 0.5
        view.layer?.borderColor = NSColor.red.cgColor
    }
    
    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var heightConstraint: NSLayoutConstraint!

    override func loadView() {
        let view = MyNSHostingView(
            rootView: self.rootView
        )
////        view.sizingOptions = []
//        self.view = view
////        self.heightConstraint = view.heightAnchor.constraint(equalToConstant: 0)
////        self.heightConstraint.isActive = true
//        view.wantsLayer = true
//        view.layer?.borderWidth = 0.5
//        view.layer?.borderColor = NSColor.red.cgColor
//        view.clipsToBounds = true
    }

    func updateHeight(to newHeight: CGFloat) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .linear)
            heightConstraint.animator().constant = newHeight
            // If needed to animate siblings’ layout too:
            view.superview?.layoutSubtreeIfNeeded()
        }
    }

//    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }

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

    var searchText: String {
        get { viewModel.searchText }
        set { viewModel.searchText = newValue }
    }

//    override func loadView() {
//        view = NSHostingView(
//            rootView: SearchFiltersView(viewModel: viewModel)
//        )
//    }
}

struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search"

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(frame: .zero)
        searchField.delegate = context.coordinator
        updateNSView(searchField, context: context)
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField

        init(_ parent: SearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            let value = (obj.object as? NSSearchField)?.stringValue ?? ""
            if parent.text != value {
                DispatchQueue.main.async { [parent] in
                    parent.text = value
                }
            }
        }
    }

}

struct SearchFiltersView: View {
    @ObservedObject var viewModel: SearchFiltersViewModel
    var onSizeChange: (CGSize) -> Void = { _ in }
    @FocusState private var isSearchFieldFocused: Bool

    @AppStorage("searchInBookmarks") var searchInBookmarks = false
    @AppStorage("searchInTranscripts") var searchInTranscripts = false

    @State var isStatusesPopoverPresented = false

    var body: some View {
        visibleBody(areFiltersVisible: $viewModel.areFiltersVisible)
    }

    @ViewBuilder
    func visibleBody(areFiltersVisible: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                SearchField(text: $viewModel.searchText)
                    .focused($isSearchFieldFocused)
                    .onChange(of: isSearchFieldFocused) { oldValue, newValue in
                        viewModel.isSearchFieldFocused = newValue
                    }
                    .onChange(of: viewModel.isSearchFieldFocused) { oldValue, newValue in
                        isSearchFieldFocused = newValue
                    }
                    .onAppear {
                        // TODO: Classically, not reliable
                        viewModel.isSearchFieldVisible = true
                    }
                    .onDisappear {
                        viewModel.isSearchFieldVisible = false
                    }

                configurationButton
                //                }

                //                    Toggle(isOn: $viewModel.areFiltersVisible) {
                //                        Text("Filters")
                //                    }
                //                    .toggleStyle(.button)
                Button("Filters") {
                    areFiltersVisible.wrappedValue.toggle()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                dropDowns

                sessionStateFilters
            }
            .disabled(!areFiltersVisible.wrappedValue)
            .frame(height: areFiltersVisible.wrappedValue ? nil : 0)
            .clipped()
        }
        .padding()
        .background(Material.bar)
        .background(SizeReader(onChange: self.onSizeChange))
        //        .animation(.linear(duration: 0.22), value: viewModel.areFiltersVisible)
    }

    @ViewBuilder
    var dropDowns: some View {
        ForEach(viewModel.pullDownMenus) { menu in
            Menu {
                ForEach(menu.items) { menuItem in
                    switch menuItem {
                    case .divider:
                        Divider()
                    case .clear:
                        Button("Clear") {
                            viewModel.clearMultipleChoiceFilter(id: menu.id)
                        }
                    case .option(let menuOption):
                        Toggle(menuOption.title, isOn: menuOption.isOn)
                    }
                }
            } label: {
                Text(menu.filter.title/* + String(repeating: "\u{00a0}", count: 1000)*/)
                    .frame(maxWidth: .infinity)
                    .border(.red)
            }
            .menuStyle(.automatic)
            .controlSize(.regular)
            .controlGroupStyle(.menu)
        }
    }

    /// Filters that represent session states, like favorite, downloaded, unwatched, contains bookmarks
    @ViewBuilder
    var sessionStateFilters: some View {
        VStack(alignment: .leading, spacing: 6) {
//        Grid {
            ForEach(viewModel.toggles) { toggle in
                if toggle.isEnabled.wrappedValue {
//                    GridRow {
//                        Text(toggle.title)
//                            .gridColumnAlignment(.trailing)

                        let affirmativeTitle = switch toggle.filter.identifier {
                        case .isFavorite: "Favorite"
                        case .isDownloaded: "Downloaded"
                        case .isUnwatched: "Watched"
                        case .hasBookmarks: "Has bookmarks"
                        default: ""
                        }

                        let negativeTitle = switch toggle.filter.identifier {
                        case .isFavorite: "Not a favorite"
                        case .isDownloaded: "Not downloaded"
                        case .isUnwatched: "Unwatched"
                        case .hasBookmarks: "No bookmarks"
                        default: ""
                        }

                        Picker("", selection: toggle.isAffirmative) {
                            Text(affirmativeTitle/*"Yes"*/).frame(maxWidth: .infinity).tag(true)
                            Text(negativeTitle/*"No"*/).frame(maxWidth: .infinity).tag(false)
                        }
                        .pickerStyle(.segmented)
                        .gridColumnAlignment(.leading)
                        .padding(.leading, -8) // nobody's perfect
//                        .fixedSize(horizontal: true, vertical: false)
//                    }
                }
            }
        }
    }

    var configurationButton: some View {
        Button {
            isStatusesPopoverPresented.toggle()
        } label: {
            Label {
                Text("Status")
            } icon: {
                Image(systemName: "switch.2")
                    .padding(4)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .foregroundStyle(viewModel.toggles.contains { $0.isEnabled.wrappedValue } ? AnyShapeStyle(.tint) : AnyShapeStyle(.foreground))
        .border(.red)
        .popover(isPresented: $isStatusesPopoverPresented) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Search in:")

                Toggle("Bookmarks", isOn: $searchInBookmarks)
                Toggle("Transcripts", isOn: $searchInTranscripts)
                    .padding(.bottom, 8)

                Text("Filter by:")

                Grid(alignment: .leading) {
                    ForEach(viewModel.toggles) { toggle in
                        GridRow {
                            Toggle(toggle.title, isOn: toggle.isEnabled)

                            toggle.image
                                .padding(.leading, 8)
                                .gridColumnAlignment(.trailing)
                        }
                    }
                }
            }
            .padding()
        }
        .transition(.opacity.animation(.linear))
    }
}

final class SearchFiltersViewModel: ObservableObject {
    @Published var isSearchFieldFocused = false
    @Published var searchText = "" {
        didSet { searchFieldAction() }
    }
    @Published var areFiltersVisible = false

    var isSearchFieldVisible = false

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

    struct Toggle: Identifiable {
        var id: FilterIdentifier { filter.identifier }
        var title: String
        var image: Image
        var filter: OptionalToggleFilter
        var isEnabled: Binding<Bool>
        var isAffirmative: Binding<Bool>
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

                    self.effectiveFilters = updatedFilters
                }
            )

            let isEnabled = Binding<Bool>(
                get: {
                    filter.isOn != nil
                }, set: { newValue in
                    var filter = filter
                    filter.isOn = newValue ? true : nil
                    self.effectiveFilters[index] = filter
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

        delegate?.searchFiltersViewController(self, didChangeFilters: updatedFilters, context: reason)
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

    func clearMultipleChoiceFilter(id: FilterIdentifier) {
        guard var (index, filter) = effectiveFilters.findIndexed(MultipleChoiceFilter.self, byID: id) else { return }

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
