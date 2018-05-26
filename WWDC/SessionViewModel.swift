//
//  SessionViewModel.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import RxRealm
import RxSwift
import RxCocoa
import RealmSwift
import PlayerUI

final class SessionViewModel {

    let style: SessionsListStyle
    var title: String
    let session: Session
    let sessionInstance: SessionInstance
    let identifier: String
    var webUrl: URL?
    var imageUrl: URL?
    let trackName: String

    private var disposeBag = DisposeBag()

    lazy var rxSession: Observable<Session> = {
        return Observable.from(object: self.session)
    }()

    lazy var rxTitle: Observable<String> = {
        return Observable.from(object: self.session).map({ $0.title })
    }()

    lazy var rxSubtitle: Observable<String> = {
        return Observable.from(object: self.session).map({ SessionViewModel.subtitle(from: $0, at: $0.event.first) })
    }()

    lazy var rxTrackName: Observable<String> = {
        return Observable.from(object: self.session).map({ $0.track.first?.name }).ignoreNil()
    }()

    lazy var rxSummary: Observable<String> = {
        return Observable.from(object: self.session).map({ $0.summary })
    }()

    lazy var rxActionPrompt: Observable<String?> = {
        guard actionLinkURL != nil else { return Observable.just(nil) }

        return Observable.from(object: self.sessionInstance).map({ $0.actionLinkPrompt })
    }()

    var actionLinkURL: URL? {
        guard let candidateURL = sessionInstance.actionLinkURL else { return nil }

        return URL(string: candidateURL)
    }

    lazy var rxContext: Observable<String> = {
        if self.style == .schedule {
            let so = Observable.from(object: self.session)
            let io = Observable.from(object: self.sessionInstance)

            return Observable.zip(so, io).map({ SessionViewModel.context(for: $0.0, instance: $0.1) })
        } else {
            return Observable.from(object: self.session).map({ SessionViewModel.context(for: $0) })
        }
    }()

    lazy var rxFooter: Observable<String> = {
        return Observable.from(object: self.session).map({ SessionViewModel.footer(for: $0, at: $0.event.first) })
    }()

    lazy var rxSessionType: Observable<SessionInstanceType> = {
        return Observable.from(object: self.session).map({ $0.instances.first?.type }).ignoreNil()
    }()

    lazy var rxColor: Observable<NSColor> = {
        return Observable.from(object: self.session).map({ SessionViewModel.trackColor(for: $0) }).ignoreNil()
    }()

    lazy var rxDarkColor: Observable<NSColor> = {
        return Observable.from(object: self.session).map({ SessionViewModel.darkTrackColor(for: $0) }).ignoreNil()
    }()

    lazy var rxImageUrl: Observable<URL?> = {
        return Observable.from(object: self.session).map({ SessionViewModel.imageUrl(for: $0) })
    }()

    lazy var rxWebUrl: Observable<URL?> = {
        return Observable.from(object: self.session).map({ SessionViewModel.webUrl(for: $0) })
    }()

    lazy var rxIsDownloaded: Observable<Bool> = {
        return Observable.from(object: self.session).map({ $0.isDownloaded })
    }()

    lazy var rxIsFavorite: Observable<Bool> = {
        return Observable.collection(from: self.session.favorites.filter("isDeleted == false")).map({ $0.count > 0 })
    }()

    lazy var rxIsCurrentlyLive: Observable<Bool> = {
        guard self.sessionInstance.realm != nil else {
            return Observable.just(false)
        }

        return Observable.from(object: self.sessionInstance).map({ $0.isCurrentlyLive })
    }()

    lazy var rxIsLab: Observable<Bool> = {
        guard self.sessionInstance.realm != nil else {
            return Observable.just(false)
        }

        return Observable.from(object: self.sessionInstance).map({ $0.type == .lab })
    }()

    lazy var rxPlayableContent: Observable<Results<SessionAsset>> = {
        let playableAssets = self.session.assets.filter("rawAssetType == %@ OR rawAssetType == %@", SessionAssetType.streamingVideo.rawValue, SessionAssetType.liveStreamVideo.rawValue)

        return Observable.collection(from: playableAssets)
    }()

    lazy var rxCanBePlayed: Observable<Bool> = {
        let validAssets = self.session.assets.filter("(rawAssetType == %@ AND remoteURL != '') OR (rawAssetType == %@ AND SUBQUERY(session.instances, $instance, $instance.isCurrentlyLive == true).@count > 0)", SessionAssetType.streamingVideo.rawValue, SessionAssetType.liveStreamVideo.rawValue)
        let validAssetsObservable = Observable.collection(from: validAssets)

        return validAssetsObservable.map({ $0.count > 0 })
    }()

    lazy var rxDownloadableContent: Observable<Results<SessionAsset>> = {
        let downloadableAssets = self.session.assets.filter("(rawAssetType == %@ AND remoteURL != '')", SessionAssetType.hdVideo.rawValue)

        return Observable.collection(from: downloadableAssets)
    }()

    lazy var rxProgresses: Observable<Results<SessionProgress>> = {
        let progresses = self.session.progresses.filter(NSPredicate(value: true))

        return Observable.collection(from: progresses)
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

        if let webUrlStr = session.asset(of: .webpage)?.remoteURL {
            webUrl = URL(string: webUrlStr)
        }
    }

    static func subtitle(from session: Session, at event: ConfCore.Event?) -> String {
        guard let event = event else { return "" }

        let year = Calendar.current.component(.year, from: event.startDate)

        return "WWDC \(year) · Session \(session.number)"
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

        if (event.startDate...event.endDate).contains(Date()), let date = session.instances.first?.startTime {
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
            guard instance.type == .session || instance.type == .lab else {
                return nil
            }
        }

        let imageAsset = session.asset(of: .image)

        guard let thumbnail = imageAsset?.remoteURL, let thumbnailUrl = URL(string: thumbnail) else { return nil }

        return thumbnailUrl
    }

    static func webUrl(for session: Session) -> URL? {
        guard let url = session.asset(of: .webpage)?.remoteURL else { return nil }

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

    static let dateFormatter: DateFormatter = {
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
        let result = dateFormatter.string(from: date) + ", " + timeFormatter.string(from: date)

        return withTimeZoneName ? result + timeZoneNameSuffix : result
    }

}

extension SessionViewModel: UserActivityRepresentable { }

extension SessionViewModel {

    var isFavorite: Bool {
        return session.favorites.filter("isDeleted == false").count > 0
    }

}
