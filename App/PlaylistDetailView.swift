import SwiftUI

struct PlaylistDetailView: View {
    @EnvironmentObject var model: AppModel
    @State private var showingAddSongs = false

    let playlist: Playlist

    var body: some View {
        let bindingPlaylist = Binding(
            get: { model.playlists.first(where: { $0.id == playlist.id }) ?? playlist },
            set: { _ in }
        )

        VStack(spacing: 0) {
            if playlist.tracks.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(bindingPlaylist.wrappedValue.tracks) { track in
                        TrackRow(
                            track: track,
                            onTap: { model.player.play(track, in: bindingPlaylist.wrappedValue.tracks) },
                            onDownload: { model.download(track) },
                            onRemoveDownload: { model.deleteDownload(track.id) },
                            onAddToPlaylist: { other in
                                guard other.id != playlist.id else { return }
                                model.addTrack(track, to: other.id)
                            },
                            onPlayNext: { playNext(track) },
                            isDownloaded: model.isDownloaded(track.id),
                            isDownloading: model.downloading.contains(track.id)
                        )
                        .listRowBackground(Color.melCard)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .onDelete { offsets in
                        bindingPlaylist.wrappedValue.tracks.remove(atOffsets: offsets)
                        model.savePlaylists()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.melBackground)
            }
        }
        .screenBackground()
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Adicionar músicas", systemImage: "plus") {
                        showingAddSongs = true
                    }
                    Button("Tocar tudo", systemImage: "play.fill") {
                        if !playlist.tracks.isEmpty {
                            model.player.play(playlist.tracks[0], in: playlist.tracks)
                        }
                    }
                    Button("Excluir playlist", systemImage: "trash", role: .destructive) {
                        if let idx = model.playlists.firstIndex(where: { $0.id == playlist.id }) {
                            model.playlists.remove(at: idx)
                            model.savePlaylists()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.melTextPrimary)
                }
            }
        }
        .sheet(isPresented: $showingAddSongs) {
            AddSongsToPlaylistView(playlist: playlist)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.melTextMuted)
            Text("Playlist vazia")
                .font(.title3.weight(.medium))
                .foregroundColor(.melTextSecondary)
            Text("Toque em \"Adicionar músicas\" para começar")
                .font(.subheadline)
                .foregroundColor(.melTextMuted)
            Button {
                showingAddSongs = true
            } label: {
                Label("Adicionar músicas", systemImage: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: 240)
                    .padding(.vertical, 14)
                    .background(Color.melAccent)
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
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

struct AddSongsToPlaylistView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let playlist: Playlist
    @State private var query = ""
    @State private var results: [Track] = []
    @State private var loading = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.melTextMuted)
                    TextField("Buscar para adicionar...", text: $query)
                        .foregroundColor(.melTextPrimary)
                        .textInputAutocapitalization(.never)
                        .onSubmit { performSearch(query) }
                        .onChange(of: query) { _, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty { results = []; return }
                            Task { try? await Task.sleep(nanoseconds: 400_000_000); guard !Task.isCancelled else { return }; await MainActor.run { performSearch(trimmed) } }
                        }
                    if !query.isEmpty {
                        Button { query = ""; results = [] } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.melTextMuted)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.melCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if loading {
                    Spacer()
                    ProgressView().tint(.melAccent)
                    Spacer()
                } else if !results.isEmpty {
                    List {
                        ForEach(results) { track in
                            TrackRow(
                                track: track,
                                onTap: { add(track) },
                                onDownload: { model.download(track) },
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
                    Text("Nenhum resultado").foregroundColor(.melTextSecondary)
                    Spacer()
                } else {
                    Spacer()
                }
            }
            .screenBackground()
            .navigationTitle("Adicionar à \(playlist.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func performSearch(_ text: String) {
        loading = true
        Task {
            do {
                let tracks = try await YouTubeAPI.search(text)
                await MainActor.run {
                    results = tracks
                    loading = false
                }
            } catch {
                await MainActor.run { loading = false }
            }
        }
    }

    private func add(_ track: Track) {
        model.addTrack(track, to: playlist.id)
        // Keep open for multiple additions
    }
}