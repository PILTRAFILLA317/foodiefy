import Foundation

// Only event IDs, timestamps and up to ten URLs. No auth or provider access.
enum ShareInbox {
    static let ttl: TimeInterval = 86400
    static func directory() throws -> URL {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "FoodiefyAppGroup") as? String,
              !group.isEmpty, !group.contains("$("),
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { throw NSError(domain: "FoodiefyShare", code: 1) }
        let directory = root.appendingPathComponent("share-inbox-v1", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    static func peek() throws -> [String: Any]? {
        let directory = try directory()
        var pending: [[String: Any]] = []
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey]) {
            guard url.pathExtension == "json" else { continue }
            let size = (try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
            guard size <= 65536,
                  let value = try? JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any],
                  let created = value["created"] as? Double,
                  Date().timeIntervalSince1970 - created / 1000 < ttl,
                  created / 1000 <= Date().timeIntervalSince1970 + 60
            else { try FileManager.default.removeItem(at: url); continue }
            pending.append(value)
        }
        return pending.sorted { ($0["created"] as? Double ?? 0) < ($1["created"] as? Double ?? 0) }.first
    }
    static func save(urls: [String]) throws {
        _ = try peek() // Collect expired events before enforcing the inbox bound.
        let directory = try directory()
        guard try FileManager.default.contentsOfDirectory(atPath: directory.path).count < 20 else {
            throw NSError(domain: "FoodiefyShare", code: 2)
        }
        let id = UUID().uuidString
        let value: [String: Any] = ["id": id, "created": Int64(Date().timeIntervalSince1970 * 1000), "urls": Array(urls.prefix(10))]
        let url = directory.appendingPathComponent(id + ".json")
        try JSONSerialization.data(withJSONObject: value).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        var mutable = url; try mutable.setResourceValues(values)
    }
    static func ack(_ id: String) throws {
        guard UUID(uuidString: id) != nil else { return }
        let url = try directory().appendingPathComponent(id + ".json")
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    static func urls(in text: String) -> [String] {
        guard text.utf8.count <= 32768 else { return [] }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        var urls: [String] = []
        for match in matches {
            guard let url = match.url, let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
                  url.host != nil, url.user == nil, url.password == nil, url.absoluteString.count <= 4096 else { continue }
            if !urls.contains(url.absoluteString) { urls.append(url.absoluteString) }
            if urls.count == 10 { break }
        }
        return urls
    }
}
