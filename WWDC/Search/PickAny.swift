//
//  PickAny.swift
//  WWDC
//
//  Created by luca on 02.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

protocol PickAnyPickerItem: Identifiable, Equatable {
    associatedtype Label: StringProtocol
    var label: Label? { get }
    var isSelected: Bool { get set }
}

enum PickAnyPickerChangeReason {
    case selection
    case reset
}

extension Transaction {
    @Entry var changeReason: PickAnyPickerChangeReason?
}

@available(macOS 26.0, *)
struct PickAnyPicker<Item: PickAnyPickerItem>: View {
    private let showClearButton: Bool
    private let options: [Item]
    @Binding var selectedItems: [Item]
    @State private var segmentSize: CGSize?
    @Binding private var controlSize: CGSize?
    init(showClearButton: Bool = true, options: [Item], selectedItems: Binding<[Item]>, controlSize: Binding<CGSize?>? = nil) {
        self.showClearButton = showClearButton
        self.options = options
        _selectedItems = selectedItems
        _controlSize = controlSize ?? .constant(nil)
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 5) {
                if showClearButton && !selectedItems.isEmpty {
                    FilterResetButton(count: selectedItems.count) {
                        withAnimation {
                            withTransaction(\.changeReason, .reset) {
                                selectedItems.removeAll()
                            }
                        }
                    }.frame(height: segmentSize?.height)
                }
                SelectAnySegmentControl(options: options, selectedItems: $selectedItems)
                    .clipShape(RoundedRectangle(cornerRadius: segmentSize.flatMap { $0.height * 0.5 } ?? 0))
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { newValue in
                        segmentSize = newValue
                        controlSize = newValue
                    }
            }
            .padding(.bottom, 10)
        }
//        .frame(minWidth: segmentSize?.width)
        .scrollDisabled(selectedItems.isEmpty)
    }
}

@available(macOS 26.0, *)
struct PickAnyMenuPicker<Item: PickAnyPickerItem>: View {
    let title: String
    let showClearButton: Bool
    @State var options: [Item]
    @Binding var selectedItems: [Item]
    let ignoreUpdates = State(initialValue: false) // no need to update ui
    init(title: String, options: [Item], showClearButton: Bool = true, selectedItems: Binding<[Item]>) {
        self.title = title
        self.showClearButton = showClearButton
        self.options = options
        _selectedItems = selectedItems
    }

    var body: some View {
        #if DEBUG
        // swiftlint:disable:next redundant_discardable_let
        let _ = Self._printChanges()
        #endif
        HStack(spacing: 5) {
            if showClearButton && !selectedItems.isEmpty {
                FilterResetButton(count: selectedItems.count) {
                    withAnimation {
                        selectedItems.removeAll()
                    }
                }
            }
            Menu {
                ForEach($options) { option in
                    if let label = option.wrappedValue.label {
                        Toggle(label, isOn: option.isSelected)
                    } else {
                        Divider()
                    }
                }
            } label: {
                titleView
                    .contentShape(Rectangle())
            }
            .buttonStyle(.capsuleButton(tint: selectedItems.isEmpty ? nil : .accentColor.opacity(0.5), trailingIcon: Image(systemName: "chevron.up.chevron.down"), glassy: true))
        }
        .frame(maxWidth: .infinity)
        .onChange(of: options) { oldValue, newValue in
            guard newValue != oldValue, !ignoreUpdates.wrappedValue else {
                return
            }
            withAnimation {
                selectedItems = newValue.filter { $0.isSelected == true }.compactMap { $0 }
            }
        }
        .onChange(of: selectedItems) { oldValue, newValue in
            guard newValue != oldValue else {
                return
            }
            ignoreUpdates.wrappedValue = true
            for idx in options.indices {
                options[idx].isSelected = newValue.contains(options[idx])
            }
            ignoreUpdates.wrappedValue = false
        }
    }

    private var titleView: some View {
        Group {
            if selectedItems.isEmpty {
                Text(title)
                    .transition(.blurReplace)
            } else {
                Text(selectedItems.compactMap(\.label).joined(separator: ", "))
                    .transition(.blurReplace)
            }
        }
        .foregroundStyle(.primary)
        .animation(.default, value: selectedItems)
    }
}
