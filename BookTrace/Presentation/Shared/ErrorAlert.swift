//
//  ErrorAlert.swift
//  Shared
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import SwiftUI

extension View {
    /// Uygulamanın tek tip hata uyarısı.
    ///
    /// `UserFacingError` iptal edilmiş işler için hiç üretilmediğinden, buraya
    /// yalnızca kullanıcının görmesi gereken hatalar ulaşır.
    func errorAlert(_ error: Binding<UserFacingError?>) -> some View {
        alert(
            "Something went wrong",
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { isPresented in if !isPresented { error.wrappedValue = nil } }
            ),
            presenting: error.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) { error.wrappedValue = nil }
        } message: { presented in
            Text(presented.message)
        }
    }
}
