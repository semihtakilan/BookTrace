//
//  BookDetailFetching.swift
//  Models
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import Foundation

/// Elde olan bir kitabın eksik alanlarını tamamlayan kaynak.
///
/// `BookSearching` liste sorularını soruyor; bu ise tek kitabı derinleştiriyor.
/// İkisini ayırmanın sebebi kota: listeler ucuz kaynaktan toplanıp, pahalı
/// kaynağa yalnızca kullanıcının gerçekten açtığı kitap için gidilebilsin.
public protocol BookDetailFetching: Sendable {
    /// Kitabın bilinen alanlarını koruyarak eksiklerini doldurur.
    func detail(for book: BookReference) async throws -> BookReference
}
