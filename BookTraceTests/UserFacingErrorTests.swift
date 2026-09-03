//
//  UserFacingErrorTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation
import Models
import NetworkKit
import Testing
@testable import BookTrace

/// Uygulamadaki tek hata geçidi. Saf bir dönüşüm olduğu için doğrudan sınanabilir.
struct UserFacingErrorTests {

    // MARK: - İptal hata değildir

    @Test func cancellationProducesNoError() {
        #expect(UserFacingError(CancellationError()) == nil)
        #expect(UserFacingError(NetworkError.cancelled) == nil)
        #expect(UserFacingError(URLError(.cancelled)) == nil)
        #expect(UserFacingError(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)) == nil)
    }

    // MARK: - Kaynak hataları

    @Test func googleBooksErrorsMapToTheirOwnCases() {
        #expect(UserFacingError(GoogleBooksServiceError.bookNotFound) == .bookNotFound)
        #expect(UserFacingError(GoogleBooksServiceError.regionUnavailable("TR")) == .serviceUnavailable)
        #expect(UserFacingError(GoogleBooksServiceError.unreadableResponse) == .unexpectedResponse)
        #expect(UserFacingError(GoogleBooksServiceError.quotaExceeded(hasAPIKey: true))
                == .quotaExceeded(hasAPIKey: true))
        #expect(UserFacingError(GoogleBooksServiceError.quotaExceeded(hasAPIKey: false))
                == .quotaExceeded(hasAPIKey: false))
    }

    @Test func domainAndScannerErrorsMapToTheirOwnCases() {
        #expect(UserFacingError(CachedBookSearchingError.bookNotFound) == .bookNotFound)
        #expect(UserFacingError(LocalLibraryRepositoryError.entryNotFound("book-1")) == .notInLibrary)
        #expect(UserFacingError(ScannerError.noCameraAvailable) == .cameraUnavailable)
        #expect(UserFacingError(ScannerError.cannotAddInput) == .cameraUnavailable)
    }

    // MARK: - HTTP durum kodları

    @Test func statusCodesDecideTheMessage() {
        #expect(UserFacingError(NetworkError.rateLimited()) == .quotaExceeded(hasAPIKey: GoogleBooksAPIKey.value != nil))
        #expect(UserFacingError(NetworkError.forbidden()) == .quotaExceeded(hasAPIKey: GoogleBooksAPIKey.value != nil))
        #expect(UserFacingError(NetworkError.notFound()) == .bookNotFound)
        #expect(UserFacingError(NetworkError.serverError(statusCode: 503)) == .serviceUnavailable)
        #expect(UserFacingError(NetworkError.decodingError(CancellationError())) == .unexpectedResponse)
        #expect(UserFacingError(NetworkError.timeout()) == .timedOut)
    }

    @Test func connectionFailuresReadAsOffline() {
        #expect(UserFacingError(URLError(.notConnectedToInternet)) == .offline)
        #expect(UserFacingError(URLError(.networkConnectionLost)) == .offline)
        #expect(UserFacingError(URLError(.cannotFindHost)) == .offline)
        #expect(UserFacingError(NetworkError.networkError(URLError(.notConnectedToInternet))) == .offline)
        #expect(UserFacingError(URLError(.timedOut)) == .timedOut)
    }

    @Test func anythingElseFallsBackToUnknown() {
        struct Mystery: Error {}
        #expect(UserFacingError(Mystery()) == .unknown)
    }

    // MARK: - "Tekrar dene" butonunun görünürlüğü

    @Test func onlyRecoverableFailuresOfferARetry() {
        #expect(UserFacingError.offline.isRetryable)
        #expect(UserFacingError.timedOut.isRetryable)
        #expect(UserFacingError.serviceUnavailable.isRetryable)
        #expect(UserFacingError.quotaExceeded(hasAPIKey: false).isRetryable)
        #expect(UserFacingError.unknown.isRetryable)

        #expect(!UserFacingError.bookNotFound.isRetryable)
        #expect(!UserFacingError.notInLibrary.isRetryable)
        #expect(!UserFacingError.cameraUnavailable.isRetryable)
        #expect(!UserFacingError.unexpectedResponse.isRetryable)
    }
}
