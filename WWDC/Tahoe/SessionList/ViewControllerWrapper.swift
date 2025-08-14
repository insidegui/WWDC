//
//  ViewControllerWrapper.swift
//  WWDC
//
//  Created by luca on 09.08.2025.
//  Copyright © 2025 Guilherme Rambo. All rights reserved.
//

import AppKit
import SwiftUI

struct ViewControllerWrapper: NSViewControllerRepresentable {
    let viewController: NSViewController
    var additionalSafeAreaInsets: EdgeInsets?
    func makeNSViewController(context: Context) -> NSViewController {
        viewController
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {
        if let inset = additionalSafeAreaInsets {
            nsViewController.viewIfLoaded?.additionalSafeAreaInsets = .init(top: inset.top, left: inset.leading, bottom: inset.bottom, right: inset.trailing)
        }
    }
}
