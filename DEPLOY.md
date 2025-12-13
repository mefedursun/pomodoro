# 🚀 GitHub Pages Deployment Guide

Bu dosya, uygulamayı GitHub Pages'de canlı demo olarak yayınlamak için adımları içerir.

## 📋 Adımlar

### 1. GitHub Repository Oluşturma

1. GitHub'da yeni bir repository oluşturun
2. Repository adını `pomodoro` olarak ayarlayın (veya istediğiniz isim)
3. Repository'yi public yapın (GitHub Pages için gerekli)

### 2. Kodu GitHub'a Push Etme

```bash
# Git repository'yi başlat (eğer yoksa)
git init

# Tüm dosyaları ekle
git add .

# İlk commit
git commit -m "Initial commit: Pomodoro Timer App"

# GitHub repository'nizi ekleyin (your-username yerine kendi kullanıcı adınızı yazın)
git remote add origin https://github.com/your-username/pomodoro.git

# Main branch'e push edin
git branch -M main
git push -u origin main
```

### 3. GitHub Pages'i Aktif Etme

#### Otomatik Deploy (GitHub Actions - Önerilen)

1. Repository Settings → Pages
2. Source: "GitHub Actions" seçin
3. `.github/workflows/deploy.yml` dosyası otomatik olarak çalışacak
4. Her push'ta otomatik olarak deploy edilecek

#### Manuel Deploy

1. Web build oluşturun:
   ```bash
   flutter build web --release --base-href "/pomodoro/"
   ```

2. `build/web` klasöründeki tüm dosyaları kopyalayın

3. Repository'de `gh-pages` branch'i oluşturun:
   ```bash
   git checkout --orphan gh-pages
   git rm -rf .
   # build/web içindeki dosyaları buraya kopyalayın
   git add .
   git commit -m "Deploy to GitHub Pages"
   git push origin gh-pages
   ```

4. Repository Settings → Pages
5. Source: "gh-pages branch" seçin
6. Save

### 4. README.md'deki Link'i Güncelleme

`README.md` dosyasındaki live demo linkini kendi repository URL'inizle değiştirin:

```markdown
**[Try it in your browser!](https://your-username.github.io/pomodoro/)**
```

`your-username` yerine kendi GitHub kullanıcı adınızı yazın.

### 5. Repository Adı Farklıysa

Eğer repository adınız `pomodoro` değilse:

1. `.github/workflows/deploy.yml` dosyasındaki `base-href` değerini değiştirin:
   ```yaml
   run: flutter build web --release --base-href "/your-repo-name/"
   ```

2. README.md'deki linkleri güncelleyin

## ✅ Kontrol Listesi

- [ ] GitHub repository oluşturuldu
- [ ] Kod push edildi
- [ ] GitHub Actions workflow çalıştı (Actions sekmesinde kontrol edin)
- [ ] GitHub Pages aktif edildi
- [ ] Live demo linki çalışıyor
- [ ] README.md güncellendi

## 🔗 Live Demo URL Formatı

```
https://your-username.github.io/repository-name/
```

Örnek:
```
https://mefedursun.github.io/pomodoro/
```

## 🐛 Sorun Giderme

### Build hatası alıyorsanız:
```bash
flutter clean
flutter pub get
flutter build web --release
```

### GitHub Actions çalışmıyorsa:
- Repository Settings → Actions → General
- "Allow all actions and reusable workflows" seçin
- Save

### Sayfa yüklenmiyor:
- GitHub Pages'in aktif olduğundan emin olun
- URL'nin doğru olduğunu kontrol edin
- Birkaç dakika bekleyin (deploy zaman alabilir)

## 📝 Notlar

- İlk deploy 5-10 dakika sürebilir
- Sonraki deploy'lar daha hızlı olacak
- Her push'ta otomatik deploy yapılır
- `gh-pages` branch'i otomatik oluşturulur

