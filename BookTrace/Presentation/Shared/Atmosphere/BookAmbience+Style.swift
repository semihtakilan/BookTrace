//
//  BookAmbience+Style.swift
//  Atmosphere
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import Models
import SwiftUI

/// Havanın görsel karşılığı.
///
/// Sınıflandırmanın kendisi `Models`'da, SwiftUI'dan bağımsız duruyor; ekranın
/// ondan ne anladığı burada.
extension BookAmbience {

    /// Okuma ekranının üstünde görünen oda adı.
    var roomName: LocalizedStringKey {
        switch self {
        case .literary:       "A quiet room"
        case .scienceFiction: "Far from here"
        case .mystery:        "After dark"
        case .history:        "The long ago"
        case .philosophy:     "Still water"
        case .technology:     "The workshop"
        case .biography:      "Lamplight"
        case .poetry:         "Between the lines"
        case .nature:         "Open air"
        case .children:       "Once upon a time"
        }
    }

    /// Sayacın altındaki tek satır. Kitabın türüne göre değişir; hep aynı
    /// cümleyi görmek birkaç oturumdan sonra görünmez oluyordu.
    var invitation: LocalizedStringKey {
        switch self {
        case .literary:       "Just you and the next page."
        case .scienceFiction: "The universe can wait. This one can’t."
        case .mystery:        "Somebody knows something."
        case .history:        "It all really happened."
        case .philosophy:     "Read slowly. Think slower."
        case .technology:     "One idea at a time."
        case .biography:      "Someone lived this."
        case .poetry:         "A few lines are enough."
        case .nature:         "The world, up close."
        case .children:       "Turn the page and see."
        }
    }

    var systemImage: String {
        switch self {
        case .literary:       "book.pages"
        case .scienceFiction: "sparkles"
        case .mystery:        "moon.stars"
        case .history:        "hourglass"
        case .philosophy:     "circle.hexagongrid"
        case .technology:     "chevron.left.forwardslash.chevron.right"
        case .biography:      "person.crop.circle"
        case .poetry:         "quote.opening"
        case .nature:         "leaf"
        case .children:       "wand.and.stars"
        }
    }

    /// Arka planda hangi hareketin çalışacağı.
    var field: AmbienceField {
        switch self {
        case .literary:       .motes
        case .scienceFiction: .stars
        case .mystery:        .fog
        case .history:        .grain
        case .philosophy:     .rings
        case .technology:     .grid
        case .biography:      .lamp
        case .poetry:         .lines
        case .nature:         .leaves
        case .children:       .sparks
        }
    }

    /// Kapak rengi kitabın kendi rengidir; hava ise onu bir miktar iter.
    ///
    /// `limit`, tonun en fazla ne kadar döndürülebileceği. Mesafenin bir oranı
    /// kadar döndürmek denenmişti: kırmızı kapaklı bir bilim kurgu maviyle
    /// kırmızının tam ortasına, yani mora düşüyordu — ne kitabın ne de türün
    /// rengi. Sabit ve küçük bir dönüş kapağı tanınır bırakıyor, türü yalnızca
    /// hissettiriyor.
    var hueBias: (target: Double, limit: Double)? {
        switch self {
        case .scienceFiction: (0.62, 0.10)
        case .mystery:        (0.72, 0.08)
        case .history:        (0.09, 0.10)
        case .nature:         (0.30, 0.09)
        case .children:       (0.13, 0.08)
        case .technology:     (0.52, 0.08)
        default:              nil
        }
    }

    /// Kapaktan bağımsız, türün kendi rengi.
    ///
    /// Keşif ekranındaki konu kartlarının rengi buradan geliyor: orada henüz
    /// bir kapak yok, ama altı kutunun altısının aynı beyaz olması da tam
    /// olarak eski tasarımın sorunuydu.
    var signaturePalette: BookPalette {
        let hue: Double = switch self {
        case .literary:       0.07
        case .scienceFiction: 0.62
        case .mystery:        0.73
        case .history:        0.09
        case .philosophy:     0.45
        case .technology:     0.53
        case .biography:      0.02
        case .poetry:         0.86
        case .nature:         0.30
        case .children:       0.13
        }
        return BookPalette(hue: hue, vibrancy: 0.55)
    }
}

/// Okuma ekranının arka planında çalışan hareket ailesi.
enum AmbienceField: Sendable, Hashable {
    /// Havada asılı toz zerreleri.
    case motes
    /// Paralaks yıldız alanı.
    case stars
    /// Ağır ağır geçen sis katmanları.
    case fog
    /// Eski kâğıt dokusu ve yavaş bir ışık geçişi.
    case grain
    /// Nefes alan iç içe halkalar.
    case rings
    /// Perspektif ızgara ve tarama çizgisi.
    case grid
    /// Yavaşça gezinen bir lamba ışığı.
    case lamp
    /// Yukarı süzülen ince çizgiler.
    case lines
    /// Aşağı düşen yapraklar.
    case leaves
    /// Sıçrayan küçük ışıklar.
    case sparks
}

extension BookPalette {
    /// Havanın ton eğilimini uygulanmış hâli.
    ///
    /// Kapak rengi tamamen ezilmiyor: yalnızca türün tonuna doğru çekiliyor.
    /// Kırmızı kapaklı bir bilim kurgu hâlâ kırmızıya çalıyor ama uzayın
    /// serinliğini alıyor.
    func biased(by ambience: BookAmbience) -> BookPalette {
        guard let bias = ambience.hueBias else { return self }

        // Ton çemberi dairesel: 0.95'ten 0.05'e giden yol 0.9 değil 0.1.
        var difference = bias.target - hue
        if difference > 0.5 { difference -= 1 }
        if difference < -0.5 { difference += 1 }

        let shift = min(abs(difference), bias.limit) * (difference < 0 ? -1 : 1)
        let shifted = (hue + shift + 1).truncatingRemainder(dividingBy: 1)
        return BookPalette(hue: shifted, vibrancy: max(vibrancy, 0.28))
    }
}
