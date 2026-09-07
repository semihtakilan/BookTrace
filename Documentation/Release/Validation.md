# Yayın hazırlığı — uygulama ve doğrulama kaydı

7 Eylül 2026. Bu kayıt yerel çalışma ağacına aittir; commit, GitHub CI, TestFlight veya mağaza yayını yapılmış sayılmaz. Kullanıcının yönlendirmesiyle bu aşamanın kapsamı projeyi mağaza kurulumuna hazırlamaktır. Hesap ve mağaza işlemleri [sonraki aşamanın kontrol listesinde](ReleaseChecklist.md) tutulur.

## Uygulanan kapsam

| Plan | Projedeki karşılığı |
|---|---|
| A — Veri modeli | Donmuş V1 şeması, V2 geçişi, bitiş tarihi/puan/not/favori/alıntı/hedef modelleri; App Group'a SQLite ve yan dosyalarıyla güvenli kopyalama; kitap ve alt kayıtların tekilleştirilmesi. |
| B — Eşitleme | CloudKit private yapılandırması, yerel çalışma, görünür eşitleme durumu ve uzak değişiklik sonrası yenileme. Arama önbelleği CloudKit dışında kalır. |
| C — Pro | StoreKit 2, doğrulanmış entitlement, Keychain önbelleği, Restore, üç ürün, dinamik fiyat/indirim, yalnızca uygun yıllık ürün için 7 gün deneme ve özellik kilitleri. |
| D — Okuma ekranları | Widget uzantısı, ortak kalıcılık paketi, okuma/hedef/seri widget'ları ve oturumun duraklama/devam/bitişini izleyen Live Activity. Pro süresi bitince erişim güncellenir. |
| E–F — Hedef ve istatistik | Dört dönem ve dört ölçütte hedef; önceden hesaplanan okuma takvimi, aylık dağılım, hız, saat, puan, tür ve bitirilen kitap ortalamaları. |
| G — Alıntılar | El ile giriş, cihaz içi Vision OCR, kaydetmeden önce düzenleme, arama/favori ve kapak paletine göre paylaşım kartı. Eski alıntılar Pro bittikten sonra okunabilir ve silinebilir. |
| H — Yıl özeti | Yıl seçimi, ücretsiz temel özet/PNG; Pro için ek kartlar ve yüksek çözünürlük. Aralık ayında Journal bağlantısı. |
| I — Aktarım | Ücretsiz Goodreads CSV/JSON içe aktarma; dosya sınırı, önizleme, ilerleme, durdurma ve sonuç sayıları. Mevcut ilerleme/notlar korunur. Pro CSV/JSON dışa aktarma. |
| J — Öneriler | Puan/favori/tür sinyalleriyle yerel sıralama, terk edilen kitaplardan olumsuz sinyal, kütüphanedekileri hariç tutma ve önbellekli katalog adayları. |
| K — Yayın materyalleri | EN/TR/DE mağaza metinleri, ürün yerelleştirmeleri, 66 fiyat satırı, gizlilik/destek HTML sayfaları, App Review notları ve çekim planı. Destek adresi `booktrace.help@gmail.com`. |

README; dört target'ı, kurulum seçeneklerini, ücretsiz/Pro ayrımını, veri akışını ve test komutlarını açıklayacak şekilde güncellendi. Fiyat ve politika URL'leri için gerçek mağaza/alan adı değerleri uydurulmadı.

## Otomatik doğrulama

Araç zinciri: Xcode 26.6, iOS 26.5 SDK. Uygulama testleri iPhone SE (2. nesil), iOS 18.4 simülatöründe ad hoc imzalı test host'u kullanır.

| Kontrol | Sonuç |
|---|---|
| Models | **118 test / 13 suite geçti.** Goodreads tarihleri Los Angeles, İstanbul ve Tokyo'da yıl sınırıyla sınanır. |
| NetworkKit | **12 test / 3 suite geçti.** |
| StoreKit ve entitlement hedefli koşu | **26 test / 4 suite geçti.** |
| Tüm uygulama ve widget testleri | **235 uygulama testi / 26 suite ve 9 widget testi / 1 suite geçti.** Xcode `TEST SUCCEEDED`. [Sonuç özeti](Validation/app-test-summary.json). |
| Release simülatör derlemesi | **BUILD SUCCEEDED.** Uygulama ve widget uzantısı, arm64 ve x86_64. Simulator derlemesi dağıtım imzası doğrulaması değildir. |
| Yapısal kontroller | String Catalog/StoreKit/metadata JSON, plist/entitlement/privacy manifest, yeni Swift başlıkları, CI YAML/shell/Python sözdizimi ve `git diff --check` geçti. |

StoreKit testleri gerçek StoreKit 2 API'leri ve `Config/BookTrace.storekit` ile çalışır; canlı ücret çekmez. Üç ürünün satın alınması/geri yüklenmesi, yıllık teklif ve %48 indirim, kullanıcı iptali, Ask to Buy, dönem/deneme bitişi, lifetime iadesi ve grace period olmadan başarısız yenileme doğrulanır. Eşzamanlı entitlement sorgularında geçersizleşen sonuçların önbelleğe yazılmaması ayrıca sınanır.

Kalıcılık regresyonları V1→V2 geçişini, App Group kopyasını, tekilleştirmeyi, başarısız kayıtta geri almayı, silinmiş kaydı yeniden oluşturmamayı ve güncel veri üzerine yalnızca değişen alanları kaydetmeyi kapsar. Alıntı/taslak ve ağ beklemesi olmayan aktarımı iptal etme senaryoları eklendi. [Kısa test/derleme çıktıları](Validation/checks.txt) bu klasörde saklanır.

Bu makinede iOS 26.5, `SKTestSession` yerel yapılandırmasını “not installed for development” hatasıyla reddetti; aynı yapılandırma iOS 18.4'te çalıştı. CI bu nedenle Xcode 26.6'yı koruyup tam iOS 18.4 runtime'ını kuracak ve tüm uygulama/widget testlerini orada çalıştıracak şekilde ayarlandı. Runtime yoksa test atlamaz veya başka sürüme sessizce geçmez. GitHub'daki yeni iş akışı henüz çalıştırılmadı. Kaynaklar ve komutlar [README test bölümünde](../../README.md#build-and-test).

## Ekran kontrolü

iPhone 17 Pro Max / iOS 26.5 simülatöründe Journal bağlantıları, ücretsiz istatistik görünümü, yıl özeti, PNG paylaşım önizlemesi, ayarlar, aktarım ve yerel gizlilik metni açıldı. iCloud hesabı olmadan yerel durum gösterildi. Ürün bulunmadığında Pro satın alma düğmesi kapalı; yeniden deneme, Restore ve politika bağlantıları görünür.

[Ücretsiz yıl kartının üretilmiş paylaşım önizlemesi](Validation/year-share-free.jpg) boş bir test kütüphanesinden alınmıştır; mağaza görseli değildir. Önizleme üretimi, başka bir uygulamaya gerçekten paylaşım yapıldığı anlamına gelmez.

Görsel kontrolde Journal özellik kartının genişliği, eski yerel saklama metni ve paywall içindeki gizlilik sayfasının kapatma düğmesi düzeltildi.

## Sonraki aşamanın doğrulamaları

Apple imzalama/capability kaydı, App Store Connect ürünleri ve fiyat noktaları, iki gerçek cihazla CloudKit, sandbox/TestFlight satın almaları, kamera OCR, kilit ekranı/Live Activity ve widget yenilemesinin cihaz koşulları sonraki yayın kontrolünde doğrulanacak. Yerel kod/test sonucu bu canlı işlemlerin tamamlandığını göstermez.

Gizlilik/destek sayfaları yayımlanmaya hazır yerel dosyalardır. Gerçek HTTPS adresleri, mağaza bilgileri ve ekran görüntüsü setleri [yayın kontrol listesine](ReleaseChecklist.md) göre sonraki aşamada tamamlanır.
