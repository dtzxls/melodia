import SwiftUI

struct SearchView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var results: [Track] = []
    @State private var loading = false
    @State private var message: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                if loading {
                    Spacer()
                    ProgressView()
                        .tint(.melAccent)
                    Spacer()
                } else if let message {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.melTextMuted)
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.melTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else if !results.isEmpty {
                    List {
                        ForEach(results) { track in
                            TrackRow(
                                track: track,
                                onTap: { select(track) },
                                onDownload: { download(track) },
                                onAddToPlaylist: { addToPlaylist(track, $0) },
                                onPlayNext: { playNext(track) },
                                isDownloaded: model.isDownloaded(track.id),
                                isDownloading: model.downloading.contains(track.id)
                            )
                            .listRowBackground(Color.melCard)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.melBackground)
                } else if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.melTextMuted)
                        Text("Nenhum resultado")
                            .font(.subheadline)
                            .foregroundColor(.melTextSecondary)
                    }
                    Spacer()
                } else {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 56, weight: .light))
                            .foregroundColor(.melTextMuted)
                        Text("Busque artistas, músicas ou álbuns")
                            .font(.title3.weight(.medium))
                            .foregroundColor(.melTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                }
            }
            .screenBackground()
            .navigationTitle("Buscar")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.melTextMuted)
            TextField("Músicas, artistas, álbuns...", text: $query)
                .foregroundColor(.melTextPrimary)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { performSearch(query) }
                .onChange(of: query) { _, newValue in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                results = []
                                message = nil
                            } else {
                                performSearch(trimmed)
                            }
                        }
                    }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    message = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.melTextMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.melCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func performSearch(_ text: String) {
        loading = true
        message = nil
        Task {
            do {
                let tracks = try await YouTubeAPI.search(text)
                await MainActor.run {
                    results = tracks
                    loading = false
                    if tracks.isEmpty {
                        message = "Nada encontrado para \"\(text)\""
                    }
                }
            } catch {
                await MainActor.run {
                    loading = false
                    message = "Erro ao buscar: \(error.localizedDescription)"
                }
            }
        }
    }

    private func select(_ track: Track) {
        model.recordHistory(track)
        model.player.play(track, in: results)
    }

    private func download(_ track: Track) {
        model.download(track)
    }

    private func addToPlaylist(_ track: Track, _ playlist: Playlist) {
        model.addTrack(track, to: playlist.id)
    }

    private func playNext(_ track: Track) {
        var newQueue = model.player.queue
        if let idx = newQueue.firstIndex(where: { $0.id == track.id }) {
            newQueue.remove(at: idx)
        }
        newQueue.insert(track, at: model.player.queueIndex + 1)
        model.player.queue = newQueue
    }
}