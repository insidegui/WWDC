//
//  ShrinkWrapTextLayout.swift
//  WWDC
//
//  Created by Allen Humphreys on 7/24/25.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

/// A custom SwiftUI layout that encourages text wrapping during any width resizing.
///
/// ## Purpose
/// By default, `Text` views report their ideal size as the width needed to display all text
/// on a single line. This causes problems during any container resizing (split views, window
/// resizing, etc.), as the text won't wrap naturally when the available width decreases.
///
/// `ShrinkWrapTextLayout` solves this by slightly reducing the proposed width given to the text,
/// which convinces the text to wrap at appropriate points during resize operations.
///
/// ## How It Works
/// The layout subtracts a small padding value (default: 1 point) from the proposed width before
/// passing it to the text view. This makes the text think it has slightly less space than actually
/// available, encouraging it to wrap earlier and providing better resize behavior.
///
/// ## Usage Example
/// ```swift
/// ShrinkWrapTextLayout {
///     Text("Long title that should wrap during container resizing")
///         .font(.title)
///         .lineLimit(2)
/// }
/// ```
///
/// This is particularly useful for:
/// - Titles and headers in resizable containers
/// - Footer text that needs to remain readable at various widths
/// - Any text in split views or resizable windows
///
///
/// While I (Allen) had the idea for shaving off the proposed width to encourage wrapping,
/// ChatGPT wrote the initial implementation of this layout.
struct ShrinkWrapTextLayout: Layout {
    /// Amount to reduce the proposed width by (in points) to encourage text wrapping
    var padding: CGFloat = 1

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let text = subviews.first else { return .zero }

        let proposedWidth = proposal.width

        // Calculate the width we'll actually give to the text view
        let constrainedWidth: CGFloat
        switch proposedWidth {
        case nil:
            // Unspecified width proposal - use minimal width to force wrapping
            // This prevents the text from reporting its ideal single-line width
            constrainedWidth = 10
        case 0:
            // Zero proposal - respect it exactly (minimum size query)
            constrainedWidth = 0
        default:
            // Normal case: subtract padding from proposed width to encourage wrapping
            // Ensure minimum width of 10 to prevent layout issues
            constrainedWidth = max((proposedWidth ?? 0) - padding, 10)
        }

        return text.sizeThatFits(ProposedViewSize(width: constrainedWidth, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let text = subviews.first else { return }

        // Use proposed width if available, otherwise use bounds width
        let proposedWidth = proposal.width ?? bounds.width
        let constrainedWidth = max(proposedWidth - padding, 10)

        // Get the actual size the text will occupy with our constrained width
        let size = text.sizeThatFits(ProposedViewSize(width: constrainedWidth, height: bounds.height))
        
        // Vertically center the text within the available bounds
        let origin = CGPoint(x: bounds.minX, y: bounds.minY + (bounds.height - size.height) / 2)

        // Place the text with our constrained width
        text.place(at: origin, proposal: ProposedViewSize(width: constrainedWidth, height: bounds.height))
    }
}
