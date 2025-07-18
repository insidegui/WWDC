//
//  SessionSummaryViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import SwiftUI
import ConfCore
import Combine

final class SessionSummaryViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var summary: String = ""
    @Published var footer: String = ""
    @Published var actionPrompt: String = ""
    @Published var isHidden: Bool = true

    private var cancellables: Set<AnyCancellable> = []

    @MainActor
    var sessionViewModel: SessionViewModel? {
        didSet {
            updateBindings()
        }
    }

    @MainActor
    let actionsViewModel = SessionActionsViewModel()
    let relatedSessionsViewModel = RelatedSessionsViewModel()

    @MainActor
    private func updateBindings() {
        isHidden = (sessionViewModel == nil)
        actionsViewModel.viewModel = sessionViewModel

        guard let viewModel = sessionViewModel else { return }

        cancellables = []

        viewModel
            .rxTitle
            .replaceError(with: "")
            .assign(to: &$title)

        viewModel
            .rxSummary
            .replaceError(with: "")
            .assign(to: &$summary)

        viewModel
            .rxFooter
            .replaceError(with: "")
            .assign(to: &$footer)

        viewModel
            .rxActionPrompt
            .replaceNilAndError(with: "")
            .assign(to: &$actionPrompt)

        viewModel.rxRelatedSessions.driveUI { [weak self] relatedResources in
            let relatedSessions = relatedResources.compactMap({ $0.session })
            self?.relatedSessionsViewModel.sessions = relatedSessions.compactMap(SessionViewModel.init)
        }
        .store(in: &cancellables)
    }

    @MainActor
    func clickedActionLabel() {
        guard let url = sessionViewModel?.actionLinkURL else { return }
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
                Text(viewModel.title)
//                    .font(Font(NSFont.attributedBoldTitle().font))
                    .foregroundColor(Color(.primaryText))
                    .lineLimit(2)
                    .allowsTightening(true)
                    .textSelection(.enabled)
//                    .frame(maxWidth: .infinity, alignment: .leading)

                if !viewModel.isHidden {
                    SessionActionsView(viewModel: viewModel.actionsViewModel)
                }
            }
            .border(.red)

            VStack(alignment: .leading, spacing: 24) {
                // Summary ScrollView
                GeometryReader { geometry in
                    ScrollView(.vertical) {
                        Text(viewModel.summary)
                            .lineLimit(nil)
                            .font(.system(size: 15))
                            .foregroundColor(Color(.secondaryText))
                            .lineSpacing(15 * 0.2) // lineHeightMultiple: 1.2
                            .border(.pink)
                            .frame(maxWidth: geometry.size.width, alignment: .leading)
                            .border(.yellow)
                            .textSelection(.enabled)
//                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .containerRelativeFrame(.horizontal, alignment: .leading)
                    .border(.blue)
                }
                .frame(minHeight: Metrics.summaryHeight)
                .fixedSize(horizontal: false, vertical: true)

                // Context and Action Link Row
                HStack(alignment: .top, spacing: 16) {
                    Text(viewModel.footer)
                        .font(.system(size: 16))
                        .foregroundColor(Color(.tertiaryText))
                        .lineLimit(1)
                        .allowsTightening(true)
//                        .frame(maxWidth: .infinity, alignment: .leading)

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
                .border(.purple)

                // Related Sessions
                RelatedSessionsView(viewModel: viewModel.relatedSessionsViewModel)
                    .border(.yellow)
            }
        }
        .opacity(viewModel.isHidden ? 0 : 1)
        .allowsHitTesting(!viewModel.isHidden)
    }
}
