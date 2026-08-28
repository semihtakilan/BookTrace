//
//  LibraryChangeNotifier.swift
//  DI
//
//  Created by Semih TAKILAN on 28.08.2026.
//

import Observation

/// Yerel kütüphaneye her yazımdan sonra artan bir sayaç.
///
/// SwiftUI'ın `onAppear`'ı her durumda tetiklenmiyor — örneğin tam ekran okuma
/// oturumu kapandığında altındaki detay ekranı yeniden görünmüş sayılmıyor ve
/// ekranda eski ilerleme kalıyordu. Ekranlar bu sayacı dinleyerek verilerini
/// tazeler; hangi ekranın hangi yazımdan etkilendiğini tek tek izlemeye gerek kalmaz.
@MainActor
@Observable
final class LibraryChangeNotifier {
    private(set) var revision = 0

    func notifyChanged() {
        revision &+= 1
    }
}
