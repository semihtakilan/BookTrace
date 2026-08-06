//
//  HomeViewModel.swift
//  BookTrace
//
//  Created by Semih TAKILAN on 31.07.2026.
//

import Foundation
import Observation
import FactoryKit
import Models
import NetworkKit

struct BookCategory: Identifiable, Sendable {
    let id: String
    let displayName: String
    let books: [Book]
}

@MainActor
@Observable
final class HomeViewModel {
    private(set) var state: ViewState<[BookCategory]> = .idle

    @ObservationIgnored
    @Injected(\.bookSearching)
    private var bookSearching

    private let categories: [(key: String, displayName: String)] = [
        ("subject:fiction", "Kurgu"),
        ("subject:science fiction", "Bilim Kurgu"),
        ("subject:mystery", "Gizem"),
        ("subject:fantasy", "Fantastik")
    ]

    func load() async {
        state = .loading
        do {
            // Google Books başlangıçta dört eşzamanlı arama yerine sıralı çağrılır;
            // bu, geçici 503/rate-limit cevaplarının olasılığını azaltır.
            var results: [BookCategory] = []
            for category in categories {
                let books = try await bookSearching.searchBooks(query: category.key, maxResults: 10)
                results.append(
                    BookCategory(id: category.key, displayName: category.displayName, books: books)
                )
            }
            state = .loaded(results)
        } catch {
            state = .failed(userFacingMessage(for: error))
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if case NetworkError.serverError(let statusCode) = error, statusCode == 503 {
            return "Google Books geçici olarak kullanılamıyor. İstek otomatik olarak yeniden denendi; lütfen kısa süre sonra tekrar deneyin."
        }

        if case NetworkError.httpError(let statusCode, _, _) = error, statusCode == 503 {
            return "Google Books geçici olarak kullanılamıyor. İstek otomatik olarak yeniden denendi; lütfen kısa süre sonra tekrar deneyin."
        }

        guard case let NetworkError.networkError(underlying) = error,
              let urlError = underlying as? URLError else {
            return error.localizedDescription
        }

        switch urlError.code {
        case .secureConnectionFailed, .serverCertificateHasBadDate,
             .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid:
            return "Google Books ile güvenli bağlantı kurulamadı. Bu genellikle ağdaki VPN, proxy veya SSL incelemesinden kaynaklanır. Bu bağlantıları kapatıp tekrar deneyin."
        default:
            return error.localizedDescription
        }
    }
}
