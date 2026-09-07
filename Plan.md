# BookTrace — Proje Planı

Güncelleme: 7 Eylül 2026. Bu plan uygulanan kapsamı ve ertelenen ürün işlerini ayırır.

## Proje Özeti

Open Library ve Google Books üzerinden kitap keşfi, kişisel kütüphane yönetimi
ve okuma takibi sunan bir iPhone uygulaması. Üç sekme: **Library**, **Discover**,
**Journal**. Kod içindeki özellik adları sırasıyla `Books`, `Explore`, `Profile`.

**Kapsam hedefi:** Ne MVP kadar sınırlı ne de tüm fazları kasan bir kapsam —
portföyde iyi durabilecek, öğretici, dengeli bir uygulama.

## Mimari Genel Bakış

* **Desen:** MVVM + Repository Pattern, yerel SPM paketleri (`Models`, `NetworkKit`, `NetworkRegistration`)
* **DI:** FactoryKit. Composition root `AppDependencies`; navigasyon hedeflerinin
  view model'ları `ViewModelFactory` üzerinden environment'tan gelir.
* **Navigasyon:** NavigatorUI — her sekmenin kendi `Navigator`'ı var
* **Ağ Katmanı:** `NetworkService` (actor), interceptor zinciri, `async/await`
* **Yerel Kalıcılık:** SwiftData — `LocalLibraryEntryModel`, `LocalReadingSessionModel`, `LocalCategoryModel`
* **Ortak veri tipi:** `BookReference` (kaynak önekli kimlik (`gb:` / `ol:`) + başlık + yazarlar + kapak + sayfa + konu).
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
* Open Library birincil kaynak; boş/hatalı sonuçta bütçe dahilinde Google Books yedeği
* `CachedBookSearching` — taze sonucu doğrudan döndürür, bayat sonucu gösterip arkada yeniler
* Arama/konu/ISBN yenileme aralıkları 1/7/30 gün; son kullanma süreleri 7/30/365 gün
* Ayrı SwiftData önbelleği ve ilk açılış için `ShelfSeed.json`
* Detayda Open Library'ye 800 ms öncelik, ortak 8 saniye sınırı ve paylaşılan eşzamanlı istekler
* `DailyRequestBudget` — cihaz başına 25 Google Books işlemi/gün, kota hatasından sonra bir saat askı
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
* All Books: arama, sıralama, durum filtresi ve durum/sahiplik/kategori gruplaması
* Kitap silmeden önce onay
* Kitaba dokununca `BookLibraryDetailView`, plandaki üç eylem:
  * Reading Mode
  * Reading Status (değiştirmek için)
  * Ownership Status (değiştirmek için)
* Ayrıca: ilerleme güncelleme, oturum geçmişi, kütüphaneden çıkarma

## Faz 6 — Reading Mode (Okuma Oturumu Sayaç Ekranı) ✅

* Tam ekran sayaç, Pause/Resume
* Finish → sayfa çarkı veya klavye ile giriş, ilerleme önizlemesi, Discard ve Save
* Kapaktan renk paleti, türe göre atmosfer, Reduce Motion ve düşük güç desteği
* İlk oturum, ilerleme eşikleri ve kitap bitişi için kısa kutlamalar
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
* Pozitif süre ve sayfa içeren oturumların toplam süresi ÷ toplam sayfası, kitaba
  özel okuma hızını verir. Sıfır sayfalı veya sıfır süreli kayıtlar hesaba katılmaz.
* İlerleme çubuğunun yanında "tahmini kalan süre" olarak gösterilir. Tahmin
  varsayılan hızdan geliyorsa metinde `(estimate)` ibaresi yer alır; ilk
  oturumdan sonra bu ibare düşer.
* `ReadingSpeedEstimator` saf ve durumsuz — birim testleri UI'a bağlanmadan yazılabiliyor.

## Faz 8 — Yazar Modülü ⬜

Yazar arama, profil, bibliyografi.

## Faz 9 — Öneri Algoritması ⬜

Kütüphanedeki konu/kategori dağılımına dayalı basit bir benzerlik skoru ile
"Sana Göre" önerileri.

## Faz 10 — Journal & İstatistikler ◐

* [x] Kütüphane toplamları, durum ve sahiplik dağılımları
* [x] Toplam okuma süresi, sayfalar, oturum sayısı ve kişisel hız
* [x] Gün seçilebilen etkinlik görünümü ve kitaba bağlanan tam oturum geçmişi
* [x] Güncel okuma serisi ve son yedi günün etkinlik şeridi
* [ ] Kullanıcının belirleyeceği okuma hedefleri
* [ ] Swift Charts ile daha zengin trendler ve uzun dönem takvim

## Faz 11 — Cilalama & Dokümantasyon ◐

* [x] Sistem/açık/koyu tema, İngilizce/Türkçe/Almanca ve çoğul metinler
* [x] Boş/hata durumları, silme onayları ve depolama kurtarma ekranı
* [x] Dynamic Type, VoiceOver etiketleri ve Reduce Motion desteği
* [x] README, simülatör tasarım incelemeleri ve performans incelemesi
* [x] GitHub Actions iş akışı: iki paket testi, uygulama testleri, Debug ve Release derlemesi
* [x] CI günlükleri, test özeti ve `.xcresult` çıktıları; raporlarda tarihli ölçüm ayrımı
* [x] İnceleme görselleri için boyut sınırı ve dönüştürme betiği
* [ ] Bağımsız portföy sunumu ve yayın hazırlığı

CI dosyası depoda hazırdır; uzak koşum, değişiklikler GitHub'a gönderildikten sonra
başlar. Güncel sonuçlar için [CI koşumlarına](https://github.com/semihtakilan/BookTrace/actions/workflows/ci.yml) bakın.

## Sonraki ürün kapsamı

Bu plan Faz 1-11 arasındaki **tamamlanmış** mimariyi kaydeder. App Store'a
abonelikli çıkış için yapılacak iş — CloudKit eşitlemesi, StoreKit 2, Live
Activity, hedefler, widget'lar, zengin istatistik, alıntı/OCR, yıl sonu özeti,
dışa aktarma ve öneri motoru — ayrı bir belgede fazlandı:

* **[ReleasePlan.md](ReleasePlan.md)** — yayın planı ve faz sıralaması
* [Documentation/MarketAnalysis/pazar-raporu.md](Documentation/MarketAnalysis/pazar-raporu.md) — kararların dayandığı rakip analizi (7 Eylül 2026)

Oradaki kararların özeti: hesap sistemi **yok** (Bookly hesapsız çalışıp
top-grossing #62'de), eşitleme CloudKit ile ve **ücretsiz**, paywall kitap
sayısında değil **özellikte**, LLM öneri botu kapsam dışı (Faz 9'un yerel motoru
yeterli — AI öneri alanı yedi rakiple dolu).

Hâlâ kapsam dışı: arama sayfalaması ve Google Books anahtarını cihazdan çıkaracak
backend proxy.

## Notlar

* Her faz kendi başına çalışan bir uygulama bırakır.
* Yerel kütüphaneye her yazımdan sonra `LibraryChangeNotifier` sayacı artar;
  ekranlar bunu dinleyerek tazelenir. `onAppear` tek başına yetmiyordu — tam
  ekran okuma oturumu kapandığında altındaki detay ekranı "yeniden görünmüş"
  sayılmadığı için eski ilerlemeyi göstermeye devam ediyordu.
* Open Library anahtar gerektirmez. Google Books yedeği için API anahtarı
  yapılandırması `README.md` içinde; derleme ve yerel testler anahtarsız çalışır.
