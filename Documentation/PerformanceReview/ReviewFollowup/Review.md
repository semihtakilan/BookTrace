# 7 Eylül 2026 analizinin uygulanması

Kaynak: [BookTrace Durum Raporu](https://claude.ai/code/artifact/bac596c6-36b0-4119-a88b-64714ccf6e39).
Başlangıç commit'i `2b4ff02`; aşağıdaki sonuçlar bu commit üzerine uygulanan yerel
çalışma ağacına aittir. Ürün yol haritasındaki ertelenmiş özellikler bu değişikliğin kapsamına alınmadı.

| Bulgu | Uygulanan değişiklik |
| --- | --- |
| Y1 — CI eksik | Push/PR/elle tetiklenen iki iş: paket testleri ve iOS testleri + Debug/Release. Anahtar gerektirmez; günlükler, commit kimliği ve `.xcresult` saklanır. |
| Y2 — Çoğullar | Kitap sayısı, okuma serisi, üç dakika metni, kalan sayfa ve kütüphane silme açıklaması için eksik varyasyonlar tamamlandı. Mevcut ikinci argüman üzerinden sayfa çoğulları korundu. Sayfa numarası, yüzde ve sabit “son 7 gün” ifadeleri çoğul çekim gerektirmiyor. |
| Y3 — Explore türetmeleri | Spotlight, tekil kitaplar ve kısa kitaplar raf durumu değiştiğinde bir kez hesaplanan saklı özelliklere taşındı. Yükleme, tekrar deneme ve hata geçişleri test edildi. |
| Y4 — Palet yazımı/LRU | Tek bekleyen görevle bir saniyelik yazım grupları, ana aktör dışında JSON kodlama, etkinlik kaybında flush ve gerçek erişim sırasına göre tahliye. v2 renkleri v3'e taşınır; erişim sırası yeniden açılışta korunur. |
| Y5 — Görsel boyutu | 60 PNG yerine en fazla 1440 piksel JPEG; küçük görseller büyütülmedi. 64.533.031 → 6.283.290 bayt, yaklaşık %90 küçülme. Bağlantılar ve tekrar kullanılabilir betik güncellendi. Git geçmişi değiştirilmedi; eski bloblar tam klonlarda kalır. |
| Y6 — Okumada disk yazımı | Kitap başına erişim zamanı yalnızca bir saat geçtiğinde güncellenir; raftaki uygun satırlar tek save ile yazılır. Arka arkaya sorgu ve detay okumaları için regresyon testi eklendi. |
| Y7 — Ağ günlüğü | `print` yerine birleşik günlük sistemi; URL kimlik bilgileri ve hassas başlıklar günlükten önce maskelenir. URL, gövde ve hata ayrıntıları private olarak işaretlenir. NetworkKit'in macOS 10.15 desteği için `os_log` uyumluluk yolu korunur. |
| Y8 — Release derleyici tuzağı | `ViewModelHolder` içindeki açıklamalı `deinit` korundu; CI Release derlemesi her değişiklikte derleyici regresyonunu kontrol eder. |
| Y9 — Belgeler | Plan.md mevcut kapsamla hizalandı. Eski incelemelerin ölçümleri tarihsel kanıt olarak korundu; güncel sonuçlar CI koşumlarına bağlandı. |

## Doğrulama

Makine tarafından toplanan sonuçlar: [Validation.json](Validation.json).

- Models: 94 test geçti.
- NetworkKit: 12 test geçti.
- BookTraceTests: 168 test geçti; `.xcresult` özetinde hata veya atlanan test yok.
- Toplam: 274 test. Yeni kapsam; çoğul metinler, raf geçişleri, palet taşıma/LRU,
  toplu kayıt, cache erişim aralığı ve günlük URL/başlık maskelerini kapsıyor.
- Debug uygulaması test koşumunda derlendi; Release simülatör derlemesi başarılı.
- Swift derleyici uyarısı yok. Xcode, AppIntents bağımlılığı olmadığı için metadata
  çıkarımını atladığını bildirdi; bu, başarılı derleme çıktısında kalan araç uyarısıdır.
- CI YAML ve tüm `run` blokları `bash -n` ile kontrol edildi. Uzak GitHub Actions
  koşumu henüz yapılmadı; iş akışı değişiklikleri GitHub'a gönderilince çalışacak.
- Markdown dosya bağlantıları, katalog JSON'u ve `git diff --check` geçti.
- Küçültülen koyu okuma ekranı ve küçük cihazdaki geçmiş listesi görsel olarak kontrol edildi.
  Bu çalışma yeni bir uçtan uca UI testi veya canlı API performans ölçümü değildir.

Yerel doğrulamada README'deki paket ve `xcodebuild` komutları kullanıldı. API anahtarı
boş tutuldu; testler sahte kaynaklar ve yerel verilerle çalıştı. Gelecek koşumlarda
sonuçlar [CI sayfasında](https://github.com/semihtakilan/BookTrace/actions/workflows/ci.yml) yer alacak.
