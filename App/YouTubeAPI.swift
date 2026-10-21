import Foundation

struct StreamInfo {
    var url: URL
    var mimeType: String
    var bitrate: Int
    var byteLength: Int?
    var audioOnly: Bool
    var expiresAt: Date?
}

enum YouTubeAPIError: LocalizedError {
    case badResponse
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "O YouTube devolveu uma resposta inesperada."
        case .unavailable(let reason):
            return reason.isEmpty ? "Não consegui carregar esta faixa." : reason
        }
    }
}

enum YouTubeAPI {

    // MARK: - Public API

    static func search(_ query: String, limit: Int = 40) async throws -> [Track] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB",
                    "clientVersion": "2.20251015.01.00",
                    "hl": "pt",
                    "gl": "BR"
                ]
            ],
            "query": trimmed
        ]

        let json = try await post(
            path: "/youtubei/v1/search",
            body: body,
            headers: [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                "X-Youtube-Client-Name": "1",
                "X-Youtube-Client-Version": "2.20251015.01.00"
            ]
        )

        var tracks: [Track] = []
        var seen = Set<String>()

        walk(json) { node in
            guard let dict = node as? [String: Any] else { return }
            var parsed: Track?
            if let renderer = dict["videoRenderer"] as? [String: Any] {
                parsed = parseVideoRenderer(renderer)
            } else if let renderer = dict["compactVideoRenderer"] as? [String: Any] {
                parsed = parseVideoRenderer(renderer)
            } else if let lockup = dict["lockupViewModel"] as? [String: Any] {
                parsed = parseLockup(lockup)
            }
            if let track = parsed, !seen.contains(track.id) {
                seen.insert(track.id)
                tracks.append(track)
            }
        }

        if tracks.count > limit {
            tracks = Array(tracks.prefix(limit))
        }
        return tracks
    }

    static func stream(for videoID: String) async throws -> StreamInfo {
        // The iOS client with a modern version returns direct audio URLs.
        // Old client versions are rejected with FAILED_PRECONDITION.
        do {
            if let info = try await player(videoID: videoID, client: .ios) {
                return info
            }
        } catch {
            // try the next client
        }

        do {
            if let info = try await player(videoID: videoID, client: .androidVR) {
                return info
            }
        } catch {
            // fall through
        }

        throw YouTubeAPIError.unavailable("Não consegui carregar o áudio desta faixa.")
    }

    // MARK: - Player

    private enum PlayerClient {
        case ios
        case androidVR

        var context: [String: Any] {
            switch self {
            case .ios:
                return [
                    "clientName": "IOS",
                    "clientVersion": "20.14.4",
                    "deviceMake": "Apple",
                    "deviceModel": "iPhone15,3",
                    "osName": "iPhone",
                    "osVersion": "18.5.22F76",
                    "hl": "en",
                    "gl": "US"
                ]
            case .androidVR:
                return [
                    "clientName": "ANDROID_VR",
                    "clientVersion": "1.60.19",
                    "deviceMake": "Oculus",
                    "deviceModel": "Quest 3",
                    "osName": "Android",
                    "osVersion": "12L",
                    "hl": "en",
                    "gl": "US"
                ]
            }
        }

        var version: String {
            switch self {
            case .ios: return "20.14.4"
            case .androidVR: return "1.60.19"
            }
        }

        var headerName: String {
            switch self {
            case .ios: return "5"
            case .androidVR: return "28"
            }
        }

        var userAgent: String {
            switch self {
            case .ios:
                return "com.google.ios.youtube/20.14.4 (iPhone15,3; U; CPU iOS 18_5 like Mac OS X;)"
            case .androidVR:
                return "com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip"
            }
        }
    }

    private static func player(videoID: String, client: PlayerClient) async throws -> StreamInfo? {
        let body: [String: Any] = [
            "context": ["client": client.context],
            "videoId": videoID,
            "contentCheckOk": true,
            "racyCheckOk": true
        ]

        let json = try await post(
            path: "/youtubei/v1/player",
            body: body,
            headers: [
                "User-Agent": client.userAgent,
                "X-Youtube-Client-Name": client.headerName,
                "X-Youtube-Client-Version": client.version,
                "X-Origin": "https://www.youtube.com"
            ]
        )

        if let status = json["playabilityStatus"] as? [String: Any],
           let state = status["status"] as? String,
           state != "OK" {
            let reason = status["reason"] as? String ?? ""
            throw YouTubeAPIError.unavailable(reason)
        }

        guard let streaming = json["streamingData"] as? [String: Any] else {
            return nil
        }

        var candidates: [[String: Any]] = []
        if let adaptive = streaming["adaptiveFormats"] as? [[String: Any]] {
            candidates.append(contentsOf: adaptive)
        }
        if let formats = streaming["formats"] as? [[String: Any]] {
            candidates.append(contentsOf: formats)
        }

        var bestFormat: [String: Any]?
        var bestScore = Int.min

        for format in candidates {
            guard let urlString = format["url"] as? String, URL(string: urlString) != nil else { continue }
            let mime = (format["mimeType"] as? String) ?? ""
            let bitrate = intValue(format["averageBitrate"]) ?? intValue(format["bitrate"]) ?? 0

            var score = 0
            if mime.hasPrefix("audio/mp4") {
                score += 3000
            } else if mime.hasPrefix("audio/webm") {
                score += 2100
            } else if mime.hasPrefix("audio/") {
                score += 2000
            } else if mime.hasPrefix("video/mp4") {
                score += 1000
            } else {
                score += 100
            }
            score += min(bitrate / 1000, 500)

            if bestFormat == nil || score > bestScore {
                bestScore = score
                bestFormat = format
            }
        }

        if let format = bestFormat,
           let urlString = format["url"] as? String,
           let url = URL(string: urlString) {
            let mime = (format["mimeType"] as? String) ?? "audio/mp4"
            return StreamInfo(
                url: url,
                mimeType: mime,
                bitrate: intValue(format["averageBitrate"]) ?? intValue(format["bitrate"]) ?? 0,
                byteLength: intValue(format["contentLength"]),
                audioOnly: mime.hasPrefix("audio/"),
                expiresAt: expiry(from: urlString)
            )
        }

        if let hls = streaming["hlsManifestUrl"] as? String, let url = URL(string: hls) {
            return StreamInfo(
                url: url,
                mimeType: "application/x-mpegURL",
                bitrate: 0,
                byteLength: nil,
                audioOnly: true,
                expiresAt: expiry(from: hls)
            )
        }

        return nil
    }

    // MARK: - HTTP

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 90
        configuration.httpAdditionalHeaders = ["Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8"]
        return URLSession(configuration: configuration)
    }()

    private static func post(path: String, body: [String: Any], headers: [String: String]) async throws -> [String: Any] {
        guard let url = URL(string: "https://www.youtube.com" + path + "?prettyPrint=false") else {
            throw YouTubeAPIError.badResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw YouTubeAPIError.badResponse
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YouTubeAPIError.badResponse
        }
        return json
    }

    // MARK: - Parsing helpers

    private static func walk(_ node: Any, _ visit: (Any) -> Void) {
        visit(node)
        if let dict = node as? [String: Any] {
            for value in dict.values {
                walk(value, visit)
            }
        } else if let array = node as? [Any] {
            for value in array {
                walk(value, visit)
            }
        }
    }

    private static func text(_ any: Any?) -> String? {
        guard let dict = any as? [String: Any] else { return nil }
        if let simple = dict["simpleText"] as? String {
            return simple
        }
        if let runs = dict["runs"] as? [[String: Any]] {
            let joined = runs.compactMap { $0["text"] as? String }.joined()
            return joined.isEmpty ? nil : joined
        }
        return nil
    }

    private static func thumbnails(_ any: Any?) -> [[String: Any]] {
        guard let dict = any as? [String: Any] else { return [] }
        if let thumbs = dict["thumbnails"] as? [[String: Any]] {
            return thumbs
        }
        return []
    }

    private static func bestThumbnail(_ any: Any?) -> String? {
        let thumbs = thumbnails(any)
        let sorted = thumbs.sorted {
            (($0["width"] as? Int) ?? 0) > (($1["width"] as? Int) ?? 0)
        }
        guard var url = sorted.first?["url"] as? String else { return nil }
        if url.hasPrefix("//") { url = "https:" + url }
        return url
    }

    private static func anyImageURL(_ any: Any?) -> String? {
        var found: String?
        walk(any) { node in
            guard found == nil,
                  let dict = node as? [String: Any],
                  let raw = dict["url"] as? String else { return }
            var url = raw
            if url.hasPrefix("//") { url = "https:" + url }
            if url.contains("ytimg.com") || url.contains("ggpht.com") || url.contains("googleusercontent.com") {
                found = url
            }
        }
        return found
    }

    private static let durationRegex = try! NSRegularExpression(pattern: "(\\d{1,2}):(\\d{2})(?::(\\d{2}))?")

    private static func seconds(from value: String) -> Int? {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = durationRegex.firstMatch(in: value, range: range) else { return nil }

        func group(_ index: Int) -> Int? {
            guard index < match.numberOfRanges,
                  let range = Range(match.range(at: index), in: value) else { return nil }
            return Int(value[range])
        }

        if let secs = group(3) {
            return (group(1) ?? 0) * 3600 + (group(2) ?? 0) * 60 + secs
        }
        return (group(1) ?? 0) * 60 + (group(2) ?? 0)
    }

    private static func intValue(_ any: Any?) -> Int? {
        if let value = any as? Int { return value }
        if let value = any as? NSNumber { return value.intValue }
        if let value = any as? String { return Int(value) }
        return nil
    }

    private static func isValidVideoID(_ id: String) -> Bool {
        guard id.count == 11 else { return false }
        return id.allSatisfy { character in
            character.isLetter || character.isNumber || character == "-" || character == "_"
        }
    }

    private static func expiry(from urlString: String) -> Date? {
        guard let components = URLComponents(string: urlString),
              let value = components.queryItems?.first(where: { $0.name == "expire" })?.value,
              let seconds = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static func parseVideoRenderer(_ dict: [String: Any]) -> Track? {
        guard let id = dict["videoId"] as? String, isValidVideoID(id) else { return nil }
        guard let title = text(dict["title"]), !title.isEmpty else { return nil }

        let artist = text(dict["ownerText"])
            ?? text(dict["longBylineText"])
            ?? text(dict["shortBylineText"])
            ?? "YouTube"

        guard let durationText = text(dict["lengthText"]),
              let duration = seconds(from: durationText) else {
            return nil
        }

        let thumbnail = bestThumbnail(dict["thumbnail"]) ?? anyImageURL(dict["thumbnail"])
        return Track(id: id, title: title, artist: artist, durationSeconds: duration, thumbnailURL: thumbnail)
    }

    private static func parseLockup(_ dict: [String: Any]) -> Track? {
        guard let id = dict["contentId"] as? String, isValidVideoID(id) else { return nil }
        guard let metadata = dict["metadata"] as? [String: Any],
              let metaViewModel = metadata["lockupMetadataViewModel"] as? [String: Any] else { return nil }
        guard let titleDict = metaViewModel["title"] as? [String: Any],
              let title = titleDict["content"] as? String,
              !title.isEmpty else { return nil }

        var parts: [String] = []
        if let meta = metaViewModel["metadata"] as? [String: Any],
           let contentMeta = meta["contentMetadataViewModel"] as? [String: Any],
           let rows = contentMeta["rows"] as? [[String: Any]] {
            for row in rows {
                guard let metadataParts = row["metadataParts"] as? [[String: Any]] else { continue }
                for part in metadataParts {
                    if let textDict = part["text"] as? [String: Any],
                       let content = textDict["content"] as? String,
                       !content.isEmpty {
                        parts.append(content)
                    }
                }
            }
        }

        let info = parts.joined(separator: " • ")
        let duration = seconds(from: info)
        let artist = parts.first(where: { seconds(from: $0) == nil }) ?? "YouTube"
        let thumbnail = anyImageURL(dict["contentImage"])

        return Track(id: id, title: title, artist: artist, durationSeconds: duration, thumbnailURL: thumbnail)
    }
}
