//
//  ScheduledSessionTableCellView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 06/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

class ScheduledSessionTableCellView: NSTableCellView {

    var session: Session! {
        willSet {
            kvoController.unobserve(session)
        }
        didSet {
            updateUI()
        }
    }
    
    @IBOutlet weak var titleTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var subtitleLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak fileprivate var titleField: NSTextField!
    @IBOutlet weak fileprivate var detailsField: NSTextField!
    @IBOutlet weak var favoriteIndicator: NSTextField!
    @IBOutlet weak var trackDecorationView: NSView! {
        didSet {
            trackDecorationView.wantsLayer = true
            trackDecorationView.layer = CALayer()
        }
    }
    @IBOutlet weak var liveIndicator: RoundRectLabel! {
        didSet {
            liveIndicator.tintColor = Theme.WWDCTheme.liveColor
            liveIndicator.title = "LIVE"
            
            if #available(OSX 10.11, *) {
                liveIndicator.font = NSFont.systemFont(ofSize: 9.0, weight: NSFontWeightMedium)
            } else {
                liveIndicator.font = NSFont.systemFont(ofSize: 9.0)
            }
        }
    }
    
    fileprivate lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        
        f.locale = Locale(identifier: "en")
        f.dateFormat = "E"
        
        return f
    }()
    
    fileprivate lazy var timeFormatter: DateFormatter = {
        let f = DateFormatter()
        
        f.timeStyle = .short
        
        return f
    }()
    
    var selected = false {
        didSet {
            updateTint()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        selected = false
        
        NotificationCenter.default.removeObserver(self)
        kvoController.unobserve(session)
    }
    
    fileprivate func updateUI() {
        kvoController.observe(session, keyPath: "favorite", options: .new, action: #selector(updateSessionFlags))
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: LiveSessionsListDidChangeNotification), object: nil, queue: OperationQueue.main, using: updateLive)
        
        titleField.stringValue = session.title
        
        updateSessionFlags()
        updateLive()
        colorizeRowView()
        updateTint()
    }
    
    fileprivate func updateDetail() {
        if let schedule = session.schedule {
            if let track = schedule.track { updateTrackDecorationWithTrack(track) }
            
            let day = schedule.isLive ? "" : dateFormatter.string(from: schedule.startsAt as Date) + " "
            let startTime = timeFormatter.string(from: schedule.startsAt as Date)
            let endTime = timeFormatter.string(from: schedule.endsAt as Date)
            
            detailsField.stringValue = "\(day)\(startTime) - \(endTime) − \(schedule.room)"
        } else {
            detailsField.stringValue = "\(session.year) - Session \(session.id) - \(session.track)"
        }
    }
    
    fileprivate func updateLive(_ node: Notification? = nil) {
        updateDetail()
        
        guard let schedule = session.schedule else { return }

        if schedule.isLive {
            liveIndicator.isHidden = false
            subtitleLeadingConstraint.constant = liveIndicator.bounds.size.width + CGFloat(4.0)
        } else {
            liveIndicator.isHidden = true
            subtitleLeadingConstraint.constant = 0.0
        }
    }
    
    fileprivate func updateTrackDecorationWithTrack(_ track: Track) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.0)
        trackDecorationView.layer?.backgroundColor = NSColor(hexString: track.color).cgColor
        CATransaction.commit()
    }
    
    @objc fileprivate func updateSessionFlags() {
        favoriteIndicator.isHidden = !session.favorite
        titleTrailingConstraint.constant = session.favorite ? 27.0 : 4.0
    }
    
    fileprivate var parentRowView: VideoTableRowView? {
        return superview as? VideoTableRowView
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        
        colorizeRowView()
    }
    
    fileprivate func colorizeRowView() {
        guard let rowView = parentRowView else { return }
        
        if let schedule = session.schedule, let track = schedule.track {
            rowView.themeBackgroundColor = NSColor(hexString: track.color)
            rowView.themeSeparatorColor = NSColor(hexString: track.darkColor) 
        } else {
            rowView.themeBackgroundColor = Theme.WWDCTheme.fillColor
            rowView.themeSeparatorColor = Theme.WWDCTheme.separatorColor
        }
    }
    
    override var backgroundStyle: NSBackgroundStyle {
        didSet {
            titleField.cell?.backgroundStyle = .light
            detailsField.cell?.backgroundStyle = .light
        }
    }
    
    func updateTint() {
        if selected {
            titleField.textColor = NSColor.white
            detailsField.textColor = NSColor.white
        } else {
            titleField.textColor = NSColor(calibratedWhite: 0.0, alpha: 0.95)
            detailsField.textColor = NSColor(calibratedWhite: 0.0, alpha: 0.70)
        }
    }
    
}
