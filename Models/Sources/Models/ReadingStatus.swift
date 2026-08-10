import Foundation

public enum ReadingStatus: String, CaseIterable, Codable, Sendable {
    case toRead
    case reading
    case read
    case dnf
}
