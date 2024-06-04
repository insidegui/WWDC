import Foundation
import RealmSwift

public class SessionChapter: Object, Decodable {
    @objc public dynamic var identifier = ""
    @objc public dynamic var start = 0
    @objc public dynamic var end = 0
    @objc public dynamic var title = ""

    public override class func primaryKey() -> String? {
        return "identifier"
    }

    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case start, end, title
    }

    public required convenience init(from decoder: Decoder) throws {
        self.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.start = try container.decode(Int.self, forKey: .start)
        self.end = try container.decode(Int.self, forKey: .end)
        self.title = try container.decode(String.self, forKey: .title)
    }

    func generateIdentifier(sessionId: String) {
        self.identifier = "\(sessionId)@\(start)-\(end)"
    }

}
