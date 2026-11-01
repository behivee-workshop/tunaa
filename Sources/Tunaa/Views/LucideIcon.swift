import SwiftUI

enum LucideIcons {
    /// Icons are packaged into Contents/Resources/Icons by build.sh, alongside the
    /// app's other resources (simpler than wiring an SPM resource bundle, which
    /// insists on sitting at the .app's root rather than inside Contents/).
    static func url(_ name: String) -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Icons/\(name).svg")
    }

    static func image(_ name: String) -> NSImage? {
        guard let url = url(name), let image = NSImage(contentsOf: url) else { return nil }
        image.isTemplate = true
        return image
    }
}

/// Renders a bundled Lucide (lucide.dev) SVG as a template image, so it tints via
/// .foregroundStyle like an SF Symbol would.
struct LucideIcon: View {
    let name: String

    var body: some View {
        if let image = LucideIcons.image(name) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "questionmark.square")
        }
    }
}
