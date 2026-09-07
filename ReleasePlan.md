# BookTrace — Yayın Planı

**Uygulama durumu — 7 Eylül 2026:** Bu plandaki kaynak kodu ve yerel yayın hazırlıkları uygulandı. Tamamlanan kapsam ve test kanıtları [doğrulama kaydında](Documentation/Release/Validation.md), sonraki aşamanın işlemleri [yayın kontrol listesinde](Documentation/Release/ReleaseChecklist.md). Kullanıcının yönlendirmesiyle mağaza/hesap kurulumu ve yayınlama sonraki aşamaya bırakıldı. Aşağıdaki özgün kabul maddeleri canlı ortamda doğrulanmış sayılmaz.

Oluşturma: 7 Eylül 2026. Bu belge `Plan.md`'nin devamıdır: `Plan.md` Faz 1-11
arasındaki **tamamlanmış** mimariyi kaydeder, bu belge App Store'a abonelikli
çıkış için yapılacak işi tarif eder.

**Kardeş belgeler:**

| Belge | İçerik |
|---|---|
| [Plan.md](Plan.md) | Faz 1-11: tamamlanmış mimari ve özellikler |
| **ReleasePlan.md** *(bu belge)* | Yayın için yapılacak iş, faz sıralaması |
| [Pricing.md](Pricing.md) | Fiyat merdiveni, 13 pazarlık bölgesel ölçek, lansman sonrası takvim |
| [Documentation/MarketAnalysis/pazar-raporu.md](Documentation/MarketAnalysis/pazar-raporu.md) | Kararların dayandığı rakip analizi (7 Eylül 2026, 14 rakip) |

---

## 0. Kilitlenen kararlar

| Karar | Seçim | Gerekçe |
|---|---|---|
| Kimlik | **Hesap yok** | Bookly hesapsız çalışıp $29.99/yıl satıyor ve Books kategorisinde top-grossing #62'de. Hesap; backend, KVKK yükü ve Apple'ın uygulama içi hesap silme zorunluluğu (5.1.1(v)) getirir, karşılığında gelir getirmez. |
| Eşitleme | **CloudKit private database** | Kullanıcı Apple ID'siyle eşitlenir, sunucu maliyeti yok, veriyi biz tutmadığımız için gizlilik yükü minimum. |
| Eşitleme fiyatı | **Ücretsiz** | Bookmory ve Bookly senkronu paywall'a koyup şikayet alıyor. Ücretsiz senkron doğrudan pazarlama silahı. |
| Paywall biçimi | **Özellik kilidi** — kitap sayısı sınırı YOK | Bookly'nin 10 kitap duvarı nişin en yoğun ikinci şikayeti; ücretsiz katmanı "esasen bir deneme"ye çeviriyor. |
| Fiyat | **$3.99/ay · $24.99/yıl · $59.99 lifetime**, yıllıkta 7 gün deneme | Medyanın ($30.99) %19 altı; Bookly ve Bookmory'yi görünür biçimde kırar ama ucuz katmanın iki katı. Bölgesel ölçek: **[Pricing.md](Pricing.md)**. |
| LLM öneri botu | **Kapsam dışı** | Margins, Bookly, StoryGraph, Fable, Bookwise, READO ve Kindle'ın hepsinde AI öneri var. Yedinci oyuncu olmak farklılaşma sağlamaz, tek tekrar eden maliyet kalemimiz olur. |
| Öneri | **Yerel benzerlik motoru, ücretsiz katmanda** | Maliyetsiz, çevrimdışı, ücretsiz katmanı güçlendirir. |
| Backend | **Yok** | CloudKit ve StoreKit ihtiyacı karşılıyor. Google Books anahtarı riski Faz K'de ayrıca ele alınıyor. |

### Katman dağılımı

**Ücretsiz:** Sınırsız kitap · keşif/arama/barkod · okuma oturumları ve atmosfer ·
temel istatistik (mevcut Journal) · okuma serisi · **iCloud eşitleme** · yerel öneriler

**Pro:** Live Activity · okuma hedefleri · widget'lar · zengin istatistik (Swift Charts) ·
alıntı defteri + OCR · yıl sonu özeti · dışa aktarma

---

## 1. Mevcut durumdan hedefe

```
BUGÜN                                    HEDEF
─────                                    ─────
2 target (app + tests)          →        4 target (app, tests, widget ext, widget tests)
SwiftData yerel                 →        SwiftData + CloudKit private DB
Store: varsayılan konum         →        Store: App Group konteyneri
Schema V1                       →        Schema V2 (CloudKit uyumlu + yeni alanlar)
StoreKit yok                    →        StoreKit 2 + entitlement servisi + paywall
TARGETED_DEVICE_FAMILY = 1      →        değişmiyor (iPhone; iPad v2 kararı)
iOS 17.6                        →        değişmiyor
```

---

## Faz A — Şema V2: CloudKit uyumluluğu + yeni alanlar

**Neden birleşik:** CloudKit uyumluluk düzeltmeleri ile yeni alanlar aynı üç
modele dokunuyor. Her migration bir risk; ikisini tek sürüm artışında yapmak
kullanıcıyı tek bir geçişe maruz bırakır.

### A.1 CloudKit'in dayattığı değişiklikler

CloudKit private database üç sert kural koyar. Mevcut modeller üçünü de ihlal ediyor:

**1. `@Attribute(.unique)` desteklenmiyor — üçü de kaldırılacak:**

| Dosya | Satır | Mevcut |
|---|---|---|
| `LocalLibraryEntryModel.swift` | `bookID` | `@Attribute(.unique) var bookID: String` |
| `LocalReadingSessionModel.swift` | `id` | `@Attribute(.unique) var id: String` |
| `LocalCategoryModel.swift` | `id` | `@Attribute(.unique) var id: String` |

**2. Tüm attribute'lar optional olmalı veya varsayılan değer taşımalı.**
Şu an varsayılansız zorunlu alanlar: `title`, `authors`, `subjects`,
`readingStatusRawValue`, `ownershipStatusRawValue`, `progressTypeRawValue`,
`currentPage`, `addedDate`, `startDate`, `durationSeconds`, `pagesRead`, `name`.
Hepsine varsayılan verilecek (`var title: String = ""`, `var currentPage: Int = 0` …).

**3. Tüm ilişkiler optional olmalı veya varsayılan taşımalı.**
`readingSessions` ve `categories` `= []` alacak. `libraryEntry` zaten optional.
`.cascade` ve `.nullify` silme kuralları CloudKit'te destekleniyor, korunuyor.

### A.2 Tekillik kaybının telafisi

`@Attribute(.unique)` gidince veritabanı seviyesinde koruma kalmıyor. İki risk:

- **Uygulama içi:** `LocalLibraryRepositoryImpl.add(_:)` zaten `record(for:)` ile
  arayıp varsa güncelliyor — kod seviyesinde korunuyor, değişiklik gerekmiyor.
- **Eşitleme kaynaklı:** İki cihaz çevrimdışıyken aynı kitabı eklerse CloudKit
  birleşince iki satır oluşur. Bu **yeni** bir risk ve ele alınmalı.

Çözüm: `LibraryDeduplicator` — uygulama açılışında ve CloudKit uzak değişiklik
bildirimi geldiğinde çalışan bir birleştirme geçişi.

```
Aynı bookID'ye sahip kayıtlar için:
  - en eski addedDate'i koru
  - currentPage = max(hepsi)
  - readingStatus = en ileri durum (wishlist < toRead < reading < finished)
  - readingSessions = birleşik küme, session.id'ye göre tekilleştir
  - categories = birleşik küme
  - fazlalık kayıtları sil
```

Aynı mantık `LocalCategoryModel` (id'ye göre) ve `LocalReadingSessionModel`
(id'ye göre) için de gerekiyor. Oturum tekilleştirmesi kritik: yinelenen oturum
toplam okuma süresini ve kişisel hızı bozar.

### A.3 Yeni alanlar

Öneri motorunun ve zengin istatistiğin yakıtı. Şu an kullanıcının bir kitabı
sevip sevmediğini gösteren **hiçbir sinyal yok**.

`Models/Sources/Models/LibraryEntry.swift`:

```swift
public var rating: Int?          // 1-5, nil = puanlanmamış
public var finishedDate: Date?   // .finished'a geçildiği an
public var notes: String?        // serbest not
public var isFavorite: Bool      // hızlı sinyal
```

Yeni domain tipi `Models/Sources/Models/Quote.swift`:

```swift
public struct Quote: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public var text: String
    public var pageNumber: Int?
    public var note: String?
    public var createdDate: Date
}
```

Yeni SwiftData modeli `LocalQuoteModel` — `LocalLibraryEntryModel` ile
`.cascade` ilişki (kitap silinince alıntılar da gider).

`finishedDate` otomatik doldurulur: `readingStatus` `.finished`'a geçtiği anda
`LibraryEntry` içinde set edilir; geri alınırsa `nil`'lenir. Mevcut kayıtlar
için migration sırasında en son oturumun tarihi kullanılır, oturum yoksa `nil`.

### A.4 Şema sürümlendirme

`LibrarySchema.swift` zaten `VersionedSchema` ile kurulu — bu işi kolaylaştırıyor.

```swift
enum LibrarySchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [LocalLibraryEntryModel.self, LocalReadingSessionModel.self,
         LocalCategoryModel.self, LocalQuoteModel.self]
    }
}

enum LibraryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LibrarySchemaV1.self, LibrarySchemaV2.self] }
    static var stages: [MigrationStage] { [migrateV1toV2] }
}
```

V1 model tanımları `LibrarySchemaV1` altına **kopyalanacak** (dosyadaki yorumun
tarif ettiği yöntem). Geçiş `.custom` olmalı — `didMigrate` içinde `finishedDate`
geriye dönük doldurulur.

### A.5 Store konumu: App Group

Widget ve Live Activity uzantısı aynı SwiftData mağazasını okuyacak. Varsayılan
konum uzantıdan erişilemez.

- App Group: `group.com.semihtakilan.BookTrace`
- `LocalStore.makeConfiguration()` App Group URL'i kullanacak
- **Tek seferlik dosya taşıma:** mevcut kullanıcıların mağazası eski konumdan
  gruba taşınmalı (`.sqlite`, `-shm`, `-wal` üçü birden). Taşıma başarısızsa
  eski konumdan devam et, veri kaybetme.
- `BookCacheStorage` **taşınmayacak ve CloudKit'e bağlanmayacak**: arama önbelleği
  cihaza özgüdür, iCloud kotasını doldurmanın anlamı yok.

### Kabul kriterleri
- [ ] V1 mağazası olan bir cihaz güncellemede veri kaybetmeden açılıyor
- [ ] İki simülatörde aynı iCloud hesabıyla eklenen kitap tek satır olarak birleşiyor
- [ ] `LibraryDeduplicator` yinelenen oturumları eleyip toplam süreyi bozmuyor
- [ ] Arama önbelleği iCloud'a gitmiyor

### Testler
`Models`: `LibraryEntry` yeni alanları, `finishedDate` otomasyonu, `Quote`.
`BookTraceTests`: `LibraryDeduplicator` birleştirme senaryoları (çakışan ilerleme,
yinelenen oturum, çakışan durum), V1→V2 migration testi, App Group taşıma testi.

### Riskler
Migration + store taşıma + CloudKit aynı sürümde. **Mevcut kullanıcı yoksa ucuz,
varsa en riskli faz.** Uygulama henüz yayında olmadığı için şimdi yapmak doğru
zamanlama — yayın sonrasına kalırsa maliyeti katlanır.

---

## Faz B — CloudKit eşitlemesini açma

Faz A şemayı uyumlu hâle getirdi; bu faz eşitlemeyi devreye alıyor.

- `BookTrace.entitlements` oluştur: iCloud + CloudKit, konteyner
  `iCloud.com.semihtakilan.BookTrace`; App Group; Background Modes → Remote notifications
- `ModelConfiguration(..., cloudKitDatabase: .private("iCloud.com.semihtakilan.BookTrace"))`
- `AppDependencies` içinde konteyner kurulumu; **CloudKit açılamazsa yerel moda düş**
  (mevcut `BookCacheStore` için uygulanan "hata yukarı fırlatılmıyor" deseninin aynısı)
- Ayarlara eşitleme durumu göstergesi: son eşitleme, "iCloud kapalı" uyarısı
- Uzak değişiklik geldiğinde `LibraryChangeNotifier.notifyChanged()` tetiklenmeli —
  mevcut ekran tazeleme mekanizması bu sayede eşitleme sonrası da çalışır

### Kabul kriterleri
- [ ] iki cihaz arasında kitap, ilerleme, oturum, kategori ve alıntı eşitleniyor
- [ ] iCloud kapalı hesapta uygulama yerel modda sorunsuz çalışıyor
- [ ] eşitleme sonrası açık ekranlar kendini tazeliyor

### Riskler
CloudKit şema değişikliği geri alınamaz: development konteynerinde şema
oturmadan production'a **deploy edilmemeli**. Production'a çıkan bir CloudKit
şemasından alan silinemez.

---

## Faz C — StoreKit 2 + abonelik altyapısı

### Ürünler (App Store Connect)

| Ürün | Tip | ID | Fiyat |
|---|---|---|---|
| Aylık | Auto-renewable (grup: `BookTracePro`) | `com.semihtakilan.BookTrace.pro.monthly` | $3.99 |
| Yıllık | Auto-renewable (aynı grup) | `com.semihtakilan.BookTrace.pro.yearly` | $24.99 + 7 gün deneme |
| Lifetime | **Non-consumable** (grup dışı) | `com.semihtakilan.BookTrace.pro.lifetime` | $59.99 |

Fiyatlar ABD storefront'u içindir. 13 pazar için elle ayarlanacak bölgesel ölçek,
deneme/teklif yapısı ve Small Business Program notu: **[Pricing.md](Pricing.md)**.
Kritik mekanik: Apple **abonelik fiyatlarını otomatik güncellemez** — bir bölgeye
özel fiyat koyduğun an o bölgenin bakımı sana geçer.

Lifetime abonelik grubuna giremez; ayrı bir non-consumable olarak tanımlanır ve
entitlement mantığında ayrıca kontrol edilir.

### C.0 App Store Connect kurulumu (koddan bağımsız, erken başlar)

- [ ] **Small Business Program başvurusu** — komisyon %30 yerine %15. Yeni
      geliştirici hemen başvurabilir; her yıl yeniden kaydolunur. Yıllıkta net
      geliri $17.49'dan $21.24'e çıkarır, yani tek başına fiyat kararından daha
      büyük etki.
- [ ] Abonelik grubu `BookTracePro` + iki abonelik + bir non-consumable oluştur
- [ ] **Bölgesel fiyatları elle gir — yalnızca 13 pazar** ([Pricing.md](Pricing.md) §3).
      Kalan ~160 storefront Apple'ın otomatik dönüşümünde bırakılır.
- [ ] Yıllığa **7 gün introductory offer (free trial)** tanımla. Aylığa deneme
      **verme** — yıllığa yönlendiren kaldıracı harcar. Lifetime'da teknik olarak
      mümkün değil.
- [ ] Abonelik yerelleştirilmiş adları ve açıklamaları (EN/TR/DE)
- [ ] Yenileme, iptal ve fiyat değişikliği e-posta şablonlarını gözden geçir

**Lansman indirimi taban fiyatı düşürerek yapılmayacak.** Abonelik taban fiyatını
sonradan yükseltmek mevcut abonelerin onayını gerektirir veya onları eski fiyatta
bırakır. İndirim gerekirse **introductory offer** ile yapılır; taban sabit kalır.

**Uyarı:** Apple abonelik fiyatlarını kur/vergi değiştikçe otomatik güncellemez ve
bir bölgeye özel fiyat koyduğun an o storefront'un bakımı kalıcı olarak sana geçer.
Elle ayarlanan 13 pazar yılda bir gözden geçirilmeli.

### Yeni dosyalar

```
BookTrace/Core/Subscription/
├── ProEntitlement.swift        # Domain: .free / .pro(kaynak, bitiş)
├── SubscriptionService.swift   # actor: ürün yükleme, satın alma, restore
├── EntitlementStore.swift      # @Observable @MainActor, UI'ın gördüğü tek kaynak
└── ProGate.swift               # ViewModifier + .proGated() yardımcıları
BookTrace/Presentation/Features/Paywall/
├── PaywallView.swift
└── PaywallViewModel.swift
Config/BookTrace.storekit        # yerel test yapılandırması
```

### Teknik notlar

- `Transaction.updates` dinleyicisi **uygulama açılışında** başlatılır ve yaşam
  boyu sürer; yoksa uygulama dışında yenilenen abonelik yakalanmaz
- Entitlement kaynağı `Transaction.currentEntitlements` — sunucu doğrulaması yok,
  hesap yok, cihaz Apple ID'sine bağlı
- `AppStore.sync()` ile Restore; paywall'da **görünür buton zorunlu** (Guideline 3.1.2)
- Entitlement `EntitlementStore` üzerinden `Environment`'a konur; `ViewModelFactory`
  Pro gerektiren view model'lara enjekte eder
- **Ağ yokken Pro kapanmamalı:** son bilinen entitlement Keychain'de saklanır ve
  `currentEntitlements` okunana kadar kullanılır. Uçakta Pro'nun kapanması kabul edilemez.

### Paywall tetikleyicileri

Onboarding duvarı **yok** — nişte en çok puan düşüren desen. Paywall yalnızca:
1. Pro özelliğine dokunulduğunda (Live Activity başlatma, hedef ekleme, widget kurulumu, alıntı ekleme, dışa aktarma)
2. Ayarlar → "BookTrace Pro" satırı
3. Yıl sonu özeti hazır olduğunda (yılda bir, yumuşak)

### Kabul kriterleri
- [ ] Üç ürün de satın alınabiliyor, Pro anında açılıyor
- [ ] Restore çalışıyor; ikinci cihazda satın alma tekrar istenmiyor
- [ ] Deneme süresi bitince Pro kapanıyor
- [ ] Uçak modunda Pro açık kalıyor
- [ ] Paywall'da fiyat, süre ve dönem açıkça yazıyor; Gizlilik ve Kullanım Koşulları linkleri var
- [ ] Yıllık varsayılan seçili ve üzerinde "%48 tasarruf" rozeti var
- [ ] Deneme yalnızca yıllıkta görünüyor; aylık ve lifetime'da deneme vaadi yok
- [ ] Fiyatlar cihazın storefront'una göre yerel para biriminde geliyor
      (`Product.displayPrice` — elle biçimlendirme yok)

### Testler
`StoreKitTest` + `SKTestSession`: satın alma, iptal, yenileme başarısızlığı,
deneme bitişi, restore. `ProGate` için ücretsiz/Pro davranış testleri.

---

## Faz D — Live Activity + widget'lar

**Yeni target:** `BookTraceWidgets` (Widget Extension) + `BookTraceWidgetsTests`.

### D.1 Live Activity — bu projenin en doğal özelliği

`ReadingSessionViewModel` süreyi `Timer` ile saymıyor; `sessionStartDate` ve
`Date()` farkından hesaplıyor. Live Activity'nin `Text(timerInterval:)` bileşeni
de tam olarak böyle çalışır — **uygulama arka plandayken bile sistem sayacı
kendi günceller**. Mevcut tasarım bu özelliği neredeyse bedava veriyor.

```swift
struct ReadingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var pausedElapsed: TimeInterval?   // nil = çalışıyor
        var currentPage: Int
        var pageCount: Int?
    }
    let bookTitle: String
    let author: String
    let coverURLString: String?
    let paletteHex: String?     // mevcut BookPalette'ten
}
```

- Kilit ekranı görünümü + Dynamic Island (compact / minimal / expanded)
- Duraklatıldığında `pausedElapsed` dolar, sayaç donar
- Oturum kaydedilince veya iptal edilince Activity `.end` edilir
- **Kapak paleti Live Activity'ye taşınır** — rakiplerde olmayan görsel imza
- `NSSupportsLiveActivities = YES` (`Config/Info.plist`)
- Live Activity Pro özelliği; ücretsiz kullanıcıda oturum normal çalışır, sadece
  kilit ekranı sayacı yok

### D.2 Widget'lar

| Widget | Boyutlar | İçerik |
|---|---|---|
| Şu An Okunan | small, medium | Kapak, ilerleme çubuğu, kalan süre tahmini |
| Okuma Serisi | small | Seri günü + son 7 gün şeridi |
| Hedef İlerlemesi | small, medium | Yıllık/aylık hedefe göre halka |
| Kilit ekranı | accessoryCircular, accessoryRectangular | Seri ve ilerleme |

- Veri App Group'taki SwiftData mağazasından okunur (Faz A.5)
- `WidgetCenter.shared.reloadAllTimelines()` — `LibraryChangeNotifier` tetiklendiğinde
- Widget'lar Pro; ücretsiz kullanıcıda kurulum ekranı paywall'a yönlendirir

### Kabul kriterleri
- [ ] Oturum başlayınca kilit ekranında sayaç görünüyor ve uygulama kapalıyken doğru sayıyor
- [ ] Duraklat/devam Live Activity'ye yansıyor
- [ ] Oturum kaydedilince Activity kapanıyor
- [ ] Widget'lar veriyi App Group'tan okuyor, kütüphane değişince tazeleniyor
- [ ] Reduce Motion ve düşük güç modunda davranış bozulmuyor

---

## Faz E — Okuma hedefleri

`Plan.md` Faz 10'da açık kalan madde.

```swift
public struct ReadingGoal: Identifiable, Hashable, Sendable, Codable {
    public enum Period: String, Codable, Sendable { case daily, weekly, monthly, yearly }
    public enum Metric: String, Codable, Sendable { case minutes, pages, books, sessions }
    public let id: String
    public var period: Period
    public var metric: Metric
    public var target: Int
    public var startDate: Date
    public var isActive: Bool
}
```

- `GoalProgressCalculator` — saf, durumsuz, `Models` paketinde, birim testli
  (`ReadingSpeedEstimator` ve `ReadingStreak` ile aynı desen)
- Yeni `LocalReadingGoalModel` (CloudKit uyumlu, Faz A kurallarıyla)
- Journal'da hedef kartı; widget'ta halka
- Hedefe ulaşınca mevcut `SessionCelebrationView` altyapısı yeniden kullanılır
- Bildirim **yok** (v1): izin istemek dönüşümü düşürür, hedef zaten widget'ta görünür

---

## Faz F — Zengin istatistik (Swift Charts)

`Plan.md` Faz 10'un ikinci açık maddesi. StoryGraph'ın iOS'ta yapamadığı şey bu
ve nişte en net farklılaşma alanı.

- Yıllık takvim ısı haritası (GitHub katkı grafiği deseni)
- Aylık okuma süresi ve sayfa trendi
- Tür/konu dağılımı — `BookReference.subjects` üzerinden
- Okuma hızının zaman içindeki değişimi
- Günün saatine göre okuma dağılımı (`ReadingSession.startDate`)
- Puan dağılımı (Faz A'nın `rating` alanı)
- Bitirilen kitapların ortalama süresi ve sayfa sayısı

Mevcut `ProfileViewModel` türetilmiş değerleri `load()` içinde bir kez hesaplayıp
saklıyor (`@Observable` computed property'leri önbelleklemiyor). Yeni istatistikler
**aynı deseni** izlemeli, yoksa her yeniden çizimde tüm oturumlar yeniden düzlenir.

Hesaplamalar `Models` paketinde saf fonksiyonlar olarak yazılır; `ProfileViewModel`
yalnızca çağırır. Böylece UI'sız test edilebilir.

Ücretsiz katman mevcut Journal'ı korur; bu ekranlar Pro.

---

## Faz G — Alıntı defteri + OCR

Rakiplerde en zayıf alan; Bookly alıntı görselini Pro'ya koymuş, yani talebi
kendisi doğruluyor.

- Alıntı ekleme: elle yazma veya **kamerayla sayfa fotoğrafı → Vision OCR**
- `VNRecognizeTextRequest` (iOS 17.6 uyumlu API), tamamen cihaz içi, ücretsiz, çevrimdışı
- OCR sonrası **düzenlenebilir** metin alanı — otomatik kabul edilmez
- Sayfa numarası, not, favori işareti
- Alıntıdan paylaşılabilir görsel kartı (kitap paleti ve atmosferiyle)
- Kitap detayında alıntı sekmesi; Journal'da tüm alıntılarda arama

**Dürüst kısıt:** Vision'ın metin tanıma dil listesinde **Türkçe yok**. Latin
alfabesi olduğu için karakterler büyük ölçüde tanınır ama Türkçe'ye özgü
karakterlerde (ı, ğ, ş) ve kelime düzeltmesinde doğruluk düşer. Bu yüzden
düzenlenebilir alan zorunlu, otomatik kayıt yok. Kullanıcıya OCR'ın yardımcı
olduğu, kusursuz olmadığı anlatılmalı.

---

## Faz H — Yıl sonu özeti

Ücretsiz viral pazarlama; App Store'a organik trafik getiren tek özellik.

- Kaç kitap, kaç sayfa, kaç saat, en uzun seri, en hızlı okunan kitap,
  en çok okunan tür, yılın kitabı (en yüksek puan)
- Mevcut kapak paleti ve atmosfer sistemiyle üretilen paylaşılabilir kart
- Aralık ayında Journal'da otomatik beliren giriş
- **Özet ücretsiz, tam sürüm (tüm kartlar + yüksek çözünürlüklü dışa aktarma) Pro** —
  paylaşılan görselde uygulama adı geçtiği için ücretsiz kısım pazarlama yatırımı

---

## Faz I — Dışa/içe aktarma

- **Dışa:** CSV (Goodreads sütun düzeniyle uyumlu) ve JSON (tam yedek, alıntılar ve oturumlar dahil)
- **İçe:** Goodreads CSV — rakipten göçün önündeki en büyük engeli kaldırır.
  Margins'in hızlı büyümesindeki etkenlerden biri Goodreads/StoryGraph/Fable içe aktarma.
- ISBN → `BookReference` çözümleme mevcut `HybridBookSearching` üzerinden;
  `DailyRequestBudget` sınırına takılmamak için toplu içe aktarma Open Library
  öncelikli ve kademeli olmalı
- Dışa aktarma Pro; **içe aktarma ücretsiz** (kullanıcı kazanma aracı, engel değil)

---

## Faz J — Yerel öneri motoru

`Plan.md` Faz 9. Ücretsiz katmanda kalır.

`Models/Sources/Models/RecommendationEngine.swift` — saf, durumsuz, birim testli:

```
Sinyaller:
  + bitirilmiş kitapların konuları ve yazarları (ağırlık × puan)
  + isFavorite işaretli kitaplar (yüksek ağırlık)
  + okunmakta olanların konuları (orta ağırlık)
  − abandoned kitapların konuları (negatif ağırlık)
  − kütüphanede zaten olanlar (elenir)
```

Adaylar Open Library konu uçlarından çekilir; ek maliyet yok. Explore'da
"Sana Göre" rafı olarak görünür. Yazar modülü (`Plan.md` Faz 8) bu motorun
doğal devamıdır ve buraya bağlanır.

---

## Faz K — Store hazırlığı

### K.1 Google Books anahtarı

Anahtar şu an `Config/Secrets.xcconfig` üzerinden Info.plist'e gömülüyor.
`Secrets.xcconfig` doğru şekilde `.gitignore`'da (`.gitignore:75`), ama derlenmiş
IPA'dan anahtar çıkarılabilir. Ücretli bir uygulamada bu, kotanın yakılması demek.

Backend yazmama kararı verildiği için üç seçenek:
1. **Google Cloud kısıtları** — anahtarı iOS bundle ID'sine kilitle (ücretsiz, hemen yapılabilir, kısmi koruma)
2. Open Library'yi tek kaynağa çıkar, Google Books'u tamamen kaldır
3. Sonradan hafif bir proxy (kararı erteleriz)

v1 için **(1)** yeterli; mevcut `DailyRequestBudget` zaten cihaz başına 25 istek
sınırı koyuyor.

### K.2 Apple gereklilikleri

- [ ] Paid Applications Agreement + banka/vergi bilgisi (**günler sürebilir, ilk iş bu**)
- [ ] Small Business Program başvurusu (%15 komisyon) — bkz. Faz C.0
- [ ] 13 pazarın bölgesel fiyatları girildi ([Pricing.md](Pricing.md) §3)
- [ ] Gizlilik Politikası URL'i — hem ASC'de hem paywall içinde link
- [ ] Kullanım Koşulları (EULA) — aynı iki yerde
- [ ] App Privacy etiketleri: kamera (barkod + OCR), arama sorguları, CloudKit verisi
- [ ] Restore Purchases butonu — çalışır ve görünür
- [ ] Abonelik başlığı, süresi, dönem başına fiyatı paywall'da açık (3.1.2)
- [ ] Ekran görüntüleri: 6.9" ve 6.5"
- [ ] Destek URL'i, pazarlama URL'i
- [ ] Yaş derecelendirme anketi
- [ ] İhracat uyumluluğu beyanı (yalnızca HTTPS → standart muafiyet)
- [ ] Kamera izin metinleri (barkod ve OCR için ayrı ayrı anlamlı)

**Hesap silme gerekmiyor** — hesap sistemi yok. Bu, hesapsız mimarinin somut kazancı.

### K.3 ASO — ciddi bir risk

App Store'da "Book Tracker" adını taşıyan **en az beş ayrı uygulama** ve 20+ jenerik
klon var. "BookTrace" bunların arasında kaybolur.

- Alt başlık ve anahtar kelimeler farklılaşmayı taşımalı: okuma oturumu, odaklanma,
  Live Activity, istatistik, gizlilik, abonelik yok değil ama **kitap sınırı yok**
- Apple editöryel başvurusu (App Store'da öne çıkarma formu) — Margins'in iki yılda
  sıfırdan 19.000 yoruma çıkmasındaki en büyük etken
- TestFlight halka açık link ile erken geri bildirim

---

## Test stratejisi

Mevcut kurulum korunur ve genişletilir: `Models` ve `NetworkKit` paket testleri,
`BookTraceTests` uygulama testleri, CI'da Debug + Release derlemesi.

| Alan | Nerede | Ne test edilir |
|---|---|---|
| Yeni domain alanları | `ModelsTests` | `finishedDate` otomasyonu, `Quote`, `rating` sınırları |
| Öneri motoru | `ModelsTests` | Skorlama, negatif sinyal, eleme |
| Hedefler | `ModelsTests` | `GoalProgressCalculator` dönem sınırları |
| İstatistik hesapları | `ModelsTests` | Saf fonksiyonlar, UI'sız |
| Migration | `BookTraceTests` | V1→V2, veri kaybı yok |
| Deduplication | `BookTraceTests` | Çakışan ilerleme, yinelenen oturum |
| App Group taşıma | `BookTraceTests` | Taşıma başarısızsa eski konumdan devam |
| StoreKit | `BookTraceTests` + `SKTestSession` | Satın alma, restore, deneme bitişi, iptal |
| Entitlement | `BookTraceTests` | Çevrimdışı davranış, Keychain önbelleği |

CI'ya widget target'ının derlemesi eklenmeli.

---

## Sıralama ve bağımlılıklar

```
A (Şema V2 + App Group)
├─→ B (CloudKit)
├─→ C (StoreKit)  ──┐
│                   ├─→ D (Live Activity + Widget)   [A: App Group, C: gate]
│                   ├─→ E (Hedefler)                  [A: şema, C: gate]
│                   ├─→ F (İstatistik)                [A: rating/finishedDate, C: gate]
│                   ├─→ G (Alıntı + OCR)              [A: Quote, C: gate]
│                   ├─→ H (Yıl sonu özeti)            [F: hesaplar, C: gate]
│                   └─→ I (Dışa aktarma)              [A: şema, C: gate]
└─→ J (Öneri motoru)                                  [A: rating; gate yok, ücretsiz]

K (Store hazırlığı) — K.1 ve K.2'nin idari kısmı EN BAŞTA başlatılır
```

**Neden bu sıra:** A her şeyin altında; şema değişikliğini yayın sonrasına
bırakmak maliyeti katlar. C erken gelir çünkü ödeme altyapısı çalışmadan Pro
özellikleri geliştirmek spekülatiftir — gate'i baştan koyup her özelliği
arkasına takmak, sonradan gate eklemekten ucuzdur. D ilk Pro özelliği olarak
seçildi çünkü hem en görünür hem de mevcut mimariye en ucuz oturan özellik.

**Paralel başlatılabilir:** K.2'nin idari maddeleri (Paid Applications Agreement,
banka/vergi) kod işinden bağımsızdır ve gecikme riski taşır — bugün başlatılmalı.

---

## Riskler

| Risk | Etki | Azaltma |
|---|---|---|
| Görünmezlik (ASO) | **En yüksek** — iyi ürün yetmez | Farklı isim açısı, editöryel başvuru, TestFlight, yıl sonu özeti viralliği |
| CloudKit şeması production'a erken deploy | Geri alınamaz | Development konteynerinde şema oturmadan deploy yok |
| A fazı migration + store taşıma + CloudKit birlikte | Veri kaybı | Yayın öncesi yap; her adımda geri düşüş yolu; migration testi |
| Senkron ücretsizken Pro'nun algılanan değeri düşük | Dönüşüm | Live Activity ve istatistik tek başına ödeme tetiklemeli; paywall'da bunlar öne çıkar |
| Vision OCR Türkçe'yi resmî desteklemiyor | TR kullanıcı hayal kırıklığı | Düzenlenebilir alan zorunlu, beklenti doğru kurulur |
| Bookly'nin 61.000 yorumluk sosyal kanıtı | Organik büyüme yavaş | Uzun vadeli; niş konumlanma (okuma oturumu) ile doğrudan rekabetten kaçın |
| Google Books anahtarı IPA'dan çıkarılabilir | Kota yakılması | Bundle ID kısıtı + mevcut `DailyRequestBudget` |
| Abonelik fiyatları kur kaymasıyla bayatlar | Elle ayarlanan 13 pazarda gelir erimesi | Apple bunları güncellemiyor; yıllık gözden geçirme takvime alındı ([Pricing.md](Pricing.md) §6) |
| TR'de rakiplerin bayat fiyatları yanında pahalı görünme | TR dönüşümü | ₺449 katı PPP'nin (₺566,99) altına çekildi; TR gelir değil yorum/erişim pazarı olarak konumlandı |
| Lifetime aboneliği yiyor | LTV düşer | 3. ayda lifetime oranı %25'i geçerse fiyat yükseltilir ([Pricing.md](Pricing.md) §6) |

---

## Kapsam dışı (bilinçli)

- LLM sohbet/öneri botu — alan dolu, tekrar eden maliyet (Faz J yerel motoru yeterli)
- Hesap sistemi, backend, sosyal katman
- Apple Watch uygulaması, iPad düzeni (`TARGETED_DEVICE_FAMILY = 1` korunuyor)
- Push bildirimleri
- EPUB/PDF okuyucu
- Kitap kulübü, arkadaş takibi

Bunlar reddedilmiş değil, **v1 sonrası** kararlar. Her biri ayrı bir ürün
kararı gerektiriyor ve v1'in kapsamını taşıyamaz.
