//
//  BookmarkViewController.swift
//  WWDC
//
//  Created by Guilherme Rambo on 28/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import ConfCore

final class BookmarkViewController: NSViewController {

    private let bookmark: Bookmark
    
    init(bookmark: Bookmark) {
        self.bookmark = bookmark
        
        super.init(nibName: nil, bundle: nil)!
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.appearance = WWDCAppearance.appearance()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
}
