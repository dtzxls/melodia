import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        if let track = model.player.current {
            Button {
                model.player.showNowPlaying = true
            } label: {
                HStack(spacing: 12) {
                    TrackThumb(url: track.thumbnailURL, size: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.melTextPrimary)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.caption)
                            .foregroundColor(.melTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button { model.player.toggle() } label: {
                        Image(systemName: model.player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.melTextPrimary)
                            .frame(width: 36, height: 36)
                            .background(Color.melAccent)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button { model.player.next() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.melTextSecondary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.melElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 10, y: -4)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .buttonStyle(.plain)
        }
    }
}