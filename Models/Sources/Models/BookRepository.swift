import Foundation

/// Kullanıcının yerel kitaplığını yöneten domain sözleşmesi.
@MainActor
public protocol BookRepository: AnyObject {
    func add(_ book: Book) throws
    func update(_ book: Book) throws
    func delete(id: String) throws
    func fetchBooks() throws -> [Book]
}
