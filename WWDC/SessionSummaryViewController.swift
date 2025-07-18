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

        
    }
}

struct SessionSummaryView: View {
    @ObservedObject var viewModel: SessionViewModel

    enum Metrics {
        static let summaryHeight: CGFloat = 100
    }

    @State private var summaryTextHeight: CGFloat = Metrics.summaryHeight

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Title and Actions Row
            HStack(alignment: .center) {
                Text(viewModel.title)
                    .font(Font(NSFont.boldTitleFont as CTFont))
                    .foregroundStyle(Color(.primaryText))
                    .kerning(-0.5)
                    .lineLimit(2)
                    .allowsTightening(true)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

//                SessionActionsView(viewModel: viewModel.actionsViewModel)
            }

            VStack(alignment: .leading, spacing: 0) {
                // Summary ScrollView
                GeometryReader { geometry in
                    ScrollView(.vertical) {
                        Text(viewModel.summary)
                            .lineLimit(nil)
                            .font(.system(size: 15))
                            .foregroundColor(Color(NSColor.secondaryText))
                            .lineSpacing(15 * 0.15) // lineHeightMultiple: 1.2
                            .border(.pink)
                            .textSelection(.enabled)
                            .padding(5)
                            .background {
                                GeometryReader { geometry in
                                    Color.clear
                                        .onChange(of: geometry.size.height.rounded()) { oldValue, newValue in
                                            print(newValue)
                                            summaryTextHeight = newValue
                                        }
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(
                        width: geometry.size.width,
//                        minHeight: geometry.size.height,
                        alignment: .leading
                    )
                    .border(.yellow)
                }
                .frame(
                    maxHeight: summaryTextHeight,
//                    minHeight: min(summaryTextHeight, Metrics.summaryHeight),
                )
                .border(.blue)
//                .fixedSize(horizontal: false, vertical: true)
//                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 24)

                // Context and Action Link Row
                HStack(alignment: .top, spacing: 16) {
                    Text(viewModel.footer)
                        .font(.system(size: 16))
                        .foregroundColor(Color(.tertiaryText))
                        .lineLimit(1)
                        .allowsTightening(true)

                    if !viewModel.actionPrompt.isEmpty {
                        Button(viewModel.actionPrompt) {
//                            viewModel.clickedActionLabel()
//                            guard let url = sessionViewModel?.actionLinkURL else { return }
//                            NSWorkspace.shared.open(url)
                        }
                        .font(.system(size: 16))
                        .foregroundColor(Color(.primary))
                        .buttonStyle(.plain)
                        .cursorShape(.pointingHand)
                    }
                }
                .border(.purple)
                .padding(.bottom, 20)

                // Related Sessions
                RelatedSessionsView(viewModel: viewModel.relatedSessionsViewModel)
                    .border(.yellow)
            }
        }
//        .opacity(viewModel.isHidden ? 0 : 1)
//        .allowsHitTesting(!viewModel.isHidden)
    }
}
