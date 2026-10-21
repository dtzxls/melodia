import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var model: AppModel
    @State private var showingNewPlaylist = false
    @State private var newPlaylistName = ""
    @State private var editingPlaylist: Playlist?

    var body: some View {
        NavigationStack {
            List {
                if !model.downloads.isEmpty {
                    Section {
                        ForEach(model.downloads) { record in
                            TrackRow(
                                track: record.track,
                                onTap: { model.player.play(record.track, in: model.downloads.map(\.track)) },
                                onRemoveDownload: { model.deleteDownload(record.id) },
                                isDownloaded: true
                            )
                            .listRowBackground(Color.melCard)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    } header: {
                        HStack {
                            Text("Downloads")
                                .font(.title3.bold())
                                .foregroundColor(.melTextPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section {
                    ForEach(model.playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlist: playlist)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.melAccent.opacity(0.15))
                                        .overlay(
                                            Image(systemName: "music.note.list")
                                                .font(.system(size: 24, weight: .light))
                                                .foregroundColor(.melAccent)
                                        )
                                    if let first = playlist.tracks.first,
                                       let urlString = first.thumbnailURL,
                                       let url = URL(string: urlString) {
                                        AsyncImage(url: url) { phase in
                                            if case .success(let image) = phase {
                                                image.resizable().scaledToFill()
                                            }
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                }
                                .frame(width: 52, height: 52)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.melTextPrimary)
                                        .lineLimit(1)
                                    Text("\(playlist.tracks.count) músicas")
                                        .font(.caption)
                                        .foregroundColor(.melTextSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.melCard)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .contextMenu {
                            Button("Renomear", systemImage: "pencil") {
                                editingPlaylist = playlist
                            }
                            Button("Excluir", systemImage: "trash", role: .destructive) {
                                if let idx = model.playlists.firstIndex(where: { $0.id == playlist.id }) {
                                    model.playlists.remove(at: idx)
                                    model.savePlaylists()
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Playlists")
                            .font(.title3.bold())
                            .foregroundColor(.melTextPrimary)
                        Spacer()
                        Button {
                            showingNewPlaylist = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.melAccent)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.melBackground)
            .screenBackground()
            .navigationTitle("Biblioteca")
            .toolbarBackground(.hidden, for: .navigationBar)
            .alert("Nova playlist", isPresented: $showingNewPlaylist) {
                TextField("Nome", text: $newPlaylistName)
                Button("Cancelar", role: .cancel) { newPlaylistName = "" }
                Button("Criar") {
                    let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        model.createPlaylist(named: name)
                        newPlaylistName = ""
                    }
                }
            }
            .alert("Renomear playlist", isPresented: Binding(
                get: { editingPlaylist != nil },
                set: { if !$0 { editingPlaylist = nil } }
            )) {
                TextField("Nome", text: Binding(
                    get: { editingPlaylist?.name ?? "" },
                    set: { editingPlaylist?.name = $0 }
                ))
                Button("Cancelar", role: .cancel) { editingPlaylist = nil }
                Button("Salvar") {
                    if let pl = editingPlaylist {
                        model.renamePlaylist(pl.id, to: pl.name)
                        editingPlaylist = nil
                    }
                }
            }
        }
    }
}