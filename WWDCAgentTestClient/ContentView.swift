//
//  ContentView.swift
//  WWDCAgentTestClient
//
//  Created by Guilherme Rambo on 24/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @StateObject var client = WWDCAgentClient()
    
    @State private var isShowingTestResult = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Status:")
                if client.isConnected {
                    Text("Connected")
                    
                    Button("Test") {
                        client.sendTestRequest { _ in
                            isShowingTestResult = true
                        }
                    }
                } else {
                    Text("Not Connected")
                }
            }
            
            TextField("Search", text: $client.searchTerm)
            
            List {
                ForEach(client.searchResults) { session in
                    Text(session.title)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { client.connect() }
        .alert(isPresented: $isShowingTestResult, content: {
            Alert(title: Text("Success"), message: Text("We got a reply from the agent!"), dismissButton: nil)
        })
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
