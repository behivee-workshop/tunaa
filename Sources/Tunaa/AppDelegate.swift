import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var outsideClickMonitor: Any?
    private let player = YouTubePlayerController()
    private var nowPlaying: NowPlayingManager!
    private var nowPlayingTimer: Timer?

    private static let statusIcon: NSImage? = {
        let image = LucideIcons.image("headphones")
        image?.size = NSSize(width: 18, height: 18)
        return image
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)

        nowPlaying = NowPlayingManager(player: player)
        player.onEnded = { [weak player] in player?.playNext() }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.statusIcon
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseDown, .rightMouseUp])

        // A plain borderless panel instead of NSPopover: no arrow to keep aligned,
        // and we position it ourselves (half-screen, pinned top-right) with no
        // fighting against NSPopover's own (unreliable on this setup) placement math.
        let hosting = NSHostingController(rootView: ContentView(player: player))
        panel = KeyablePanel(contentViewController: hosting)
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.isMovable = false

        nowPlayingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.nowPlaying.update() }
        }

        if let videoId = ProcessInfo.processInfo.environment["TUNAA_DEBUG_VIDEO_ID"] {
            print("[Tunaa] debug direct load: \(videoId)")
            let ref = VideoRef(id: videoId, title: "Debug", channel: "Debug", thumbnailURL: URL(string: "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg")!)
            player.load(ref)
            player.play()
        } else if let query = ProcessInfo.processInfo.environment["TUNAA_DEBUG_QUERY"] {
            Task { [player] in
                print("[Tunaa] debug search: \(query)")
                let results = (try? await YouTubeScraper.search(query)) ?? []
                print("[Tunaa] debug search results: \(results.count)")
                if let first = results.first {
                    print("[Tunaa] debug selecting: \(first.id) \(first.title)")
                    player.load(first)
                    player.play()
                }
            }
        }
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button,
              let screen = button.window?.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = NSSize(width: visible.width / 2, height: visible.height / 2)
        let origin = NSPoint(x: visible.maxX - size.width, y: visible.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        panel.orderOut(nil)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func showMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()
        let playPauseItem = NSMenuItem(
            title: player.isPlaying ? "Pause" : "Play",
            action: #selector(togglePlayPauseFromMenu),
            keyEquivalent: ""
        )
        playPauseItem.target = self
        playPauseItem.isEnabled = player.current != nil
        menu.addItem(playPauseItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Tunaa", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func togglePlayPauseFromMenu() {
        player.togglePlayPause()
    }
}
