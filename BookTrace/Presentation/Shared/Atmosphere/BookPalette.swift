//
//  BookPalette.swift
//  Atmosphere
//
//  Created by Semih TAKILAN on 04.09.2026.
//

import SwiftUI

/// Bir kitabın kapağından türetilen renk kimliği.
///
/// Kapağın baskın rengi sayfada aynen kullanılamaz: kitap kapakları kontrast
/// için tasarlanmıyor ve doğrudan kullanılınca metin okunmaz hâle geliyor.
/// Bu yüzden kapaktan yalnızca *ton* alınır; doygunluk ve parlaklık kullanım
/// yerine göre burada güvenli aralıklara sıkıştırılır. Sonuç, her kitabın
/// tanınabilir bir rengi olması ama hiçbir metnin okunmaz olmaması.
struct BookPalette: Sendable, Hashable, Codable {
    /// 0...1 aralığında ton.
    let hue: Double
    /// Kapağın ne kadar canlı olduğu. Gri tonlu kapaklarda sıfıra yaklaşır.
    let vibrancy: Double

    /// Hiç kapak yokken kullanılan, kitabın kimliğinden türeyen sabit renk.
    ///
    /// Rastgele değil: aynı kitap her açılışta aynı rengi alsın diye kimliğin
    /// karmasından üretilir.
    static func fallback(for identifier: String) -> BookPalette {
        var hash: UInt64 = 5381
        for byte in identifier.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return BookPalette(hue: Double(hash % 360) / 360, vibrancy: 0.34)
    }

    static let neutral = BookPalette(hue: 0.34, vibrancy: 0.3)

    // MARK: - Kullanıma hazır renkler

    /// Metin ve simgelerde kullanılabilecek, zemine göre okunur vurgu rengi.
    func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? color(saturation: clamped(vibrancy * 0.7, 0.22, 0.55), brightness: 0.86)
            : color(saturation: clamped(vibrancy * 1.05, 0.34, 0.85), brightness: 0.42)
    }

    /// `accent` üstündeki metin ve simgelerin rengi.
    ///
    /// Vurgu açık temada koyu, koyu temada açık; üstüne yazılan da tersi olmalı.
    /// Bu iki kural bir arada tutulmazsa düğme yazıları arada okunmaz oluyor.
    func onAccent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .black.opacity(0.86) : .white
    }

    /// Kart zeminleri için çok açık (koyu temada çok koyu) ton.
    ///
    /// Açık temadaki değerler bilerek çok düşük: ilk denemede kart kâğıdın
    /// üstünde bir renk lekesi gibi duruyordu ve uygulamanın sakinliğini
    /// bozuyordu. Kitabın rengi burada bir fısıltı; sesi vurguda yükseliyor.
    func wash(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? color(saturation: clamped(vibrancy * 0.5, 0.14, 0.34), brightness: 0.20)
            : color(saturation: clamped(vibrancy * 0.20, 0.04, 0.10), brightness: 0.98)
    }

    /// Kartın kenarına doğru koyulaşan ikinci durak — düz zemini derinleştirir.
    func washEdge(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? color(saturation: clamped(vibrancy * 0.55, 0.16, 0.40), brightness: 0.14)
            : color(saturation: clamped(vibrancy * 0.30, 0.07, 0.17), brightness: 0.94)
    }

    /// Okuma ekranının kaplayıcı zemini. Her iki temada da koyudur: okuma modu
    /// kasten loştur, kapak ve sayaç öne çıksın diye.
    func atmosphere(_ scheme: ColorScheme) -> [Color] {
        let base = clamped(vibrancy * 0.8, 0.26, 0.62)
        return [
            color(saturation: base * 0.75, brightness: scheme == .dark ? 0.17 : 0.24),
            color(saturation: base, brightness: scheme == .dark ? 0.10 : 0.14),
            color(hueOffset: 0.06, saturation: base * 0.9, brightness: scheme == .dark ? 0.06 : 0.09)
        ]
    }

    /// Parçacıkların ve ışıltıların rengi — koyu zeminin üstünde parlar.
    var glow: Color {
        color(saturation: clamped(vibrancy, 0.25, 0.7), brightness: 0.92)
    }

    /// Kapağın arkasındaki halenin rengi.
    var halo: Color {
        color(saturation: clamped(vibrancy * 0.9, 0.3, 0.75), brightness: 0.78)
    }

    private func color(hueOffset: Double = 0, saturation: Double, brightness: Double) -> Color {
        Color(hue: (hue + hueOffset).truncatingRemainder(dividingBy: 1),
              saturation: saturation,
              brightness: brightness)
    }

    private func clamped(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}

// MARK: - Kapaktan çıkarım

/// Kapak görselinden `BookPalette` üretir.
///
/// Görsel 16×24'e indirilerek okunur: 384 piksel hem baskın tonu bulmaya yeter
/// hem de ana iş parçacığını meşgul etmeyecek kadar ucuzdur.
enum BookPaletteExtractor {

    static func palette(from image: UIImage) -> BookPalette? {
        guard let pixels = downsampledPixels(from: image) else { return nil }

        // Ton çemberi 24 dilime bölünür; her piksel doygunluğuna ve orta
        // parlaklığa yakınlığına göre ağırlıklandırılır. Kapakların büyük
        // kısmı beyaz ya da siyah olduğu için ham "en çok geçen renk" hep
        // griye çıkıyordu.
        var bucketWeights = [Double](repeating: 0, count: 24)
        var bucketHueSums = [Double](repeating: 0, count: 24)
        var bucketSaturationSums = [Double](repeating: 0, count: 24)
        var totalWeight = 0.0

        for pixel in pixels {
            let (hue, saturation, brightness) = hsb(red: pixel.0, green: pixel.1, blue: pixel.2)

            let midtoneAffinity = 1 - min(1, abs(brightness - 0.55) / 0.55)
            let weight = saturation * saturation * midtoneAffinity
            guard weight > 0.001 else { continue }

            let bucket = min(23, Int(hue * 24))
            bucketWeights[bucket] += weight
            bucketHueSums[bucket] += hue * weight
            bucketSaturationSums[bucket] += saturation * weight
            totalWeight += weight
        }

        // Hiçbir piksel renkli değilse (tamamen gri bir kapak) ton uydurmak
        // yanlış olur; çağıran taraf kimlikten türeyen yedeği kullanır.
        guard let dominant = bucketWeights.indices.max(by: { bucketWeights[$0] < bucketWeights[$1] }),
              bucketWeights[dominant] > 0, totalWeight > 0 else {
            return nil
        }

        let hue = bucketHueSums[dominant] / bucketWeights[dominant]
        let saturation = bucketSaturationSums[dominant] / bucketWeights[dominant]
        // Baskın tonun kapağın ne kadarını kapladığı, canlılığın ikinci yarısı:
        // küçük bir kırmızı şerit taşıyan gri kapak canlı sayılmamalı.
        let coverage = bucketWeights[dominant] / Double(pixels.count)

        return BookPalette(hue: hue, vibrancy: min(1, saturation * 0.6 + min(1, coverage * 3) * 0.4))
    }

    /// Görseli küçük bir RGBA tamponuna çizip piksellerini döndürür.
    private static func downsampledPixels(from image: UIImage) -> [(Double, Double, Double)]? {
        guard let cgImage = image.cgImage else { return nil }

        let width = 16
        let height = 24
        var buffer = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return stride(from: 0, to: buffer.count, by: 4).compactMap { index in
            // Şeffaf pikseller premultiplied tamponda siyah görünür; sayılmaz.
            guard buffer[index + 3] > 32 else { return nil }
            return (Double(buffer[index]) / 255, Double(buffer[index + 1]) / 255, Double(buffer[index + 2]) / 255)
        }
    }

    private static func hsb(red: Double, green: Double, blue: Double) -> (Double, Double, Double) {
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let delta = maximum - minimum

        guard delta > 0.0001 else { return (0, 0, maximum) }

        let hue: Double
        switch maximum {
        case red:   hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
        case green: hue = (blue - red) / delta + 2
        default:    hue = (red - green) / delta + 4
        }

        let normalized = hue < 0 ? (hue + 6) / 6 : hue / 6
        return (normalized, maximum == 0 ? 0 : delta / maximum, maximum)
    }
}
