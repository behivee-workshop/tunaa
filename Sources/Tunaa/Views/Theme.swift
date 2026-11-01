import SwiftUI

/// Bright blue accent + soft pastel cards, pulled from design/design-inspiration.jpeg.
enum Theme {
    static let accent = Color(red: 0.11, green: 0.47, blue: 0.95)
    static let card = Color.accentColor.opacity(0.08)
    static let cardHover = Color.accentColor.opacity(0.14)
}
