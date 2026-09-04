//
//  BookTextLines.swift
//  Shared
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI

/// Yan yana duran kitap karelerini hizalar, erişilebilirlik boyutlarında ise
/// başlığın tamamının görünmesine izin verir.
struct BookTextLines: ViewModifier {
    let count: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            content.fixedSize(horizontal: false, vertical: true)
        } else {
            content.lineLimit(count, reservesSpace: true)
        }
    }
}
