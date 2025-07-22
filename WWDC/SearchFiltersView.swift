//
//  SearchFiltersView.swift
//  WWDC
//
//  Created by Allen Humphreys on 9/2/25.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

struct SearchFiltersView: View {
    @ObservedObject var viewModel: SearchFiltersViewModel

    @FocusState private var isSearchFieldFocused: Bool
    @State private var isConfigurationPopoverPresented = false

    /// Officially owned by Preferences, which is using #function to create the key 🥴
    @AppStorage("searchInBookmarks") private var searchInBookmarks = false
    @AppStorage("searchInTranscripts") private var searchInTranscripts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                SearchField(text: $viewModel.searchText) {
                    viewModel.performTextSearch()
                }
                .focused($isSearchFieldFocused)
                .synchronize($viewModel.isSearchFieldFocused, $isSearchFieldFocused)

                configurationButton

                Toggle(isOn: $viewModel.areFiltersVisible) {
                    Label {
                        Text("Filters")
                    } icon: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 9)
                    }
                }
                .toggleStyle(.button)
            }

            VStack(alignment: .leading, spacing: 6) {
                dropDowns

                sessionStateFilters
            }
            .disabled(!viewModel.areFiltersVisible)
            .frame(height: viewModel.areFiltersVisible ? nil : 0)
            .clipped()
        }
        .padding()
        .background(Material.bar)
        .background {
            WindowReader { window in
                viewModel.isInWindow = window != nil
            }
        }
    }

    @ViewBuilder
    private var dropDowns: some View {
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
                Text(menu.filter.title)
                    .frame(maxWidth: .infinity)
            }
            .menuStyle(.automatic)
            .controlSize(.regular)
        }
    }

    /// Filters that represent session states, like favorite, downloaded, unwatched, contains bookmarks
    @ViewBuilder
    private var sessionStateFilters: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(viewModel.toggles) { toggle in
                if toggle.isEnabled.wrappedValue {

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

                    Picker(toggle.title, selection: toggle.isAffirmative) {
                        Text(affirmativeTitle).frame(maxWidth: .infinity).tag(true)
                        Text(negativeTitle).frame(maxWidth: .infinity).tag(false)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .gridColumnAlignment(.leading)
                }
            }
        }
    }

    private var configurationButton: some View {
        Button {
            isConfigurationPopoverPresented.toggle()
        } label: {
            Label {
                Text("Search Options")
            } icon: {
                Image(systemName: "switch.2")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 16)
                    .padding(2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .foregroundStyle(viewModel.toggles.contains { $0.isEnabled.wrappedValue } ? AnyShapeStyle(.tint) : AnyShapeStyle(.foreground))
        .popover(isPresented: $isConfigurationPopoverPresented) {
            configurationPopover
        }
        .transition(.opacity.animation(.linear))
    }

    private var configurationPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Search in:")
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let currentPredicate = viewModel.currentPredicate {
                    Image(systemName: "info")
                        .symbolVariant(.circle)
                        .contentShape(.circle)
                        .help(currentPredicate.predicateFormat)
                }
            }

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
}

private struct WindowReader: NSViewRepresentable {
    var onChange: (NSWindow?) -> Void = { _ in }

    func makeNSView(context: Context) -> WindowReaderView {
        let v = WindowReaderView()
        v.onChange = onChange
        return v
    }

    func updateNSView(_ nsView: WindowReaderView, context: Context) {
        // no-op
    }

    final class WindowReaderView: NSView {
        var onChange: (NSWindow?) -> Void = { _ in }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onChange(window)
        }
    }
}

struct SearchFiltersViewPreviewWrapper: View {
    @StateObject var viewModel = SearchFiltersViewModel()
    @StateObject var box = Box()

    class Box: ObservableObject {
        var coordinator: SearchCoordinator?
    }

    var body: some View {
        SearchFiltersView(viewModel: viewModel)
            .onReceive((NSApplication.shared.delegate as! AppDelegate).$coordinator.compacted().prefix(1)) { // swiftlint:disable:this force_cast
                guard box.coordinator == nil else { return }
                box.coordinator = SearchCoordinator(
                    $0.storage,
                    scheduleSearchController: SearchFiltersViewModel(),
                    videosSearchController: viewModel,
                )
            }
    }
}

#Preview {
    SearchFiltersViewPreviewWrapper()
        .frame(width: 400, height: 300, alignment: .top)
        .background {
            if
                let bundle = Bundle(path: "/System/Library/PrivateFrameworks/PrintingPrivate.framework/Versions/A/Plugins/PrintingUI.bundle"),
                (try? bundle.loadAndReturnError()) != nil,
                let clarus = bundle.image(forResource: "Clarus")
            {
                Image(nsImage: clarus)
                    .renderingMode(.template)
                    .foregroundStyle(.white)
            }
        }
}
