# CepArazi Native Kotlin

Basit ve stabil Android arazi uygulaması. Flutter/Dart kullanılmaz.

## Mevcut aşama
- Kotlin + Jetpack Compose
- 5 ekranlı alt menü: Harita / Aplikasyon / Noktalar / Çizim / Dosya
- Telefon GNSS konumu ve doğruluk göstergesi
- NCN içe/dışa aktarma
- NCN nokta listesi ve hedef seçimi
- Basit Çizgi / Poligon arayüzü
- Aplikasyon hedef akışı
- GitHub Actions ile debug APK derleme altyapısı

## Bilerek henüz tamamlanmayanlar
- Gerçek harita SDK katmanı (uydu/normal)
- Harita üzerinde dokunarak çizgi/poligon köşesi verme
- TUREF/ITRF 3° TM / DOM dönüşüm motoru
- Sürekli canlı GNSS güncellemesi
- Proje/nokta/çizim kalıcı veritabanı

> Telefon GNSS'i kadastro hassasiyetinde kabul edilmez. Uygulama GNSS doğruluğunu kullanıcıya açıkça gösterir.
