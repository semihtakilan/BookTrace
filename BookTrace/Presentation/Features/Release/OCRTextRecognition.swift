//
//  OCRTextRecognition.swift
//  Release
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import AVFoundation
import Foundation
import SwiftUI
import Vision
import VisionKit

/// Vision runs on this actor, away from the main actor. Images never leave the device.
actor OCRTextRecognition {
    func recognize(pages: [Data], preferredLanguages: [String] = Locale.preferredLanguages) throws -> String {
        try Task.checkCancellation()
        var texts: [String] = []
        for data in pages {
            try Task.checkCancellation()
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true
            let supported = try request.supportedRecognitionLanguages()
            let preferred = Self.supportedPreferences(preferredLanguages, supported: supported)
            if !preferred.isEmpty { request.recognitionLanguages = preferred }
            // Avoid rewriting Turkish characters using another language's dictionary.
            request.usesLanguageCorrection = !preferredLanguages.contains(where: {
                $0.hasPrefix("tr") && !supported.contains(where: { $0.hasPrefix("tr") })
            })
            try VNImageRequestHandler(data: data, options: [:]).perform([request])
            let lines = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
            texts.append(lines.joined(separator: "\n"))
        }
        return texts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    nonisolated static func supportedPreferences(_ preferred: [String], supported: [String]) -> [String] {
        var chosen: [String] = []
        for preference in preferred {
            let language = preference.replacingOccurrences(of: "_", with: "-")
            let prefix = language.split(separator: "-").first.map(String.init) ?? language
            if let match = supported.first(where: { $0 == language })
                ?? supported.first(where: { $0.split(separator: "-").first.map(String.init) == prefix }),
               !chosen.contains(match) { chosen.append(match) }
        }
        return chosen
    }
}

struct QuoteDocumentScanner: UIViewControllerRepresentable {
    let completion: (Result<[Data], Error>) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: (Result<[Data], Error>) -> Void
        init(completion: @escaping (Result<[Data], Error>) -> Void) { self.completion = completion }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let pages = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).jpegData(compressionQuality: 0.9) }
            completion(.success(pages))
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            completion(.failure(CancellationError()))
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: any Error) {
            completion(.failure(error))
        }
    }
}
