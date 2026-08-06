import Foundation

/// Google Books arama uç noktasının doğrudan uygulama yanıtı.
public struct BookSearchResult: Decodable, Sendable {
    public let totalItems: Int
    public let items: [Book]

    enum CodingKeys: String, CodingKey {
        case totalItems, items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalItems = try container.decodeIfPresent(Int.self, forKey: .totalItems) ?? 0
        items = try container.decodeIfPresent([Book].self, forKey: .items) ?? []
    }
}
