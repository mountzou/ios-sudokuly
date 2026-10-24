import Foundation
import CryptoKit

/// Keeps unacknowledged results across termination and sign-out, separately for each UID.
struct GameHistoryOutbox: GameHistoryPendingStorage {
    let ownerID: String
    private let fileURL: URL

    init(ownerID: String, directory: URL? = nil) {
        self.ownerID = ownerID
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sudokuly/HistoryOutbox", isDirectory: true)
        let name = SHA256.hash(data: Data(ownerID.utf8)).map { String(format: "%02x", $0) }.joined()
        fileURL = root.appendingPathComponent(name + ".json")
    }

    func load() throws -> [GameRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([GameRecord].self, from: Data(contentsOf: fileURL))
            .filter { $0.ownerID == ownerID }
    }

    func replace(_ records: [GameRecord]) throws {
        let owned = records.filter { $0.ownerID == ownerID }
        if owned.isEmpty {
            if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
            return
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var url = fileURL.deletingLastPathComponent()
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        try JSONEncoder().encode(owned).write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
