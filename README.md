# BookTrace

Google Books üzerinden kitap keşfi, kişisel kütüphane yönetimi ve okuma oturumu
takibi yapan bir iOS uygulaması. Mimari ve faz durumu için [Plan.md](Plan.md).

## Gereksinimler

* Xcode 26.x, iOS 17.6+
* Bağımlılıklar SPM ile çözülür (Factory, NavigatorUI, Kingfisher) — ek kurulum yok

## Google Books API anahtarı

Uygulama `https://www.googleapis.com/books/v1/volumes` uç noktasını kullanıyor.
Bu uç nokta anahtarsız da çağrılabiliyor, ancak anahtarsız istekler Google'ın
**paylaşımlı anonim projesinin** günlük kotasını harcıyor; bu kota pratikte
sürekli dolu olduğu için anahtarsız çalıştırdığınızda arama ve kategori rafları
`HTTP 429` ile dönüyor. Dağıtılacak uygulamada kendi anahtarınız zorunlu.

### Yerel kurulum

```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Kopyaladığınız dosyada `GOOGLE_BOOKS_API_KEY` değerini kendi anahtarınızla
değiştirin. `Config/Secrets.xcconfig` `.gitignore`'da — repoya girmez.

Anahtarı almak için:

1. [Google Cloud Console](https://console.cloud.google.com/) → bir proje oluşturun
2. **APIs & Services → Library** → *Books API*'yi etkinleştirin
3. **APIs & Services → Credentials** → *Create credentials* → *API key*

### Anahtar uygulamaya nasıl giriyor

```
Config/Secrets.xcconfig   (gitignored, gerçek anahtar)
        ↓  #include?
Config/Shared.xcconfig    (app hedefinin base configuration'ı)
        ↓  $(GOOGLE_BOOKS_API_KEY)
Config/Info.plist         (INFOPLIST_FILE; Xcode üretilen girdilerle birleştirir)
        ↓  Bundle.main.object(forInfoDictionaryKey:)
GoogleBooksAPIKey.value
```

`Secrets.xcconfig` yoksa `#include?` sessizce geçiyor, anahtar boş kalıyor ve
uygulama yine derleniyor — depoyu yeni klonlayan birinin ek adım atması
gerekmiyor.

Geliştirme sırasında dosyaya dokunmadan başka bir anahtar denemek isterseniz
scheme'e `GOOGLE_BOOKS_API_KEY` environment değişkeni koyabilirsiniz; environment
değeri Info.plist'in önüne geçiyor. Bu yalnızca Xcode'dan Run için geçerli —
Archive edilen uygulamada okunmaz, o yüzden dağıtım yolu her zaman xcconfig.

### Anahtarı kısıtlayın (dağıtımdan önce zorunlu)

**iOS uygulamasına konan hiçbir anahtar gizli değildir.** İkiliyi indiren biri
`Info.plist`'i açıp anahtarı okuyabilir; obfuscation da bunu değiştirmez.
Anahtarı koruyan tek şey Google Cloud tarafındaki kısıtlamalar:

* **Application restrictions → iOS apps** → bundle kimliği
  `com.semihtakilan.BookTrace`. Uygulama isteklere `X-Ios-Bundle-Identifier`
  başlığını ekliyor; Google kısıtlamayı bu başlıkla eşleştiriyor.
* **API restrictions → Restrict key** → yalnızca *Books API*. Anahtar sızsa bile
  başka bir Google servisinin faturasını çıkaramaz.

Kotanın tamamen sizde kalması gerekiyorsa tek gerçek çözüm anahtarı kendi
sunucunuzda tutup istekleri oradan proxy'lemek; uygulama o durumda anahtar
yerine kendi backend'inizin adresini taşır.

### CI / dağıtım

`Config/Secrets.xcconfig` repoda olmadığı için CI'da build'den önce
oluşturulmalı. Anahtarı CI gizli değişkeni olarak tutup:

```bash
printf 'GOOGLE_BOOKS_API_KEY = %s\n' "$GOOGLE_BOOKS_API_KEY" > Config/Secrets.xcconfig
```

Anahtar bulunamazsa uygulama çökmüyor; istekler kota hatasıyla dönüyor ve
kullanıcıya "biraz sonra tekrar deneyin" mesajı gösteriliyor.

### `country` parametresi

Google Books, `country` parametresi olmadan gelen çağrılara `503 backendFailed`
döndürüyor — ve verilen değeri çağıranın IP'sinden tespit ettiği ülkeyle
karşılaştırıyor, uyuşmazsa yine 503. Uygulama bu yüzden isteklere cihazın bölge
ayarını (`Locale.current.region`) ekliyor.

Simülatörde 503 alıyorsanız simülatörün bölgesi bulunduğunuz ülkeyle
eşleşmiyordur: Settings → General → Language & Region → Region.

## Testler

Domain mantığı (ilerleme hesabı, durum geçişleri, cache-first davranışı, okuma
hızı tahmini) `Models` paketinde, UI'dan bağımsız olarak test ediliyor:

```bash
swift test --package-path Models
```
