import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var user: LocalUser?
    @Published var playlists: [Playlist] = []
    @Published var history: [Track] = []
    @Published var downloads: [DownloadRecord] = []
    @Published var downloading: Set<String> = []

    let player = PlayerController()

    init() {
        player.setModel(self)
        setupAudioSession()
        loadSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    // MARK: - Session

    private func loadSession() {
        if let id = Storage.activeUserID,
           let u = loadUsers().first(where: { $0.id == id }) {
            self.user = u
            loadUserData(for: u)
        }
    }

    func register(username: String, password: String) throws {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { throw AppError("Nome precisa ter pelo menos 3 caracteres.") }
        guard !password.isEmpty else { throw AppError("Senha não pode ser vazia.") }
        let users = loadUsers()
        guard !users.contains(where: { $0.username.lowercased() == trimmed.lowercased() }) else {
            throw AppError("Este nome já existe.")
        }
        let salt = UUID().uuidString.prefix(16).description
        let hash = Storage.hash(password: password, salt: salt)
        let newUser = LocalUser(
            id: UUID(),
            username: trimmed,
            passwordHash: hash,
            salt: salt,
            createdAt: Date()
        )
        var all = users
        all.append(newUser)
        Storage.save(all, to: Storage.usersFile)
        Storage.activeUserID = newUser.id
        self.user = newUser
        loadUserData(for: newUser)
    }

    func login(username: String, password: String) throws {
        let users = loadUsers()
        guard let u = users.first(where: { $0.username.lowercased() == username.lowercased() }) else {
            throw AppError("Usuário não encontrado.")
        }
        let hash = Storage.hash(password: password, salt: u.salt)
        guard hash == u.passwordHash else { throw AppError("Senha incorreta.") }
        Storage.activeUserID = u.id
        self.user = u
        loadUserData(for: u)
    }

    func logout() {
        Storage.activeUserID = nil
        self.user = nil
        self.playlists = []
        self.history = []
        self.downloads = []
        self.downloading.removeAll()
    }

    // MARK: - Persistence

    private func loadUsers() -> [LocalUser] {
        Storage.load([LocalUser].self, from: Storage.usersFile, fallback: [])
    }

    private func loadUserData(for user: LocalUser) {
        let pFile = Storage.playlistsFile(user.id)
        let hFile = Storage.historyFile(user.id)
        let dFile = Storage.downloadsFile(user.id)

        self.playlists = Storage.load([Playlist].self, from: pFile, fallback: [])
        self.history = Storage.load([Track].self, from: hFile, fallback: [])
        self.downloads = Storage.load([DownloadRecord].self, from: dFile, fallback: [])
    }

    private func savePlaylists() {
        guard let u = user else { return }
        Storage.save(playlists, to: Storage.playlistsFile(u.id))
    }

    private func saveHistory() {
        guard let u = user else { return }
        Storage.save(history, to: Storage.historyFile(u.id))
    }

    private func saveDownloads() {
        guard let u = user else { return }
        Storage.save(downloads, to: Storage.downloadsFile(u.id))
    }

    // MARK: - Playlists

    func createPlaylist(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let playlist = Playlist(name: trimmed)
        playlists.insert(playlist, at: 0)
        savePlaylists()
    }

    func renamePlaylist(_ id: UUID, to name: String) {
        guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[idx].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        savePlaylists()
    }

    func deletePlaylist(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        savePlaylists()
    }

    func addTrack(_ track: Track, to playlistID: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        if !playlists[idx].tracks.contains(where: { $0.id == track.id }) {
            playlists[idx].tracks.append(track)
            savePlaylists()
        }
    }

    func removeTrack(_ trackID: String, from playlistID: UUID) {
        guard let idx = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[idx].tracks.removeAll { $0.id == trackID }
        savePlaylists()
    }

    // MARK: - History

    func recordHistory(_ track: Track) {
        history.removeAll { $0.id == track.id }
        history.insert(track, at: 0)
        if history.count > 100 { history = Array(history.prefix(100)) }
        saveHistory()
    }

    // MARK: - Downloads

    func localURL(for videoID: String) -> URL? {
        guard let u = user else { return nil }
        let folder = Storage.downloadsFolder(u.id)
        let file = folder.appendingPathComponent("\(videoID).m4a")
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }

    func isDownloaded(_ videoID: String) -> Bool {
        localURL(for: videoID) != nil
    }

    func download(_ track: Track) {
        guard let u = user else { return }
        guard !downloading.contains(track.id) else { return }
        downloading.insert(track.id)

        Task {
            do {
                let info = try await YouTubeAPI.stream(for: track.id)
                let folder = Storage.downloadsFolder(u.id)
                let dest = folder.appendingPathComponent("\(track.id).m4a")

                // Use download delegate for progress? For simplicity: bytes stream.
                let (bytes, response) = try await URLSession.shared.bytes(from: info.url)
                var data = Data()
                let expected = response.expectedContentLength
                var received: Int64 = 0

                for try await byte in bytes {
                    data.append(byte)
                    received += 1
                }

                try data.write(to: dest, options: .atomic)

                let record = DownloadRecord(
                    id: track.id,
                    track: track,
                    fileName: dest.lastPathComponent,
                    bytes: Int64(data.count),
                    downloadedAt: Date()
                )
                await MainActor.run {
                    self.downloading.remove(track.id)
                    self.downloads.removeAll { $0.id == track.id }
                    self.downloads.insert(record, at: 0)
                    self.saveDownloads()
                }
            } catch {
                await MainActor.run {
                    self.downloading.remove(track.id)
                }
                print("Download failed: \(error)")
            }
        }
    }

    func deleteDownload(_ videoID: String) {
        guard let u = user else { return }
        let folder = Storage.downloadsFolder(u.id)
        let file = folder.appendingPathComponent("\(videoID).m4a")
        try? FileManager.default.removeItem(at: file)
        downloads.removeAll { $0.id == videoID }
        saveDownloads()
    }
}

struct AppError: LocalizedError {
    var message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}