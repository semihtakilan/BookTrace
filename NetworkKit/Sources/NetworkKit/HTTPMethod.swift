import Foundation

public enum HTTPMethod: String, Sendable, CaseIterable {
    case GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS

    public var supportsBody: Bool { [.POST, .PUT, .PATCH].contains(self) }
    public var isIdempotent: Bool { ![.POST, .PATCH].contains(self) }
    public var isSafe: Bool { [.GET, .HEAD, .OPTIONS].contains(self) }
}
