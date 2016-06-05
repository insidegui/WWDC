//
//  DockIconView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 05/06/16.
//  Copyright © 2016 Guilherme Rambo. All rights reserved.
//

import Cocoa

class DockIconView: NSView {

    private var dockTile: NSDockTile?
    
    private var year = "" {
        didSet {
            dockTile?.display()
        }
    }
    
    private lazy var formatter: NSDateFormatter = {
        let f = NSDateFormatter()
        
        f.dateFormat = "YYYY"
        
        return f
    }()
    
    init(dockTile: NSDockTile) {
        self.dockTile = dockTile
        
        super.init(frame: NSRect(x: 0, y: 0, width: dockTile.size.width, height: dockTile.size.height))
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(configure), name: WWDCWeekDidStartNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(configure), name: WWDCWeekDidEndNotification, object: nil)
        configure()
    }
    
    @objc private func configure() {
        if WWDCDatabase.sharedDatabase.config?.isWWDCWeek == true {
            year = formatter.stringFromDate(NSDate())
        } else {
            year = ""
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private var WWDCString: NSAttributedString  {
        let attrs = [
            NSFontAttributeName: NSFont.systemFontOfSize(bounds.height / 7.0),
            NSForegroundColorAttributeName: NSColor.whiteColor()
        ]
        return NSAttributedString(string: "WWDC", attributes: attrs)
    }
    
    private var yearString: NSAttributedString?  {
        guard !year.isEmpty else { return nil }
        
        let attrs = [
            NSFontAttributeName: NSFont.systemFontOfSize(bounds.height / 7.5),
            NSForegroundColorAttributeName: NSColor.whiteColor()
        ]
        return NSAttributedString(string: year, attributes: attrs)
    }
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        NSImage(named: "EmptyIcon")!.drawInRect(bounds, fromRect: NSZeroRect, operation: .CompositeSourceOver, fraction: 1.0)
        
        let title = WWDCString
        let titleSize = title.size()
        var yearSize = NSZeroSize
        
        if let yearString = yearString {
            yearSize = yearString.size()
            let yearPoint = NSPoint(x: round(bounds.width / 2.0 - yearSize.width / 2.0), y: round(bounds.height / 2.0 - titleSize.height / 2.0 - yearSize.height / 2.0))
            yearString.drawAtPoint(yearPoint)
        }
        
        let appNamePoint = NSPoint(x: round(bounds.width / 2.0 - titleSize.width / 2.0), y: round(bounds.height / 2.0 - titleSize.height / 2.0 + yearSize.height / 2.0))
        
        WWDCString.drawAtPoint(appNamePoint)
    }
    
}
