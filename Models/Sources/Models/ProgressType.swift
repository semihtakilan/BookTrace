//
//  ProgressType.swift
//  Models
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Foundation

/// İlerlemenin kullanıcıya hangi birimle gösterileceği.
///
/// Kayıtta ilerleme her zaman sayfa olarak tutulur (`LibraryEntry.currentPage`);
/// bu tip yalnızca giriş ve gösterim birimini belirler. Böylece okuma
/// oturumları ve hız tahmini tek bir birim üzerinden hesaplanabilir.
public enum ProgressType: String, CaseIterable, Codable, Sendable {
    case pages
    case percentage
}
