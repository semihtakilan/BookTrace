//
//  BookDetailViewModel.swift
//  BookTrace
//
//  Created by Semih TAKILAN on 3.08.2026.
//

import Foundation
import Observation
import FactoryKit
import Models

@MainActor
@Observable
final class BookDetailViewModel {
    let reference: BookReference
    private(set) var state: ViewState<WorkDetail> = .idle

    @ObservationIgnored
    @Injected(\.bookService)
    private var bookService

    init(reference: BookReference) {
        self.reference = reference
    }

    func load() async {
        state = .loading
        do {
            let detail = try await bookService.fetchWorkDetail(workKey: reference.workKey)
            state = .loaded(detail)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
