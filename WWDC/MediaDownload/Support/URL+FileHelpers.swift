import Foundation

extension URL {
    var exists: Bool { FileManager.default.fileExists(atPath: path) }

    func createIfNeeded() throws {
        guard !exists else { return }

        try FileManager.default.createDirectory(at: self, withIntermediateDirectories: true)
    }

    func creatingIfNeeded() throws -> URL {
        try createIfNeeded()

        return self
    }

    func deletingIfNeeded(allowDirectory: Bool = false) throws -> URL {
        var isDir = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return self }

        guard allowDirectory || !isDir.boolValue else {
            throw "Refusing to delete existing directory at \(path)"
        }

        try FileManager.default.removeItem(at: self)

        return self
    }

    func moveToTemporaryLocation() throws -> URL {
        let newTempLocation = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(lastPathComponent)

        try FileManager.default.moveItem(at: self, to: newTempLocation)

        return newTempLocation
    }
}
