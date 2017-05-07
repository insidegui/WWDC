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

final class SessionViewModel: NSObject {
    
    let session: Session
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
        return Observable.from(object: self.session).map({ SessionViewModel.context(for: $0) })
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
    
    lazy var rxModelChange: Variable<Int> = {
        return Variable<Int>(0)
    }()
    
    init?(session: Session) {
        self.session = session
        
        guard let event = session.event.first else { return nil }
        guard let track = session.track.first else { return nil }
        
        self.trackName = track.name
        
        self.imageUrl = SessionViewModel.imageUrl(for: session)
        self.identifier = session.identifier
        self.title = session.title
        self.subtitle = SessionViewModel.subtitle(from: session, at: event)
        self.context = SessionViewModel.context(for: session)
        self.color = NSColor.fromHexString(hexString: track.lightColor)
        self.summary = session.summary
        self.footer = SessionViewModel.footer(for: session, at: event)
        self.webUrl = SessionViewModel.webUrl(for: session)
        
        super.init()
        
        // MARK: SELF-UPDATE
        
        self.rxTitle.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.title = newValue
            self?.rxModelChange.value += 1
        }).addDisposableTo(self.disposeBag)
        
        self.rxSubtitle.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.subtitle = newValue
            self?.rxModelChange.value += 1
        }).addDisposableTo(self.disposeBag)
        
        self.rxTrackName.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.trackName = newValue
            self?.rxModelChange.value += 1
        }).addDisposableTo(self.disposeBag)
        
        self.rxSummary.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.summary = newValue
            self?.rxModelChange.value += 1
        }).addDisposableTo(self.disposeBag)
        
        self.rxContext.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.context = newValue
            self?.rxModelChange.value += 1
        }).addDisposableTo(self.disposeBag)
        
        self.rxFooter.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.footer = newValue
            self?.rxModelChange.value += 1
        }).addDisposableTo(self.disposeBag)
        
        self.rxColor.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.color = newValue
            self?.rxModelChange.value += 1
        }).addDisposableTo(self.disposeBag)
        
        self.rxImageUrl.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.imageUrl = newValue
            self?.rxModelChange.value += 1
        }).addDisposableTo(self.disposeBag)
        
        self.rxWebUrl.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] newValue in
            self?.webUrl = newValue
            self?.rxModelChange.value += 1
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
    
    static func context(for session: Session) -> String {
        let focusesArray = session.focuses.toArray()
        
        let focuses = SessionViewModel.focusesDescription(from: focusesArray, collapse: true)
        
        var result = session.track.first?.name ?? ""
        
        if focusesArray.count > 0 {
            result = "\(focuses) - " + result
        }
        
        return result
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
