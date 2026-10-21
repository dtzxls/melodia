import Foundation
import CryptoKit

enum Storage {
    static let folderName = "Melodia"

    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var usersFile: URL {
        root.appendingPathComponent("users.json")
    }

    static func userFolder(_ id: UUID) -> URL {
        let dir = root
            .appendingPathComponent("Users", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func playlistsFile(_ id: UUID) -> URL {
        userFolder(id).appendingPathComponent("playlists.json")
    }

    static func historyFile(_ id: UUID) -> URL {
        userFolder(id).appendingPathComponent("history.json")
    }

    static func downloadsFile(_ id: UUID) -> URL {
        userFolder(id).appendingPathComponent("downloads.json")
    }

    static func downloadsFolder(_ id: UUID) -> URL {
        let dir = userFolder(id).appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func load<T: Decodable>(_ type: T.Type, from url: URL, fallback: T) -> T {
        guard let data = try? Data(contentsOf: url) else { return fallback }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(T.self, from: data)) ?? fallback
    }

    static func save<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static var activeUserID: UUID? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "melodia.activeUser") else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            if let id = newValue {
                UserDefaults.standard.set(id.uuidString, forKey: "melodia.activeUser")
            } else {
                UserDefaults.standard.removeObject(forKey: "melodia.activeUser")
            }
        }
    }

    static func hash(password: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + ":" + password).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
