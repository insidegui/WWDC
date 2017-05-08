//
//  SessionViewModel.swift
//  WWDC
//
//  Created by Guilherme Rambo on 22/04/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore
import IGListKit
import RxRealm
import RxSwift
import RxCocoa
import RealmSwift

final class SessionViewModel: NSObject {
    
    let style: SessionsListStyle
    
    let session: Session
    let sessionInstance: SessionInstance
    let identifier: String
    
    var title: String = ""
    var subtitle: String = ""
    var trackName: String = ""
    var summary: String = ""
    var context: String = ""
    var footer: String = ""
    
    var color: NSColor = .clear
    
    var imageUrl: URL? = nil
    var webUrl: URL? = nil
    
    private var disposeBag = DisposeBag()
    
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
    
    lazy var rxColor: Observable<NSColor> = {
        return Observable.from(object: self.session).map({ SessionViewModel.trackColor(for: $0) }).ignoreNil()
    }()
    
    lazy var rxImageUrl: Observable<URL?> = {
        return Observable.from(object: self.session).map({ SessionViewModel.imageUrl(for: $0) })
    }()
    
    lazy var rxWebUrl: Observable<URL?> = {
        return Observable.from(object: self.session).map({ SessionViewModel.webUrl(for: $0) })
    }()
    
    lazy var rxValidDownload: Observable<Download?> = {
        let downloadAssets = self.session.assets.filter("rawAssetType == %@ AND SUBQUERY(downloads, $download, $download.rawStatus != %@).@count > 0", SessionAssetType.hdVideo.rawValue, DownloadStatus.none.rawValue)
        
        return Observable.collection(from: downloadAssets).map({ $0.first?.downloads.first })
    }()
    
    lazy var rxIsFavorite: Observable<Bool> = {
        return Observable.from(object: self.session).map({ $0.favorites.count > 0 })
    }()
    
    lazy var rxPlayableContent: Observable<Results<SessionAsset>> = {
        let playableAssets = self.session.assets.filter("rawAssetType == %@ OR rawAssetType == %@", SessionAssetType.streamingVideo.rawValue, SessionAssetType.liveStreamVideo.rawValue)
        
        return Observable.collection(from: playableAssets)
    }()
    
    lazy var rxDownloadableContent: Observable<Results<SessionAsset>> = {
        let downloadableAssets = self.session.assets.filter("rawAssetType == %@", SessionAssetType.hdVideo.rawValue)
        
        return Observable.collection(from: downloadableAssets)
    }()
    
    convenience init?(session: Session) {
        self.init(session: session, instance: nil, style: .videos)
    }
    
    init?(session: Session?, instance: SessionInstance?, style: SessionsListStyle) {
        self.style = style
        
        guard let session = session else { return nil }
        
        self.session = session
        self.sessionInstance = instance ?? SessionInstance()
        
        guard let event = session.event.first else { return nil }
        guard let track = session.track.first else { return nil }
        
        self.trackName = track.name
        
        self.imageUrl = SessionViewModel.imageUrl(for: session)
        self.identifier = session.identifier
        self.title = session.title
        self.subtitle = SessionViewModel.subtitle(from: session, at: event)
        
        if style == .schedule {
            self.context = SessionViewModel.context(for: session, instance: sessionInstance)
        } else {
            self.context = SessionViewModel.context(for: session)
        }
        
        self.color = NSColor.fromHexString(hexString: track.lightColor)
        self.summary = session.summary
        self.footer = SessionViewModel.footer(for: session, at: event)
        self.webUrl = SessionViewModel.webUrl(for: session)
        
        super.init()
        
        // MARK: SELF-UPDATE
        
        self.rxTitle.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.title = newValue
        }).addDisposableTo(self.disposeBag)
        
        self.rxSubtitle.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.subtitle = newValue
        }).addDisposableTo(self.disposeBag)
        
        self.rxTrackName.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.trackName = newValue
        }).addDisposableTo(self.disposeBag)
        
        self.rxSummary.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.summary = newValue
        }).addDisposableTo(self.disposeBag)
        
        self.rxContext.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.context = newValue
        }).addDisposableTo(self.disposeBag)
        
        self.rxFooter.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.footer = newValue
        }).addDisposableTo(self.disposeBag)
        
        self.rxColor.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.color = newValue
        }).addDisposableTo(self.disposeBag)
        
        self.rxImageUrl.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.imageUrl = newValue
        }).addDisposableTo(self.disposeBag)
        
        self.rxWebUrl.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.webUrl = newValue
        }).addDisposableTo(self.disposeBag)
    }
    
    init(title: String) {
        self.identifier = title
        self.title = title
        self.trackName = ""
        self.subtitle = ""
        self.summary = ""
        self.context = ""
        self.footer = ""
        self.color = .clear
        self.webUrl = nil
        self.imageUrl = nil
        self.session = Session()
        self.sessionInstance = SessionInstance()
        self.style = .videos
        
        super.init()
    }
    
    init(headerWithDate date: Date, showTimeZone: Bool) {
        self.identifier = title
        self.title = SessionViewModel.standardFormatted(date: date, withTimeZoneName: showTimeZone)
        self.trackName = ""
        self.subtitle = ""
        self.summary = ""
        self.context = ""
        self.footer = ""
        self.color = .clear
        self.webUrl = nil
        self.imageUrl = nil
        self.session = Session()
        self.sessionInstance = SessionInstance()
        self.style = .videos
        
        super.init()
    }
    
    static func subtitle(from session: Session, at event: ConfCore.Event?) -> String {
        guard let event = event else { return "" }
        
        let year = Calendar.current.component(.year, from: event.startDate)
        
        return "WWDC \(year) - Session \(session.number)"
    }
    
    static func focusesDescription(from focuses: [Focus], collapse: Bool) -> String {
        var result: String
        
        if focuses.count == 4 && collapse {
            result = "All Platforms"
        } else {
            let separator = ", "
            
            result = focuses.reduce("") { partial, focus in
                if partial.isEmpty {
                    return focus.name + separator
                } else {
                    return partial + focus.name + separator
                }
            }
            
            if let lastCommaRange = result.range(of: separator, options: .backwards, range: nil, locale: nil) {
                result = result.replacingCharacters(in: lastCommaRange, with: "")
            }
        }
        
        return result
    }
    
    static func context(for session: Session, instance: SessionInstance? = nil) -> String {
        if let instance = instance {
            var result = timeFormatter.string(from: instance.startTime) + " - " + timeFormatter.string(from: instance.endTime)
            
            if let roomName = instance.room.first?.name {
                result += " - " + roomName
            }
            
            return result
        } else {
            let focusesArray = session.focuses.toArray()
            
            let focuses = SessionViewModel.focusesDescription(from: focusesArray, collapse: true)
            
            var result = session.track.first?.name ?? ""
            
            if focusesArray.count > 0 {
                result = "\(focuses) - " + result
            }
            
            return result
        }
    }
    
    static func footer(for session: Session, at event: ConfCore.Event?) -> String {
        guard let event = event else { return "" }
        
        let year = Calendar.current.component(.year, from: event.startDate)
        
        let focusesArray = session.focuses.toArray()
        
        let allFocuses = SessionViewModel.focusesDescription(from: focusesArray, collapse: false)
        
        var result = "WWDC \(year) · Session \(session.number)"
        
        if focusesArray.count > 0 {
            result += " · \(allFocuses)"
        }
        
        return result
    }
    
    static func imageUrl(for session: Session) -> URL? {
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

extension SessionViewModel: IGListDiffable {
    
    func diffIdentifier() -> NSObjectProtocol {
        return identifier as NSObjectProtocol
    }
    
    func isEqual(toDiffableObject object: IGListDiffable?) -> Bool {
        guard let other = object as? SessionViewModel else { return false }
        
        return self.identifier == other.identifier &&
                self.title == other.title &&
                self.subtitle == other.subtitle &&
                self.context == other.context &&
                self.imageUrl == other.imageUrl &&
                self.color == other.color
    }
    
}

extension SessionViewModel: UserActivityRepresentable { }

extension SessionViewModel {
    
    var isFavorite: Bool {
        return session.favorites.count > 0
    }
    
}
