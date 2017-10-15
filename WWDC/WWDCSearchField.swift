//
//  WWDCSearchField.swift
//  WWDC
//
//  Created by Alessandro Gatti on 16/09/2017.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa

class WWDCSearchField : NSSearchField {

    private var isObservingAccessibilityState : Bool = false

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)

        if (newWindow != nil) {
            // Update the view state from the current accessibility settings too

            accessibilityOptionsChanged(nil)

            startObservingAccessibilityOptionChanges()
        } else {
            stopObservingAccessibilityOptionChanges()
        }
    }

    private func startObservingAccessibilityOptionChanges() {
        if (!isObservingAccessibilityState) {
            NotificationCenter.default.addObserver(self, selector: #selector(self.accessibilityOptionsChanged), name: Notification.Name.NSWorkspaceAccessibilityDisplayOptionsDidChange, object: nil)
            isObservingAccessibilityState = true
        }
    }

    private func stopObservingAccessibilityOptionChanges() {
        if (isObservingAccessibilityState) {
            NotificationCenter.default.removeObserver(self, name: Notification.Name.NSWorkspaceAccessibilityDisplayOptionsDidChange, object: nil)
            isObservingAccessibilityState = false
        }
    }

    @objc private func accessibilityOptionsChanged(_: Notification?) {
        if NSWorkspace.shared().accessibilityDisplayShouldIncreaseContrast {
            self.textColor = NSColor.white
        } else {
            self.textColor = NSColor.controlTextColor
        }

        if let cell = (cell as? NSSearchFieldCell)?.searchButtonCell {
            if let image = cell.image {
                cell.image = tintedImage(image, tint: self.textColor!)
            }
        }
    }

    // Taken from https://stackoverflow.com/a/25952895

    private func tintedImage(_ image: NSImage, tint: NSColor) -> NSImage {
        guard let tinted = image.copy() as? NSImage else { return image }
        tinted.lockFocus()
        tint.set()

        let imageRect = NSRect(origin: NSZeroPoint, size: image.size)
        NSRectFillUsingOperation(imageRect, .sourceAtop)

        tinted.unlockFocus()
        return tinted
    }
}
