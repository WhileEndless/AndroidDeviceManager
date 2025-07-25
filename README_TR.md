# Android Device Manager

ADB (Android Debug Bridge) aracılığıyla Android cihazları yönetmek için güçlü bir macOS menü çubuğu uygulaması.

## Versiyon
**Güncel Versiyon:** 1.1.0

## Özellikler

### Cihaz Yönetimi
- 📱 **Gerçek Zamanlı Cihaz Algılama**: Bağlı Android cihazları her 10 saniyede otomatik algılar
- ⚡ **Root Durumu Göstergesi**: Cihazın root erişimi varsa görsel gösterge
- 🔒 **Yetkilendirme Durumu**: Cihaz yetkilendirme durumunun net gösterimi
- 🔄 **Otomatik Cihaz Seçimi**: İlk bağlanan cihaz otomatik olarak seçilir
- 📡 **USB & WiFi Desteği**: Hem USB hem de kablosuz ADB bağlantılarıyla çalışır

### Temel İşlevler

#### Ekran Görüntüsü Alma
- 📸 Tek tıkla ekran görüntüsü al
- 🖼️ Varsayılan resim düzenleyicide otomatik açılır
- 📁 Özel klasörde düzenli depolama

#### Pano Entegrasyonu
- 📋 macOS pano içeriğini Android cihaza gönder (Cmd+V)
- ⌨️ İçeriği Android'de odaklanmış alana yazar

#### Shell Erişimi
- 🖥️ Terminal entegrasyonu ile hızlı shell erişimi
- 🚀 Tekrarlanan root izin istemlerini önleyen kalıcı shell oturumları
- 📝 Sık kullanılan komutlar için Hızlı Komutlar penceresi

#### Port Yönlendirme
- 🔀 İleri ve Geri port yönlendirme desteği
- 🔄 Cihaz bağlandığında otomatik geri port 8080 kurulumu
- 💾 Kalıcı port yönlendirme yapılandırmaları

#### Frida Server Yönetimi (Root Gerekli)
- 🔧 Frida sunucularını indir ve yükle
- 📦 Çoklu mimari desteği
- 🔄 Versiyon yönetimi

#### Logcat Görüntüleyici
- 📋 Renk kodlu seviyelerle gerçek zamanlı log görüntüleme
- 🔍 Paket adı ve log seviyesine göre filtreleme
- 💾 Logları dosyaya aktarma
- 🖥️ Tam ekran desteği
- ⌘A Tüm metni seçme desteği

#### Dosya Yöneticisi
- 📁 **Tam Dosya Sistemi Gezintisi**: Root desteğiyle tüm Android dosya sisteminde gezin
- 🔄 **Sürükle & Bırak Yükleme**: Finder'dan dosyaları sürükleyerek gerçek zamanlı ilerleme ile yükleyin
- 📥 **Toplu İndirme**: Birden fazla dosyayı yapılandırılabilir hedef konuma indirin
- ✏️ **Dosya İşlemleri**: Sağ tık menüsü ile yeniden adlandırma, silme ve yönetim
- 🔍 **Gerçek Zamanlı Arama**: Mevcut dizindeki dosyaları anında filtreleyin
- 🗄️ **SQLite Entegrasyonu**: .db dosyalarını Terminal'de sqlite3 ile doğrudan açın
- 📊 **Sütun Sıralama**: İsim, boyut veya değiştirilme tarihine göre sıralayın
- 🔙 **Gezinti Geçmişi**: Kolay gezinti için İleri/Geri butonları
- 🔗 **Sembolik Bağlantı Desteği**: Sembolik linkler üzerinden sorunsuz gezinti

### Kullanıcı Arayüzü
- 🎨 Temiz, yerel macOS arayüzü
- 📱 Detaylı özelliklerle cihaz bilgi penceresi
- ⚙️ Özelleştirme için tercihler
- ℹ️ Versiyon bilgisiyle hakkında penceresi

## Sistem Gereksinimleri
- macOS 10.14 (Mojave) veya üzeri
- ADB (Android Debug Bridge) kurulu ve PATH'te
- USB hata ayıklama etkin Android cihaz

## Kurulum

### DMG'den
1. En son DMG'yi releases'den indirin
2. DMG dosyasını açın
3. Android Device Manager'ı Uygulamalar'a sürükleyin
4. Uygulamalar klasöründen başlatın

### Kaynak Koddan
```bash
git clone https://github.com/WhileEndless/AndroidDeviceManager.git
cd AndroidDeviceManager
swift build -c release
```

## Kullanım

1. **Android cihazınızı bağlayın** USB veya WiFi ile
2. **USB hata ayıklamayı etkinleştirin** Android cihazınızda
3. **Android Device Manager'ı başlatın** - menü çubuğunda 📱 olarak görünecek
4. Tüm özelliklere erişmek için menü çubuğu simgesine tıklayın

### Klavye Kısayolları
- **Cmd+S**: Ekran Görüntüsü Al
- **Cmd+V**: Panoyu Cihaza Gönder
- **Cmd+T**: Terminal Aç
- **Cmd+R**: Cihazları Yenile
- **Cmd+,**: Tercihleri Aç
- **Cmd+Q**: Çıkış

### Logcat Görüntüleyicide
- **Cmd+A**: Tüm Metni Seç

## Kaynak Koddan Derleme

### Önkoşullar
- Xcode 12.0 veya üzeri
- Swift 5.3 veya üzeri

### Derleme Adımları
```bash
# Depoyu klonla
git clone https://github.com/WhileEndless/AndroidDeviceManager.git
cd AndroidDeviceManager

# Uygulamayı derle
swift build -c release

# Veya derleme scriptini kullan
./build_app.sh
```

## Mimari

### Proje Yapısı
```
AndroidDeviceManager/
├── Sources/
│   ├── Models/          # Veri modelleri
│   ├── Managers/        # İş mantığı
│   ├── Services/        # ADB ve shell servisleri
│   ├── Windows/         # UI pencereleri
│   └── StatusBarController.swift
├── Resources/           # Varlıklar ve kaynaklar
└── Tests/              # Birim testler
```

### Ana Bileşenler
- **StatusBarController**: Ana menü çubuğu arayüzü
- **DeviceManager**: Cihaz keşfi ve yönetimi
- **ShellSessionManager**: Kalıcı shell oturum yönetimi
- **ADBClient**: ADB komut arayüzü

## Katkıda Bulunma

1. Depoyu fork'layın
2. Özellik dalınızı oluşturun (`git checkout -b feature/harika-ozellik`)
3. Değişikliklerinizi commit edin (`git commit -m 'Harika özellik ekle'`)
4. Dala push yapın (`git push origin feature/harika-ozellik`)
5. Pull Request açın

## Lisans

Bu proje GNU Affero General Public License v3.0 altında lisanslanmıştır - detaylar için LICENSE dosyasına bakın.

## Geliştirme

Bu proje, Claude Code'un Opus modeli kullanılarak geliştirilmiş olup, yapay zeka destekli yazılım geliştirmenin yeteneklerini göstermektedir. Tüm uygulama mimarisi, uygulaması ve optimizasyonları Claude ile işbirliği içinde geliştirilmiştir.

## Teşekkür

- Swift ve Cocoa (AppKit) ile geliştirildi
- Android Debug Bridge (ADB) kullanır
- Frida dinamik enstrümantasyon araç seti desteği
- Claude Code (Opus modeli) ile geliştirildi

## Destek

Sorunlar ve özellik istekleri için lütfen ziyaret edin:
https://github.com/WhileEndless/AndroidDeviceManager/issues

---
© 2025 WhileEndless