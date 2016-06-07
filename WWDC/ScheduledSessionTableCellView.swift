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
            KVOController.unobserve(session)
        }
        didSet {
            updateUI()
        }
    }
    
    @IBOutlet weak var titleTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var subtitleLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak private var titleField: NSTextField!
    @IBOutlet weak private var detailsField: NSTextField!
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
                liveIndicator.font = NSFont.systemFontOfSize(9.0, weight: NSFontWeightMedium)
            } else {
                liveIndicator.font = NSFont.systemFontOfSize(9.0)
            }
        }
    }
    
    private lazy var dateFormatter: NSDateFormatter = {
        let f = NSDateFormatter()
        
        f.locale = NSLocale(localeIdentifier: "en")
        f.dateFormat = "E"
        
        return f
    }()
    
    private lazy var timeFormatter: NSDateFormatter = {
        let f = NSDateFormatter()
        
        f.dateFormat = "HH:mm"
        
        return f
    }()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        NSNotificationCenter.defaultCenter().removeObserver(self)
        KVOController.unobserve(session)
    }
    
    private func updateUI() {
        KVOController.observe(session, keyPath: "favorite", options: .New, action: #selector(updateSessionFlags))
        
        NSNotificationCenter.defaultCenter().addObserverForName(LiveSessionsListDidChangeNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: updateLive)
        
        titleField.stringValue = session.title
        
        updateSessionFlags()
        updateLive()
    }
    
    private func updateDetail() {
        if let schedule = session.schedule {
            if let track = schedule.track { updateTrackDecorationWithTrack(track) }
            
            let day = schedule.isLive ? "" : dateFormatter.stringFromDate(schedule.startsAt) + " "
            let startTime = timeFormatter.stringFromDate(schedule.startsAt)
            let endTime = timeFormatter.stringFromDate(schedule.endsAt)
            
            detailsField.stringValue = "\(day)\(startTime) - \(endTime) − \(schedule.room)"
        } else {
            detailsField.stringValue = "\(session.year) - Session \(session.id) - \(session.track)"
        }
    }
    
    private func updateLive(node: NSNotification? = nil) {
        updateDetail()
        
        guard let schedule = session.schedule else { return }

        if schedule.isLive {
            liveIndicator.hidden = false
            subtitleLeadingConstraint.constant = liveIndicator.bounds.size.width + CGFloat(4.0)
        } else {
            liveIndicator.hidden = true
            subtitleLeadingConstraint.constant = 0.0
        }
    }
    
    private func updateTrackDecorationWithTrack(track: Track) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.0)
        trackDecorationView.layer?.backgroundColor = NSColor(hexString: track.color)?.CGColor
        CATransaction.commit()
    }
    
    @objc private func updateSessionFlags() {
        favoriteIndicator.hidden = !session.favorite
        titleTrailingConstraint.constant = session.favorite ? 27.0 : 4.0
    }
    
}
