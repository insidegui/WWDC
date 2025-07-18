//
//  RelatedSessionsViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 13/05/18.
//  Copyright © 2018 Guilherme Rambo. All rights reserved.
//

import SwiftUI
import Combine

protocol RelatedSessionsDelegate: AnyObject {
    func relatedSessions(_ controller: RelatedSessionsViewModel, didSelectSession viewModel: SessionViewModel)
}

struct RelatedSessionsView: View {
    var sessions: [SessionViewModel]

    struct Metrics {
        static let height: CGFloat = 96 + scrollerOffset
        static let itemHeight: CGFloat = 64
        static let scrollerOffset: CGFloat = 15
        static let scrollViewHeight: CGFloat = itemHeight + scrollerOffset
        static let itemWidth: CGFloat = 360
        static let itemSpacing: CGFloat = 10
    }

    var body: some View {
//        if viewModel.isHidden {
//        }
        VStack(alignment: .leading, spacing: 0) {
            Text("Related Sessions")
                .font(Font(NSFont.wwdcRoundedSystemFont(ofSize: 20, weight: .semibold) as CTFont))
                .foregroundColor(Color(.secondaryText))
                .lineLimit(1)
                .truncationMode(.tail)

            GeometryReader { geometry in
                ScrollViewReader { scrollView in
                    ScrollView(.horizontal, showsIndicators: true) {
                        SetScrollerStyle(.overlay)

                        HStack(spacing: Metrics.itemSpacing) {
                            ForEach(sessions, id: \.identifier) { session in
                                sessionButton(for: session, in: scrollView)
                            }
                        }
                        .padding(.horizontal, 0)
                        .padding(.bottom, Metrics.scrollerOffset)

                    }
                    .frame(maxWidth: geometry.size.width, alignment: .leading)
                    //                    .containerRelativeFrame(.horizontal, alignment: .leading)
                    .border(.blue)
                    .scrollIndicatorsFlash(trigger: sessions.map(\.identifier))
                    .onChange(of: sessions.map(\.identifier)) {
                        scrollView.scrollTo(sessions.first?.identifier, anchor: .leading)
                    }
                }
            }
            .frame(height: Metrics.scrollViewHeight)
            .background(Color(.darkWindowBackground))
        }
        .frame(height: sessions.isEmpty? 0 : Metrics.height)
        .opacity(sessions.isEmpty ? 0 : 1)
    }

    func sessionButton(for session: SessionViewModel, in scrollView: ScrollViewProxy) -> some View {
        Button {
            viewModel.selectSession(session)
        } label: {
            SessionCellView(
                cellViewModel: SessionCellViewModel(session: session),
                style: .rounded
            )
            .frame(width: Metrics.itemWidth, height: Metrics.itemHeight)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RelatedSessionsView(viewModel: RelatedSessionsViewModel(sessions: [.preview]))
}
