# 🚀 GitHub'a Yayınlama Adımları

## 1️⃣ GitHub Repository Oluşturma

1. GitHub.com'a gidin ve giriş yapın
2. Sağ üstteki **"+"** butonuna tıklayın → **"New repository"**
3. Repository bilgilerini doldurun:
   - **Repository name**: `pomodoro` (veya istediğiniz isim)
   - **Description**: "A beautiful Pomodoro timer app with task management"
   - **Public** seçin (GitHub Pages için gerekli)
   - **Initialize this repository with a README** seçmeyin (zaten var)
4. **"Create repository"** butonuna tıklayın

## 2️⃣ Kodu GitHub'a Push Etme

Terminal'de şu komutları çalıştırın:

```bash
# Git repository'yi başlat (eğer daha önce yapmadıysanız)
git init

# Tüm dosyaları ekle
git add .

# İlk commit
git commit -m "Initial commit: Pomodoro Timer App with web support"

# GitHub repository'nizi ekleyin (your-username yerine kendi kullanıcı adınızı yazın)
git remote add origin https://github.com/your-username/pomodoro.git

# Main branch'e push edin
git branch -M main
git push -u origin main
```

**Not**: `your-username` yerine kendi GitHub kullanıcı adınızı yazın.

## 3️⃣ GitHub Pages'i Aktif Etme

### Otomatik Deploy (Önerilen - GitHub Actions)

1. GitHub repository'nize gidin
2. **Settings** sekmesine tıklayın
3. Sol menüden **Pages** seçin
4. **Source** kısmından **"GitHub Actions"** seçin
5. **Save** butonuna tıklayın

Artık her push'ta otomatik olarak deploy edilecek!

### İlk Deploy'u Tetikleme

1. Repository'de **Actions** sekmesine gidin
2. **"Deploy to GitHub Pages"** workflow'unu bulun
3. **"Run workflow"** butonuna tıklayın
4. Workflow çalışmaya başlayacak (5-10 dakika sürebilir)

## 4️⃣ Live Demo Linki

Deploy tamamlandıktan sonra (5-10 dakika), uygulamanız şu adreste canlı olacak:

```
https://your-username.github.io/pomodoro/
```

**Örnek**: Eğer GitHub kullanıcı adınız `mefedursun` ise:
```
https://mefedursun.github.io/pomodoro/
```

## 5️⃣ README.md'yi Güncelleme

`README.md` dosyasındaki live demo linkini kendi URL'inizle değiştirin:

1. `README.md` dosyasını açın
2. `your-username` yerine kendi GitHub kullanıcı adınızı yazın
3. Değişiklikleri commit edin:
   ```bash
   git add README.md
   git commit -m "Update README with live demo link"
   git push
   ```

## ✅ Kontrol Listesi

- [ ] GitHub repository oluşturuldu
- [ ] Kod push edildi
- [ ] GitHub Pages aktif edildi (GitHub Actions)
- [ ] İlk deploy tamamlandı (Actions sekmesinde kontrol edin)
- [ ] Live demo linki çalışıyor
- [ ] README.md güncellendi

## 🎉 Tamamlandı!

Artık uygulamanız Chrome ve diğer tarayıcılarda çalışıyor! 

**Live Demo**: `https://your-username.github.io/pomodoro/`

## 🔄 Güncelleme Yapmak İçin

Her değişiklikten sonra:

```bash
git add .
git commit -m "Your commit message"
git push
```

GitHub Actions otomatik olarak yeni versiyonu deploy edecek!

## 🐛 Sorun Giderme

### GitHub Actions çalışmıyor:
- Repository Settings → Actions → General
- "Allow all actions and reusable workflows" seçin
- Save

### Sayfa yüklenmiyor:
- GitHub Pages'in aktif olduğundan emin olun
- Actions sekmesinde deploy'un başarılı olduğunu kontrol edin
- Birkaç dakika bekleyin (deploy zaman alabilir)

### Build hatası:
```bash
flutter clean
flutter pub get
flutter build web --release --base-href "/pomodoro/"
```

