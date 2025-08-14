//
//  SelectAnySegmentControl.swift
//  WWDC
//
//  Created by luca on 02.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import SwiftUI

@available(macOS 26.0, *)
struct SelectAnySegmentControl<Item: PickAnyPickerItem>: NSViewRepresentable {
    let options: [Item]
    @Binding var selectedItems: [Item]
    init(options: [Item], selectedItems: Binding<[Item]>) {
        self.options = options
        _selectedItems = selectedItems
    }

    private func onSelectionChange(_ control: NSSegmentedControl) {
        guard control.segmentCount == options.count else {
            return
        }

        withTransaction(\.changeReason, .selection) {
            withAnimation {
                selectedItems = options.indices.map { idx in
                    var item = options[idx]
                    item.isSelected = control.isSelected(forSegment: idx)
                    return item
                }.filter { $0.isSelected }
            }
        }
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: options.compactMap(\.label).map(String.init(_:)), trackingMode: .selectAny, target: context.coordinator, action: #selector(Coordinator.selectionDidChange))
        control.segmentStyle = .roundRect
        context.coordinator.onSelectionChange = onSelectionChange(_:)
        control.borderShape = .capsule
        control.segmentDistribution = .fillProportionally
        return control
    }

    func updateNSView(_ nsView: NSSegmentedControl, context: Context) {
        guard context.transaction.changeReason == .reset else {
            return
        }

        for idx in 0 ..< nsView.segmentCount {
            nsView.setSelected(false, forSegment: idx)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var shouldReceiveUpdates = true
        var onSelectionChange: ((_ control: NSSegmentedControl) -> Void)?
        @objc func selectionDidChange(_ control: NSSegmentedControl) {
            onSelectionChange?(control)
        }
    }
}

#Preview {
    @Previewable @State var selectedItems: [ContentFilterOption] = []
    if #available(macOS 26.0, *) {
        PickAnyPicker(options: [
            "Favorites",
            "Downloaded",
            "UnWatched",
            "Bookmarks"
        ], selectedItems: $selectedItems)
    }
}
