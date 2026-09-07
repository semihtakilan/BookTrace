# Storefront fiyat kurulumu

Kaynak: [Pricing.md, bölüm 3](../../Pricing.md). Değerler 7 Eylül 2026 tarihli **istenen fiyatlardır**; App Store Connect'te seçilmiş veya satışta olduğu doğrulanmış fiyatlar değildir.

## Neden 66 satır?

Planda **13 fiyat grubu** var. Avro çekirdeği Almanya, Fransa, Hollanda, Belçika, Avusturya, İrlanda ve Finlandiya'yı; Güney Avrupa İspanya, İtalya, Portekiz ve Yunanistan'ı kapsar. Tekil ülkelere açıldığında **22 storefront × 3 ürün = 66 satır** oluşur. Diğer avro kullanan ülkeler bu iki gruba kendiliğinden eklenmez.

[pricing-storefronts.csv](pricing-storefronts.csv) UTF-8, virgülle ayrılmış ve CRLF satır sonlu bir aktarım/kurulum çalışma listesidir. Doğrudan Apple API'sine gönderilecek hazır bir API payload'ı değildir.

| Alan | Kullanımı |
|---|---|
| `pricing_group`, `tier` | Kaynak plandaki grup ve T1–T4 katmanı |
| `storefront_alpha2` | İki harfli ülke kodu |
| `asc_territory_alpha3` | App Store Connect territory tanımlaması için üç harfli kod |
| `currency` | ISO para birimi; fiyat sembolden bağımsız sayıdır |
| `product_id`, `product_type` | Kaynak kod ve StoreKit ile birebir eşleşen kimlik ve ürün tipi |
| `subscription_group`, `period` | Aylık/yıllıkta `BookTracePro`, `P1M`/`P1Y`; lifetime'da boş |
| `proposed_price` | Kullanıcının planladığı fiyat; geçerli fiyat noktası olduğu varsayılmaz |
| `intro_trial_days` | Yalnızca yıllıkta 7; diğer ürünlerde 0 |
| `selected_asc_price` | Operatörün ASC'de gerçekten seçtiği fiyat; başlangıçta boş |
| `asc_price_point_id` | Varsa seçilmiş gerçek fiyat noktası kimliği; başlangıçta boş |
| `status` | Başlangıçta `PENDING_ASC_PRICE_POINT_VALIDATION` |

1. Her ürün için ABD başlangıç fiyatını seç.
2. CSV'deki her storefront'u tek tek aç. İstenen sayı listede yoksa ASC seçicisindeki en yakın uygun fiyatı değerlendir; gerçek seçim ile istenen sayı arasındaki farkı koru.
3. Gerçek değeri `selected_asc_price` sütununa ve mevcutsa fiyat noktası kimliğini yanına gir. Yalnızca doğrulanan satırın durumunu `CONFIRMED_IN_ASC` yap.
4. Liste dışında kalan storefront'lara ek el yapımı fiyat üretme. Aboneliklerin başlangıçtaki karşılaştırılabilir fiyat üretimini, sürekli otomatik kur güncellemesi olarak değerlendirme. Abonelik fiyatları ile lifetime gibi tek seferlik IAP'lerin fiyat yönetimi ayrı akışlardır. [Apple abonelik fiyat yönetimi](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions/), [Apple IAP fiyat yönetimi](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/set-a-price-for-an-in-app-purchase/).
5. Paywall'da gerçek `Product.displayPrice`, süre ve uygunluk görülmeli. Yıllık tasarruf, o storefront'un aylık ve yıllık fiyatlarından hesaplanmalı. Plandaki %48, ABD'de `1 − 24.99 / (3.99 × 12)` hesabının yuvarlanmış sonucudur; her ülkeye sabit uygulanmaz.
6. İndirim gerekiyorsa abonelik taban fiyatını değiştirip sonra geri yükseltmek yerine planın introductory-offer kararını uygula. Fiyat değişikliği sırasında Apple'ın güncel bildirim/onay akışını izleyerek mevcut abonelerin durumunu kontrol et; her artışın her bölgede aynı onay davranışına sahip olduğunu varsayma. [Apple fiyat değişikliği açıklaması](https://developer.apple.com/help/app-store-connect/manage-subscriptions/manage-pricing-for-auto-renewable-subscriptions/).

Bu tablo rakip fiyatlarını, döviz kuru tahminlerini, komisyon sonrası net gelirleri veya vergi oranlarını yeniden hesaplamaz. Gerçek para birimi fiyat noktaları ve Apple hesabındaki satış/uygunluk bilgisi girilene kadar kurulum beklemededir.
