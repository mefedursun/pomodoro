# 🚀 Hızlı Başlangıç

## ✅ Hazırlanan İşlemler

- ✅ Git repository başlatıldı
- ✅ Tüm dosyalar commit edildi
- ✅ GitHub Actions workflow hazırlandı
- ✅ Web build test edildi
- ✅ README.md güncellendi

## 📋 GitHub'a Yayınlama

### 1. Repository Oluşturma

1. https://github.com/new adresine gidin
2. **Repository name**: `pomodoro`
3. **Description**: "A beautiful Pomodoro timer app with task management"
4. **Public** seçin
5. **Create repository** butonuna tıklayın

### 2. Push Etme

**Cursor Source Control ile:**
1. Source Control (Ctrl+Shift+G) açın
2. **"Publish Branch"** butonuna tıklayın
3. Repository adı: `pomodoro`
4. **Public** seçin
5. **Publish** butonuna tıklayın

**VEYA Terminal ile:**
```bash
git remote add origin https://github.com/mefedursun/pomodoro.git
git push -u origin main
```

### 3. GitHub Pages Aktif Etme

1. https://github.com/mefedursun/pomodoro → **Settings** → **Pages**
2. **Source**: **"GitHub Actions"** seçin
3. **Save**

### 4. İlk Deploy

1. **Actions** sekmesine gidin
2. **"Deploy to GitHub Pages"** workflow'unu bulun
3. **"Run workflow"** → **"Run workflow"** butonuna tıklayın
4. 5-10 dakika bekleyin

## 🎉 Tamamlandı!

**Live Demo**: https://mefedursun.github.io/pomodoro/

## 🔄 Güncelleme

Her değişiklikten sonra:
```bash
git add .
git commit -m "Update message"
git push
```

GitHub Actions otomatik deploy edecek!
