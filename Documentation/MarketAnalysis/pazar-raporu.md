# iOS Okuma Takip / Kişisel Kitaplık Uygulamaları — App Store Pazar Analizi

**Araştırma tarihi:** 2026-09-07 · **Pazar:** ABD App Store (Türkiye storefront'u ayrıca kontrol edildi) · **Taranan:** 34+ uygulama, 14'ü detaylı profillendi

---

## 1. Özet

- Niş **kalabalık ve olgun**: 14 ciddi oyuncunun üstünde 20+ klon var, ama kategoriyi domine eden tek bir isim yok — pazar dağınık.
- Para **iki ayrı ekonomiden** geliyor ve ikisi birbirine düşman: $29.99–59.99/yıl abonelik ekonomisi (Bookly, Margins, Bookmory, Fable, StoryGraph) ve $5.99–15.99 tek seferlik ekonomi (Book Tracker, PagePath, Bookdot). Medyan yıllık abonelik **$30.99**.
- Liderler: iOS'ta çekiş bakımından **Bookly** (61.000 yorum, Books kategorisinde top-free #28 ve **top-grossing #62**) ve **Margins** (4.9 puan, 19.000 yorum, 20+ ülkede App of the Day — 2024 sonunda çıktı, iki yılda patladı).
- En belirgin boşluk: **StoryGraph'ın iOS uygulaması 3 MB'lık bir web wrapper, 20-30 saniyelik yükleme süreleriyle ve Mart 2025'ten beri güncellenmiyor** — oysa StoryGraph, Reddit ve BookTok'ta en çok önerilen Goodreads alternatifi. Marka güçlü, iOS yüzeyi çürük.
- Tavsiye edilen hamle: BookTrace'in AI öneri botunu **bayrak özelliği yapmaması** — o alan çoktan doldu — bunun yerine zaten sahip olduğu okuma oturumu/tempo/atmosfer derinliğini native hız ve Apple yüzeyleriyle (Live Activity, Watch, widget) birleştirip **hesapsız + iCloud** modeliyle Bookly'nin nefret edilen 10 kitap duvarının karşısına konumlanması.

---

## 2. Pazar manzarası

Niş üç katmana ayrılıyor:

**Katman 1 — Web/sosyal platformlar (iOS'ta zayıf):** Goodreads, StoryGraph, Fable, Hardcover, Literal, BookWyrm. Hepsi hesap zorunlu, hepsi sunucu tabanlı. Goodreads'in arayüzü 2013'teki Amazon satın almasından beri anlamlı biçimde değişmedi; StoryGraph'ın iOS uygulaması web wrapper. Bu katman kullanıcıyı **elde tutuyor ama iOS'ta memnun etmiyor.**

**Katman 2 — Native abonelik uygulamaları (paranın olduğu yer):** Bookly, Margins, Bookmory. Üçü de son bir hafta içinde güncellenmiş, üçü de 16.000+ yorumlu. Bu katman sağlıklı ve aktif.

**Katman 3 — Gizlilik odaklı tek seferlik indie'ler:** Book Tracker (booktrack.app), PagePath, Bookdot, Leafed, Simple Book Tracker. "Hesap yok, sunucu yok, izleme yok" konumlanması. Fiyat $5.99–15.99 tek seferlik. **BookTrace şu anda mimari olarak tam olarak bu katmanda duruyor** — ama kullanıcı abonelik geliri hedefliyor. Buradaki gerilim bu raporun ana meselesi.

Son 18 ayda giren ve tutunan tek büyük isim **Margins** (Kasım 2024). Tutunma sebebi net: AI "Search by Vibes" + Goodreads/StoryGraph/Fable'dan içe aktarma + Apple editöryel desteği. Aynı dönemde giren Bookster (4 yorum) ve Bookdot (3 yorum) tutunamadı — yani **niş yeni girene otomatik yer açmıyor**, editöryel destek veya keskin bir farklılaşma gerekiyor.

Klon katmanı geniş: Nightstand, Chapterly, ReadTracker, Paginary, ReadLog, ReadMark, Bookrise, Simple Book, Reading List, Handy Library ve benzeri 20+ isim. Jenerik isim, kopyala-yapıştır açıklama, yok denecek yorum sayısı. Bu, ASO'da uzun kuyruğun boş olduğunu ama **isim benzerliğinin görünürlüğü öldürdüğünü** gösteriyor — "Book Tracker" adını taşıyan en az beş farklı uygulama var.

---

## 3. Rakip karşılaştırması

Tam tablo: `karsilastirma.md` / `karsilastirma.csv`. Tablodan doğrudan okunmayan gözlemler:

- **Hesap zorunluluğu ile gelir arasında ilişki yok.** Bookly hesapsız çalışıyor ("No online account or signup needed" — App Store açıklaması), iCloud ile senkronlanıyor ve top-grossing #62'de. Margins hesap zorunlu tutuyor ve o da başarılı. Yani hesap sistemi bir gelir kaldıracı değil, bir **ürün kararı**.
- **Senkronu paywall'a koymak yaygın ama sevilmeyen bir desen.** Bookmory ücretsiz katmanda reklam gösteriyor ve cihazlar arası senkronu premium'a koyuyor. Bookly de bulut senkronu Pro'ya koyuyor. Buna karşılık Book Tracker ve Bookdot iCloud senkronu ücretsiz veriyor.
- **AI öneri artık farklılaştırıcı değil, standart.** Margins (Search by Vibes), Bookly (Bookly Assistant), StoryGraph (mood/pace ML), Fable (Scout's Pick), Bookwise, READO (Booklyn), Basmo (sohbet botu) ve Amazon'un Kindle'a eklediği "Ask this Book". 2026'da AI öneri, 2022'de karanlık mod neyse o.
- **Fiyat dağılımı çift tepeli.** $5.99–15.99 ve $29.99–59.99 arası neredeyse boş. Ortada oturan tek isim Bookdot ($12.99) ve tutunamamış. Bu, kullanıcıların "ucuz araç" ile "premium hizmet" arasında net bir zihinsel ayrım yaptığını gösteriyor.
- **Türkiye pazarı ince ama boş değil.** Bookmory Türkçe'ye tam yerelleştirilmiş (TR storefront'unda 463 yorum, ₺36,99/ay ve ₺329,99/yıl) ve Book Tracker da Türkçe destekliyor. Margins — nişin en hızlı büyüyen ismi — **yalnızca İngilizce**.

---

## 4. Para nereden geliyor

**Fiyat manzarası [Gözlem]:**

| Ölçü | Değer |
|---|---|
| Medyan yıllık abonelik | **$30.99** |
| Aralık | $12.99 – $59.99 |
| Yıllık abonelik sunan | 7/14 (%50) |
| Lifetime sunan | 5/14 (%35) |
| Reklam kullanan | 4/14 (%28) |
| Top-grossing'de doğrulanan | 1/14 (%7) — *bkz. veri boşlukları* |

**Arketip dağılımı:** freemium abonelik 6, tek seferlik ücretli 2, ücretsiz/destekçi 4, reklam+abonelik melezi 2.

**Baskın paywall desenleri:**

1. **Kullanım limiti** — en yaygın ve en çok gelir getiren. Bookly 10 kitap, Book Tracker 5 kitap, PagePath 25 kitap. [Gözlem]
2. **Özellik kilidi** — senkron, gelişmiş istatistik, temalar, dışa aktarma. Bookmory, Bookdot, StoryGraph. [Gözlem]
3. **Yumuşak duvar** — Margins "neredeyse her şey ücretsiz, opsiyonel abonelik" diyor; Hardcover ve Leafed destekçi/bahşiş modelinde. [Gözlem]

**Çıkarımlar:**

- Bookly top-free #28 **ve** top-grossing #62'de → dönüşümü çalışıyor, fiyatlandırması oturmuş. 10 kitap duvarı acımasız ama işe yarıyor. [Çıkarım]
- Margins 4.9 puanla en yumuşak paywall'a sahip ve yine de $59.99/yıl — nişin en pahalı yıllığı — istiyor. Yani **sevilen bir üründe yüksek fiyat cezalandırılmıyor**; cezalandırılan agresif duvar. [Çıkarım]
- Bookster'ın aynı anda hem $24.99 hem $59.99 yıllık kalemi ve 6 IAP satırı taşıması fiyat denemesi yaptığını, 4 yorumluk çekişi ise denemenin tutmadığını gösteriyor. [Çıkarım]
- 5/14 uygulamanın lifetime sunması ve tek seferlik ekonomi katmanının varlığı, nişte **belirgin bir abonelik yorgunluğu** olduğunu söylüyor. Bir kaynak bunu doğrudan formüle ediyor: okuma günlüğü tamamen telefonda çalışır, sunucu altyapısı gerektirmez, dolayısıyla aylık ücret orantısız hissettirir. [Gözlem]
- Bookly için üçüncü parti tahmin ayda ~40.000 indirme ve ~$60-70k gelir veriyor. [Tahmin] — tek bir agregatörden, doğrulanmadı, aynı sayfa son güncelleme tarihini de yanlış veriyor (Eylül 2024 diyor, App Store 3 gün önce diyor). Büyüklük mertebesi fikri için kullanılabilir, sayı olarak kullanılamaz.

---

## 5. Kullanıcı şikayetleri

Sıklık sırasıyla, her biri birden fazla bağımsız kaynakta:

**1. StoryGraph iOS uygulamasının performansı** — en yoğun ve en iyi belgelenmiş şikayet. Uygulama 3 MB'lık bir web wrapper; kullanıcılar 20-30 saniyelik, bazen dakikalara çıkan yükleme süreleri bildiriyor; açılışların yaklaşık yarısında boş ekranda takılma raporlanıyor. Kasım 2024'ten beri bozuluyor, ekip sorunu kabul etmiş ama ilerleme yavaş. Kaynaklar: StoryGraph'ın kendi resmî yol haritası bug bölümü (iki ayrı açık kayıt), App Store yorumları, karşılaştırma yazıları.

**2. Bookly'nin 10 kitap duvarı** — ücretsiz katman "esasen bir deneme" olarak niteleniyor. Kullanıcılar limite hızla ulaştıklarını, üstelik bitmiş kitapları **silemedikleri** için yer açamadıklarını (silme Pro özelliği) bildiriyor. Kaynaklar: birden çok inceleme yazısı ve App Store yorum derlemeleri.

**3. Abonelik yorgunluğu** — "bu kadar basit bir şey neden aylık abonelik istiyor, tek seferlik ödeme seçeneği olmalı" teması tekrar ediyor. Bir kaynak destekleyici veri sunuyor: insanların %41'i yinelenen ödemelerden bunaldığını söylüyor, kitap kategorisindeki tüketici harcamasının %77'si tek seferlik satın almalardan geliyor. [Gözlem — tek kaynaklı, bağımsız doğrulanmadı]

**4. Goodreads'in eskimişliği** — arayüz 2013'ten beri değişmemiş, yarım yıldız puanlama yok, istatistik yok, Amazon okuma etkinliğini izliyor. Bu, tüm nişin var oluş sebebi.

**5. Senkronun paywall arkasında olması** — Bookmory'de cihazlar arası senkron premium; ücretsiz katmanda reklam var.

**6. Kitap veritabanı boşlukları** — StoryGraph, Bookdot ve Literal için tekrar eden "niş başlıklar bulunamıyor" şikayeti. *BookTrace'in Open Library + Google Books melez kaynağı burada avantajlı.*

---

## 6. Boşluklar

### Boşluk 1 — iOS'ta hızlı, native, istatistik-derin bir StoryGraph alternatifi

- **Kanıt:** StoryGraph en çok önerilen Goodreads alternatifi ama iOS uygulaması web wrapper, 20-30 sn yükleme, 18 aydır güncellenmiyor, iOS'ta yalnızca 3.600 yorum toplayabilmiş. Marka talebi ile iOS arzı arasında ölçülebilir bir uçurum var.
- **Kimin derdi:** StoryGraph'ın istatistiklerini seven ama telefonda kullanamayan okur.
- **Neden hâlâ boş:** StoryGraph mimari olarak web-first; native'e geçmek onlar için sıfırdan yazmak demek ve ekip küçük. Rakiplerse (Bookly, Bookmory) istatistik derinliğine değil alışkanlık/oyunlaştırmaya odaklanmış. Yani boşluk teknik bir tercihin yan etkisi, gözden kaçmış bir fırsat değil — bu onu **gerçek** yapıyor.

### Boşluk 2 — Cömert ücretsiz katmanlı, hesapsız, senkronu ücretsiz veren abonelik uygulaması

- **Kanıt:** Bookly'nin 10 kitap duvarı en yoğun ikinci şikayet; Bookmory senkronu paywall'a koyuyor ve ücretsizde reklam gösteriyor; buna karşılık Margins "neredeyse her şey ücretsiz" diyerek 4.9 puan **ve** nişin en pahalı yıllığını birlikte tutturuyor.
- **Kimin derdi:** Kitap sayısı sınırına takılıp uygulamayı silen, ama doğru üründe ödemeye hazır orta-ağır okur.
- **Neden hâlâ boş:** Sıkı limit kısa vadede daha iyi dönüşüyor; Margins'in yumuşak modeli yatırım parasıyla finanse edilebilen bir lüks. Solo geliştirici için riskli ama uygulanabilir — çünkü maliyet tabanı düşük.

### Boşluk 3 — Okuma oturumunun kendisini ciddiye alan uygulama

- **Kanıt:** Rakiplerde zamanlayıcı var (Bookly, Bookmory, Bookdot) ama hepsinde sayaç bir veri giriş aracı. Hiçbirinde odaklanma deneyimi, ortam tasarımı veya Live Activity yok. Bookly ambient sesleri Pro'ya koymuş — yani bu yönde talep olduğunu kendisi doğruluyor.
- **Kimin derdi:** Telefon yüzünden okuyamayan, "okuma seansı" ritüeli kurmak isteyen okur — Forest/Flora'nın odaklanma kitlesiyle örtüşen bir segment.
- **Neden hâlâ boş:** Tracker geliştiricileri kendilerini kayıt aracı olarak görüyor, odaklanma uygulaması olarak değil. Bu bir konumlanma boşluğu; teknik engel yok. **BookTrace'in mevcut kapak paletleri, atmosferler ve tempo tahmini altyapısı tam olarak buraya oturuyor.**

### Boşluk 4 — İngilizce dışı pazarlar

- **Kanıt:** Nişin en hızlı büyüyen ismi Margins yalnızca İngilizce. Bookmory 15 dille bu boşluğu kısmen doldurmuş ve TR storefront'unda 463 yoruma ulaşmış. BookTrace'in EN/TR/DE desteği hazır.
- **Kimin derdi:** Türk ve Alman okurlar.
- **Neden hâlâ boş:** Yerelleştirme sıkıcı ve ölçülmesi zor bir yatırım; ABD merkezli ekipler önceliklendirmiyor. Ama **tek başına bir ürün stratejisi değil** — TR pazarının ARPU'su düşük, ancak ek bir kaldıraç.

### Boşluk 5 — *Kapanmış* boşluk: AI öneri

Dürüst olmak gerekirse burada boşluk yok. Margins, Bookly, StoryGraph, Fable, Bookwise, READO ve Basmo'nun hepsinde AI öneri var; Amazon Kindle'a "Ask this Book" ekledi. BookTrace'in öneri botu bu alana **geç giren yedinci oyuncu** olur. Sohbet botunu ürünün bayrağı yapma.

---

## 7. Fikirler

> BookTrace zaten var olan bir ürün olduğu için bunlar sıfırdan uygulama fikirleri değil, **BookTrace için üç konumlanma stratejisi**. Güçlüden zayıfa sıralı.

### Fikir 1: "Okuma seansı" konumlanması — Odaklanma + derin istatistik, hesapsız

- **Hedeflediği boşluk:** Boşluk 3 (oturum deneyimi) + Boşluk 1 (native hız/istatistik) + Boşluk 2 (cömert ücretsiz katman).
- **Hedef kitle:** Telefon yüzünden okuyamadığını söyleyen, ritüel kurmak isteyen 20-40 yaş okur. Reddit'te r/books, r/productivity; TikTok'ta #readingroutine. Bookly'nin kitlesiyle örtüşüyor ama Bookly'nin duvarından rahatsız olan kısmı.
- **MVP kapsamı (v1):** ① Mevcut okuma oturumu + atmosfer deneyimi (hazır) ② **Live Activity + Dynamic Island** ile kilit ekranında canlı sayaç ③ Okuma hedefleri + Home/Lock Screen widget'ları ④ `rating` / `finishedDate` / `notes` alanları ve bunlara dayalı Swift Charts istatistikleri ⑤ **iCloud (CloudKit) senkron — ücretsiz** ⑥ Yıl sonu paylaşılabilir okuma özeti.
- **v1'e girmeyecekler:** LLM sohbet botu (alan dolu, maliyet riski yüksek), sosyal katman (ağ etkisi gerektirir, solo geliştirici kaldıramaz), hesap sistemi (gereksiz yük — bkz. Bookly kanıtı), Apple Watch (v2).
- **Monetizasyon:** Freemium abonelik. **$29.99/yıl + $4.99/ay + $59.99 lifetime.** Medyanın ($30.99) hemen altında yıllık, ama lifetime'ı Bookly'nin $79.99'unun belirgin altına koyarak abonelik yorgunluğu segmentini de topluyor. Paywall **kitap sayısında değil özellikte**: kütüphane, oturumlar, temel istatistik ve yerel öneriler sınırsız ve ücretsiz; Pro = Live Activity + hedefler + widget + zengin istatistik + alıntı/OCR + yıl sonu özeti + dışa aktarma. Senkron **ücretsiz** — bu, Bookmory ve Bookly'ye karşı doğrudan bir pazarlama silahı. 7 gün deneme.
- **Solo yapılabilirlik: 20/25**

  | Eksen | Puan | Gerekçe |
  |---|---|---|
  | Teknik kapsam | 5 | Tamamen cihaz-içi + CloudKit; backend yok, sunucu maliyeti yok |
  | İçerik yükü | 5 | İçerik kullanıcıdan ve Open Library/Google Books'tan geliyor |
  | Bulunabilirlik | 3 | "Book tracker" adı beş uygulamada var; ASO'da farklı bir isim açısı şart |
  | Rekabet duvarı | 3 | Bookly ve Bookmory güçlü ve aktif, ama ikisi de sevilmeyen bir paywall taşıyor |
  | Ödeme anı | 4 | Live Activity ve yıl sonu özeti net "şimdi öderim" anları |

- **Riskler:** ① Bookly'nin 61.000 yorumluk sosyal kanıtını aşmak organik olarak çok zor — ASO ve editöryel başvuru olmadan görünmezlik en büyük tehdit. ② Senkronu ücretsiz vermek Pro'nun algılanan değerini düşürebilir; Live Activity ve istatistiğin tek başına ödeme tetiklemesi gerekir. ③ CloudKit göçü mevcut SwiftData şemasını değiştirmeyi gerektiriyor (tüm property'ler optional/default, `@Attribute(.unique)` kaldırılmalı) — mevcut kullanıcı yoksa ucuz, varsa riskli.

### Fikir 2: "Tek seferlik ödeme" konumlanması — Abonelik karşıtı premium

- **Hedeflediği boşluk:** Boşluk 2 ve şikayet #3 (abonelik yorgunluğu).
- **Hedef kitle:** Bookly/Bookmory aboneliğinden kaçan, Book Tracker ve PagePath'e yönelen ama o uygulamaları özellik olarak yetersiz bulan okur.
- **MVP kapsamı (v1):** Fikir 1'in aynısı, ama monetizasyon tersine — tek seferlik $14.99 tam sürüm, abonelik yok. Ücretsiz katman 10-15 kitap.
- **v1'e girmeyecekler:** Abonelik, LLM botu (tekrar eden maliyeti tek seferlik gelirle karşılanamaz), bulut backend.
- **Monetizasyon:** Tek seferlik **$14.99** — Book Tracker'ın $5.99'unun ve PagePath'in $9.99'unun üstünde, "daha ciddi ürün" konumlanması. Pazar medyanının çok altında toplam gelir, ama sıfır tekrar eden maliyet.
- **Solo yapılabilirlik: 19/25**

  | Eksen | Puan | Gerekçe |
  |---|---|---|
  | Teknik kapsam | 5 | Fikir 1 ile aynı; hatta CloudKit dışında hiçbir şey gerekmiyor |
  | İçerik yükü | 5 | Aynı |
  | Bulunabilirlik | 4 | "Abonelik yok" net bir ASO ve pazarlama mesajı; kategoride arayan kitle var |
  | Rekabet duvarı | 3 | Tek seferlik katman kalabalık ama oyuncular zayıf ve özellik olarak sığ |
  | Ödeme anı | 2 | Tek seferlik ödemede LTV düşük; ölçek olmadan gelir anlamlı olmuyor |

- **Riskler:** ① Gelir tavanı düşük — kullanıcı başına $14.99 bir kez; ciddi gelir için on binlerce indirme gerekir. ② Kullanıcı tabanı büyüdükçe destek ve sunucu-suz bile olsa bakım maliyeti sürekli, gelir ise değil. ③ Kullanıcının belirttiği abonelik hedefiyle doğrudan çelişiyor.

### Fikir 3: "Türkçe/Almanca öncelikli" konumlanma

- **Hedeflediği boşluk:** Boşluk 4.
- **Hedef kitle:** Türk ve Alman okurlar; TR'de Bookmory'nin 463 yorumu bu pazarın var olduğunu ama doymadığını gösteriyor.
- **MVP kapsamı:** Fikir 1 + Türkçe kitap veritabanı kalitesine özel yatırım (Kitapyurdu/İdefix ISBN eşleştirmesi, Türkçe yayınevi metadata'sı), TR fiyatlandırması (₺ bazlı, Bookmory'nin ₺329,99/yıl çıpasının altında).
- **v1'e girmeyecekler:** Global pazarlama, İngilizce ASO önceliği.
- **Monetizasyon:** TR için ₺249/yıl civarı, global için Fikir 1 fiyatlandırması.
- **Solo yapılabilirlik: 15/25**

  | Eksen | Puan | Gerekçe |
  |---|---|---|
  | Teknik kapsam | 4 | Türkçe kitap metadata kaynağı entegrasyonu ek iş |
  | İçerik yükü | 2 | Türkçe kitap veritabanı Open Library'de zayıf; küratörlük gerekebilir |
  | Bulunabilirlik | 4 | TR App Store'da rekabet çok daha az |
  | Rekabet duvarı | 4 | Bookmory dışında ciddi yerelleştirilmiş rakip yok |
  | Ödeme anı | 1 | TR ARPU düşük; ₺ bazlı abonelik geliri global fiyatların çok altında |

- **Riskler:** ① TR pazarının toplam büyüklüğü solo geliştiriciyi geçindirmeye yetmeyebilir. ② Türkçe kitap metadata'sı için güvenilir ücretsiz API yok; elle küratörlük ölçeklenmiyor. ③ Tek başına strateji değil — Fikir 1'in üstüne bir katman olarak anlamlı.

---

## 8. Veri boşlukları ve güven notu

- **Sıralama verisi yalnızca Bookly için bulunabildi.** Diğer 13 uygulama için top-free/top-grossing verisi yok. Bu yüzden tablodaki "top-grossing'de görünen %7" oranı **nişin fakir olduğunun kanıtı değil**, veri eksikliğinin sonucudur. Bu oranı rapor sonucu olarak kullanma.
- **Fable, Goodreads, Hardcover, Bookwise, READO, Leafed ve PagePath** için puan/yorum sayısı ve son güncelleme tarihi doğrulanamadı; bu satırlar tabloda `—` bırakıldı.
- **Çelişki 1:** Bookdot'un blogu Bookly'nin hesap gerektirdiğini yazıyor; Bookly'nin kendi App Store açıklaması "No online account or signup needed" diyor. App Store'u esas aldım — ayrıca Bookdot doğrudan rakip olduğu için blogu SEO amaçlı ve taraflı.
- **Çelişki 2:** Bir agregatör Bookly'nin son güncellemesini Eylül 2024, App Store 3 gün önce gösteriyor. Agregatör bayat.
- **Çelişki 3:** Margins için bir kaynak 40.000+, App Store sayfası 19.000 yorum diyor. App Store'u esas aldım.
- **Bookdot'un fiyatları GBP'den yaklaşık USD'ye çevrildi** (£9.99 ≈ $12.99); tabloda bu yaklaşık değer var.
- **Bookdot ve Bookster'ın yorum sayıları (3 ve 4)** tek bir storefront'un sayısı olabilir; global toplam daha yüksek olabilir. Yine de her ikisinin de tutunamadığı sonucu diğer sinyallerle tutarlı.
- **Reddit'e doğrudan erişilemedi;** şikayet temaları ikincil kaynaklardan (inceleme yazıları, StoryGraph'ın resmî bug yol haritası, App Store yorum derlemeleri) toplandı. Şikayet #1 ve #2 çok kaynaklı ve güçlü; #3'ün sayısal kısmı tek kaynaklı.

---

## 9. Kaynaklar

Erişim tarihi: 2026-09-07

- https://apps.apple.com/us/app/bookly-book-tracker/id1085047737
- https://apps.apple.com/us/app/margins-book-tracker/id6737528718
- https://apps.apple.com/us/app/storygraph-reading-tracker/id1570489264
- https://apps.apple.com/us/app/bookmory-reading-tracker/id1515533482
- https://apps.apple.com/tr/app/bookmory-okuma-takipçisi/id1515533482
- https://apps.apple.com/gb/app/bookdot-book-tracker/id6503656539
- https://apps.apple.com/us/app/book-tracker-bookster/id6476703822
- https://apps.apple.com/us/app/book-tracker-bookshelf-tbr/id1491660771
- https://apps.apple.com/us/app/leafed-private-book-tracker/id6754466418
- https://roadmap.thestorygraph.com/bugs/posts/app-is-very-slow-after-recent-updates
- https://roadmap.thestorygraph.com/bugs/posts/app-slowness
- https://booktrack.app/
- https://bookdot.app/blog/best-book-tracking-apps-compared/
- https://kindredview.com/pagepath/complete-guide-book-tracking/best-book-tracker-no-subscription/
- https://adapty.io/paywall-library/bookly/
- https://bookriot.com/bookly-review/
- https://makeheadway.com/blog/best-book-tracking-app/
- https://unstar.app/blog/goodreads-storygraph-fable-hardcover-bookly-reading-tracker-apps-ranked-2026
- https://www.getbookpal.com/blog/best-ai-reading-companion-apps-2026
- https://bookwiseapp.com/
- https://mustreadapp.com/blog/best-book-tracking-apps-2026
