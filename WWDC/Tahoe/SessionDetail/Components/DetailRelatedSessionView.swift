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
        @State private var sessions: [SessionItemViewModel] = []
        @Environment(\.coordinator) private var coordinator
        @Environment(SessionItemViewModel.self) var currentSession

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
                    ForEach(sessions) { session in
                        Button {
                            coordinator?.selectSessionOnAppropriateTab(with: session.session)
                        } label: {
                            SessionItemView(horizontalPadding: 5)
                                .environment(session)
                        }
                        .buttonStyle(SessionItemButtonStyle(style: .rounded))
                        .id(session.id)
                    }
                }
                .padding([.bottom, .horizontal])
            }
            .opacity(sessions.isEmpty ? 0 : 1)
            .onReceive(sessionsUpdate) {
                if $0.map(\.id) != sessions.map(\.id) {
                    sessions = $0
                }
            }
        }

        private var sessionsUpdate: AnyPublisher<[SessionItemViewModel], Never> {
            currentSession.session.rxRelatedSessions
                .replaceErrorWithEmpty()
                .map { $0.compactMap { $0.session }.compactMap(SessionViewModel.init(session:)) }
                .removeDuplicates(by: { $0.map(\.identifier) == $1.map(\.identifier) })
                .map { $0.map(SessionItemViewModel.init(session:)) }
                .eraseToAnyPublisher()
        }
    }
}
