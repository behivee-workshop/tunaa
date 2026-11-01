import AppKit

/// NSPanel with a borderless style mask refuses keyboard focus by default, which
/// would silently block the search field from ever receiving typed input.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
