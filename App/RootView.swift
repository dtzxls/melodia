import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.user == nil {
                AuthView()
            } else {
                mainTabs
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Início", systemImage: "house.fill")
                }
                .safeAreaInset(edge: .bottom) { MiniPlayerView() }

            SearchView()
                .tabItem {
                    Label("Buscar", systemImage: "magnifyingglass")
                }
                .safeAreaInset(edge: .bottom) { MiniPlayerView() }

            LibraryView()
                .tabItem {
                    Label("Biblioteca", systemImage: "square.stack.fill")
                }
                .safeAreaInset(edge: .bottom) { MiniPlayerView() }
        }
        .tint(Color.melAccent)
        .fullScreenCover(isPresented: Binding(
            get: { model.player.showNowPlaying },
            set: { model.player.showNowPlaying = $0 }
        )) {
            NowPlayingView()
        }
    }
}