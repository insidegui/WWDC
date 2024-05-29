import SwiftUI

public extension View {
    @ViewBuilder
    func numericContentTransition(value: Double? = nil, countsDown: Bool = false) -> some View {
        if let value, #available(macOS 14.0, iOS 17.0, *) {
            contentTransition(.numericText(value: value))
        } else if #available(macOS 13.0, iOS 16.0, *) {
            contentTransition(.numericText(countsDown: countsDown))
        } else {
            self
        }
    }
}
