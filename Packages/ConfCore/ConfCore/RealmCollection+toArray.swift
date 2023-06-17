import RealmSwift

extension List {
    public func toArray() -> [Element] { Array(self) }
}

extension Results {
    public func toArray() -> [Element] { Array(self) }
}
