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

final class RelatedSessionsViewModel: ObservableObject {
    @Published var sessions: [SessionViewModel] = []
    @Published var isHidden: Bool = true

    weak var delegate: RelatedSessionsDelegate?

    func selectSession(_ viewModel: SessionViewModel) {
        delegate?.relatedSessions(self, didSelectSession: viewModel)
    }

    init(sessions: [SessionViewModel] = []) {
        self.sessions = sessions

        self.$sessions
            .map { $0.isEmpty }
            .assign(to: &$isHidden)
    }
}

struct RelatedSessionsView: View {
    @ObservedObject var viewModel: RelatedSessionsViewModel

    struct Metrics {
        static let height: CGFloat = 96 + scrollerOffset
        static let itemHeight: CGFloat = 64
        static let scrollerOffset: CGFloat = 15
        static let scrollViewHeight: CGFloat = itemHeight + scrollerOffset
        static let itemWidth: CGFloat = 360
        static let padding: CGFloat = 24
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Related Sessions")
                .font(Font(NSFont.wwdcRoundedSystemFont(ofSize: 20, weight: .semibold) as CTFont))
                .foregroundColor(Color(.secondaryText))
                .lineLimit(1)
                .truncationMode(.tail)

            ScrollViewReader { scrollView in
                ScrollView(.horizontal, showsIndicators: true) {
                    SetScrollerStyle(.overlay)

                    HStack(spacing: Metrics.padding) {
                        ForEach(viewModel.sessions, id: \.identifier) { session in
                            sessionButton(for: session, in: scrollView)
                        }
                    }
                    .padding(.horizontal, 0)
                    .padding(.bottom, Metrics.scrollerOffset)
                }
            }
            .frame(height: Metrics.scrollViewHeight)
            .background(Color(.darkWindowBackground))
        }
        .frame(height: Metrics.height)
        .opacity(viewModel.isHidden ? 0 : 1)
        .allowsHitTesting(!viewModel.isHidden)
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
        .onAppear {
            if session.identifier == viewModel.sessions.first?.identifier {
                scrollView.scrollTo(session.identifier, anchor: .leading)
            }
        }
    }
}

#Preview {
    RelatedSessionsView(viewModel: RelatedSessionsViewModel(sessions: [.preview]))
}
