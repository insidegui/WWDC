//
//  SessionListView.swift
//  WWDC
//
//  Created by luca on 06.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import Combine
import SwiftUI

@available(macOS 26.0, *)
struct SessionListView: View {
    @Bindable var viewModel: SessionListViewModel

    private let columns = [GridItem(.flexible(), alignment: .leading)]

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 5, pinnedViews: .sectionHeaders) {
                ForEach(viewModel.sections) { section in
                    SessionListSectionView(section: section, selectedSession: $viewModel.selectedSession)
                }
            }
        }
        .task {
            viewModel.prepareForDisplay()
        }
    }
}

@available(macOS 26.0, *)
private struct SessionListSectionView: View {
    let section: SessionListSection
    @Binding var selectedSession: SessionListSection.Session?
    var body: some View {
        Section {
            ForEach(section.sessions) { session in
                Button {
                    selectedSession = session
                } label: {
                    SessionItemView(session: session.model)
                }
                .buttonStyle(SessionItemButtonStyle(style: .flat))
                .environment(\.isSelected, selectedSession == session)
            }
        } header: {
            Group {
                if let symbol = section.systemSymbol {
                    Label(section.title, systemImage: symbol)
                        .labelIconToTitleSpacing(5)
                } else {
                    Text(section.title)
                }
            }
            .lineLimit(1)
            .font(.headline)
            .padding(.horizontal, 10)
        }
    }
}
