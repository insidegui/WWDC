//
//  ContentView.swift
//  WWDCAgentTestClient
//
//  Created by Guilherme Rambo on 24/05/21.
//  Copyright © 2021 Guilherme Rambo. All rights reserved.
//

import SwiftUI

let testSessionID = "wwdc2020-10694"

struct ContentView: View {
    @StateObject var client = WWDCAgentClient()
    
    @State private var isShowingTestResult = false
    @State private var selectedSessionId: String?
    
    private let eventOptions = ["(All Events)", "wwdc2020", "wwdc2019", "wwdc2018", "wwdc2017", "wwdc2016", "wwdc2015", "wwdc2014", "insights", "tech-talks"]
    
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
            
            VStack {
                HStack {
                    Picker("Limit results to", selection: $client.filterEventId) {
                        ForEach(eventOptions, id: \.self) { identifier in
                            Text(identifier).tag(identifier)
                        }
                    }
                }
                
                HStack {
                    Text("Fetch:")
                    Button("Favorites") {
                        client.fetchFavoriteIdentifiers()
                    }
                    
                    Button("Downloaded") {
                        client.fetchDownloadedIdentifiers()
                    }
                    
                    Button("Watched") {
                        client.fetchWatchedIdentifiers()
                    }
                    
                    Button("Unwatched") {
                        client.fetchUnwatchedIdentifiers()
                    }
                }
            }
            
            List(selection: $selectedSessionId) {
                ForEach(client.searchResults, id: \.self) { sessionId in
                    Text(sessionId)
                        .tag(sessionId)
                }
            }
            
            Spacer()
            
            VStack {
                if let selectedId = selectedSessionId {
                    Text("Test commands (apply to \(selectedId))")
                    
                    HStack {
                        Button("Reveal") {
                            client.revealVideo(with: selectedId)
                        }
                        
                        Button("Favorite") {
                            client.setFavorite(true, for: selectedId)
                        }
                        
                        Button("Unfavorite") {
                            client.setFavorite(false, for: selectedId)
                        }
                        
                        Button("Watch") {
                            client.setWatched(true, for: selectedId)
                        }
                        
                        Button("Unwatch") {
                            client.setWatched(false, for: selectedId)
                        }
                        
                        Button("Download") {
                            client.startDownload(for: selectedId)
                        }
                        
                        Button("Stop Download") {
                            client.stopDownload(for: selectedId)
                        }
                    }
                } else {
                    Text("Select a session ID to test commands")
                }
            }
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
