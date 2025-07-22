//
//  RelatedSessionsViewModel.swift
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
    @Published var sessions: [SessionCellViewModel] = [] {
        didSet {
            seed &+= 1 // increment with overflow
        }
    }
    /// Used to track when our session array changed without doing a bunch of string comparisons
    @Published var seed: UInt32 = 0
    var isHidden: Bool { sessions.isEmpty }

    weak var delegate: RelatedSessionsDelegate?

    func selectSession(_ viewModel: SessionViewModel) {
        delegate?.relatedSessions(self, didSelectSession: viewModel)
    }

    init(sessions: [SessionCellViewModel] = []) {
        self.sessions = sessions
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
        static let itemSpacing: CGFloat = 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Related Sessions")
                .font(Font(NSFont.wwdcRoundedSystemFont(ofSize: 20, weight: .semibold) as CTFont))
                .foregroundColor(Color(.secondaryText))
                .lineLimit(1)
                .truncationMode(.tail)

            scrollView()
        }
        .frame(height: viewModel.sessions.isEmpty ? 0 : nil)
        .opacity(viewModel.sessions.isEmpty ? 0 : 1)
    }

    func scrollView() -> some View {
        ScrollViewReader { scrollView in
            ScrollView(.horizontal, showsIndicators: true) {
                hStack(scrollView: scrollView)
                    .background {
                        SetScrollerStyle(.overlay)
                    }
                    .padding(.bottom, Metrics.scrollerOffset)
            }
            .frame(height: Metrics.itemHeight)
            .onChange(of: viewModel.seed) { _, newValue in
                scrollView.scrollTo(viewModel.sessions.first?.viewModel?.identifier, anchor: .leading)
            }
        }
        .frame(height: Metrics.scrollViewHeight)
        .background(Color(.darkWindowBackground))
        .padding(.top, Metrics.scrollerOffset)
    }

    func hStack(scrollView: ScrollViewProxy) -> some View {
        LazyHStack(spacing: Metrics.itemSpacing) {
            ForEach(viewModel.sessions, id: \.viewModel?.identifier) { session in
                sessionButton(for: session)
            }
        }
        .frame(height: Metrics.itemHeight)
    }

    func sessionButton(for session: SessionCellViewModel) -> some View {
        Button {
            viewModel.selectSession(session.viewModel!)
        } label: {
            SessionCellView(
                cellViewModel: session,
                style: .rounded
            )
            .frame(width: Metrics.itemWidth, height: Metrics.itemHeight)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RelatedSessionsView(viewModel: RelatedSessionsViewModel(sessions: [SessionCellViewModel(session: .preview)]))
}
