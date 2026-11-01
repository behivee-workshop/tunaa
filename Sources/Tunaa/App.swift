import AppKit

@main
@MainActor
struct TunaaApp {
    static func main() {
        setvbuf(stdout, nil, _IONBF, 0)
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
