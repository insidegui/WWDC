//
//  ContentView.swift
//  SearchClient
//
//  Created by Guilherme Rambo on 21/02/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataSource: DataSource

    var body: some View {
        VStack {
            TextField("WWDC Search", text: $dataSource.searchTerm)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            List {
                ForEach(dataSource.results) { result in
                    Text(result.summary)
                }
            }
        }
    }
}
