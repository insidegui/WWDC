//
//  SessionViewModel.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import Combine
import RealmSwift
import PlayerUI

//protocol OptionalType {
//    associatedtype Wrapped
//
//    var optional: Wrapped? { get }
//}
//
//extension Optional: OptionalType {
//    var optional: Wrapped? { return self }
//}
//
//extension Observable where Element: OptionalType {
//    func ignoreNil() -> Observable<Element.Wrapped> {
//        return flatMap { value in
//            value.optional.map { Observable<Element.Wrapped>.just($0) } ?? Observable<Element.Wrapped>.empty()
//        }
//    }
//}

final class SessionViewModel {

    let style: SessionsListStyle
    var title: String
    let session: Session
    let sessionInstance: SessionInstance
    let identifier: String
    var webUrl: URL?
    var imageUrl: URL?
    let trackName: String

    lazy var rxSession: some Publisher<Session, Error> = {
        return Publishers.Concatenate(prefix: Just(session).setFailureType(to: Error.self), suffix: valuePublisher(session))
    }()

    lazy var rxTranscriptAnnotations: AnyPublisher<List<TranscriptAnnotation>, Error> = {
        guard let annotations = session.transcript()?.annotations else {
            return Just(List<TranscriptAnnotation>()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        return annotations.collectionPublisher.eraseToAnyPublisher()
    }()

    lazy var rxSessionInstance: some Publisher<SessionInstance, Error> = {
        return Publishers.Concatenate(prefix: Just(sessionInstance).setFailureType(to: Error.self), suffix: valuePublisher(sessionInstance))
    }()

    lazy var rxTitle: some Publisher<String, Error> = {
        return rxSession.map { $0.title }
    }()

    lazy var rxSubtitle: some Publisher<String, Error> = {
        return rxSession.map { SessionViewModel.subtitle(from: $0, at: $0.event.first) }
    }()

    lazy var rxTrackName: some Publisher<String, Error> = {
        return rxSession.compactMap { $0.track.first?.name }
    }()

    lazy var rxSummary: some Publisher<String, Error> = {
        return rxSession.map { $0.summary }
    }()

    lazy var rxActionPrompt: AnyPublisher<String?, Error> = {
        guard sessionInstance.startTime > today() else { return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher() }
        guard actionLinkURL != nil else { return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher() }

        return rxSessionInstance.map { $0.actionLinkPrompt }.eraseToAnyPublisher()
    }()

    var actionLinkURL: URL? {
        guard let candidateURL = sessionInstance.actionLinkURL else { return nil }

        return URL(string: candidateURL)
    }

    lazy var rxContext: AnyPublisher<String, Error> = {
        if self.style == .schedule {

            return Publishers.CombineLatest(rxSession, rxSessionInstance).map {
                SessionViewModel.context(for: $0.0, instance: $0.1)
            }.eraseToAnyPublisher()
        } else {
            return rxSession.map { SessionViewModel.context(for: $0) }.eraseToAnyPublisher()
        }
    }()

    lazy var rxFooter: some Publisher<String, Error> = {
        return rxSession.map { SessionViewModel.footer(for: $0, at: $0.event.first) }
    }()

    lazy var rxSessionType: some Publisher<SessionInstanceType, Error> = {
        return rxSession.compactMap { $0.instances.first?.type }
    }()

    lazy var rxColor: some Publisher<NSColor, Error> = {
        return rxSession.compactMap { SessionViewModel.trackColor(for: $0) }
    }()

    lazy var rxDarkColor: some Publisher<NSColor, Error> = {
        return rxSession.compactMap { SessionViewModel.darkTrackColor(for: $0) }
    }()

    lazy var rxImageUrl: some Publisher<URL?, Error> = {
        return rxSession.map { SessionViewModel.imageUrl(for: $0) }
    }()

    lazy var rxWebUrl: some Publisher<URL?, Error> = {
        return rxSession.map { SessionViewModel.webUrl(for: $0) }
    }()

    lazy var rxIsDownloaded: some Publisher<Bool, Error> = {
        return rxSession.map { $0.isDownloaded }
    }()

    lazy var rxIsFavorite: some Publisher<Bool, Error> = {
        return self.session.favorites.filter("isDeleted == false").collectionPublisher.map { $0.count > 0 }
    }()

    lazy var rxIsCurrentlyLive: some Publisher<Bool, Error> = {
        guard self.sessionInstance.realm != nil else {
            return Just(false).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        return rxSessionInstance.map { $0.isCurrentlyLive }.eraseToAnyPublisher()
    }()

    lazy var rxIsLab: AnyPublisher<Bool, Error> = {
        guard self.sessionInstance.realm != nil else {
            return Just(false).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        return rxSessionInstance.map { [.lab, .labByAppointment].contains($0.type) }.eraseToAnyPublisher()
    }()

    lazy var rxPlayableContent: some Publisher<Results<SessionAsset>, Error> = {
        let playableAssets = self.session.assets(matching: [.streamingVideo, .liveStreamVideo])

        return playableAssets.collectionPublisher
    }()

    lazy var rxCanBePlayed: some Publisher<Bool, Error> = {
        let validAssets = self.session.assets.filter("(rawAssetType == %@ AND remoteURL != '') OR (rawAssetType == %@ AND SUBQUERY(session.instances, $instance, $instance.isCurrentlyLive == true).@count > 0)", SessionAssetType.streamingVideo.rawValue, SessionAssetType.liveStreamVideo.rawValue)
        let validAssetsObservable = validAssets.collectionPublisher

        return validAssetsObservable.map { $0.count > 0 }
    }()

    lazy var rxDownloadableContent: some Publisher<Results<SessionAsset>, Error> = {
        let downloadableAssets = self.session.assets.filter("(rawAssetType == %@ AND remoteURL != '')", DownloadManager.downloadQuality.rawValue)

        return downloadableAssets.collectionPublisher
    }()

    lazy var rxProgresses: some Publisher<Results<SessionProgress>, Error> = {
        let progresses = self.session.progresses.filter(NSPredicate(value: true))

        return progresses.collectionPublisher
    }()

    lazy var rxRelatedSessions: some Publisher<Results<RelatedResource>, Error> = {
        // Return sessions with videos, or any session that hasn't yet occurred
        let predicateFormat = "type == %@ AND (ANY session.assets.rawAssetType == %@ OR ANY session.instances.startTime >= %@)"
        let relatedPredicate = NSPredicate(format: predicateFormat, RelatedResourceType.session.rawValue, SessionAssetType.streamingVideo.rawValue, today() as NSDate)
        let validRelatedSessions = self.session.related.filter(relatedPredicate)

        return validRelatedSessions.collectionPublisher
    }()

    convenience init?(session: Session) {
        self.init(session: session, instance: nil, style: .videos)
    }

    init?(session: Session?, instance: SessionInstance?, style: SessionsListStyle) {
        self.style = style

        guard let session = session ?? instance?.session else { return nil }
        guard let track = session.track.first ?? instance?.track.first else { return nil }

        trackName = track.name
        self.session = session
        sessionInstance = instance ?? session.instances.first ?? SessionInstance()
        title = session.title
        identifier = session.identifier
        imageUrl = SessionViewModel.imageUrl(for: session)

        if let webUrlStr = session.asset(ofType: .webpage)?.remoteURL {
            webUrl = URL(string: webUrlStr)
        }
    }

    static func subtitle(from session: Session, at event: ConfCore.Event?) -> String {
        guard let event = event else { return "" }

        let year = Calendar.current.component(.year, from: event.startDate)
        var name = event.name

        /*
        We want to make sure that WWDC events show the year
        So we add it it not present.
        */
        if name == "WWDC" {
            name.append(" \(year)")
        }

        return "\(name) · Session \(session.number)"
    }

    static func focusesDescription(from focuses: [Focus], collapse: Bool) -> String {
        var result: String

        if focuses.count == 4 && collapse {
            result = "All Platforms"
        } else {
            let separator = ", "

            result = focuses.reduce("") { $0 + $1.name + separator }
            result = result.trimmingCharacters(in: CharacterSet(charactersIn: separator))
        }

        return result
    }

    static func context(for session: Session, instance: SessionInstance? = nil) -> String {
        if let instance = instance {
            var result = timeFormatter.string(from: instance.startTime) + " - " + timeFormatter.string(from: instance.endTime)

            result += " · " + instance.roomName

            return result
        } else {
            let focusesArray = session.focuses.toArray()

            let focuses = SessionViewModel.focusesDescription(from: focusesArray, collapse: true)

            var result = session.track.first?.name ?? ""

            if focusesArray.count > 0 {
                result = "\(focuses) · " + result
            }

            return result
        }
    }

    static func footer(for session: Session, at event: ConfCore.Event?) -> String {
        guard let event = event else { return "" }

        let focusesArray = session.focuses.toArray()

        let allFocuses = SessionViewModel.focusesDescription(from: focusesArray, collapse: false)

        var result = "\(event.name) · Session \(session.number)"

        if (event.startDate...event.endDate).contains(today()), let date = session.instances.first?.startTime {
            result += " · " + standardFormatted(date: date, withTimeZoneName: false)
        }

        if session.mediaDuration > 0, let duration = String(timestamp: session.mediaDuration) {
            result += " · " + duration
        }

        if focusesArray.count > 0 {
            result += " · \(allFocuses)"
        }

        return result
    }

    static func imageUrl(for session: Session) -> URL? {
        if let instance = session.instances.first {
            guard [.session, .lab, .labByAppointment].contains(instance.type) else {
                return nil
            }
        }

        let imageAsset = session.asset(ofType: .image)

        guard let thumbnail = imageAsset?.remoteURL, let thumbnailUrl = URL(string: thumbnail) else { return nil }

        return thumbnailUrl
    }

    static func webUrl(for session: Session) -> URL? {
        guard let url = session.asset(ofType: .webpage)?.remoteURL else { return nil }

        return URL(string: url)
    }

    static func trackColor(for session: Session) -> NSColor? {
        guard let code = session.track.first?.lightColor else { return nil }

        return NSColor.fromHexString(hexString: code)
    }

    static func darkTrackColor(for session: Session) -> NSColor? {
        guard let code = session.track.first?.darkColor else { return nil }

        return NSColor.fromHexString(hexString: code)
    }

    static let shortDayOfTheWeekFormatter: DateFormatter = {
        let df = DateFormatter()

        df.locale = Locale.current
        df.timeZone = TimeZone.current
        df.dateFormat = "E"

        return df
    }()

    static let dayOfTheWeekFormatter: DateFormatter = {
        let df = DateFormatter()

        df.locale = Locale.current
        df.timeZone = TimeZone.current
        df.dateFormat = "EEEE"

        return df
    }()

    static let timeFormatter: DateFormatter = {
        let tf = DateFormatter()

        tf.locale = Locale.current
        tf.timeZone = TimeZone.current
        tf.timeStyle = .short

        return tf
    }()

    static var timeZoneNameSuffix: String {
        if let name = TimeZone.current.localizedName(for: .shortGeneric, locale: Locale.current) {
            return " " + name
        } else {
            return ""
        }
    }

    static func standardFormatted(date: Date, withTimeZoneName: Bool) -> String {
        let result = dayOfTheWeekFormatter.string(from: date) + ", " + timeFormatter.string(from: date)

        return withTimeZoneName ? result + timeZoneNameSuffix : result
    }

}

extension SessionViewModel: UserActivityRepresentable { }

extension SessionViewModel {

    var isFavorite: Bool { session.isFavorite }

}
