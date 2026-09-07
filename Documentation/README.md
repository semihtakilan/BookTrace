# İnceleme belgeleri

Tasarım ve performans raporları tarihli çalışma kayıtlarıdır. İçlerindeki test
sayıları ve ekran görüntüleri o incelemeye aittir; sonraki commit'lerin sonuçlarıyla
geriden değiştirilmez.

Güncel doğrulama için [CI koşumlarını](https://github.com/semihtakilan/BookTrace/actions/workflows/ci.yml)
açın. Her koşum commit kimliğini, kullanılan Xcode sürümünü, paket test günlüklerini,
Debug/Release derleme günlüklerini ve uygulama testlerinin `.xcresult` çıktısını
saklar. Çıktıların saklama süresi 14 gündür. CI iş akışının GitHub'da çalışması için
önce depoya gönderilmesi gerekir.

## Ekran görüntüsü kuralı

İnceleme görsellerini en uzun kenarı en fazla 1440 piksel olan JPEG olarak saklayın
(varsayılan kalite 80). Metinlerin, hata durumlarının ve erişilebilirlik örneklerinin
okunabildiğini görsel olarak kontrol edin. Piksel düzeyinde hata kanıtı gerekiyorsa
küçük bir PNG kesiti kullanın ve nedenini raporda belirtin.

Yeni PNG ekran görüntülerini küçültmek ve Markdown bağlantılarını güncellemek için,
macOS'ta depo kökünden:

```bash
python3 Scripts/optimize_review_images.py
```

Betik yalnızca `Documentation/` altındaki PNG dosyalarını dönüştürür. Mevcut JPEG'leri
tekrar sıkıştırmaz ve Git geçmişini değiştirmez. Tarihî büyük görseller önceki
commit'lerde kalır; tam geçmişi içeren bir klonun küçülmesi bu değişiklikle garanti
edilmez. Ham simülatör çıktıları geçici klasörde tutulabilir.
