//
//  BookService.swift
//  BookTrace
//
//  Created by Semih TAKILAN on 31.07.2026.
//

import FactoryKit
import NetworkKit
import Models

protocol BookService: Sendable {
    func fetchBook(isbn: String) async throws -> Book
    func fetchSubject(_ subject: String, limit: Int) async throws -> [BookReference]
    func fetchWorkDetail(workKey: String) async throws -> WorkDetail
}

final class BookServiceLive: BookService {

    @Injected(\.networkService)
    private var networkService

    nonisolated init() {}

    func fetchBook(isbn: String) async throws -> Book {
        let response = try await networkService.execute(BookByISBNEndpoint(isbn: isbn))
        guard let book = response["ISBN:\(isbn)"] else {
            throw NetworkError.notFound()
        }
        return book
    }

    func fetchSubject(_ subject: String, limit: Int = 10) async throws -> [BookReference] {
        let response = try await networkService.execute(SubjectEndpoint(subject: subject, limit: limit))
        return response.works.map(\.asBookReference)
    }

    func fetchWorkDetail(workKey: String) async throws -> WorkDetail {
        try await networkService.execute(WorkEndpoint(workKey: workKey))
    }
}

extension Container {
    var bookService: Factory<BookService> { self { BookServiceLive() } }
}
