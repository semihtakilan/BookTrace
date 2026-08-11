import Foundation

public enum ReadingStatus: String, CaseIterable, Codable, Sendable {
    case library
    case wishlist
    case toRead
    case reading
    case finished
    case abandoned
    case starred
}
