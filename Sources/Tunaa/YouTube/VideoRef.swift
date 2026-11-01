import Foundation

struct VideoRef: Identifiable, Equatable {
    let id: String
    let title: String
    let channel: String
    let thumbnailURL: URL
}
