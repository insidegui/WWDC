//
//  NewExploreCategoryList.swift
//  WWDC
//
//  Created by luca on 06.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import SwiftUI

@available(macOS 26.0, *)
struct NewExploreCategoryList: View {
    @Environment(NewExploreViewModel.self) var viewModel
    @State private var sections: [ExploreTabContent.Section] = []
    @State private var showDetail = false
    var body: some View {
        ScrollViewReader { proxy in
            @Bindable var viewModel = viewModel
            List(sections, selection: $viewModel.selectedCategory) { section in
                Label {
                    Text(section.title)
                } icon: {
                    section.icon
                }
            }
            .onChange(of: viewModel.selectedCategory) { _, newValue in
                proxy.scrollTo(newValue, anchor: .bottom)
            }
        }
        .onAppear {
            showDetail = true
        }
        .onReceive(viewModel.provider.$content.receive(on: DispatchQueue.main)) { newContent in
            sections = newContent?.sections ?? []
            if viewModel.selectedCategory == nil {
                viewModel.selectedCategory = sections.first?.id
            }
        }
    }
}
