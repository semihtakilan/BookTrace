# BookTrace — Fiyatlandırma Ölçeği

**Hazırlık durumu — 7 Eylül 2026:** Üç ürün ve yıllık deneme [yerel StoreKit kataloğunda](Config/BookTrace.storekit) hazır. Bu belgedeki 13 fiyat grubu [66 satırlık, 22 storefront'u kapsayan kurulum CSV'sine](Documentation/Release/pricing-storefronts.csv) aktarıldı. [Kurulum notları](Documentation/Release/PricingSetup.md) gerçek Apple fiyat noktalarının sonraki aşamada nasıl doğrulanacağını açıklar. Mağaza kurulumu henüz yapılmadı.

Oluşturma: 7 Eylül 2026. [ReleasePlan.md](ReleasePlan.md) Faz C'nin fiyat ekidir.
Dayanak: [Documentation/MarketAnalysis/pazar-raporu.md](Documentation/MarketAnalysis/pazar-raporu.md)
ve Apple'ın 2026 fiyat noktası sistemi.

---

## 1. Taban merdiven (ABD storefront'u = baz)

| Ürün | Fiyat | Tip |
|---|---|---|
| Aylık | **$3.99** | Auto-renewable, grup `BookTracePro` |
| **Yıllık** | **$24.99** | Auto-renewable, aynı grup, **7 gün ücretsiz deneme** |
| Lifetime | **$59.99** | Non-consumable, grup dışı |

- Yıllık, 12 aylığa göre **%48 tasarruf** — yıllığa yönlendirmek için gereken eşiğin üstünde
- Lifetime = yıllığın **2.4 katı** — abonelik gelirini yok etmeden abonelik direncine cevap
- Paywall'da varsayılan seçili olan **yıllık**, üzerinde tasarruf rozetiyle

### Neden $24.99, önceki plandaki $29.99 değil

| Rakip | Yıllık | Aylık | Lifetime |
|---|---|---|---|
| Bookdot | $12.99 | $2.49 | $12.99 |
| **BookTrace** | **$24.99** | **$3.99** | **$59.99** |
| Bookster | $24.99 | $4.99 | $49.99 |
| Bookly | $29.99 | $4.99 | $79.99 |
| Bookmory | $30.99 | $3.49 | — |
| StoryGraph | $49.99 | $4.99 | — |
| Fable | $49.99 | $5.99 | — |
| Margins | $59.99 | $5.99 | — |
| **Medyan** | **$30.99** | **$4.99** | — |

$24.99, medyanın **%19 altında** ve iki doğrudan rakibin (Bookly $29.99, Bookmory $30.99)
ikisini de görünür biçimde kırıyor — ama ucuz katmanın ($5.99–12.99) iki katı, yani
"ucuz uygulama" sinyali vermiyor. İstenen etki tam olarak bu: mağazada yan yana
bakan kullanıcı için net bir avantaj, ama değersizleştirme yok.

Aylık $3.99 Bookly, StoryGraph, Fable ve Margins'in altında; yalnızca Bookmory
($3.49) daha ucuz — ve Bookmory ücretsiz katmanında reklam gösteriyor, biz göstermiyoruz.

Lifetime $59.99, Bookly'nin $79.99'unun **%25 altında**. Nişte belgelenmiş abonelik
yorgunluğu (14 uygulamanın 5'i lifetime sunuyor, ayrı bir tek-seferlik ekonomi katmanı var)
karşısında bu kalem bir tavizden çok bir dönüşüm kilidi.

---

## 2. Bilmeden yanlış yapılacak üç mekanik

**① Apple abonelik fiyatlarını otomatik güncellemez.** Ücretli uygulamalar ve
tek seferlik IAP'ler kur ve vergi değiştikçe Apple tarafından ayarlanır;
**auto-renewable abonelikler ayarlanmaz.** Bir kez koyduğun fiyat, kur ne yaparsa
yapsın orada kalır.

Bunun kanıtı Bookly'nin Türkiye sayfasında duruyor: yıllık aboneliği **₺132,99**
(yıllar önce konmuş, hiç güncellenmemiş), aynı uygulamanın lifetime'ı ise
**₺3.999,99** (non-consumable olduğu için Apple güncel kura çekmiş). Aynı üründe
30 kat fark. Bu bir hata değil, sistemin çalışma biçimi.

**② Bir bölgeye özel fiyat koyduğun an, o bölgenin sorumluluğu sende.** Apple o
storefront için bir daha otomatik ayarlama yapmaz. Bu yüzden **175 storefront'un
hepsini elle ayarlama** — aşağıdaki 13 pazarı elle koy, kalanını Apple'ın otomatik
dönüşümüne bırak. Elle ayarladığın her pazar, yılda bir gözden geçirmen gereken
bir kalemdir.

**③ Small Business Program'a başvur.** Yıllık geliri $1M altındaki geliştiriciler
için komisyon %30 yerine **%15**. Yeni geliştirici hemen başvurabilir, her yıl
yeniden kaydolunur. Ayrıca 12 ayı dolduran her abonede komisyon ikinci yıldan
itibaren zaten %15'e düşer.

| Ürün | Brüt | Net (%15) |
|---|---|---|
| Aylık | $3.99 | $3.39 |
| Yıllık | $24.99 | $21.24 |
| Lifetime | $59.99 | $50.99 |

---

## 3. Bölgesel ölçek

Apple'ın otomatik dönüşümü kuru çevirir ama **satın alma gücünü görmez**:
İngiltere ve Almanya'da ABD'nin %10-25 altına, Türkiye/Brezilya/Hindistan gibi
pazarlarda ise karşılanabilir seviyenin **2-3 katı üstüne** düşer. Aşağıdaki
tablo satın alma gücüne göre düzeltilmiştir.

| Katman | Pazar | Aylık | Yıllık | Lifetime |
|---|---|---|---|---|
| **T1** | 🇺🇸 ABD *(baz)* | $3.99 | **$24.99** | $59.99 |
| T1 | 🇬🇧 Birleşik Krallık | £2.99 | **£17.99** | £43.99 |
| T1 | 🇩🇪🇫🇷🇳🇱🇧🇪🇦🇹🇮🇪🇫🇮 Avro çekirdeği | €2.99 | **€20.99** | €50.99 |
| T1 | 🇨🇦 Kanada | C$4.99 | **C$33.99** | C$79.99 |
| T1 | 🇦🇺 Avustralya | A$4.99 | **A$33.99** | A$79.99 |
| T1 | 🇯🇵 Japonya | ¥600 | **¥3.900** | ¥9.400 |
| **T2** | 🇪🇸🇮🇹🇵🇹🇬🇷 Güney Avrupa | €1.99 | **€14.99** | €35.99 |
| T2 | 🇵🇱 Polonya | zł6.99 | **zł44.99** | zł107.99 |
| T2 | 🇰🇷 Güney Kore | ₩4.000 | **₩25.000** | ₩59.000 |
| **T3** | 🇧🇷 Brezilya | R$9.99 | **R$59.99** | R$144.99 |
| T3 | 🇲🇽 Meksika | MX$33.99 | **MX$199** | MX$479 |
| T3 | 🇹🇷 **Türkiye** | ₺69.99 | **₺449** | ₺1.099 |
| **T4** | 🇮🇳 Hindistan | ₹150 | **₹850** | ₹2.000 |

**Kalan ~160 storefront:** Apple'ın otomatik dönüşümüne bırak. Bu pazarlarda
hacim, elle bakım maliyetini karşılamıyor. Altı ay sonra gelir raporunda öne
çıkan bir pazar olursa o zaman elle ayarla.

**Yuvarlama kuralları** (Apple'ın geçerli fiyat sonları para birimine göre değişir):
çoğu para biriminde `.99`; JPY, IDR, RUB, HUF tam sayı; KRW ve THB 10'un katı;
INR, ILS, CHF `.00`/`.50`.

---

## 4. Türkiye — özel durum

Katı PPP hesabı Türkiye için **₺566,99** veriyor. Öneri **₺449** ve bu bilinçli
bir sapma. Sebep, TR storefront'unda kullanıcının gördüğü manzara:

| Uygulama | TR yıllık fiyatı | Durum |
|---|---|---|
| Bookly | ₺132,99 | Bayat — yıllar önce konmuş, Apple abonelik fiyatını güncellemiyor |
| Bookmory | ₺329,99 | Büyük olasılıkla aynı sebeple bayat |
| **BookTrace** | **₺449** | Güncel kurla konuyor |
| Bookly (yeni promo kalemi) | ₺999,99 | Güncel kurla konmuş, gerçek seviye |

Türk kullanıcı ₺449'u ₺132,99'un yanında görecek. Katı PPP'nin dediği ₺566,99
bu optikte savunulamaz; ₺449 ise Bookmory'nin üstünde kalarak premium sinyalini
korur, Bookly'nin güncel ₺999,99'unun ise yarısıdır.

`₺449` ayrıca Türkiye'de **tanıdık bir fiyat sonu** — `₺415` gibi bir rakam
otomatik üretilmiş hissi verir, `₺449` kasıtlı görünür.

**Dürüst uyarı:** ₺449 brüt ~$9, net ~$7.65. Türkiye bu üründe bir gelir pazarı
değil; **erken yorum, kelime-ağızdan yayılma ve yerel geri bildirim** pazarı.
Türkçe yerelleştirmen hazır ve nişin en hızlı büyüyen ismi Margins yalnızca
İngilizce — bu avantajı fiyatla boğmanın anlamı yok. Gelir beklentisini T1
pazarlarına kur.

---

## 5. Deneme ve teklif yapısı

- **7 gün ücretsiz deneme yalnızca yıllıkta.** Aylıkta deneme verme; kullanıcıyı
  yıllığa yönlendiren en güçlü kaldıraç bu.
- **Lifetime'da deneme yok** (non-consumable, teknik olarak da mümkün değil).
- **Lansman indirimi taban fiyatı düşürerek yapılmaz.** Abonelik taban fiyatını
  sonradan yükseltmek Apple'da mevcut abonelerin onayını gerektirir veya onları
  eski fiyatta bırakır — kalıcı bir karmaşa. Bunun yerine **introductory offer**
  kullan: ilk yıl indirimli, taban fiyat sabit kalır, mekaniği Apple yönetir.
- **Win-back offer**'ı v1'e koyma; iptal verisi biriktikten sonra anlamlı olur.

---

## 6. Lansmandan sonra gözden geçirilecekler

| Ne zaman | Ne bakılır | Karar |
|---|---|---|
| 1. ay | Aylık/yıllık dağılımı | Yıllık %60'ın altındaysa paywall'da yıllığın vurgusu artırılır |
| 3. ay | Lifetime oranı | Satışların %25'ini geçiyorsa lifetime cannibalizasyonu var; fiyat yükseltilir |
| 3. ay | Deneme → ücretli dönüşümü | %30'un altındaysa deneme süresi veya paywall zamanlaması gözden geçirilir |
| 6. ay | Ülke bazında gelir | Otomatik dönüşümde bırakılan pazarlardan öne çıkan varsa elle ayarlanır |
| 6. ay | TR ARPU | Beklendiği gibi düşükse fiyat korunur; şaşırtıcı derecede iyiyse ₺549'a çekilir |
| 12. ay | Elle ayarlanan 13 pazar | Kur kaymasına göre gözden geçirilir (Apple yapmayacak) |

---

## 7. Veri boşlukları

- Bölgesel çarpanlar **$19.99 bazlı bir PPP referans tablosundan** türetildi
  (Nisan 2026 anlık görüntüsü). Kur oynadıkça kayar; App Store Connect'in fiyat
  noktası seçicisindeki gerçek değerler esastır — yukarıdaki rakamlar oraya
  girerken en yakın geçerli fiyat noktasına yuvarlanmalı.
- 13 pazar için doğrulanmış çıpa var. İsviçre, İskandinavya, Orta Doğu, Güneydoğu
  Asya ve Afrika için doğrulanmış PPP verisi bulunamadı — bu yüzden bilinçli
  olarak otomatik dönüşüme bırakıldılar, uydurma rakam yazılmadı.
- Bookmory'nin TR fiyatının bayat olduğu bir **çıkarımdır**: ABD fiyatı ($30.99)
  ile TR fiyatı (₺329,99) arasındaki oran, Apple'ın güncel TR dönüşümüyle
  (~₺50/$1) bağdaşmıyor. Bookly'de aynı desen abonelik ve non-consumable
  kalemlerin farkıyla doğrudan gözlemlenebiliyor.
- Türkiye Dijital Hizmet Vergisi 2026'da %7,5'ten %5'e indi ve Apple bunu
  fiyatlara yansıttı; 2027 için %2,5 planlanıyor. TR fiyatı o tarihte tekrar
  gözden geçirilmeli.
