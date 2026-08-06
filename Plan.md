# Proje Planı: Kitap Takip Uygulaması (iOS)

## Faz 1: Proje Kurulumu ve Altyapı Hazırlığı
Bu fazda temel proje iskeletini, dış bağımlılıkları ve modüler klasör yapısını kuracaksın.

*   **1.1. Versiyon Kontrolü:** Proje başlangıcında yerel bir GitHub repository'si başlat (main branch). İlerideki her fazı ayrı bir branch (örn: `feature/network-layer`) üzerinden yürüt.
*   **1.2. Bağımlılıkların (SPM) Kurulumu:** 
    *   `Factory` (Dependency Injection)
    *   `Navigator` (Routing)
    *   `Kingfisher` (Image Caching)
*   **1.3. Klasör (Domain) Yapılandırması:** Clean Architecture standartlarına göre klasörleri oluştur:
    *   `Domain/` (Entity, Enum, UseCase, Repository Protokolleri)
    *   `Data/` (API Servisleri, SwiftData Modelleri, Repository Implementasyonları)
    *   `Presentation/` (View, ViewModel, Navigator Yapılandırmaları)
    *   `Core/` (Uzantılar, Haptic Yöneticisi, Hata Tipleri)

## Faz 2: Veri Modelleri ve Yerel Depolama (Data Layer)
Uygulamanın omurgası olan durum (state) yönetimini ve veritabanı kurulumunu yapacaksın.

*   **2.1. Domain Entity'lerini Tanımla:** 
    *   `ReadingStatus` (Enum): `.toRead`, `.reading`, `.read`, `.dnf` (Yarım Bırakılan).
    *   `Book` yapısını (struct) oluştur (`id`, `title`, `author`, `pageCount`, `coverURL`, `status`, `isFavorite`, `currentProgress`).
*   **2.2. SwiftData Kurulumu:**
    *   Domain'deki `Book` entity'sini SwiftData modeline (`@Model`) maple.
    *   Ana uygulama girişinde `.modelContainer(for:)` yapılandırmasını kur.
*   **2.3. LocalRepository Yazımı:**
    *   `BookRepository` protokolünü oluştur (Ekle, Sil, Güncelle, Listele).
    *   SwiftData kullanarak bu protokolü implemente et (`LocalBookRepositoryImpl`).
    *   `Factory` modülüne bu repository'yi register et.

## Faz 3: Ağ Katmanı (Network Layer) ve Google Books API
Dışarıdan veri çekme işlemlerini UI'dan tamamen izole bir şekilde ayarlayacaksın.

*   **3.1. API Servisi:** Google Books API üzerinden ISBN ve Metin araması yapacak `GoogleBooksService` sınıfını yaz.
*   **3.2. DTO (Data Transfer Object) Eşlemesi:** API'den dönen karmaşık JSON'ı, `Domain/Book` yapısına dönüştürecek (map edecek) fonksiyonları yaz. 
*   **3.3. Unit Testing:** `swift-testing` framework'ü ile birim testleri yaz. Repository mock'larını yapılandırarak ağ bağlantısı olmadan uygulamanın state kapsama alanını (örn: API'den boş kapak resmi döndüğünde uygulamanın çökmemesi) ve filtreleme mantığını doğrula.

## Faz 4: Temel Arayüz ve Navigasyon (Presentation)
Kullanıcının etkileşime gireceği ana ekranları ve sayfa geçişlerini inşa edeceksin.

*   **4.1. Navigator Kurulumu:** `Navigator` paketini kullanarak sayfa geçiş rotalarını (AppRoutes) tanımla. 
*   **4.2. Arama Ekranı (Search):**
    *   Kullanıcı yazarken API'yi yormamak için `Debounce` (örn: 0.5 sn bekleme) mantığı ekle.
    *   Kapakları `Kingfisher` ile yükle (`KFImage`). Kapak yoksa şık bir yer tutucu (placeholder) göster.
*   **4.3. Barkod Tarayıcı (AVFoundation):** Kameradan ISBN okuyan özel bir UIViewRepresentable oluştur ve sonucu doğrudan arama fonksiyonuna bağla.
*   **4.4. Kitap Detay ve Liste Ekranları:** Kitap detaylarını ve kullanıcının okuma durumuna göre filtrelenmiş listelerini (SwiftData `@Query` kullanarak) oluştur.

## Faz 5: İmzalı Özellik (Custom Dairesel Slider)
Kullanıcı deneyimini (UX) en üst seviyeye çıkaracak özel ilerleme bileşenini geliştireceksin.

*   **5.1. Matematik ve Geometri:** `DragGesture` kullanarak parmağın konumundan açıyı hesaplayan (`atan2`) algoritmayı yaz.
*   **5.2. Yüzdelik Dilim (Quarter) Snapping:**
    *   Toplam sayfa sayısını 4'e böl (%25, %50, %75, %100 noktaları).
    *   Parmağın açısı bu noktalara (örn: ±10 derece) yaklaştığında, göstergeyi doğrudan o noktaya kilitle (Snap).
*   **5.3. Haptic Feedback Entegrasyonu:**
    *   Slider hareket ederken ara sayfalarda `UISelectionFeedbackGenerator` tetikle.
    *   Slider bir çeyrek noktasına (Snap) kilitlendiğinde `UIImpactFeedbackGenerator(style: .rigid)` tetikle.

## Faz 6: Kullanıcıyı Elde Tutma (Retention) Öğeleri
Widget'lar ve istatistiklerle uygulamanın her gün açılmasını sağlayacak geliştirmeler.

*   **6.1. Okuma İstatistikleri:** Swift Charts (`Charts` framework) kullanarak basit bir grafik çiz. X ekseni aylar, Y ekseni okunan kitap sayısı olsun.
*   **6.2. iOS Widget Extension:** 
    *   Şu an `.reading` statüsünde olan kitabı cihaz hafızasından (SwiftData veya AppGroup UserDefaults) okuyan bir widget tasarla.
    *   Kapak fotoğrafını ve dairesel veya çizgisel ilerleme barını Kilit Ekranı ve Ana Ekran için küçük (small) boyutta ayarla.