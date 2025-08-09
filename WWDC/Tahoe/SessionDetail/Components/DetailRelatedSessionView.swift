//
//  DetailRelatedSessionView.swift
//  WWDC
//
//  Created by luca on 05.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine
import SwiftUI

@available(macOS 26.0, *)
extension NewSessionDetailView {
    struct RelatedSessionsView: View {
        @Binding var sessions: [SessionViewModel]
        @Environment(\.coordinator) private var coordinator
        let scrollPosition: Binding<ScrollPosition>

        enum Metrics {
            static let height: CGFloat = 96 + scrollerOffset
            static let itemHeight: CGFloat = 64
            static let scrollerOffset: CGFloat = 15
            static let scrollViewHeight: CGFloat = itemHeight + scrollerOffset
            static let itemWidth: CGFloat = 360
            static let itemSpacing: CGFloat = 10
        }

        let columns = [
            GridItem(.flexible(minimum: Metrics.itemWidth, maximum: .infinity), spacing: Metrics.itemSpacing),
            GridItem(.flexible(minimum: Metrics.itemWidth, maximum: .infinity), spacing: Metrics.itemSpacing)
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                Text("Related Sessions")
                    .font(Font(NSFont.wwdcRoundedSystemFont(ofSize: 20, weight: .semibold) as CTFont))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal)

                LazyVGrid(columns: columns) {
                    ForEach(sessions, id: \.identifier) { session in
                        Button {
//                            sessions.removeAll() // reload
                            scrollPosition.wrappedValue.scrollTo(edge: .top)
                            coordinator?.selectSessionOnAppropriateTab(with: session)
                        } label: {
                            SessionItemViewForDetail(session: session)
                        }
                        .buttonStyle(SessionItemButtonStyle(style: .rounded))
                        .id(session.identifier)
                    }
                }
                .padding([.bottom, .horizontal])
            }
            .opacity(sessions.isEmpty ? 0 : 1)
        }
    }
}
