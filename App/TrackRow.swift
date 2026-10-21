import SwiftUI

struct TrackRow: View {
    let track: Track
    var showsDuration: Bool = true
    var showsArtist: Bool = true
    var onTap: (() -> Void)? = nil
    var onDownload: (() -> Void)? = nil
    var onRemoveDownload: (() -> Void)? = nil
    var onAddToPlaylist: ((Playlist) -> Void)? = nil
    var onPlayNext: (() -> Void)? = nil
    var isDownloaded: Bool = false
    var isDownloading: Bool = false

    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            TrackThumb(url: track.thumbnailURL, size: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.melTextPrimary)
                    .lineLimit(1)

                if showsArtist || showsDuration {
                    HStack(spacing: 4) {
                        if showsArtist {
                            Text(track.artist)
                                .font(.caption)
                                .foregroundColor(.melTextSecondary)
                                .lineLimit(1)
                        }
                        if showsDuration, let dur = track.durationSeconds {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.melTextMuted)
                            Text(Track.timeString(dur))
                                .font(.caption)
                                .foregroundColor(.melTextSecondary)
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            if isDownloading {
                ProgressView()
                    .frame(width: 24, height: 24)
            } else if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.melAccent)
            }

            Menu {
                if let onPlayNext {
                    Button("Tocar a seguir", systemImage: "text.badge.plus") { onPlayNext() }
                }
                if let onDownload, !isDownloaded && !isDownloading {
                    Button("Baixar", systemImage: "arrow.down.circle") { onDownload() }
                }
                if isDownloaded, let onRemoveDownload {
                    Button("Remover download", systemImage: "trash", role: .destructive) { onRemoveDownload() }
                }
                if let onAddToPlaylist, !model.playlists.isEmpty {
                    Menu("Adicionar à playlist") {
                        ForEach(model.playlists) { pl in
                            Button(pl.name) { onAddToPlaylist(pl) }
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.melTextSecondary)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .menuOrder(.fixed)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .padding(.vertical, 4)
    }
}

struct TrackThumb: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        ZStack {
            if let urlString = url, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Color.melElevated
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color.melElevated
                    @unknown default:
                        Color.melElevated
                    }
                }
            } else {
                Color.melElevated
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}