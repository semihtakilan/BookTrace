import Foundation

/// Kullanıcının kitabı okuma yaşam döngüsündeki konumu.
public enum ReadingStatus: String, CaseIterable, Codable, Sendable {
    case toRead
    case reading
    case read
    case dnf
}
