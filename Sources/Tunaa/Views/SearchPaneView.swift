import SwiftUI

struct SearchPaneView: View {
    let onSelect: (VideoRef) -> Void

    @State private var query = ""
    @State private var results: [VideoRef] = []
    @State private var isSearching = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                LucideIcon(name: "search")
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Theme.accent)
                TextField("Search YouTube", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit(runSearch)
                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                    } label: {
                        LucideIcon(name: "circle-x")
                            .frame(width: 14, height: 14)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Theme.card)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Theme.accent, lineWidth: 2)
                    .opacity(isSearchFocused ? 1 : 0)
            )

            if isSearching {
                ProgressView().controlSize(.small)
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(results) { ref in
                        Button {
                            onSelect(ref)
                        } label: {
                            HStack(spacing: 10) {
                                AsyncImage(url: ref.thumbnailURL) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color.gray.opacity(0.2) }
                                    .frame(width: 90, height: 51)
                                    .clipped()
                                    .cornerRadius(8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ref.title).font(.caption).lineLimit(2)
                                    Text(ref.channel).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(6)
                            .background(Theme.card)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isSearching = true
        Task {
            let found = try? await YouTubeScraper.search(q)
            results = found ?? []
            isSearching = false
        }
    }
}
