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
    /// ISBN sorgusu sürerken ekranda bir şey dönüyor olsun diye.
    private(set) var isResolvingBarcode = false
    var error: UserFacingError?

    @ObservationIgnored
    private let bookSearching: any BookSearching

    /// Raf yüklemesi view'ın `.task`'ına değil, view model'a bağlı.
    /// Aksi hâlde kullanıcı sekme değiştirince istek iptal oluyor ve raflar
    /// "iptal edildi" hatasıyla kalıyordu.
    @ObservationIgnored private var shelvesTask: Task<Void, Never>?

    init(bookSearching: any BookSearching) {
        self.bookSearching = bookSearching
    }

    var isShowingSearchResults: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Kategori rafları

    /// Rafları yalnızca bir kez doldurur; sekmeye her dönüşte ağa çıkmaz.
    func loadShelvesIfNeeded() {
        guard shelvesTask == nil else { return }
        shelvesTask = Task { [weak self] in
            await self?.loadPendingShelves()
        }
    }

    /// Tek bir rafı yeniden dener — "Try again" bunu çağırır.
    func retry(shelf: SubjectShelf) async {
        guard let index = shelves.firstIndex(where: { $0.id == shelf.id }) else { return }
        shelves[index].state = .loading
        shelves[index].state = await state(forShelfAt: index)
    }

    /// Aynı anda kaç rafın istek attığı.
    ///
    /// Altısı birden gidince Google Books isteklerin bir kısmına 503 dönüyordu ve
    /// kullanıcı ilk açılışta yarısı hatalı bir ekran görüyordu.
    private static let shelfConcurrencyLimit = 3

    private func loadPendingShelves() async {
        let pendingIndices = shelves.indices.filter { shelves[$0].state.isIdle }
        guard !pendingIndices.isEmpty else { return }

        for index in pendingIndices {
            shelves[index].state = .loading
        }

        await withTaskGroup(of: (Int, ViewState<[BookReference]>).self) { group in
            var remaining = pendingIndices.makeIterator()

            for _ in 0..<Self.shelfConcurrencyLimit {
                guard let index = remaining.next() else { break }
                let subject = shelves[index].subject
                group.addTask { [bookSearching] in
                    (index, await Self.loadShelf(subject: subject, using: bookSearching))
                }
            }

            // Biten her rafın yerine bir yenisi girer; pencere hiç genişlemez.
            while let (index, state) = await group.next() {
                shelves[index].state = state

                guard let next = remaining.next() else { continue }
                let subject = shelves[next].subject
                group.addTask { [bookSearching] in
                    (next, await Self.loadShelf(subject: subject, using: bookSearching))
                }
            }
        }

        // İptal yüzünden başa dönen raf kaldıysa bir sonraki deneme serbest olsun.
        if shelves.contains(where: { $0.state.isIdle }) {
            shelvesTask = nil
        }
    }

    /// Rafı yükler; geçici bir hatada kısa bir gecikmeyle bir kez daha dener.
    ///
    /// Elle "Try again"e basıldığında raflar ilk seferde geliyordu, yani bu
    /// hatalar kalıcı değil — kullanıcıya göstermeden önce bir şans daha veriyoruz.
    private static func loadShelf(
        subject: BookSubject,
        using bookSearching: any BookSearching
    ) async -> ViewState<[BookReference]> {
        let attemptLimit = 2

        for attempt in 1...attemptLimit {
            do {
                return .loaded(try await bookSearching.books(inSubject: subject.query, maxResults: 15))
            } catch {
                // İptal bir hata değil: raf başa döner, sonraki girişte yeniden denenir.
                guard let userError = UserFacingError(error) else { return .idle }
                guard userError.isRetryable, attempt < attemptLimit else { return .failed(userError) }

                try? await Task.sleep(for: .milliseconds(600))
                if Task.isCancelled { return .idle }
            }
        }

        return .idle
    }

    private func state(forShelfAt index: Int) async -> ViewState<[BookReference]> {
        do {
            let books = try await bookSearching.books(inSubject: shelves[index].subject.query, maxResults: 15)
            return .loaded(books)
        } catch {
            guard let userError = UserFacingError(error) else { return .idle }
            return .failed(userError)
        }
    }

    // MARK: - Arama

    func performSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchState = .idle
            return
        }

        searchState = .loading
        do {
            searchState = .loaded(try await bookSearching.searchBooks(query: query, maxResults: 20))
        } catch {
            // Kullanıcı yazmaya devam ettiyse arama iptal edilir; bu bir hata değil.
            guard let userError = UserFacingError(error) else {
                searchState = .idle
                return
            }
            searchState = .failed(userError)
        }
    }

    func clearSearch() {
        searchText = ""
        searchState = .idle
    }

    // MARK: - Barkod

    /// Barkoddan gelen ISBN'i kitaba çevirir ve detay akışına bağlar.
    ///
    /// Sheet kapandıktan sonra sorgu birkaç saniye sürebiliyor; bu sürede
    /// ekranda hiçbir şey olmayınca uygulama donmuş görünüyordu.
    func handleBarcodeScan(isbn: String) async {
        isResolvingBarcode = true
        defer { isResolvingBarcode = false }

        do {
            scannedBook = try await bookSearching.findBook(isbn: isbn)
        } catch let scanError {
            self.error = UserFacingError(scanError)
        }
    }
}
