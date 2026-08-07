# Proje Planı: Kitap Takip Uygulaması (iOS)

## Faz 1: Proje Kurulumu ve Altyapı Hazırlığı
Bu fazda temel proje iskeletini, dış bağımlılıkları ve modüler klasör yapısını kuracaksın.

*   **1.1. Versiyon Kontrolü:** Proje başlangıcında yerel bir GitHub repository'si başlat (main branch). İlerideki her fazı ayrı bir branch üzerinden yürüt.
*   **1.2. Bağımlılıkların (SPM) Kurulumu:** `Factory` (Dependency Injection), `Navigator` (Routing) ve `Kingfisher` (Image Caching) paketlerini ekle.
*   **1.3. Klasör (Domain) Yapılandırması:** Clean Architecture standartlarına göre `Domain`, `Data`, `Presentation` ve `Core` klasörlerini oluştur.

## Faz 2: Veri Modelleri ve Yerel Depolama (Data Layer)
Uygulamanın omurgası olan durum (state) yönetimini ve veritabanı kurulumunu yapacaksın.

*   **2.1. Domain Entity'lerini Tanımla:** `ReadingStatus` (Enum) ve `Book` yapısını (struct) oluştur.
*   **2.2. SwiftData Kurulumu:** `Book` entity'sini modele dönüştür ve `.modelContainer(for:)` yapılandırmasını kur.
*   **2.3. LocalRepository Yazımı:** `BookRepository` protokolünü SwiftData ile implemente et ve modüle kaydet.

## Faz 3: Ağ Katmanı (Network Layer) ve Performans Optimizasyonu (Önbellek)
Dışarıdan veri çekme işlemlerini UI'dan izole edecek, API isteklerini minimize ederek performansı ve ağ kullanımını optimize edeceksin.

*   **3.1. API Servisi:** Google Books API üzerinden ISBN ve metin araması yapacak servisi oluştur.
*   **3.2. DTO Eşlemesi:** API'den dönen JSON formatını `Domain/Book` yapısına dönüştürecek modelleri yaz.
*   **3.3. In-Memory Cache (NSCache) Yöneticisi:** Ana sayfa verilerini ve sık yapılan aramaları cihazın RAM'inde belirli bir süre (TTL - Time to Live) tutacak bağımsız bir cache yöneticisi kurgula.
*   **3.4. Cache-First (Önce Önbellek) Stratejisi:** Repository katmanını güncelleyerek veriyi önce önbellekten oku. Veri önbellekte yoksa veya süresi dolmuşsa API'ye istek at, dönen yeni veriyi önbelleğe kaydet ve arayüze ilet.
*   **3.5. Görsel Önbellekleme:** Arayüzde kapak fotoğrafları için Kingfisher entegrasyonunu kurgulayarak ağ üzerinden indirilen görsellerin cihaz diskinde ve belleğinde otomatik saklanmasını sağla.
*   **3.6. Unit Testing:** Önbellek mantığının (veri varken API'nin tetiklenmediğinin) doğruluğunu ve state kapsama alanını birim testleriyle doğrula.

## Faz 4: Temel Arayüz ve Navigasyon (Presentation)
Kullanıcının etkileşime gireceği ana ekranları ve sayfa geçişlerini inşa edeceksin.

*   **4.1. Navigator Kurulumu:** Uygulama içi sayfa geçiş rotalarını (AppRoutes) tanımla.
*   **4.2. Arama Ekranı (Search):** Kullanıcı yazarken API'yi yormamak için `Debounce` mantığı ekle ve görsel yüklemelerini kurgula.
*   **4.3. Barkod Tarayıcı (AVFoundation):** Kameradan ISBN okuyan özel bir tarayıcı oluşturup arama fonksiyonuna bağla.
*   **4.4. Kitap Detay ve Liste Ekranları:** SwiftData `@Query` özelliğini kullanarak filtreli listeleme ve detay görünümlerini oluştur.

## Faz 5: İmzalı Özellik (Custom Dairesel Slider)
Kullanıcı deneyimini (UX) en üst seviyeye çıkaracak özel ilerleme bileşenini geliştireceksin.

*   **5.1. Matematik ve Geometri:** Parmağın konumundan açıyı hesaplayan algoritmayı yaz.
*   **5.2. Yüzdelik Dilim Snapping:** Göstergeyi belirli yüzdelik noktalara (%25, %50 vb.) otomatik kilitle.
*   **5.3. Haptic Feedback:** Slider hareket ederken ve kilitlenirken uygun titreşim geri bildirimlerini ekle.

## Faz 6: Kullanıcıyı Elde Tutma (Retention) Öğeleri
Widget'lar ve istatistiklerle uygulamanın her gün açılmasını sağlayacak geliştirmeler.

*   **6.1. Okuma İstatistikleri:** Swift Charts kullanarak okunan kitap sayısını aylara göre gösteren bir grafik çiz.
*   **6.2. iOS Widget Extension:** Şu an okunan kitabı Kilit Ekranı ve Ana Ekran'da gösteren bir widget tasarla.
