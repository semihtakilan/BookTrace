import Foundation

public typealias APIModel = Codable & Sendable
public typealias NetworkModel = APIModel & Identifiable & Equatable & Hashable
