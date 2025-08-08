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

    var body: some View {
        List(viewModel.sections, selection: $viewModel.selectedSessions) { section in
            Section {
                ForEach(section.sessions) { session in
                    SessionItemView(session: session.model)
                        .id(session)
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
            }
            .listRowInsets(.all, 0)
        }
        .task {
            viewModel.prepareForDisplay()
        }
    }
}
