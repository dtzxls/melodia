import Foundation

struct Track: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var artist: String
    var durationSeconds: Int?
    var thumbnailURL: String?

    var subtitle: String {
        var parts: [String] = []
        if !artist.isEmpty { parts.append(artist) }
        if let duration = durationSeconds, duration > 0 {
            parts.append(Track.timeString(duration))
        }
        return parts.joined(separator: " • ")
    }

    static func timeString(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        return timeString(Int(seconds.rounded()))
    }
}

struct Playlist: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var tracks: [Track]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, tracks: [Track] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.createdAt = createdAt
    }
}

struct LocalUser: Identifiable, Codable, Hashable {
    var id: UUID
    var username: String
    var passwordHash: String
    var salt: String
    var createdAt: Date
}

struct DownloadRecord: Identifiable, Codable, Hashable {
    var id: String
    var track: Track
    var fileName: String
    var bytes: Int64
    var downloadedAt: Date
}
