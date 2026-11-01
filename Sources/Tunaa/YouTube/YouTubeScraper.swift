import Foundation

/// Gets search results and "up next" chaining by reading the same embedded JSON
/// (`ytInitialData`) that youtube.com's own pages render from. No API key involved,
/// since the YouTube Data API doesn't even expose this "up next" relation anymore.
enum YouTubeScraper {

    static func search(_ query: String) async throws -> [VideoRef] {
        var components = URLComponents(string: "https://www.youtube.com/results")!
        components.queryItems = [URLQueryItem(name: "search_query", value: query)]
        let html = try await fetchHTML(components.url!)
        guard let json = extractJSONObject(after: "ytInitialData = ", in: html) else { return [] }
        var renderers: [[String: Any]] = []
        collectRenderers(json, keys: ["videoRenderer"], into: &renderers)
        return renderers.compactMap(videoRef(from:))
    }

    static func upNext(after videoId: String) async throws -> VideoRef? {
        let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)")!
        let html = try await fetchHTML(url)
        guard let json = extractJSONObject(after: "ytInitialData = ", in: html) else { return nil }

        var autoplay: [[String: Any]] = []
        collectRenderers(json, keys: ["playerOverlayAutoplayRenderer"], into: &autoplay)
        if let ref = autoplay.first.flatMap(videoRef(from:)) { return ref }

        var compact: [[String: Any]] = []
        collectRenderers(json, keys: ["compactVideoRenderer"], into: &compact)
        return compact.first { ($0["videoId"] as? String) != videoId }.flatMap(videoRef(from:))
    }

    // MARK: - Fetch

    private static func fetchHTML(_ url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (data, _) = try await URLSession.shared.data(for: request)
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - ytInitialData extraction

    /// Finds `marker{...}` and returns the parsed JSON object, matching braces by hand
    /// (skipping over string contents) since the blob can be megabytes of nested JSON.
    private static func extractJSONObject(after marker: String, in html: String) -> Any? {
        guard let markerRange = html.range(of: marker) else { return nil }
        let rest = html[markerRange.upperBound...]
        guard let braceStart = rest.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false
        var i = braceStart
        var endIndex: String.Index?

        while i < rest.endIndex {
            let c = rest[i]
            if inString {
                if escaped {
                    escaped = false
                } else if c == "\\" {
                    escaped = true
                } else if c == "\"" {
                    inString = false
                }
            } else if c == "\"" {
                inString = true
            } else if c == "{" {
                depth += 1
            } else if c == "}" {
                depth -= 1
                if depth == 0 {
                    endIndex = i
                    break
                }
            }
            i = rest.index(after: i)
        }

        guard let end = endIndex,
              let data = rest[braceStart...end].data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func collectRenderers(_ node: Any, keys: Set<String>, into results: inout [[String: Any]]) {
        if let dict = node as? [String: Any] {
            for key in keys {
                if let renderer = dict[key] as? [String: Any] {
                    results.append(renderer)
                }
            }
            for value in dict.values {
                collectRenderers(value, keys: keys, into: &results)
            }
        } else if let array = node as? [Any] {
            for value in array {
                collectRenderers(value, keys: keys, into: &results)
            }
        }
    }

    // MARK: - Renderer -> VideoRef

    private static func videoRef(from renderer: [String: Any]) -> VideoRef? {
        guard let id = renderer["videoId"] as? String else { return nil }
        let title = extractText(renderer["title"]) ?? "Untitled"
        let channel = ["ownerText", "longBylineText", "shortBylineText"]
            .compactMap { extractText(renderer[$0]) }
            .first ?? ""
        let thumbnail = extractThumbnail(renderer) ?? URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")!
        return VideoRef(id: id, title: title, channel: channel, thumbnailURL: thumbnail)
    }

    private static func extractText(_ node: Any?) -> String? {
        guard let dict = node as? [String: Any] else { return nil }
        if let simple = dict["simpleText"] as? String { return simple }
        if let runs = dict["runs"] as? [[String: Any]], let text = runs.first?["text"] as? String { return text }
        return nil
    }

    private static func extractThumbnail(_ renderer: [String: Any]) -> URL? {
        guard let thumb = renderer["thumbnail"] as? [String: Any],
              let thumbs = thumb["thumbnails"] as? [[String: Any]],
              let urlString = thumbs.last?["url"] as? String else { return nil }
        return URL(string: urlString)
    }
}
