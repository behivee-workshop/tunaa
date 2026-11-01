import SwiftUI

struct ContentView: View {
    @ObservedObject var player: YouTubePlayerController

    var body: some View {
        HStack(spacing: 0) {
            SearchPaneView { ref in
                player.load(ref)
                player.play()
            }
            Divider()
            PlayerPaneView(player: player)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
