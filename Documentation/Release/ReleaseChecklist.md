# BookTrace yayın kontrol listesi

Hazırlanma: 7 Eylül 2026. **Bu fazın kapsamı projeyi mağaza kurulumuna hazırlamaktır. Kullanıcının yönlendirmesiyle mağaza/hesap kurulumu sonraki faza bırakılmıştır.** Aşağıdaki açık kutular bu fazda istenen eksik işler değil, sonraki yayın fazının devridir. Bir kutu yalnızca ilgili işlem veya doğrulama gerçekten yapıldığında işaretlenir.

## Yerelde hazır

- [x] [EN/TR/DE mağaza metinleri ve ürün yerelleştirmeleri](app-store-metadata.json).
- [x] [13 fiyat grubunun 22 storefront'a açılmış 66 ürün/fiyat satırı](pricing-storefronts.csv).
- [x] [Gizlilik sayfaları](website/privacy.html) ve [destek sayfaları](website/support.html), üç dilde, `booktrace.help@gmail.com` iletişim adresiyle.
- [x] [App Review notları](AppReviewNotes.md) ve [ekran görüntüsü çekim planı](ScreenshotBrief.md).
- [x] Kaynakta tanımlı kimlikler: uygulama `com.semihtakilan.BookTrace`, uzantı `com.semihtakilan.BookTrace.widgets`, App Group `group.com.semihtakilan.BookTrace`, CloudKit konteyneri `iCloud.com.semihtakilan.BookTrace`.
- [x] Yerel StoreKit yapılandırması `Config/BookTrace.storekit`; bu dosya App Store Connect'te ürün oluşturmaz.
- [x] Uygulama ve widget için kaynak `PrivacyInfo.xcprivacy` dosyaları hazır. UserDefaults ve kullanıcı seçimiyle dosya içe aktarma için required-reason API bildirimleri eklendi; son Archive raporu sonraki fazda kontrol edilecek.
- [x] `Config/Shared.xcconfig` içinde `BOOKTRACE_PRIVACY_POLICY_URL` ve `BOOKTRACE_TERMS_OF_USE_URL` için boş yapılandırma alanları hazır. URL yokken uygulama yerel gizlilik metnini ve Apple standart EULA bağlantısını kullanır.

Bu belgelerin hazırlanması; App Store Connect ürünlerinin, banka/vergi işlemlerinin, CloudKit production şemasının, TestFlight dağıtımının veya gerçek satın almaların tamamlandığı anlamına gelmez. Bunlara ait canlı doğrulama kanıtı bu klasörde yoktur.

## 1. Apple hesabı ve imzalama — bekliyor

- [ ] App Store Connect'te doğru takım ve uygulama kaydını aç. Bundle ID'nin yukarıdaki uygulama kimliğiyle eşleştiğini doğrula.
- [ ] Account Holder, **Business / Agreements** bölümünden gerekli Paid Apps sözleşmesini inceleyip kabul etsin; gerekli banka ve vergi bilgilerini aynı hesapta tamamlasın. Bu belgelerde herhangi bir sözleşme kabul edilmedi veya hesap bilgisi girilmedi. [Apple sözleşme yönetimi](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/).
- [ ] Uygunsa Small Business Program başvurusunu hesap sahibi yapsın ve ilişkili geliştirici hesaplarını doğru bildirsin. Programın güncel resmî sayfası uygunluk ve başvuru adımlarını açıklıyor; kaynak plandaki “her yıl yeniden kayıt” ifadesi bu sayfada doğrulanmadığından burada bir zorunluluk olarak tekrarlanmıyor. Hesaptaki güncel bildirimler izlenmeli. [Apple program bilgisi](https://developer.apple.com/app-store/small-business-program/).
- [ ] Developer portalında uygulama ve widget kimliklerine aynı App Group'u bağla. Uygulamada iCloud/CloudKit ve push bildirim yeteneklerini etkinleştir; uygun development/distribution profillerini yeniden oluştur veya Xcode otomatik imzalamasını yenile.
- [ ] İmzalı Archive üzerinde uygulama ve widget entitlement'larını doğrula: doğru App Group, CloudKit konteyneri ve distribution için uygun push ortamı bulunmalı. Simulator'da `CODE_SIGNING_ALLOWED=NO` derlemesi bu kontrolün yerine geçmez.

## 2. Ürünler ve fiyatlandırma — bekliyor

1. **Subscriptions** bölümünde `BookTracePro` grubunu oluştur.
2. Aynı erişim düzeyinde iki auto-renewable ürün oluştur: `com.semihtakilan.BookTrace.pro.monthly` (1 ay) ve `com.semihtakilan.BookTrace.pro.yearly` (1 yıl).
3. **In-App Purchases** bölümünde `com.semihtakilan.BookTrace.pro.lifetime` ürününü **Non-Consumable** olarak oluştur. Lifetime abonelik grubunun dışında kalır.
4. [Mağaza JSON dosyasındaki](app-store-metadata.json) EN/TR/DE ürün adlarını ve açıklamalarını ilgili ürünlere gir. Ürün inceleme ekran görüntülerini ekle. App Store'da gösterilen ürün adı en fazla 30, açıklama en fazla 45 karakterdir. [Apple IAP alanları](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information).
5. ABD başlangıç fiyatlarını aylık `3.99 USD`, yıllık `24.99 USD`, lifetime `59.99 USD` olarak seç. [Fiyat kurulum notlarına](PricingSetup.md) göre 22 storefront'un her ürününü kontrol et. CSV'deki fiyatlar planlanan değerlerdir; seçicinin gerçek fiyat noktası ve varsa yuvarlaması kaydedilmeden tamamlandı sayılmaz.
6. Yalnızca yıllığa 7 günlük ücretsiz introductory offer ekle. Kullanılabilir bölgeleri ve tarihleri seç; aylığa ve lifetime'a deneme ekleme. Uygunluk hesabını Apple'ın ürün/veri durumuyla doğrula. [Apple introductory offer kurulumu](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/).
7. Ürün ve uygulama satışa açıklığını kontrol et. İlk IAP/abonelik incelemesini uygulama sürümüne bağla; yalnızca yerel StoreKit dosyasının başarılı olması yeterli değildir.

- [ ] Üç ürün ve yerelleştirmeleri kaydedildi.
- [ ] 66 CSV satırının gerçek ASC fiyatı/fiyat noktası doğrulandı.
- [ ] Yıllık deneme tanımlandı; diğer iki üründe deneme yok.
- [ ] Storefront'tan gelen fiyat, dönem ve uygun teklif gerçek cihazda paywall ile eşleşiyor.
- [ ] Gizlilik ve kullanım koşulları bağlantıları ile Restore Purchases görünür ve çalışır. Abonelik koşulları satın alma öncesinde açık biçimde sunulur. [App Review 3.1.2](https://developer.apple.com/app-store/review/guidelines/#subscriptions).

## 3. CloudKit development ve production — bekliyor

- [ ] Development konteynerinde imzalı uygulamayı çalıştır; kütüphane, oturum, kategori, alıntı ve hedef modellerinin şemada oluştuğunu doğrula.
- [ ] Aynı iCloud hesabıyla iki cihazda kitap ekleme, ilerleme, puan, not, favori, alıntı ve hedef değişikliklerinin iki yönde geldiğini kontrol et.
- [ ] İki cihaz çevrimdışıyken aynı kitabı ekle ve oturum üret. Bağlantı gelince tek kitap, tekil oturum kimlikleri ve doğru toplam süre kaldığını doğrula.
- [ ] iCloud kapalı, bağlantı kesilmiş ve yetersiz saklama alanı durumlarını dene; mevcut yerel kütüphane açılmalı ve durum açıkça görünmeli.
- [ ] Gerçek eski mağaza kopyasıyla V1→V2 ve App Group taşımasını doğrula. Başarısız taşıma senaryosunda eski yerel verinin korunmasını ayrıca kontrol et.
- [ ] Development verisini gözden geçirdikten sonra CloudKit Console'da **Deploy Schema Changes** işlemini yap. Production'daki tür ve alanlar sonradan silinemez; bu adım test sonucu görülmeden uygulanmamalıdır. App Store sürümleri production şemasını kullanır. [Apple CloudKit yayın akışı](https://developer.apple.com/documentation/CloudKit/deploying-an-icloud-container-s-schema).
- [ ] İmzalı TestFlight sürümünde production konteynerini iki cihazla yeniden doğrula. Development cihaz testini production doğrulaması olarak kaydetme.
- [ ] Test tarihi, cihazlar, yapı numarası, iCloud ortamı ve sonuçları sürümün doğrulama kaydına ekle. Şema yayımlama işlemi kullanıcı kayıtlarını development'tan production'a taşınmış saydırmaz.

## 4. StoreKit sandbox ve gerçek cihaz matrisi — bekliyor

Yerel `.storekit` testleri uygulama davranışını denetler. App Store Connect ürünleri, imzalama ve Apple işlem akışı için ayrıca sandbox gerekir. Sandbox testleri gerçek ücret çekmeden işlem davranışını doğrulamak içindir. [Apple sandbox başlangıcı](https://developer.apple.com/help/app-store-connect/test-in-app-purchases/overview-of-testing-in-sandbox/).

| Senaryo | Beklenen sonuç | Kayıt |
|---|---|---|
| Aylık, yıllık, lifetime ayrı ayrı satın alma | Doğrulanmış işlemden sonra Pro açılır | Bekliyor |
| Kullanıcı ödeme sayfasından vazgeçer | Pro açılmaz, hata gibi gösterilmez | Bekliyor |
| Bekleyen satın alma / Ask to Buy | Onay gelmeden Pro açılmaz; sonradan güncelleme alınır | Bekliyor |
| Yıllık teklif için uygun ve uygun olmayan hesap | Deneme yalnızca uygun yıllık üründe görünür | Bekliyor |
| Deneme sona erer / yenileme iptal edilir | Geçerli erişim tarihine göre doğru davranır | Bekliyor |
| Başarılı ve başarısız yenileme | Güncellenen entitlement doğru yansır | Bekliyor |
| İade veya işlem iptali | Geçersiz erişim yeniden açılmaz | Bekliyor |
| Uçak modu ve uygulamayı yeniden açma | Geçerli önbellekteki Pro erişimi korunur | Bekliyor |
| Başka Apple hesabı / Restore | Önceki hesabın Pro durumu diğer hesaba sızmaz | Bekliyor |
| İkinci iPhone'da Restore | Aynı satın alma yeniden ücret istenmeden bulunur | Bekliyor |
| Pro biter, eski alıntılar ve hedefler vardır | Kaydedilmiş içerik okunabilir; yeni Pro işlemleri kilitlenir | Bekliyor |
| Aylık ↔ yıllık plan değişimi | StoreKit'in gerçek durum ve tarihleri yansır | Bekliyor |

TestFlight satın almaları da sandbox kullanır. Hızlandırılmış yenileme süreleri ile gerçek üretim süresi birbirine karıştırılmamalıdır. TestFlight'ta doğrulanan işlem, gerçek kullanıcıdan ücret alındığı anlamına gelmez. [Apple TestFlight satın alma testi](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/).

## 5. Gizlilik, destek ve mağaza bilgileri — bekliyor

- [ ] `website/` klasöründeki altı HTML sayfasını ve CSS'i kullanıcıya ait kalıcı bir HTTPS adresinde yayımla. Bu klasör kendi başına bir yayımlanmış web sitesi değildir.
- [ ] İngilizce, Türkçe ve Almanca gizlilik/destek URL'lerini gerçekten açarak doğrula. JSON'daki `null` URL alanlarını gerçek adreslerle doldur; yerel dosya yolu, `mailto:` veya uydurma alan adı kullanma.
- [ ] Aynı gerçek gizlilik URL'sini uygulamanın paywall yapılandırmasına ve App Store Connect **App Privacy** alanına gir. iOS uygulaması için gizlilik politikası URL'si gerekir. [Apple gizlilik alanı](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/).
- [ ] Yayın sonrası gerçek URL'leri `Config/Shared.xcconfig` içindeki ilgili alanlara gir. `.xcconfig` içinde `//` yorum başlangıcı olduğundan HTTPS adresini `https:/$()/alan-adi/yol` biçiminde yaz ve derlenmiş Info.plist'te sonucun normal `https://…` olduğunu doğrula. Alan adı bu hazırlıkta uydurulmadı. Kullanım koşulları alanı boşsa Apple standart EULA bağlantısı korunur.
- [ ] `booktrace.help@gmail.com` posta kutusunun alımını kullanıcı kendi hesabında doğrulasın. Buradan test e-postası gönderilmedi.
- [ ] App Privacy yanıtlarını son Archive'ın veri akışıyla karşılaştır. Kamera izni tek başına “Photos or Videos toplanıyor” sonucu değildir: OCR cihaz içinde işler, ancak kaydedilen alıntılar iCloud'a gidebilir. Arama/ISBN sorguları, katalog sağlayıcıları, destek yazışmaları ve satın alma durumunu değerlendir. Otomatik olarak “Data Not Collected” seçme; Apple'ın saklama/erişim tanımına göre gerçek akışı bildir. [Apple veri türleri ve toplama tanımı](https://developer.apple.com/app-store/app-privacy-details/).
- [ ] Son Archive ve SDK'ların privacy manifest/required-reason API raporunu incele. Bu listede kamera ve ağ erişimi bulunduğu için takip izni gerektiği varsayılmamalı; gerçek kullanım esas alınmalı.
- [ ] Güncel yaş derecelendirme ve varsa bölgesel uygunluk sorularını hesap sahibi yanıtlasın. Yanıtlar bu klasörde tahmin edilmedi.
- [ ] Son yapıdaki şifreleme kullanımını export-compliance sorularıyla karşılaştır ve gerekiyorsa belge ekle. Yalnızca HTTPS kullanıldığı varsayımını tüm SDK'lar için otomatik muafiyet beyanına dönüştürme. [Apple export-compliance akışı](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/).
- [ ] Mağaza başlığı, alt başlık, açıklama, anahtar kelimeler ve inceleme iletişim bilgilerini gir. App Review telefon numarası mevcut kullanıcı bilgisi olmadan doldurulmadı.

## 6. Google Books anahtarı — bekliyor

- [ ] Kullanılan anahtarın Google Cloud projesinde izinlerini gözden geçir; Books API ve iOS uygulama kimliği kısıtlarını doğru anahtara uygula.
- [ ] Kısıt uygulandıktan sonra imzalı cihazda arama, ISBN ve kitap detayı çalıştığını doğrula. Kaynak istekleri `X-Ios-Bundle-Identifier` başlığını gönderiyor; bu tek başına sunucu tarafında kısıtların tanımlandığını kanıtlamaz.
- [ ] Anahtarı depo veya yayın belgelerine koyma. API anahtarının IPA içinden çıkarılabileceğini kabul ederek kota takibini Google hesabında doğrula. Gerçek anahtar bu hazırlıkta okunmadı veya belgelenmedi.

## 7. Ekran görüntüleri, TestFlight ve gönderim — bekliyor

- [ ] [Çekim planındaki](ScreenshotBrief.md) ekranları son imzalı yapıdan, örnek kitap/veriyle EN/TR/DE çek. Her görüntüde gerçek mevcut özellik görünmeli; hayalî istatistik/ödül veya yapılmamış iCloud eşitlemesi iddiası ekleme.
- [ ] 6.9 inç için kabul edilen dikey ölçülerden birini kullan: `1260×2736`, `1290×2796` veya `1320×2868`. 6.5 inç için `1242×2688` veya `1284×2778` kullan. JPEG/PNG görüntülerde alfa olmamalı. Apple 6.5 inç setini 6.9 inç seti verilmediğinde zorunlu tutuyor; bu proje iki seti de ayrı kontrol amacıyla hazırlayabilir. [Apple ekran görüntüsü ölçüleri](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
- [ ] Xcode Organizer'dan Archive'ı doğrula ve doğru App Store Connect kaydına yükle; build processing'in bitmesini bekle.
- [ ] Önce internal TestFlight grubuna dağıt. iCloud production, satın almalar, Live Activity, widget yenileme, Pro/free geçişleri ve veri taşıma senaryolarını bu yapıda tamamla.
- [ ] External TestFlight için beta açıklamasını, test edilecek alanları ve iletişim bilgisini gir; gerektiğinde beta incelemesine gönder. Onaydan sonra public link'i oluştur. Bu hazırlıkta public TestFlight link'i oluşturulmadı. [Apple dış testçi akışı](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/).
- [ ] Mağaza sürümüne doğru build'i ve IAP'leri ekle. Varsayılan yayın tercihini hesapta gözden geçir; gönderimi hazır olduğu doğrulanan sürüm için yap.
- [ ] Son kontrol: gerçek URL'ler, gerçek ürün fiyatları, uygun deneme metni, görünür Restore, veri taşımada kayıp yok, tüm uzantılar imzalı, inceleme notları güncel.
- [ ] App Review'a gönderim, production şema yayını ve mağazada yayınlama tarihlerini ayrı ayrı kaydet. Hiçbiri otomatik olarak tamamlandı sayılmaz.

## Lansman sonrası takip

[Pricing.md](../../Pricing.md) zamanlaması korunur: 1. ay aylık/yıllık dağılımı; 3. ay lifetime oranı ve deneme dönüşümü; 6. ay ülke dağılımı ve Türkiye geliri; 12. ay elle seçilmiş fiyatlar. Takip, Apple'ın raporlarıyla yapılır; uygulamaya kullanıcı davranışı analitiği eklenmiş sayılmaz. Bu belge zamanlanmış otomasyon oluşturmaz.
