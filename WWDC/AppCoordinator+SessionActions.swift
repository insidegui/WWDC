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
import os.log

extension AppCoordinator: SessionActionsViewControllerDelegate {

    func sessionActionsDidSelectCancelDownload(_ sender: NSView?) {
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }

        guard let url = viewModel.session.asset(ofType: .hdVideo)?.remoteURL else { return }

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

        guard let slidesAsset = viewModel.session.asset(ofType: .slides) else { return }

        guard let url = URL(string: slidesAsset.remoteURL) else { return }

        NSWorkspace.shared.open(url)
    }

    func sessionActionsDidSelectDownload(_ sender: NSView?) {
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }

        guard let videoAsset = viewModel.session.asset(ofType: .hdVideo) else { return }

        DownloadManager.shared.download(videoAsset)
    }

    func sessionActionsDidSelectDeleteDownload(_ sender: NSView?) {
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }

        guard let videoAsset = viewModel.session.asset(ofType: .hdVideo) else { return }

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

    @objc func sessionActionsDidSelectCalendar(_ sender: NSView?) {
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }

        let status = EKEventStore.authorizationStatus(for: .event)
        let eventStore = EKEventStore()

        switch status {
        case .notDetermined, .denied, .restricted:
            eventStore.requestAccess(to: .event) { hasAccess, _ in
                guard hasAccess else { return }

                DispatchQueue.main.async {
                    self.saveCalendarEvent(viewModel: viewModel, eventStore: eventStore)
                }
            }
        case .authorized:
            self.saveCalendarEvent(viewModel: viewModel, eventStore: eventStore)
        }
    }

    private func saveCalendarEvent(viewModel: SessionViewModel, eventStore: EKEventStore) {
        let event = EKEvent(eventStore: eventStore)

        if let storedEvent = eventStore.event(withIdentifier: viewModel.sessionInstance.calendarEventIdentifier) {
            let alert = WWDCAlert.create()

            alert.messageText = "You've already scheduled this session"
            alert.informativeText = "Would you like to remove it from your calendar?"

            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Cancel")
            alert.window.center()

            enum Choice: NSApplication.ModalResponse.RawValue {
                case removeCalender = 1000
                case cancel = 1001
            }

            guard let choice = Choice(rawValue: alert.runModal().rawValue) else { return }

            switch choice {
            case .removeCalender:
                do {
                    try eventStore.remove(storedEvent, span: .thisEvent, commit: true)
                } catch let error as NSError {
                    os_log("Failed to remove event from calender: %{public}@",
                           log: self.log,
                           type: .error,
                           String(describing: error))
                }
            default:
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

        storage.modify(viewModel.sessionInstance) { $0.calendarEventIdentifier = event.eventIdentifier }

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
        } catch {
            os_log("Failed to add event to calendar: %{public}@",
                   log: self.log,
                   type: .error,
                   String(describing: error))
        }
    }

    func sessionActionsDidSelectShare(_ sender: NSView?) {
        guard let sender = sender else { return }
        guard let viewModel = selectedViewModelRegardlessOfTab else { return }

        guard let webpageAsset = viewModel.session.asset(ofType: .hdVideo) else { return }

        guard let url = URL(string: webpageAsset.remoteURL) else { return }

        let picker = NSSharingServicePicker(items: [url])
        picker.delegate = PickerDelegate.shared
        picker.show(relativeTo: .zero, of: sender, preferredEdge: .minY)
    }
}

final class PickerDelegate: NSObject, NSSharingServicePickerDelegate {

    static let shared = PickerDelegate()

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {

        let copyService = NSSharingService(title: "Copy URL", image: #imageLiteral(resourceName: "copy"), alternateImage: nil) {

            if let url = items.first as? URL {

                NSPasteboard.general.clearContents()
                if !NSPasteboard.general.setString(url.absoluteString, forType: .string) {
                    os_log("Failed to copy URL",
                           log: .default,
                           type: .error)
                }
            } else {
                os_log("Sharing expects a URL and did not receive one",
                       log: .default,
                       type: .error)
            }
        }

        var proposedServices = proposedServices
        proposedServices.insert(copyService, at: 0)

        return proposedServices
    }
}
