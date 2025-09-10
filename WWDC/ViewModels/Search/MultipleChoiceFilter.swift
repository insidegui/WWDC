//
//  MultipleChoiceFilter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct FilterOption: Equatable, Codable {
    private static let separatorTitle = "-------"
    private static let clearTitle = "Clear"

    let title: String
    let value: String
    var isNegative: Bool = false

    init(title: String, value: String, isNegative: Bool = false) {
        self.title = title
        self.value = value
        self.isNegative = isNegative
    }

    func negated(with newTitle: String) -> FilterOption {
        return FilterOption(title: newTitle, value: value, isNegative: true)
    }

    enum CodingKeys: String, CodingKey {
        case value, title
    }

    static var separator: FilterOption { .init(title: Self.separatorTitle, value: Self.separatorTitle) }
    static var clear: FilterOption { .init(title: Self.clearTitle, value: Self.clearTitle) }

    var isSeparator: Bool { title == Self.separatorTitle }
    var isClear: Bool { title == Self.clearTitle }
}

extension Array where Element == FilterOption {

    init?(_ fromArray: [Any]?) {

        guard let fromArray = fromArray as? [[String: String]] else {
            return nil
        }

        self = [FilterOption]()

        for i in fromArray {
            if let title = i["title"], let value = i["value"] {
                append(FilterOption(title: title, value: value))
            }
        }
    }

}

struct MultipleChoiceFilter: FilterType {
    private static func optionsWithClear(_ newValue: [FilterOption]) -> [FilterOption] {
        if !newValue.contains(.clear) {
            var withClear = newValue
            withClear.append(.separator)
            withClear.append(.clear)
            return withClear
        } else {
            return newValue
        }
    }

    var identifier: FilterIdentifier
    var collectionKey: String?
    var modelKey: String
    private var _options: [FilterOption]
    var options: [FilterOption] {
        get { _options }
        set { _options = Self.optionsWithClear(newValue) }
    }
    private var _selectedOptions: [FilterOption] = []
    var selectedOptions: [FilterOption] {
        get {
            return _selectedOptions
        }
        set {
            // For state preservation we ensure that selected options are actually part of the options that are available on this filter
            _selectedOptions = newValue.filter { options.contains($0) }
        }
    }

    var emptyTitle: String

    var isEmpty: Bool {
        return selectedOptions.isEmpty
    }

    var title: String {
        if isEmpty || selectedOptions.count == options.count {
            return emptyTitle
        } else {
            let t = selectedOptions.reduce("", { $0 + ", " + $1.title })

            guard !t.isEmpty else { return t }

            return String(t[t.index(t.startIndex, offsetBy: 2)...])
        }
    }

    var predicate: NSPredicate? {
        guard !isEmpty else { return nil }

        let subpredicates = selectedOptions.map { option -> NSPredicate in
            let format: String

            let op = option.isNegative ? "!=" : "=="

            if let collectionKey {
                format = "SUBQUERY(\(collectionKey), $iter, $iter.\(modelKey) \(op) %@).@count > 0"
            } else {
                format = "\(modelKey) \(op) %@"
            }

            return NSPredicate(format: format, option.value)
        }

        return NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }

    init(id identifier: FilterIdentifier, modelKey: String, collectionKey: String? = nil, options: [FilterOption], emptyTitle: String) {
        self.identifier = identifier
        self.collectionKey = collectionKey
        self.modelKey = modelKey
        self._options = Self.optionsWithClear(options)
        self.emptyTitle = emptyTitle
    }

    mutating func reset() {
        selectedOptions = []
    }

    var state: State {
        State(selectedOptions: selectedOptions)
    }

    struct State: Codable {
        let selectedOptions: [FilterOption]
    }
}
