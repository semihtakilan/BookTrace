//
//  OCRTextRecognitionTests.swift
//  BookTraceTests
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import Testing
@testable import BookTrace

struct OCRTextRecognitionTests {
    @Test func languageSelectionUsesOnlyRuntimeSupportedLanguages() {
        #expect(OCRTextRecognition.supportedPreferences(["tr-TR", "de-DE", "en-US"], supported: ["en-US", "de-DE"]) == ["de-DE", "en-US"])
    }

    @Test func localeVariantsResolveWithoutDuplicatesOrUnsupportedClaims() {
        #expect(OCRTextRecognition.supportedPreferences(["en_GB", "en-US", "tr"], supported: ["en-US", "fr-FR"]) == ["en-US"])
        #expect(OCRTextRecognition.supportedPreferences(["tr"], supported: ["en-US"]).isEmpty)
        #expect(OCRTextRecognition.supportedPreferences(["tr"], supported: ["tr-TR"]) == ["tr-TR"])
    }

    @Test func cancelledRecognitionDoesNotReturnPartialScannedText() async {
        let task = Task {
            return try await OCRTextRecognition().recognize(pages: [])
        }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancelled recognition to throw")
        } catch is CancellationError {
        } catch { Issue.record("Unexpected error: \(error)") }
    }
}
