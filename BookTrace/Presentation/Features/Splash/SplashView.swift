//
//  SplashView.swift
//  Splash
//
//  Created by Semih TAKILAN on 07.08.2026.
//

import SwiftUI

/// Açılış ekranı.
///
/// `AppRouteTypeManager.performStartupTasks()` bir iş yapmadığı sürece bu ekran
/// pratikte hiç görünmez — daha önce buraya konan bir saniyelik yapay bekleme
/// kaldırıldı. Ekranın kendisi duruyor: gerçek açılış işi (auth, uzak
/// yapılandırma, cache ısıtma) eklendiği gün gösterilecek yüzey bu.
struct SplashView: View {
    var body: some View {
        ZStack {
            ReadingStyle.background
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 68, weight: .regular))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                // Uygulama adı marka; çevrilmez.
                Text(verbatim: "BookTrace")
                    .font(ReadingStyle.title())

                Text("Track what you read")
                    .font(.subheadline)
                    .foregroundStyle(ReadingStyle.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
