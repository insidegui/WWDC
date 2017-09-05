//
//  NSTableView+Rx.swift
//  WWDC
//
//  Created by Guilherme Rambo on 11/02/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Cocoa
import RxSwift
import RxCocoa

final class RxTableViewDelegateProxy: DelegateProxy, NSTableViewDelegate, DelegateProxyType {

    weak private(set) var tableView: NSTableView?

    fileprivate var selectedRowSubject = PublishSubject<Int?>()

    required init(parentObject: AnyObject) {
        tableView = parentObject as? NSTableView

        super.init(parentObject: parentObject)
    }

    public override class func createProxyForObject(_ object: AnyObject) -> AnyObject {
        let control: NSTableView = object as! NSTableView
        return control.createRxDelegateProxy()
    }

    public class func currentDelegateFor(_ object: AnyObject) -> AnyObject? {
        let tableView: NSTableView = object as! NSTableView
        return tableView.delegate
    }

    public class func setCurrentDelegate(_ delegate: AnyObject?, toObject object: AnyObject) {
        let tableView: NSTableView = object as! NSTableView
        tableView.delegate = delegate as? NSTableViewDelegate
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let numberOfRows = tableView?.numberOfRows else { return }
        guard let selectedRow = tableView?.selectedRow else { return }

        let row: Int? = (0..<numberOfRows).contains(selectedRow) ? selectedRow : nil

        selectedRowSubject.on(.next(row))
    }

}

extension NSTableView {

    func createRxDelegateProxy() -> RxTableViewDelegateProxy {
        return RxTableViewDelegateProxy(parentObject: self)
    }

}

extension Reactive where Base: NSTableView {

    public var delegate: DelegateProxy {
        return RxTableViewDelegateProxy.proxyForObject(base)
    }

    public var selectedRow: ControlProperty<Int?> {
        let delegate = RxTableViewDelegateProxy.proxyForObject(base)

        let source = Observable.deferred { [weak tableView = base] () -> Observable<Int?> in
            if let startingRow = tableView?.selectedRow, startingRow >= 0 {
                return delegate.selectedRowSubject.startWith(startingRow)
            } else {
                return delegate.selectedRowSubject.startWith(nil)
            }
            }.takeUntil(deallocated)

        let observer = UIBindingObserver(UIElement: base) { (control, value: Int?) in
            if let row = value {
                control.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            } else {
                control.deselectAll(nil)
            }
        }

        return ControlProperty(values: source, valueSink: observer.asObserver())
    }
    
}
