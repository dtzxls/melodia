import Foundation
import AVFoundation
import MediaPlayer

@MainActor
final class PlayerController: ObservableObject {
    @Published var current: Track?
    @Published var isPlaying = false
    @Published var position: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    @Published var showWebFallback = false
    @Published var showNowPlaying = false

    var queue: [Track] = []
    var queueIndex = 0

    private var player = AVPlayer()
    private var timeObserver: Any?
    private var model: AppModel?

    func setModel(_ model: AppModel) {
        self.model = model
    }

    func play(_ track: Track, in queue: [Track]? = nil) {
        stopObserver()
        self.queue = queue ?? [track]
        self.queueIndex = self.queue.firstIndex(where: { $0.id == track.id }) ?? 0
        self.current = track
        self.isLoading = true
        self.showWebFallback = false
        Task { await loadAndPlay(track) }
    }

    private func loadAndPlay(_ track: Track) async {
        if let localURL = model?.localURL(for: track.id) {
            await startPlayback(localURL: localURL)
        } else {
            do {
                let info = try await YouTubeAPI.stream(for: track.id)
                await startPlayback(remoteURL: info.url)
            } catch {
                // Fallback to embedded web player
                await MainActor.run {
                    self.isLoading = false
                    self.showWebFallback = true
                }
            }
        }
    }

    private func startPlayback(localURL: URL? = nil, remoteURL: URL? = nil) async {
        let item: AVPlayerItem
        if let localURL = localURL {
            item = AVPlayerItem(url: localURL)
        } else if let remoteURL = remoteURL {
            item = AVPlayerItem(url: remoteURL)
        } else {
            return
        }

        await MainActor.run {
            player.replaceCurrentItem(with: item)
            addObserver()
            player.play()
            isPlaying = true
            isLoading = false
            showWebFallback = false
            showNowPlaying = true
            updateNowPlayingInfo()
        }
    }

    func toggle() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func next() {
        guard !queue.isEmpty else { return }
        queueIndex = (queueIndex + 1) % queue.count
        play(queue[queueIndex], in: queue)
    }

    func previous() {
        guard !queue.isEmpty else { return }
        queueIndex = (queueIndex - 1 + queue.count) % queue.count
        play(queue[queueIndex], in: queue)
    }

    func seek(to time: TimeInterval) {
        let target = CMTime(seconds: time, preferredTimescale: 1000)
        player.seek(to: target)
    }

    private func addObserver() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 1000), queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.position = time.seconds
            if let item = self.player.currentItem {
                self.duration = item.duration.seconds
            }
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    private func stopObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    @objc private func itemDidFinish() {
        Task { @MainActor in
            next()
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = current else { return }
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.artist
        if let artURL = track.thumbnailURL, let url = URL(string: artURL) {
            Task.detached {
                if let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                    }
                }
            }
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    deinit {
        stopObserver()
    }
}