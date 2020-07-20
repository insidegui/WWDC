//
//  MultipleChoiceFilter.swift
//  WWDC
//
//  Created by Guilherme Rambo on 27/05/17.
//  Copyright © 2017 Guilherme Rambo. All rights reserved.
//

import Foundation

struct FilterOption: Equatable, Codable {
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

    var identifier: FilterIdentifier
    var isSubquery: Bool
    var collectionKey: String
    var modelKey: String
    var options: [FilterOption]
    private var _selectedOptions: [FilterOption] = [FilterOption]()
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

            if isSubquery {
                format = "SUBQUERY(\(collectionKey), $\(collectionKey), $\(collectionKey).\(modelKey) \(op) %@).@count > 0"
            } else {
                format = "\(modelKey) \(op) %@"
            }

            return NSPredicate(format: format, option.value)
        }

        return NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
    }

    init(identifier: FilterIdentifier, isSubquery: Bool, collectionKey: String, modelKey: String, options: [FilterOption], selectedOptions: [FilterOption], emptyTitle: String) {
        self.identifier = identifier
        self.isSubquery = isSubquery
        self.collectionKey = collectionKey
        self.modelKey = modelKey
        self.options = options
        self.emptyTitle = emptyTitle

        // Computed property
        self.selectedOptions = selectedOptions
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

