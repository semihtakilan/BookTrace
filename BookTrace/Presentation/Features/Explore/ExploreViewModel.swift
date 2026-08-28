//
//  ExploreViewModel.swift
//  Explore
//
//  Created by Semih TAKILAN on 11.08.2026.
//

import Foundation
import Models
import Observation

/// Explore'daki tek bir kategori rafı ve yükleme durumu.
struct SubjectShelf: Identifiable {
    let subject: BookSubject
    var state: ViewState<[BookReference]> = .idle

    var id: String { subject.id }
}

@MainActor
@Observable
final class ExploreViewModel {
    var searchText: String = ""
    private(set) var searchState: ViewState<[BookReference]> = .idle
    private(set) var shelves: [SubjectShelf] = BookSubject.featured.map { SubjectShelf(subject: $0) }

    /// Barkod okunduğunda doldurulur; ekran bunu görüp detay sayfasına gider.
    var scannedBook: BookReference?
    var errorMessage: String?

    @ObservationIgnored
    private let bookSearching: any BookSearching

    init(bookSearching: any BookSearching) {
        self.bookSearching = bookSearching
    }

    var isShowingSearchResults: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Rafları yalnızca ilk açılışta doldurur; sekmeye her dönüşte ağa çıkmaz.
    ///
    /// Raflar birbirinden bağımsız olduğu için paralel yüklenir — sırayla
    /// beklemek ilk açılışı gereksiz yere uzatıyordu.
    func loadShelvesIfNeeded() async {
        let pendingIndices = shelves.indices.filter { shelves[$0].state.isIdle }
        guard !pendingIndices.isEmpty else { return }

        for index in pendingIndices {
            shelves[index].state = .loading
        }

        await withTaskGroup(of: (Int, ViewState<[BookReference]>).self) { group in
            for index in pendingIndices {
                let subject = shelves[index].subject
                group.addTask { [bookSearching] in
                    do {
                        let books = try await bookSearching.books(inSubject: subject.query, maxResults: 15)
                        return (index, .loaded(books))
                    } catch {
                        return (index, .failed(error.localizedDescription))
                    }
                }
            }

            for await (index, state) in group {
                shelves[index].state = state
            }
        }
    }

    func retry(shelf: SubjectShelf) async {
        guard let index = shelves.firstIndex(where: { $0.id == shelf.id }) else { return }
        await load(shelfAt: index)
    }

    func performSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchState = .idle
            return
        }

        searchState = .loading
        do {
            searchState = .loaded(try await bookSearching.searchBooks(query: query, maxResults: 20))
        } catch is CancellationError {
            // Kullanıcı yazmaya devam etti; bir sonraki arama sonucu gelecek.
        } catch {
            searchState = .failed(error.localizedDescription)
        }
    }

    func clearSearch() {
        searchText = ""
        searchState = .idle
    }

    /// Barkoddan gelen ISBN'i kitaba çevirir ve detay akışına bağlar.
    func handleBarcodeScan(isbn: String) async {
        do {
            scannedBook = try await bookSearching.findBook(isbn: isbn)
        } catch {
            errorMessage = "Scanned \(isbn), but no book matched it: \(error.localizedDescription)"
        }
    }

    private func load(shelfAt index: Int) async {
        let subject = shelves[index].subject
        shelves[index].state = .loading

        do {
            let books = try await bookSearching.books(inSubject: subject.query, maxResults: 15)
            shelves[index].state = .loaded(books)
        } catch {
            shelves[index].state = .failed(error.localizedDescription)
        }
    }
}
