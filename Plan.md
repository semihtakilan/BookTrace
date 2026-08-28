# BookTrace — Proje Planı

## Proje Özeti

Google Books API'sini kullanan, kitap keşfi, kişisel kütüphane yönetimi ve okuma
takibi sunan bir iOS uygulaması. 3 tab: **Books** (kütüphane/okuma takibi),
**Explore** (arama/kategori/barkod ile keşif), **Profile**.

**Kapsam hedefi:** Ne MVP kadar sınırlı ne de tüm fazları kasan bir kapsam —
portföyde iyi durabilecek, öğretici, dengeli bir uygulama.

## Mimari Genel Bakış

* **Desen:** MVVM + Repository Pattern, yerel SPM paketleri (`Models`, `NetworkKit`, `NetworkRegistration`)
* **DI:** FactoryKit. Composition root `AppDependencies`; navigasyon hedeflerinin
  view model'ları `ViewModelFactory` üzerinden environment'tan gelir.
* **Navigasyon:** NavigatorUI — her sekmenin kendi `Navigator`'ı var
* **Ağ Katmanı:** `NetworkService` (actor), interceptor zinciri, `async/await`
* **Yerel Kalıcılık:** SwiftData — `LocalLibraryEntryModel`, `LocalReadingSessionModel`, `LocalCategoryModel`
* **Ortak veri tipi:** `BookReference` (volumeId + başlık + yazarlar + kapak + sayfa + konu).
  Explore'un üç kaynağından (arama/kategori/barkod) gelen kitapları tek bir Detay
  akışına bağlar. Kütüphane kaydı ise `LibraryEntry` — içinde bir `BookReference`
  taşır, üzerine yalnızca kullanıcıya ait durumu ekler.

### Katman ayrımı

Domain tipleri (`BookReference`, `LibraryEntry`, `ReadingSession`, `ReadingSpeedEstimator`)
test edilebilir olsun diye `Models` paketinde, SwiftData ve UI'dan bağımsız durur.
SwiftData modelleri uygulama hedefinde yaşar ve Domain tiplerine dönüştürülür.

## Faz 1 — Temel Altyapı ✅

Network katmanı, `Endpoint` protokolü, DI kurulumu, interceptor zinciri.

## Faz 2 — Keşif Altyapısı ✅

* `GoogleBooksSearchEndpoint` (`/volumes`) — tek uç nokta, üç fabrika metodu:
  * `.search(query:)` — serbest metin arama
  * `.subject(_:)` — kategori bazlı keşif (`q=subject:"..."`)
  * `.isbn(_:)` — barkoddan gelen ISBN ile tek kitap
* `CacheFirstBookSearching` — arama/konu/ISBN sonuçlarını 24 saat diskte tutar
* Kapak görselleri Kingfisher ile önbelleklenir

## Faz 3 — Explore Tab (Arama + Kategori + Barkod) ✅

* Arama çubuğu — 500 ms debounce
* Kategori rafları — 6 konu, paralel yüklenir, her raf kendi hata/tekrar dene durumunu taşır
* Barkod tarama (AVFoundation) → ISBN → kitap
* Üçü de aynı yere çıkıyor: Kitap Detay ekranı (`BookReference` ile)

## Faz 4 — Kitap Detay & Kütüphaneye Ekleme ✅

* Detayda açıklama, konu etiketleri, sayfa sayısı, ISBN, yayın tarihi
* "Add to Library" → form:
  * Reading Status: Wishlist, To Read, Reading, Finished, Abandoned
  * Progress Type: Pages / Percentage
  * Page Count girişi
  * Ownership Status: Borrowed, Not Owned, Owned
  * Categories (kullanıcı etiketleri + kitabın konularından öneriler)
* Kitap zaten kütüphanedeyse form mevcut seçimlerle dolar ve kaydı günceller;
  ilerleme ve okuma oturumları korunur.

### Veri modeli

```swift
enum ReadingStatus  { case wishlist, toRead, reading, finished, abandoned }
enum OwnershipStatus { case borrowed, notOwned, owned }
enum ProgressType   { case pages, percentage }

struct LibraryEntry {
    var book: BookReference          // id == book.id
    var readingStatus: ReadingStatus
    var ownershipStatus: OwnershipStatus
    var progressType: ProgressType
    var pageCount: Int?              // kullanıcının girdiği; yoksa book.pageCount
    var currentPage: Int             // her zaman sayfa cinsinden
    var categories: [Category]
    var addedDate: Date
    var readingSessions: [ReadingSession]
}
```

**Not:** `progressType` yalnızca giriş ve gösterim birimini belirler. İlerleme
kayıtta her zaman sayfa olarak tutulur ki okuma oturumları ve hız tahmini tek
birim üzerinden hesaplanabilsin.

## Faz 5 — Books Tab (Kütüphane Listesi) ✅

* Üstte "Now Reading" bölümü: kapak, ilerleme çubuğu, tahmini kalan süre
* Reading Status, Ownership Status ve Categories bölümleri — yatay raflar
* "Edit" ile raflardan kitap silme
* Kitaba dokununca `BookLibraryDetailView`, plandaki üç eylem:
  * Reading Mode
  * Reading Status (değiştirmek için)
  * Ownership Status (değiştirmek için)
* Ayrıca: ilerleme güncelleme, oturum geçmişi, kütüphaneden çıkarma

## Faz 6 — Reading Mode (Okuma Oturumu Sayaç Ekranı) ✅

* Tam ekran sayaç, Pause/Resume
* Sağ üstte Finish → "kaç sayfa okudunuz" sayfası, Discard ve Save
* Save → yeni `ReadingSession`, `currentPage` ilerler, gerekirse durum
  `.reading`/`.finished` olur

```swift
struct ReadingSession {
    let id: String
    let startDate: Date
    let durationSeconds: Int
    let pagesRead: Int
}
```

**Arka plan dayanıklılığı:** Sayaç `Timer` ile artırılmıyor; geçen süre saklanan
başlangıç tarihi ile `Date()` farkından hesaplanıyor. Saniyelik tik yalnızca
görüntüyü tazeliyor, bu yüzden uygulama arka plandayken de süre doğru kalıyor.

## Faz 7 — Okuma Hızı Tahmini ✅

* Varsayılan hız: sayfa başına 2 dakika (hiç oturum yokken)
* En az bir `ReadingSession` varsa: o kitabın tüm oturumlarının toplam süresi ÷
  toplam okunan sayfa = kişiye ve kitaba özel sayfa başına süre
* İlerleme çubuğunun yanında "tahmini kalan süre" olarak gösterilir. Tahmin
  varsayılan hızdan geliyorsa metinde `(estimate)` ibaresi yer alır; ilk
  oturumdan sonra bu ibare düşer.
* `ReadingSpeedEstimator` saf ve durumsuz — birim testleri UI'a bağlanmadan yazılabiliyor.

## Faz 8 — Yazar Modülü ⬜

Yazar arama, profil, bibliyografi.

## Faz 9 — Öneri Algoritması ⬜

Kütüphanedeki konu/kategori dağılımına dayalı basit bir benzerlik skoru ile
"Sana Göre" önerileri.

## Faz 10 — Profile Tab & İstatistikler ⬜

Okuma hedefleri, streak takvimi, Swift Charts ile trendler.

## Faz 11 — Cilalama & Dokümantasyon ⬜

Tema desteği, boş/hata durumlarının gözden geçirilmesi, README, portföy sunumu.

## Notlar

* Her faz kendi başına çalışan bir uygulama bırakır.
* Yerel kütüphaneye her yazımdan sonra `LibraryChangeNotifier` sayacı artar;
  ekranlar bunu dinleyerek tazelenir. `onAppear` tek başına yetmiyordu — tam
  ekran okuma oturumu kapandığında altındaki detay ekranı "yeniden görünmüş"
  sayılmadığı için eski ilerlemeyi göstermeye devam ediyordu.
* Google Books API anahtarı için `README.md`'ye bakın. Anahtarsız çağrılar
  Google'ın paylaşımlı anonim kotasını kullanıyor ve pratikte sürekli HTTP 429 dönüyor.
