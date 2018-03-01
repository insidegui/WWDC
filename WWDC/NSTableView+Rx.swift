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

final class RxTableViewDelegateProxy: DelegateProxy<NSTableView, NSTableViewDelegate>, NSTableViewDelegate, DelegateProxyType {

    weak private(set) var tableView: NSTableView?

    fileprivate var selectedRowSubject = PublishSubject<Int?>()

    init(tableView: NSTableView) {
        self.tableView = tableView
        super.init(parentObject: tableView, delegateProxy: RxTableViewDelegateProxy.self)
    }

    static func registerKnownImplementations() {
        self.register(make: { RxTableViewDelegateProxy(tableView: $0)})
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let numberOfRows = tableView?.numberOfRows else { return }
        guard let selectedRow = tableView?.selectedRow else { return }

        let row: Int? = (0..<numberOfRows).contains(selectedRow) ? selectedRow : nil

        selectedRowSubject.on(.next(row))
    }

    static func currentDelegate(for object: NSTableView) -> NSTableViewDelegate? {
        return object.delegate
    }

    static func setCurrentDelegate(_ delegate: NSTableViewDelegate?, to object: NSTableView) {
        object.delegate = delegate
    }
}

extension Reactive where Base: NSTableView {

    public var delegate: DelegateProxy<NSTableView, NSTableViewDelegate> {
        return RxTableViewDelegateProxy.proxy(for: base)
    }

    public var selectedRow: ControlProperty<Int?> {
        let delegate = RxTableViewDelegateProxy.proxy(for: base)

        let source = Observable.deferred { [weak tableView = base] () -> Observable<Int?> in
            if let startingRow = tableView?.selectedRow, startingRow >= 0 {
                return delegate.selectedRowSubject.startWith(startingRow)
            } else {
                return delegate.selectedRowSubject.startWith(nil)
            }
            }.takeUntil(deallocated)

        let observer = Binder(base) { (control, value: Int?) in
            if let row = value {
                control.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            } else {
                control.deselectAll(nil)
            }
        }

        return ControlProperty(values: source, valueSink: observer.asObserver())
    }

}
