import SwiftUI
import AVFoundation
import WebKit

struct NowPlayingView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.melBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.melTextMuted)
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    if model.player.showWebFallback, let track = model.player.current {
                        YouTubeEmbedView(videoID: track.id)
                            .frame(maxWidth: .infinity)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    } else if let track = model.player.current {
                        VStack(spacing: 20) {
                            if let urlString = track.thumbnailURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().scaledToFill()
                                    } else {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.melAccent.opacity(0.15))
                                            .overlay(Image(systemName: "music.note").font(.system(size: 60, weight: .light)).foregroundColor(.melAccent))
                                    }
                                }
                                .frame(width: 280, height: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                            }

                            VStack(spacing: 6) {
                                Text(track.title)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.melTextPrimary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                Text(track.artist)
                                    .font(.system(size: 16))
                                    .foregroundColor(.melTextSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 24)

                            SliderView()
                                .padding(.horizontal, 24)

                            HStack(spacing: 40) {
                                Button { model.player.previous() } label: {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.melTextPrimary)
                                }
                                Button { model.player.toggle() } label: {
                                    Image(systemName: model.player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 36, weight: .medium))
                                        .foregroundColor(.melTextPrimary)
                                        .frame(width: 64, height: 64)
                                        .background(Color.melAccent)
                                        .clipShape(Circle())
                                }
                                Button { model.player.next() } label: {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.melTextPrimary)
                                }
                            }
                            .padding(.top, 8)

                            Spacer()

                            // Bottom actions
                            HStack(spacing: 24) {
                                Button {
                                    if let track = model.player.current {
                                        model.download(track)
                                    }
                                } label: {
                                    Image(systemName: model.player.current.flatMap { model.isDownloaded($0.id) ?? false } == true ? "arrow.down.circle.fill" : "arrow.down.circle")
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundColor(.melTextSecondary)
                                }
                                .disabled(model.player.current == nil)

                                Button {
                                    if let track = model.player.current {
                                        model.recordHistory(track)
                                    }
                                } label: {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundColor(.melTextSecondary)
                                }

                                Button {
                                    // add to playlist - could show sheet
                                } label: {
                                    Image(systemName: "text.badge.plus")
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundColor(.melTextSecondary)
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

struct SliderView: View {
    @EnvironmentObject var model: AppModel
    @State private var isEditing = false

    var body: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isEditing ? model.player.position : model.player.position },
                    set: { newValue in
                        if isEditing {
                            model.player.position = newValue
                        }
                    }
                ),
                in: 0...max(model.player.duration, 1),
                onEditingChanged: { editing in
                    isEditing = editing
                    if !editing {
                        model.player.seek(to: model.player.position)
                    }
                }
            )
            .tint(Color.melAccent)

            HStack {
                Text(Track.timeString(model.player.position))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.melTextSecondary)
                Spacer()
                Text(Track.timeString(model.player.duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.melTextSecondary)
            }
        }
    }
}

struct YouTubeEmbedView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        let html = """
        <!DOCTYPE html>
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
        <style>body,html{margin:0;padding:0;height:100%;background:#000}iframe{width:100%;height:100%;border:0}</style>
        </head><body>
        <iframe src="https://www.youtube-nocookie.com/embed/\(videoID)?autoplay=1&playsinline=1&controls=1&rel=0&modestbranding=1" allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}