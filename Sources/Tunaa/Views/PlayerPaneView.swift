import SwiftUI
import WebKit

struct WebViewContainer: NSViewRepresentable {
    let webView: WKWebView
    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct PlayerPaneView: View {
    @ObservedObject var player: YouTubePlayerController

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // The real YouTube player lives here, fully covered by the cover art below.
                WebViewContainer(webView: player.webView)
                CoverArt(url: player.current?.thumbnailURL)
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .cornerRadius(14)

            VStack(spacing: 3) {
                Text(player.current?.title ?? "Nothing playing")
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(player.current?.channel ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { player.elapsed },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 1)
            )
            .tint(Theme.accent)
            .disabled(player.duration == 0)

            HStack {
                Text(format(player.elapsed)).font(.caption2).monospacedDigit()
                Spacer()
                Text(format(player.duration)).font(.caption2).monospacedDigit()
            }

            HStack(spacing: 28) {
                Button { player.playPrevious() } label: {
                    LucideIcon(name: "skip-back")
                        .frame(width: 20, height: 20)
                }
                Button { player.togglePlayPause() } label: {
                    LucideIcon(name: player.isPlaying ? "pause" : "play")
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Theme.accent)
                        .clipShape(Circle())
                }
                Button { player.playNext() } label: {
                    LucideIcon(name: "skip-forward")
                        .frame(width: 20, height: 20)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func format(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let total = Int(t)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct CoverArt: View {
    let url: URL?
    var body: some View {
        if let url {
            AsyncImage(url: url) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: {
                Color.black.opacity(0.8)
            }
        } else {
            Color.black.opacity(0.8)
        }
    }
}
