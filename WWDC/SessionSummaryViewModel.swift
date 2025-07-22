//
//  SessionSummaryViewModel.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import SwiftUI
import ConfCore
import Combine
import Algorithms

@MainActor
final class SessionSummaryViewModel: ObservableObject, Signposting {
    nonisolated static let log = makeLogger()
    nonisolated static let signposter = makeSignposter()

    @Published var title: String = ""
    @Published var summary: String = ""
    @Published var footer: String = ""
    @Published var actionPrompt: String = ""

    let actionsViewModel = SessionActionsViewModel()
    let relatedSessionsViewModel = RelatedSessionsViewModel()

    var session: SessionViewModel? {
        didSet {
            updateBindings()
        }
    }

    private var cancellables: Set<AnyCancellable> = []

    init(session: SessionViewModel? = nil) {
        self.session = session

        updateBindings()
    }

    private func updateBindings() {
        cancellables = []

        actionsViewModel.viewModel = session

        guard let session else { return }
        session.connect()

        session.$title.removeDuplicates().weakAssign(to: \.title, on: self).store(in: &cancellables)
        session.$summary.removeDuplicates().weakAssign(to: \.summary, on: self).store(in: &cancellables)
        session.$footer.removeDuplicates().weakAssign(to: \.footer, on: self).store(in: &cancellables)

        // Materializing the related sessions can't happen on the SessionViewModel because
        // doing that would cause infinite related sessions recursion.
        session.$relatedSessions.driveUI { [weak self] relatedSessions in
            self?.relatedSessionsViewModel.sessions = relatedSessions.compactMap(SessionViewModel.init).map(SessionCellViewModel.init)
        }
        .store(in: &cancellables)

        // https://github.com/insidegui/WWDC/issues/724
        // I believe this is a dead feature, it appears to have been showing a link to sign up for a lab.
        // The API has since been updated, we could restore the feature because there's other data available now.
        session.rxActionPrompt.replaceNilAndError(with: "").assign(to: \.actionPrompt, on: self).store(in: &cancellables)
    }

    func clickedActionLabel() {
        guard let url = session?.actionLinkURL else { return }

        NSWorkspace.shared.open(url)
    }
}

struct SessionSummaryView: View {
    @ObservedObject var viewModel: SessionSummaryViewModel

    enum Metrics {
        static let summaryHeight: CGFloat = 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Title and Actions Row
            HStack(alignment: .center) {
                ShrinkWrapTextLayout {
                    Text(viewModel.title)
                        .font(Font(NSFont.boldTitleFont as CTFont))
                        .foregroundStyle(Color(.primaryText))
                        .kerning(-0.5)
                        .lineLimit(2)
                        .allowsTightening(true)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                }

                Spacer()

                SessionActionsView(viewModel: viewModel.actionsViewModel)
            }

            VStack(alignment: .leading, spacing: 0) {
                // Summary ScrollView
                ScrollView(.vertical) {
                    Text(viewModel.summary)
                        .lineLimit(nil)
                        .font(.system(size: 15))
                        .foregroundColor(Color(NSColor.secondaryText))
                        .lineSpacing(15 * 0.15) // lineHeightMultiple: 1.2
                        .textSelection(.enabled)
                        .padding(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: Metrics.summaryHeight)
                .padding(.bottom, 24)

                // Context and Action Link Row
                HStack(alignment: .top, spacing: 16) {
                    ShrinkWrapTextLayout {
                        Text(viewModel.footer)
                            .font(.system(size: 16))
                            .foregroundColor(Color(.tertiaryText))
                            .lineLimit(2)
                            .allowsTightening(true)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !viewModel.actionPrompt.isEmpty {
                        Button(viewModel.actionPrompt) {
                            viewModel.clickedActionLabel()
                        }
                        .font(.system(size: 16))
                        .foregroundColor(Color(.primary))
                        .buttonStyle(.plain)
                        .cursorShape(.pointingHand)
                    }
                }
                .padding(.bottom, 20)

                // Related Sessions
                RelatedSessionsView(viewModel: viewModel.relatedSessionsViewModel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    SessionSummaryView(
        viewModel: SessionSummaryViewModel(session: .preview)
    )
    .padding()
}
