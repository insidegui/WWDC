//
//  AppCoordinator+SessionActions.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RealmSwift
import ConfCore
import PlayerUI
import EventKit
import OSLog

private enum SessionActionChoice: Int {
    case yes = 1001
    case no = 1000
}

private enum CalendarChoice: NSApplication.ModalResponse.RawValue {
    case removeCalendar = 1000
    case cancel = 1001
}

extension WWDCCoordinator/*: SessionActionsDelegate */{

    func sessionActionsDidSelectCancelDownload(_ sender: NSView?) {
        guard let viewModel = activeTabSelectedSessionViewModel else { return }

        MediaDownloadManager.shared.cancelDownload(for: [viewModel.session])
    }

    func sessionActionsDidSelectFavorite(_ sender: NSView?) {
        guard let session = activeTabSelectedSessionViewModel?.session else { return }

        storage.toggleFavorite(on: session)
    }

    func sessionActionsDidSelectSlides(_ sender: NSView?) {
        guard let viewModel = activeTabSelectedSessionViewModel else { return }

        guard let slidesAsset = viewModel.session.asset(ofType: .slides) else { return }

        guard let url = URL(string: slidesAsset.remoteURL) else { return }

        NSWorkspace.shared.open(url)
    }

    func sessionActionsDidSelectDownload(_ sender: NSView?) {
        guard let viewModel = activeTabSelectedSessionViewModel else { return }

        MediaDownloadManager.shared.download([viewModel.session])
    }

    func sessionActionsDidSelectDeleteDownload(_ sender: NSView?) {
        guard let viewModel = activeTabSelectedSessionViewModel else { return }

        let alert = WWDCAlert.create()

        alert.messageText = "Remove downloaded video"
        alert.informativeText = "Are you sure you want to delete the downloaded video? This action can't be undone."

        alert.addButton(withTitle: "No")
        alert.addButton(withTitle: "Yes")

        guard let choice = SessionActionChoice(rawValue: alert.runModal().rawValue) else { return }

        switch choice {
        case .yes:
            do {
                try MediaDownloadManager.shared.removeDownloadedMedia(for: viewModel.session)
            } catch {
                NSAlert(error: error).runModal()
            }
        case .no:
            break
        }
    }

    func sessionActionsDidSelectShare(_ sender: NSView?) {
        guard let sender = sender else { return }
        guard let viewModel = activeTabSelectedSessionViewModel else { return }

        guard let webpageAsset = viewModel.session.asset(ofType: .webpage) else { return }

        guard let url = URL(string: webpageAsset.remoteURL) else { return }

        let picker = NSSharingServicePicker(items: [url.replacingAppleDeveloperHostWithNativeHost])
        picker.delegate = PickerDelegate.shared
        picker.show(relativeTo: .zero, of: sender, preferredEdge: .minY)
    }

    func sessionActionsDidSelectShareClip(_ sender: NSView?) {
        switch activeTab {
        case .schedule:
            scheduleController.splitViewController.detailViewController.shelfController.showClipUI()
        case .videos:
            videosController.detailViewController.shelfController.showClipUI()
        default:
            break
        }
    }

}

final class PickerDelegate: NSObject, NSSharingServicePickerDelegate, Logging {

    static let shared = PickerDelegate()
    static let log = makeLogger()

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, sharingServicesForItems items: [Any], proposedSharingServices proposedServices: [NSSharingService]) -> [NSSharingService] {

        let copyService = NSSharingService(title: "Copy URL", image: #imageLiteral(resourceName: "copy"), alternateImage: nil) { [log] in

            if let url = items.first as? URL {

                NSPasteboard.general.clearContents()
                if !NSPasteboard.general.setString(url.absoluteString, forType: .string) {
                    log.error("Failed to copy URL")
                }
            } else {
                log.error("Sharing expects a URL and did not receive one")
            }
        }

        var proposedServices = proposedServices

        // Add a "Reveal in Finder" option for local file URLs
        if let url = items.first as? URL, url.isFileURL {
            let finderService = NSSharingService(title: "Reveal in Finder", image: #imageLiteral(resourceName: "reveal-in-finder"), alternateImage: nil) {
                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
            }

            proposedServices.insert(finderService, at: 0)
        } else {
            proposedServices.insert(copyService, at: 0)
        }

        return proposedServices
    }
}

extension Storage {
    func toggleFavorite(on session: Session) {
        setFavorite(!session.isFavorite, onSessionsWithIDs: [session.identifier])
    }
}

// MARK: - Calendar Integration

extension WWDCCoordinator {
    func sessionActionsDidSelectCalendar(_ sender: NSView?) {
        guard let viewModel = activeTabSelectedSessionViewModel else { return }

        Task { @MainActor in
            do {
                guard let store = try await authorizeCalendarAccess() else { return }
                saveCalendarEvent(viewModel: viewModel, eventStore: store)
            } catch {
                WWDCAlert.show(with: error)
            }
        }
    }

    private func authorizeCalendarAccess() async throws -> EKEventStore? {
        let store = EKEventStore()

        let status = EKEventStore.authorizationStatus(for: .event)

        // TODO: Compile-time check can be removed once we require Xcode 15 for building
        #if compiler(>=5.9)
        if #available(macOS 14.0, *) {
            if [.writeOnly, .fullAccess].contains(status) { return store }

            guard try await store.requestWriteOnlyAccessToEvents() else { return nil }
            return store
        } else {
            guard status != .authorized else { return store }

            guard try await store.requestAccess(to: .event) else { return nil }
            return store
        }
        #else
        guard status != .authorized else { return store }
        guard try await store.requestAccess(to: .event) else { return nil }
        return store
        #endif
    }

    private func saveCalendarEvent(viewModel: SessionViewModel, eventStore: EKEventStore) {
        if let storedEvent = eventStore.event(withIdentifier: viewModel.sessionInstance.calendarEventIdentifier) {
            let alert = WWDCAlert.create()

            alert.messageText = "You've already scheduled this session"
            alert.informativeText = "Would you like to remove it from your calendar?"

            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Cancel")
            alert.window.center()

            guard let choice = CalendarChoice(rawValue: alert.runModal().rawValue) else { return }

            switch choice {
            case .removeCalendar:
                do {
                    try eventStore.remove(storedEvent, span: .thisEvent, commit: true)
                } catch let error as NSError {
                    log.error("Failed to remove event from calendar: \(String(describing: error), privacy: .public)")
                }
            default:
                break
            }

            return
        }

        let event = viewModel.calendarEvent(in: eventStore)
        event.calendar = eventStore.defaultCalendarForNewEvents

        storage.modify(viewModel.sessionInstance) {
            if let identifier = event.eventIdentifier {
                $0.calendarEventIdentifier = identifier
            } else {
                $0.calendarEventIdentifier = $0.identifier
            }
        }

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
        } catch {
            log.error("Failed to add event to calendar: \(String(describing: error), privacy: .public)")
        }
    }
}

private extension SessionViewModel {
    func calendarEvent(in store: EKEventStore) -> EKEvent {
        let event = EKEvent(eventStore: store)
        event.startDate = sessionInstance.startTime
        event.endDate = sessionInstance.endTime
        event.title = session.title
        event.location = sessionInstance.roomName
        event.url = webUrl
        return event
    }
}
