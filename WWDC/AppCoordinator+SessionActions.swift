//
//  AppCoordinator+SessionActions.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import RxSwift
import ConfCore
import PlayerUI
import EventKit

extension AppCoordinator: SessionActionsViewControllerDelegate {

    func sessionActionsDidSelectCancelDownload(_ sender: NSView?) {
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }

        guard let url = viewModel.session.assets.filter("rawAssetType == %@", SessionAssetType.hdVideo.rawValue).first?.remoteURL else { return }

        _ = DownloadManager.shared.cancelDownload(url)
    }

    func sessionActionsDidSelectFavorite(_ sender: NSView?) {
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }

        if viewModel.isFavorite {
            storage.removeFavorite(for: viewModel.session)
        } else {
            storage.createFavorite(for: viewModel.session)
        }
    }

    func sessionActionsDidSelectSlides(_ sender: NSView?) {
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }

        guard let slidesAsset = viewModel.session.asset(of: .slides) else { return }

        guard let url = URL(string: slidesAsset.remoteURL) else { return }

        NSWorkspace.shared.open(url)
    }

    func sessionActionsDidSelectDownload(_ sender: NSView?) {
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }

        guard let videoAsset = viewModel.session.assets.filter("rawAssetType == %@", SessionAssetType.hdVideo.rawValue).first else { return }

        DownloadManager.shared.download(videoAsset)
    }

    func sessionActionsDidSelectDeleteDownload(_ sender: NSView?) {        
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }

        guard let videoAsset = viewModel.session.assets.filter("rawAssetType == %@", SessionAssetType.hdVideo.rawValue).first else { return }

        let alert = WWDCAlert.create()

        alert.messageText = "Remove downloaded video"
        alert.informativeText = "Are you sure you want to delete the downloaded video? This action can't be undone."

        alert.addButton(withTitle: "No")
        alert.addButton(withTitle: "Yes")

        enum Choice: Int {
            case yes = 1001
            case no = 1000
        }

        guard let choice = Choice(rawValue: alert.runModal().rawValue) else { return }

        switch choice {
        case .yes:
            DownloadManager.shared.deleteDownload(for: videoAsset)
        case .no:
            break
        }
    }
    
    func sessionActionsDidSelectCalendar(_ sender: NSView?) {
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }

        let status = EKEventStore.authorizationStatus(for: .event)
        let eventStore = EKEventStore()
        
        if status == .notDetermined || status == .denied {

            eventStore.requestAccess(to: .event, completion: { (hasAccess, error) in
                
                if hasAccess == true {
                    self.saveCalendarEvent(viewModel: viewModel, eventStore: eventStore)
                }
            })
            
        } else if status == .authorized {
            
            self.saveCalendarEvent(viewModel: viewModel, eventStore: eventStore)
            
        } else {
        
            return
        }
    }
    
    private func saveCalendarEvent(viewModel:SessionViewModel!, eventStore:EKEventStore!)  {
        let event = EKEvent.init(eventStore: eventStore)
        
        if let storedEvent = eventStore.event(withIdentifier: viewModel.sessionInstance.calendarEventIdentifier) {
            
            let alert = WWDCAlert.create()
            
            alert.messageText = "You've already scheduled this session"
            alert.informativeText = "Would you like to remove it from your Calender?"
            
            alert.addButton(withTitle: "Remove from Calender")
            alert.addButton(withTitle: "Cancel")
            alert.window.center()
            
            enum Choice: Int {
                case removeCalender = 1000
                case cancel = 1001
            }
            
            guard let choice = Choice(rawValue: alert.runModal()) else { return }
            
            switch choice {
            case .removeCalender:
                do {
                    try eventStore.remove(storedEvent, span: .thisEvent, commit: true)
                    
                } catch let error as NSError {
                    
                    print("Failed to remove event from calender due to error: \(error)")
                }
                break
            case .cancel:
                break
            }

            return
        }
        
        event.startDate = viewModel.sessionInstance.startTime
        event.endDate = viewModel.sessionInstance.endTime
        event.title = viewModel.session.title
        event.location = viewModel.sessionInstance.roomName
        event.url = viewModel.webUrl
        event.calendar = eventStore.defaultCalendarForNewEvents
        self.storage.realm.beginWrite()
        viewModel.sessionInstance.calendarEventIdentifier = event.eventIdentifier
        do {
            try self.storage.realm.commitWrite()
            
        } catch let error as NSError {
            print("Error writing session instance to storage: \(error)")
        }
       
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            
        } catch let error as NSError {
            print("Failed to add event to calender due to error: \(error)")
        }
    }

    func sessionActionsDidSelectShare(_ sender: NSView?) {
        guard let sender = sender else { return }
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }

        guard let webpageAsset = viewModel.session.assets.filter("rawAssetType == %@", SessionAssetType.webpage.rawValue).first else { return }

        guard let url = URL(string: webpageAsset.remoteURL) else { return }

        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: .zero, of: sender, preferredEdge: .minY)
    }
}
