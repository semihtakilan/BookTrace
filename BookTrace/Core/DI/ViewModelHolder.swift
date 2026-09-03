//
//  ViewModelHolder.swift
//  DI
//
//  Created by Semih TAKILAN on 03.09.2026.
//

import SwiftUI

/// View model'ı `body` içinde bir kez üretmek için kutu.
///
/// Navigasyon hedefleri bir enum case'inden doğduğu için bağımlılıklarını
/// `@Environment`'tan alır; environment ise `init` sırasında okunamaz. Bu
/// yüzden fabrika çağrısı `body` içinde yapılıyordu.
///
/// `@State`'in başlangıç değeri yalnızca ilk çizimde saklanır — ama o değeri
/// üreten ifade her çizimde çalışır. Sonuç doğru oluyordu (ilk değer
/// kazanıyor), ama her yeniden çizimde bir view model boşuna kuruluyordu; o
/// initializer'a bir gün iş girdiği gün (örneğin bir repository çağrısı)
/// sessizce her karede çalışırdı.
///
/// Bu kutu ile her çizimde ayrılan tek şey boş bir referans; view model ilk
/// erişimde bir kez üretilir ve saklanır.
@MainActor
final class ViewModelHolder<Value> {
    private var value: Value?

    // Boş `deinit`: bu olmadan Release derlemesinde optimize edici
    // (`EarlyPerfInliner`) jenerik sınıfın üretilmiş yıkıcısında çöküyor.
    deinit {}

    func callAsFunction(_ make: () -> Value) -> Value {
        if let value { return value }
        let created = make()
        value = created
        return created
    }
}
