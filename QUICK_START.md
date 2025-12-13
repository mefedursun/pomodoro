# 🚀 Hızlı Başlangıç - GitHub'a Yayınlama

## ✅ Yapılan İşlemler

1. ✅ Git repository başlatıldı
2. ✅ Tüm dosyalar commit edildi
3. ✅ GitHub Actions workflow hazırlandı
4. ✅ Web build test edildi

## 📋 Şimdi Yapmanız Gerekenler

### 1. GitHub'da Repository Oluşturun

1. https://github.com/new adresine gidin
2. Repository bilgilerini doldurun:
   - **Repository name**: `pomodoro`
   - **Description**: "A beautiful Pomodoro timer app with task management"
   - **Public** seçin
   - **Initialize this repository with a README** seçmeyin (zaten var)
3. **"Create repository"** butonuna tıklayın

### 2. Remote Ekleme ve Push

Repository oluşturduktan sonra, terminal'de şu komutları çalıştırın:

```bash
git remote add origin https://github.com/mefedursun/pomodoro.git
git push -u origin main
```

**VEYA** Cursor'ın Source Control panelinden:
1. Source Control (Ctrl+Shift+G) açın
2. "Publish Branch" butonuna tıklayın
3. Repository adını `pomodoro` olarak girin
4. Public olarak seçin
5. Publish'e tıklayın

### 3. GitHub Pages'i Aktif Edin

1. GitHub repository'nize gidin: https://github.com/mefedursun/pomodoro
2. **Settings** sekmesine tıklayın
3. Sol menüden **Pages** seçin
4. **Source** kısmından **"GitHub Actions"** seçin
5. **Save** butonuna tıklayın

### 4. İlk Deploy'u Başlatın

1. Repository'de **Actions** sekmesine gidin
2. **"Deploy to GitHub Pages"** workflow'unu bulun
3. **"Run workflow"** butonuna tıklayın
4. Workflow çalışmaya başlayacak (5-10 dakika sürebilir)

## 🎉 Tamamlandı!

Deploy tamamlandıktan sonra (5-10 dakika), uygulamanız şu adreste canlı olacak:

**🌐 Live Demo**: https://mefedursun.github.io/pomodoro/

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

