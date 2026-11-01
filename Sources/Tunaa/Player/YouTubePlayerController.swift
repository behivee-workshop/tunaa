import AppKit
import Combine
import WebKit

/// Runs the real YouTube IFrame Player inside a WKWebView that is never shown on
/// screen (the SwiftUI cover art sits on top of it in a ZStack) — so YouTube's own
/// playback/ad/DRM handling all just works, we just never let anyone see the video.
@MainActor
final class YouTubePlayerController: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {

    @Published private(set) var current: VideoRef?
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var elapsed: TimeInterval = 0

    var onEnded: (() -> Void)?

    let webView: WKWebView
    private var history: [VideoRef] = []
    private var pollTimer: Timer?
    private var isPageLoaded = false
    private var pendingCommands: [() -> Void] = []

    override init() {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 360, height: 203), configuration: config)
        super.init()
        config.userContentController.add(self, name: "tunaa")
        webView.navigationDelegate = self
        webView.loadHTMLString(Self.playerHTML, baseURL: URL(string: "https://tunaa.app"))
        startPolling()
    }

    func load(_ ref: VideoRef) {
        if let current, current.id != ref.id {
            history.append(current)
        }
        current = ref
        elapsed = 0
        duration = 0
        runWhenPageLoaded { [webView] in
            webView.evaluateJavaScript("tunaaLoad('\(ref.id)')") { _, error in
                if let error { print("[Tunaa] tunaaLoad JS error: \(error)") }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[Tunaa] webview didFail: \(error)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[Tunaa] webview didFailProvisional: \(error)")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isPageLoaded = true
        let pending = pendingCommands
        pendingCommands.removeAll()
        pending.forEach { $0() }
    }

    // The inline <script> that defines tunaaLoad/tunaaPlay/etc only exists once the
    // HTML document itself has finished loading — calls issued before that (which can
    // easily happen right after launch) hit an undefined function and silently fail.
    private func runWhenPageLoaded(_ command: @escaping () -> Void) {
        if isPageLoaded { command() } else { pendingCommands.append(command) }
    }

    func play() { runWhenPageLoaded { [webView] in webView.evaluateJavaScript("tunaaPlay()") } }
    func pause() { runWhenPageLoaded { [webView] in webView.evaluateJavaScript("tunaaPause()") } }
    func togglePlayPause() { isPlaying ? pause() : play() }

    func seek(to time: TimeInterval) {
        elapsed = time
        runWhenPageLoaded { [webView] in webView.evaluateJavaScript("tunaaSeek(\(time))") }
    }

    func playNext() {
        guard let current else { return }
        Task {
            if let next = try? await YouTubeScraper.upNext(after: current.id) {
                load(next)
                play()
            }
        }
    }

    func playPrevious() {
        guard let previous = history.popLast() else { return }
        current = previous
        elapsed = 0
        duration = 0
        runWhenPageLoaded { [webView] in webView.evaluateJavaScript("tunaaLoad('\(previous.id)')") }
        play()
    }

    // MARK: - JS bridge

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let event = body["event"] as? String else { return }
        print("[Tunaa] JS event: \(body)")
        switch event {
        case "stateChange":
            guard let state = body["state"] as? Int else { return }
            switch state {
            case 1: isPlaying = true; isBuffering = false
            case 2: isPlaying = false
            case 3: isBuffering = true
            case 0:
                isPlaying = false
                onEnded?()
            default: break
            }
        case "error":
            isPlaying = false
        default: break
        }
    }

    // MARK: - Polling for elapsed/duration (IFrame API has no push events for these)

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollTime() }
        }
    }

    private func pollTime() {
        webView.evaluateJavaScript("tunaaCurrentTime()") { [weak self] result, _ in
            guard let t = result as? Double else { return }
            Task { @MainActor in self?.elapsed = t }
        }
        webView.evaluateJavaScript("tunaaDuration()") { [weak self] result, _ in
            guard let d = result as? Double, d > 0 else { return }
            Task { @MainActor in self?.duration = d }
        }
        if ProcessInfo.processInfo.environment["TUNAA_DEBUG_VIDEO_ID"] != nil {
            webView.evaluateJavaScript("tunaaDebugInfo()") { result, _ in
                print("[Tunaa] debug info: \(result ?? "nil")")
            }
        }
    }

    private static let playerHTML = """
    <!DOCTYPE html><html><body style="margin:0">
    <div id="player"></div>
    <script src="https://www.youtube.com/iframe_api"></script>
    <script>
    var player;
    var isPlayerReady = false;
    var pendingVideoId = null;

    function onYouTubeIframeAPIReady() {
      player = new YT.Player('player', {
        height: '203', width: '360',
        playerVars: { playsinline: 1, controls: 0 },
        events: {
          onReady: function(e) {
            isPlayerReady = true;
            window.webkit.messageHandlers.tunaa.postMessage({event:'ready'});
            if (pendingVideoId) { player.loadVideoById(pendingVideoId); pendingVideoId = null; }
          },
          onStateChange: function(e) { window.webkit.messageHandlers.tunaa.postMessage({event:'stateChange', state: e.data}); },
          onError: function(e) { window.webkit.messageHandlers.tunaa.postMessage({event:'error', code: e.data}); }
        }
      });
    }
    // Player creation + its internal iframe take a beat to become ready; calls that
    // arrive before then are queued instead of silently dropped.
    function tunaaLoad(id) {
      if (isPlayerReady) { player.loadVideoById(id); } else { pendingVideoId = id; }
    }
    function tunaaPlay() { if (isPlayerReady) player.playVideo(); }
    function tunaaPause() { if (isPlayerReady) player.pauseVideo(); }
    function tunaaSeek(t) { if (isPlayerReady) player.seekTo(t, true); }
    function tunaaCurrentTime() { return isPlayerReady ? player.getCurrentTime() : 0; }
    function tunaaDuration() { return isPlayerReady ? player.getDuration() : 0; }
    function tunaaDebugInfo() {
      if (!isPlayerReady) return 'not ready';
      return JSON.stringify({
        state: player.getPlayerState(),
        loadedFraction: player.getVideoLoadedFraction(),
        url: player.getVideoUrl(),
        quality: player.getPlaybackQuality()
      });
    }
    </script>
    </body></html>
    """
}
