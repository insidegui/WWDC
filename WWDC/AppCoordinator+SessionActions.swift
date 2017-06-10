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
        
        guard let url = viewModel.session.assets.filter({ $0.assetType == .hdVideo }).first?.remoteURL else { return }
        
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
        
        NSWorkspace.shared().open(url)
    }
    
    func sessionActionsDidSelectDownload(_ sender: NSView?) {
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }
        
        guard let videoAsset = viewModel.session.assets.filter({ $0.assetType == .hdVideo }).first else { return }
        
        DownloadManager.shared.download(videoAsset)
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
        event.startDate = viewModel.sessionInstance.startTime
        event.endDate = viewModel.sessionInstance.endTime
        event.title = viewModel.session.title
        event.location = viewModel.sessionInstance.roomName
        event.url = viewModel.webUrl
        event.calendar = eventStore.defaultCalendarForNewEvents
       
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            
        } catch let e as NSError {
            print("Failed to add event to calender due to error: \(e)")
        }
    }
    
    func sessionActionsDidSelectDeleteDownload(_ sender: NSView?) {        
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }
        
        guard let videoAsset = viewModel.session.assets.filter({ $0.assetType == .hdVideo }).first else { return }
        
        let alert = WWDCAlert.create()
        
        alert.messageText = "Remove downloaded video"
        alert.informativeText = "Are you sure you want to delete the downloaded video? This action can't be undone."
        
        alert.addButton(withTitle: "No")
        alert.addButton(withTitle: "Yes")
        
        enum Choice: Int {
            case yes = 1001
            case no = 1000
        }
        
        guard let choice = Choice(rawValue: alert.runModal()) else { return }
        
        switch choice {
        case .yes:
            DownloadManager.shared.deleteDownload(for: videoAsset)
        case .no:
            break
        }
    }
    
    func sessionActionsDidSelectShare(_ sender: NSView?) {
        guard let sender = sender else { return }
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }
        
        guard let webpageAsset = viewModel.session.assets.filter({ $0.assetType == .webpage }).first else { return }
        
        guard let url = URL(string: webpageAsset.remoteURL) else { return }
        
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: .zero, of: sender, preferredEdge: .minY)
    }
    
}
