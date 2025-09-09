//
//  SearchField.swift
//  WWDC
//
//  Created by Allen Humphreys on 9/2/25.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

/// Basic SwiftUI wrapper for NSSearchField
struct SearchField: NSViewRepresentable {
    /// The text being edited, updated live as the user types
    @Binding var text: String
    var placeholder: String = "Search"
    /// Called when the underlying NSSearchField sends its action. NSSearchField automatically delays
    /// the search action until the user pauses typing.
    var onSearch: @MainActor () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(frame: .zero)
        searchField.delegate = context.coordinator
        searchField.target = context.coordinator
        searchField.action = #selector(Coordinator.searchFieldAction(_:))
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

        /// This is delayed via NSSearchField behavior
        @objc
        func searchFieldAction(_ sender: NSSearchField) {
            DispatchQueue.main.async { [parent] in
                // controlTextDidChange guarantees immediate text entry updates are relayed to SwiftUI state,
                // but when the clear button is clicked, the action is sent before that state update happens.
                //
                // Additionally, this is just prudent to ensure state is in sync before sending the search action.
                if parent.text != sender.stringValue {
                    parent.text = sender.stringValue
                }

                parent.onSearch()
            }
        }

        /// This is immediately called as the user types
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
