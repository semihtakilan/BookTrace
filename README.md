# BookTrace

Google Books üzerinden kitap keşfi, kişisel kütüphane yönetimi ve okuma oturumu
takibi yapan bir iOS uygulaması. Mimari ve faz durumu için [Plan.md](Plan.md).

## Gereksinimler

* Xcode 26.x, iOS 17.6+
* Bağımlılıklar SPM ile çözülür (Factory, NavigatorUI, Kingfisher) — ek kurulum yok

## Google Books API anahtarı (gerekli)

Uygulama `https://www.googleapis.com/books/v1/volumes` uç noktasını kullanıyor.
Bu uç nokta teknik olarak anahtarsız da çağrılabiliyor, ancak anahtarsız
istekler Google'ın **paylaşımlı anonim projesinin** günlük kotasını harcıyor;
bu kota pratikte sürekli dolu olduğu için anahtarsız çalıştırdığınızda arama ve
kategori rafları `HTTP 429` ile dönecektir.

Kendi anahtarınızı almak için:

1. [Google Cloud Console](https://console.cloud.google.com/) → bir proje oluşturun
2. **APIs & Services → Library** → *Books API*'yi etkinleştirin
3. **APIs & Services → Credentials** → *Create credentials* → *API key*

Anahtarı uygulamaya iki yoldan biriyle verebilirsiniz:

**Scheme environment değişkeni (önerilen — anahtar repoya girmez):**

Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables →
`GOOGLE_BOOKS_API_KEY` = *anahtarınız*

**Info.plist:**

`GOOGLE_BOOKS_API_KEY` anahtarını ekleyin. Bu dosya repoya girdiği için
anahtarı doğrudan yazmak yerine bir build setting'e (`$(GOOGLE_BOOKS_API_KEY)`)
bağlamanız daha güvenli.

Anahtar bulunamazsa uygulama yine de istek atar; kota hatası alındığında hata
mesajı kullanıcıyı anahtar eklemeye yönlendirir.

## Testler

Domain mantığı (ilerleme hesabı, durum geçişleri, cache-first davranışı, okuma
hızı tahmini) `Models` paketinde, UI'dan bağımsız olarak test ediliyor:

```bash
swift test --package-path Models
```
