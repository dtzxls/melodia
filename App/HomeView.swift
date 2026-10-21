import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var greeting: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if !model.history.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ouvidos recentemente")
                                .font(.title2.bold())
                                .foregroundColor(.melTextPrimary)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(model.history.prefix(10)) { track in
                                        VStack(alignment: .leading, spacing: 8) {
                                            TrackThumb(url: track.thumbnailURL, size: 160)
                                            Text(track.title)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.melTextPrimary)
                                                .lineLimit(1)
                                            Text(track.artist)
                                                .font(.caption)
                                                .foregroundColor(.melTextSecondary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 160)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            model.recordHistory(track)
                                            model.player.play(track, in: model.history)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    if !model.playlists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suas playlists")
                                .font(.title2.bold())
                                .foregroundColor(.melTextPrimary)
                                .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(model.playlists.prefix(10)) { playlist in
                                        PlaylistCard(playlist: playlist)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    if model.history.isEmpty && model.playlists.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 56, weight: .light))
                                .foregroundColor(.melTextMuted)
                            Text("Nada por aqui ainda")
                                .font(.title3.weight(.medium))
                                .foregroundColor(.melTextSecondary)
                            Text("Busque músicas e crie playlists para começar.")
                                .font(.subheadline)
                                .foregroundColor(.melTextMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 8)
            }
            .screenBackground()
            .navigationTitle("Início")
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                updateGreeting()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.melTextPrimary)
                Text("O que vamos ouvir hoje?")
                    .font(.subheadline)
                    .foregroundColor(.melTextSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func updateGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: greeting = "Bom dia"
        case 12..<18: greeting = "Boa tarde"
        default: greeting = "Boa noite"
        }
    }
}

struct PlaylistCard: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.melAccent.opacity(0.15))
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.melAccent)
                    )

                if let first = playlist.tracks.first,
                   let urlString = first.thumbnailURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(width: 160, height: 160)

            Text(playlist.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.melTextPrimary)
                .lineLimit(1)
            Text("\(playlist.tracks.count) músicas")
                .font(.caption)
                .foregroundColor(.melTextMuted)
        }
        .frame(width: 160)
    }
}