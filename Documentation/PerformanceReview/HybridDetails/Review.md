# Kitap açıklaması yükleme iyileştirmesi

6 Eylül 2026 — Keşfet → kitap detayı → Kitabın içinde.

Önceki akış OpenLibrary yanıtını tamamen bekliyor, açıklama eksikse Google Books’a geçiyordu. Detay istekleri de genel ağ politikasındaki üç denemeyi kullanıyordu. Aynı kitabın eşzamanlı açılışları ayrı istekler üretebiliyor; açıklaması olmayan kitaplar her açılışta yeniden sorgulanıyordu. Kütüphanede kayıtlı olmak ise açıklama eksik olsa bile zenginleştirmeyi engelliyordu.

## Uygulanan politika

- Kayıtlı açıklama önce gösterilir. Eksik açıklamalar kütüphanedeki kitaplar için de tamamlanır.
- OpenLibrary’ye 800 ms öncelik verilir. Açıklama bu sürede gelmezse mevcut günlük bütçe dahilinde Google da sorgulanır. OpenLibrary erken ve açıklamasız yanıt verirse Google hemen başlar.
- İlk kullanılabilir açıklama döner, bekleyen diğer istek iptal edilir. Boş yanıt yarışı kazanmaz. Google kimlikli kitap doğrudan Google’a gider; kayıt kimliği korunur.
- Her detay isteği 6 saniye ve tek ağ denemesiyle sınırlıdır. Tüm detay işleminin, kuyruk dahil, 8 saniyelik sınırı vardır. İki kaynağın hatası veya toplam zaman aşımı yeniden deneme durumuna taşınır.
- Aynı kitap için eşzamanlı ekranlar tek isteği paylaşır. Son bekleyici ayrıldığında ağ isteği iptal edilir. Başarılı açıklamalar mevcut SwiftData önbelleğine yazılır; açıklamasız sonuçlar en fazla 128 anahtarlık bellekte 30 saniye tutulur. Hata ve iptal sonuçları bu bekleme süresine alınmaz.
- Yükleniyor, açıklama mevcut değil ve yeniden dene durumları mevcut tasarım diliyle gösterilir; Türkçe, İngilizce ve Almanca metinler eklendi.

## Doğrulama

92 Models, 159 uygulama ve 10 NetworkKit testi geçti. Testler iki kaynağın yarışı, erken boş yanıt, kota sınırı, zaman aşımı, iptal, eşzamanlı açılış, yeniden deneme ve kütüphaneden gelen açıklama durumlarını kapsıyor. Debug ve Release simülatör derlemeleri başarılı.

Kontrollü gecikme testinde 2 saniyelik birincil kaynak ve anında yanıt veren yedek kaynak kullanıldı. Uygulamadaki varsayılan 800 ms politikasıyla açıklama 0,854 saniyede döndü; yavaş istek iptal edildi. Bu bir regresyon testi ölçümüdür; canlı API’ler için süre garantisi veya saha ortalaması değildir.

iPhone 17 Pro / iOS 26.5 simülatöründe gerçek kataloglarla kontrol edildi: The Cruel Prince ilk açılışta yükleme durumundan açıklamaya geçti; ikinci açılışta açıklama ilk görünümde hazırdı. Ringkasan sejarat filsafat açıklamasız sonucu açık bir mesajla gösterdi. Release sürümü simülatöre kuruldu.

## Ekran görüntüleri

- [Önce: yüklenirken açıklama bölümü görünmüyor](before-detail.png)
- [Sonra: yüklenen açıklama](after-detail.png)
- [Açıklaması bulunmayan kitap](description-status.png)

Görüntüler arayüz kanıtıdır; ağ süresi ölçmek için kullanılmadı. Dış servislerin yanıt süresi ve Google bütçesi ilk açılış hızını etkilemeye devam eder.
